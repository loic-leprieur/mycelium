import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../database.dart';
import '../photo_store.dart';
import 'backup_codec.dart';
import 'backup_format.dart';
import 'backup_zip.dart';

/// Comment appliquer une sauvegarde à des données déjà présentes.
enum RestoreMode {
  /// Ajoute ce qui manque (par identifiant) sans rien supprimer ni modifier.
  merge,

  /// Efface les données actuelles, puis importe la sauvegarde.
  replace,
}

enum BackupPhase {
  /// Lecture des tables.
  collecting,

  /// Écriture de l'archive (photos une à une).
  packing,

  /// Lecture et vérification de l'archive.
  reading,

  /// Recopie des photos.
  photos,

  /// Écriture dans la base.
  saving,
}

class BackupProgress {
  const BackupProgress(this.phase, {this.done = 0, this.total = 0});

  final BackupPhase phase;
  final int done;
  final int total;

  /// Avancement de 0 à 1, ou null s'il n'est pas mesurable.
  double? get fraction => total > 0 ? (done / total).clamp(0, 1).toDouble() : null;
}

typedef BackupProgressCallback = void Function(BackupProgress progress);

/// Retrouve le fichier d'une photo enregistrée en base (chemin relatif ou ancien
/// chemin absolu). Par défaut `resolveStoredPhoto`, qui retrouve aussi une photo
/// dont l'ancien chemin pointe vers un autre conteneur de l'application.
typedef PhotoResolver = Future<File?> Function(String? stored);

/// Archive créée, prête à être partagée ou enregistrée.
class BackupArchive {
  const BackupArchive({
    required this.file,
    required this.createdAt,
    required this.counts,
    required this.missingPhotos,
    required this.sizeBytes,
  });

  final File file;
  final DateTime createdAt;

  /// Contenu de l'archive (dont `photos` : fichiers réellement inclus).
  final BackupCounts counts;

  /// Photos référencées mais introuvables sur l'appareil (non incluses).
  final int missingPhotos;
  final int sizeBytes;

  String get fileName => p.basename(file.path);
}

/// Ce que contient une archive, avant de la restaurer.
class BackupPreview {
  const BackupPreview({
    required this.createdAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.counts,
    required this.missingPhotos,
  });

  final DateTime createdAt;
  final String appVersion;
  final int schemaVersion;
  final BackupCounts counts;
  final int missingPhotos;
}

/// Compte rendu d'une restauration.
class RestoreReport {
  const RestoreReport({
    required this.mode,
    required this.added,
    required this.alreadyPresent,
    required this.photosCopied,
  });

  final RestoreMode mode;

  /// Lignes écrites dans la base.
  final BackupCounts added;

  /// Lignes de l'archive déjà présentes (fusion seulement) : laissées telles quelles.
  final BackupCounts alreadyPresent;

  /// Photos recopiées dans le dossier de l'application.
  final int photosCopied;
}

/// Sauvegarde et restauration (DATA-2), suppression totale (DATA-4).
///
/// Prend la base et le dossier des photos en paramètres : aucun état global,
/// donc testable avec une base en mémoire et un dossier temporaire. Le travail
/// lourd (archive, photos, sommes de contrôle) tourne dans un autre isolate.
class BackupService {
  BackupService({
    required this.db,
    required this.photosRoot,
    this.resolvePhoto = resolveStoredPhoto,
    this.appVersion = backupAppVersion,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase db;

  /// Dossier des Documents de l'application : contient `harvest_photos/`,
  /// `species_photos/` et `identification_photos/`.
  final Directory photosRoot;
  final PhotoResolver resolvePhoto;
  final String appVersion;
  final DateTime Function() _clock;

  // --- Date de la dernière sauvegarde ---

  Future<DateTime?> lastBackupAt() async {
    final raw = await db.metaValue(lastBackupKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  /// À appeler une fois l'archive réellement confiée à l'utilisateur
  /// (partagée ou enregistrée).
  Future<void> markBackupDone(DateTime at) =>
      db.setMeta(lastBackupKey, at.toUtc().toIso8601String());

  // --- Export ---

  /// Crée `mycelium-sauvegarde-AAAA-MM-JJ.zip` dans [outputDir]. Les archives
  /// précédentes de ce dossier sont supprimées (elles contiennent des positions GPS).
  Future<BackupArchive> createArchive({
    required Directory outputDir,
    DateTime? now,
    BackupProgressCallback? onProgress,
  }) async {
    final createdAt = now ?? _clock();
    onProgress?.call(const BackupProgress(BackupPhase.collecting));
    try {
      // Instantané cohérent : aucune écriture ne s'intercale entre deux tables.
      final snap = await db.transaction(() async => (
            spots: await db.select(db.spots).get(),
            outings: await db.select(db.outings).get(),
            harvests: await db.select(db.harvests).get(),
            customSpecies: await db.select(db.customSpecies).get(),
            identifications: await db.select(db.identifications).get(),
            spotSpecies: await db.select(db.spotSpecies).get(),
            appMeta: await db.select(db.appMeta).get(),
          ));

      final photos = _PhotoCollector(resolvePhoto);
      final harvests = [
        for (final h in snap.harvests)
          harvestJson(h, await photos.add(h.photoPath, harvestPhotoFolder)),
      ];
      final customSpecies = [
        for (final r in snap.customSpecies)
          customSpeciesJson(r, await photos.add(r.photoPath, speciesPhotoFolder)),
      ];
      final identifications = [
        for (final i in snap.identifications)
          identificationJson(i, (await photos.add(i.photoPath, identificationPhotoFolder)) ?? ''),
      ];
      // Le consentement reste sur l'appareil. La date de sauvegarde est celle de
      // CETTE archive : restaurée telle quelle, elle dit « sauvegardé le … ».
      final meta = <String, String>{
        for (final r in snap.appMeta)
          if (!isConsentKey(r.key)) r.key: r.value,
        lastBackupKey: createdAt.toUtc().toIso8601String(),
      };

      final counts = BackupCounts(
        spots: snap.spots.length,
        outings: snap.outings.length,
        harvests: snap.harvests.length,
        customSpecies: snap.customSpecies.length,
        identifications: snap.identifications.length,
        spotSpecies: snap.spotSpecies.length,
        appMeta: meta.length,
        photos: photos.files.length,
      );
      final missing = (photos.missing.toList()..sort());
      final manifest = BackupManifest(
        appVersion: appVersion,
        schemaVersion: db.schemaVersion,
        createdAt: createdAt,
        counts: counts,
        missingPhotos: missing,
      );
      final dataJson = encodeData(
        spots: [for (final s in snap.spots) spotJson(s)],
        outings: [for (final o in snap.outings) outingJson(o)],
        harvests: harvests,
        customSpecies: customSpecies,
        identifications: identifications,
        spotSpecies: [for (final r in snap.spotSpecies) spotSpeciesJson(r)],
        appMeta: meta,
      );

      await outputDir.create(recursive: true);
      await _deleteOldArchives(outputDir);
      final target = File(p.join(outputDir.path, backupFileName(createdAt)));
      final partial = File('${target.path}.part');

      final entries = photos.files.entries.map((e) => (e.key, e.value)).toList();
      final progress = ReceivePort();
      final subscription = progress.listen((message) {
        if (message is int) {
          onProgress?.call(BackupProgress(BackupPhase.packing, done: message, total: entries.length));
        }
      });
      onProgress?.call(BackupProgress(BackupPhase.packing, total: entries.length));
      try {
        await writeArchiveInBackground(WriteArchiveJob(
          zipPath: partial.path,
          manifestJson: manifest.toJsonText(),
          dataJson: dataJson,
          photos: entries,
          progress: progress.sendPort,
        ));
        await partial.rename(target.path);
      } catch (_) {
        await _deleteQuietly(partial);
        rethrow;
      } finally {
        await subscription.cancel();
        progress.close();
      }

      return BackupArchive(
        file: target,
        createdAt: createdAt,
        counts: counts,
        missingPhotos: missing.length,
        sizeBytes: await target.length(),
      );
    } on BackupException {
      rethrow;
    } catch (e) {
      throw BackupException(
        BackupErrorKind.failed,
        'La sauvegarde n\'a pas pu être créée. Vérifiez l\'espace disponible sur l\'appareil.',
        detail: '$e',
      );
    }
  }

  // --- Import ---

  /// Lit et valide [archive] sans RIEN écrire, et dit ce qu'elle contient.
  /// Lève une [BackupException] (en français) si elle n'est pas utilisable.
  Future<BackupPreview> inspect(File archive) async {
    final parsed = await _read(archive);
    return BackupPreview(
      createdAt: parsed.manifest.createdAt,
      appVersion: parsed.manifest.appVersion,
      schemaVersion: parsed.manifest.schemaVersion,
      counts: parsed.counts,
      missingPhotos: parsed.manifest.missingPhotos.length,
    );
  }

  Future<ParsedBackup> _read(File archive) async {
    try {
      return await inspectArchiveInBackground(InspectJob(archive.path, db.schemaVersion));
    } on BackupException {
      rethrow;
    } catch (e) {
      throw BackupException(
        BackupErrorKind.corrupted,
        'La sauvegarde est endommagée ou incomplète : elle ne peut pas être lue.',
        detail: '$e',
      );
    }
  }

  /// Restaure [archive]. Tout est vérifié AVANT la première écriture ; ensuite
  /// les photos puis la base sont mises à jour de façon annulable : si quelque
  /// chose échoue, rien n'a changé (ni la base, ni les photos).
  Future<RestoreReport> restore(
    File archive, {
    RestoreMode mode = RestoreMode.merge,
    BackupProgressCallback? onProgress,
  }) async {
    onProgress?.call(const BackupProgress(BackupPhase.reading));
    final data = await _read(archive);

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final staging = Directory(p.join(photosRoot.path, '$_stagingPrefix$stamp'));
    final trash = Directory(p.join(photosRoot.path, '$_trashPrefix$stamp'));
    var keepTrash = false;
    try {
      await photosRoot.create(recursive: true);
      await _deleteLeftovers();

      // A. Photos à recopier : toutes en remplacement ; en fusion, celles qui
      // manquent sur l'appareil (aucune photo existante n'est écrasée).
      final wanted = mode == RestoreMode.replace
          ? data.photoPaths
          : [
              for (final rel in data.photoPaths)
                if (!await File(p.join(photosRoot.path, rel)).exists()) rel,
            ];
      var copied = 0;
      if (wanted.isNotEmpty) {
        await staging.create(recursive: true);
        final progress = ReceivePort();
        final subscription = progress.listen((message) {
          if (message is int) {
            onProgress?.call(BackupProgress(BackupPhase.photos, done: message, total: wanted.length));
          }
        });
        onProgress?.call(BackupProgress(BackupPhase.photos, total: wanted.length));
        try {
          copied = await extractPhotosInBackground(ExtractJob(
            zipPath: archive.path,
            targetPath: staging.path,
            photoPaths: wanted,
            progress: progress.sendPort,
          ));
        } finally {
          await subscription.cancel();
          progress.close();
        }
      }

      // B. Mise en place des photos (annulable).
      final undo = mode == RestoreMode.replace
          ? await _swapPhotoFolders(staging, trash)
          : await _addPhotos(staging, wanted);

      // C. Base de données : une seule transaction.
      onProgress?.call(const BackupProgress(BackupPhase.saving));
      try {
        final applied = await _apply(data, mode);
        // D. Les anciennes photos (remplacement) ne servent plus.
        return RestoreReport(
          mode: mode,
          added: applied.added,
          alreadyPresent: applied.alreadyPresent,
          photosCopied: copied,
        );
      } catch (e) {
        keepTrash = !await _tryUndo(undo);
        if (e is BackupException) rethrow;
        throw BackupException(
          BackupErrorKind.failed,
          'La restauration a échoué : vos données n\'ont pas été modifiées.',
          detail: '$e',
        );
      }
    } on BackupException {
      rethrow;
    } catch (e) {
      throw BackupException(
        BackupErrorKind.failed,
        'La restauration a échoué : vos données n\'ont pas été modifiées.',
        detail: '$e',
      );
    } finally {
      await _deleteQuietly(staging);
      // Si le retour en arrière n'a pas pu remettre les anciennes photos en
      // place, elles restent dans ce dossier plutôt que d'être perdues.
      if (!keepTrash) await _deleteQuietly(trash);
    }
  }

  Future<bool> _tryUndo(Future<void> Function() undo) async {
    try {
      await undo();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Fusion : déplace les photos extraites dans les dossiers de l'application,
  /// sans jamais écraser un fichier existant. Renvoie l'annulation.
  Future<Future<void> Function()> _addPhotos(Directory staging, List<String> wanted) async {
    final created = <File>[];
    Future<void> undo() async {
      for (final file in created) {
        await _deleteQuietly(file);
      }
    }

    try {
      for (final rel in wanted) {
        final target = File(p.join(photosRoot.path, rel));
        if (await target.exists()) continue;
        await target.parent.create(recursive: true);
        await File(p.join(staging.path, rel)).rename(target.path);
        created.add(target);
      }
    } catch (_) {
      await undo();
      rethrow;
    }
    return undo;
  }

  /// Remplacement : met les dossiers de photos actuels de côté dans [trash],
  /// puis installe ceux extraits. Renvoie l'annulation (qui remet tout en place).
  Future<Future<void> Function()> _swapPhotoFolders(Directory staging, Directory trash) async {
    final setAside = <String>[];
    final installed = <String>[];
    Future<void> undo() async {
      for (final folder in installed) {
        await _deleteQuietly(Directory(p.join(photosRoot.path, folder)));
      }
      for (final folder in setAside) {
        await Directory(p.join(trash.path, folder)).rename(p.join(photosRoot.path, folder));
      }
    }

    try {
      for (final folder in photoFolders) {
        final live = Directory(p.join(photosRoot.path, folder));
        if (!await live.exists()) continue;
        await trash.create(recursive: true);
        await live.rename(p.join(trash.path, folder));
        setAside.add(folder);
      }
      for (final folder in photoFolders) {
        final extracted = Directory(p.join(staging.path, folder));
        if (!await extracted.exists()) continue;
        await extracted.rename(p.join(photosRoot.path, folder));
        installed.add(folder);
      }
    } catch (_) {
      await undo();
      rethrow;
    }
    return undo;
  }

  Future<_Applied> _apply(ParsedBackup data, RestoreMode mode) => db.transaction(() async {
        final replace = mode == RestoreMode.replace;
        final wasEmpty = await _hasNoData();
        if (replace) await _clearTables(keepConsent: true);

        // Insertion par identifiant : une ligne déjà présente n'est jamais modifiée.
        Future<BackupCounts> insertNew<T>(
          Set<String> existing,
          List<T> rows,
          String Function(T) idOf,
          Future<void> Function(List<T>) insert,
          BackupCounts Function(int added, int present) counts,
        ) async {
          final fresh = [for (final r in rows) if (existing.add(idOf(r))) r];
          if (fresh.isNotEmpty) await insert(fresh);
          return counts(fresh.length, rows.length - fresh.length);
        }

        final added = <BackupCounts>[];
        final present = <BackupCounts>[];
        void record(Future<BackupCounts> Function(bool isAdded) _) {}

        final spots = await _insertNew(
          existing: {for (final r in await db.select(db.spots).get()) r.id},
          rows: data.spots,
          idOf: (r) => r.id,
          insert: (rows) => db.batch((b) => b.insertAll(db.spots, rows)),
        );
        final outings = await _insertNew(
          existing: {for (final r in await db.select(db.outings).get()) r.id},
          rows: data.outings,
          idOf: (r) => r.id,
          insert: (rows) => db.batch((b) => b.insertAll(db.outings, rows)),
        );
        final harvests = await _insertNew(
          existing: {for (final r in await db.select(db.harvests).get()) r.id},
          rows: data.harvests,
          idOf: (r) => r.id,
          insert: (rows) => db.batch((b) => b.insertAll(db.harvests, rows)),
        );
        final customSpecies = await _insertNew(
          existing: {for (final r in await db.select(db.customSpecies).get()) r.id},
          rows: data.customSpecies,
          idOf: (r) => r.id,
          insert: (rows) => db.batch((b) => b.insertAll(db.customSpecies, rows)),
        );
        final identifications = await _insertNew(
          existing: {for (final r in await db.select(db.identifications).get()) r.id},
          rows: data.identifications,
          idOf: (r) => r.id,
          insert: (rows) => db.batch((b) => b.insertAll(db.identifications, rows)),
        );

        // Espèces d'un coin : `markSpeciesSeen` garde la date la plus récente.
        final knownPairs = {
          for (final r in await db.select(db.spotSpecies).get()) '${r.spotId}\u0000${r.speciesId}',
        };
        var newPairs = 0;
        for (final r in data.spotSpecies) {
          if (knownPairs.add('${r.spotId}\u0000${r.speciesId}')) newPairs++;
          await db.markSpeciesSeen(r.spotId, r.speciesId, r.lastSeenAt);
        }

        // Valeurs persistantes : une clé déjà présente garde sa valeur locale
        // (réglages de cet appareil). Le consentement n'est jamais importé.
        final localMeta = {for (final r in await db.select(db.appMeta).get()) r.key: r.value};
        var newMeta = 0;
        for (final e in data.appMeta.entries) {
          if (e.key == lastBackupKey || localMeta.containsKey(e.key)) continue;
          await db.setMeta(e.key, e.value);
          newMeta++;
        }
        // Les données de cet appareil sont celles de l'archive (remplacement, ou
        // fusion dans une base vide) : l'archive EST la dernière sauvegarde.
        if (replace || wasEmpty) {
          await db.setMeta(lastBackupKey, data.manifest.createdAt.toUtc().toIso8601String());
        }

        return _Applied(
          added: BackupCounts(
            spots: spots.$1,
            outings: outings.$1,
            harvests: harvests.$1,
            customSpecies: customSpecies.$1,
            identifications: identifications.$1,
            spotSpecies: newPairs,
            appMeta: newMeta,
          ),
          alreadyPresent: BackupCounts(
            spots: spots.$2,
            outings: outings.$2,
            harvests: harvests.$2,
            customSpecies: customSpecies.$2,
            identifications: identifications.$2,
            spotSpecies: data.spotSpecies.length - newPairs,
          ),
        );
      });

  /// Insère les lignes de [rows] dont l'identifiant n'est pas dans [existing].
  /// Renvoie (insérées, déjà présentes).
  Future<(int, int)> _insertNew<T>({
    required Set<String> existing,
    required List<T> rows,
    required String Function(T) idOf,
    required Future<void> Function(List<T>) insert,
  }) async {
    final fresh = [for (final r in rows) if (existing.add(idOf(r))) r];
    if (fresh.isNotEmpty) await insert(fresh);
    return (fresh.length, rows.length - fresh.length);
  }

  Future<bool> _hasNoData() async {
    Future<bool> empty<R>(Future<List<R>> Function() firstRow) async => (await firstRow()).isEmpty;
    return await empty(() => (db.select(db.spots)..limit(1)).get()) &&
        await empty(() => (db.select(db.outings)..limit(1)).get()) &&
        await empty(() => (db.select(db.harvests)..limit(1)).get()) &&
        await empty(() => (db.select(db.customSpecies)..limit(1)).get()) &&
        await empty(() => (db.select(db.identifications)..limit(1)).get());
  }

  /// Vide toutes les tables. [keepConsent] garde les clés `consent_*` d'`appMeta`.
  Future<void> _clearTables({required bool keepConsent}) async {
    await db.delete(db.spotSpecies).go();
    await db.delete(db.harvests).go();
    await db.delete(db.outings).go();
    await db.delete(db.identifications).go();
    await db.delete(db.customSpecies).go();
    await db.delete(db.spots).go();
    final keys = [
      for (final r in await db.select(db.appMeta).get())
        if (!keepConsent || !isConsentKey(r.key)) r.key,
    ];
    if (keys.isNotEmpty) await (db.delete(db.appMeta)..where((t) => t.key.isIn(keys))).go();
  }

  // --- Suppression totale (DATA-4) ---

  /// Supprime TOUTES les données : toutes les tables (consentement compris, donc
  /// l'application redevient « neuve ») et tous les dossiers de photos. Efface
  /// aussi les archives de [archiveDir] (elles contiennent les positions GPS).
  Future<void> deleteEverything({Directory? archiveDir}) async {
    try {
      await db.transaction(() => _clearTables(keepConsent: false));
    } catch (e) {
      throw BackupException(
        BackupErrorKind.failed,
        'La suppression a échoué : vos données n\'ont pas été modifiées.',
        detail: '$e',
      );
    }

    final problems = <String>[];
    Future<void> remove(FileSystemEntity entity) async {
      try {
        if (await entity.exists()) await entity.delete(recursive: true);
      } catch (e) {
        problems.add('${p.basename(entity.path)} : $e');
      }
    }

    for (final folder in photoFolders) {
      await remove(Directory(p.join(photosRoot.path, folder)));
    }
    await _deleteLeftovers();
    if (archiveDir != null) await _deleteOldArchives(archiveDir);

    // Les lignes supprimées resteraient lisibles dans les pages libres du
    // fichier SQLite : on le réécrit pour que les positions GPS disparaissent.
    try {
      await db.customStatement('VACUUM');
    } catch (_) {
      // Sans conséquence sur la suppression elle-même.
    }

    if (problems.isNotEmpty) {
      throw BackupException(
        BackupErrorKind.failed,
        'Vos données ont été supprimées, mais certaines photos n\'ont pas pu être effacées. '
        'Recommencez la suppression.',
        detail: problems.join('; '),
      );
    }
  }

  // --- Fichiers temporaires ---

  static const _stagingPrefix = '.mycelium_import_';
  static const _trashPrefix = '.mycelium_replaced_';

  /// Restes d'une restauration interrompue (extraction ou anciennes photos).
  Future<void> _deleteLeftovers() async {
    if (!await photosRoot.exists()) return;
    await for (final entity in photosRoot.list()) {
      final name = p.basename(entity.path);
      if (name.startsWith(_stagingPrefix) || name.startsWith(_trashPrefix)) {
        await _deleteQuietly(entity);
      }
    }
  }

  Future<void> _deleteOldArchives(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      final name = p.basename(entity.path);
      if (entity is File && name.startsWith('mycelium-sauvegarde-') && (name.endsWith('.zip') || name.endsWith('.zip.part'))) {
        await _deleteQuietly(entity);
      }
    }
  }
}

Future<void> _deleteQuietly(FileSystemEntity entity) async {
  try {
    if (await entity.exists()) await entity.delete(recursive: true);
  } catch (_) {
    // Un fichier temporaire resté en place n'est pas bloquant.
  }
}

class _Applied {
  const _Applied({required this.added, required this.alreadyPresent});

  final BackupCounts added;
  final BackupCounts alreadyPresent;
}

/// Rassemble les photos à mettre dans l'archive : chemin relatif de l'archive ->
/// fichier source. Une même photo n'est ajoutée qu'une fois ; deux fichiers
/// différents de même nom reçoivent des noms distincts.
class _PhotoCollector {
  _PhotoCollector(this._resolve);

  final PhotoResolver _resolve;

  /// Chemin relatif dans l'archive -> chemin du fichier à copier.
  final Map<String, String> files = {};

  /// Chemins relatifs des photos référencées mais introuvables.
  final Set<String> missing = {};

  final Map<String, String> _bySource = {};
  final Map<String, String> _byStored = {};

  /// Renvoie le chemin relatif à écrire en base dans l'archive pour [stored].
  Future<String?> add(String? stored, String defaultFolder) async {
    if (stored == null || stored.isEmpty) return null;
    final known = _byStored[stored];
    if (known != null) return known;

    var rel = archivePhotoPath(stored, defaultFolder);
    final file = await _resolve(stored);
    if (file == null) {
      missing.add(rel);
    } else {
      final source = p.normalize(file.absolute.path);
      final already = _bySource[source];
      if (already != null) {
        rel = already;
      } else {
        rel = _uniqueName(rel);
        files[rel] = source;
        _bySource[source] = rel;
        missing.remove(rel);
      }
    }
    return _byStored[stored] = rel;
  }

  String _uniqueName(String rel) {
    if (!files.containsKey(rel)) return rel;
    final folder = p.posix.dirname(rel);
    final name = p.posix.basenameWithoutExtension(rel);
    final ext = p.posix.extension(rel);
    for (var n = 2;; n++) {
      final candidate = '$folder/$name-$n$ext';
      if (!files.containsKey(candidate)) return candidate;
    }
  }
}
