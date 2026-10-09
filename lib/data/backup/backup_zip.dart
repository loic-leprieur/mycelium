import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'backup_codec.dart';
import 'backup_format.dart';

// Fonctions lourdes (lecture/écriture de l'archive, somme de contrôle des
// photos). Elles sont TOP-LEVEL et ne reçoivent que des valeurs simples pour
// pouvoir tourner dans un autre isolate (`Isolate.run`) : l'interface ne se
// fige pas pendant une sauvegarde de plusieurs centaines de Mo.

/// Garde-fous : le manifeste et `data.json` sont chargés en mémoire.
const _maxManifestBytes = 1 << 20; // 1 Mio
const _maxDataBytes = 256 << 20; // 256 Mio
const _maxEntries = 200000;

// --- Écriture ---

/// Ce qu'il faut écrire dans l'archive.
class WriteArchiveJob {
  const WriteArchiveJob({
    required this.zipPath,
    required this.manifestJson,
    required this.dataJson,
    required this.photos,
    this.progress,
  });

  final String zipPath;
  final String manifestJson;
  final String dataJson;

  /// (chemin relatif dans `photos/`, chemin du fichier à copier).
  final List<(String, String)> photos;

  /// Reçoit le nombre de photos déjà écrites.
  final SendPort? progress;
}

/// Écrit l'archive en flux : le manifeste et les données sont compressés, les
/// photos (déjà compressées en JPEG) sont STOCKÉES telles quelles, copiées par
/// morceaux d'1 Mio sans jamais être chargées entièrement en mémoire.
void writeArchive(WriteArchiveJob job) {
  final out = OutputFileStream(job.zipPath);
  try {
    final encoder = ZipEncoder()..startEncode(out, level: DeflateLevel.defaultCompression);
    encoder.add(ArchiveFile.string(backupManifestEntry, job.manifestJson));
    encoder.add(ArchiveFile.string(backupDataEntry, job.dataJson));
    var done = 0;
    for (final (rel, source) in job.photos) {
      final entry = ArchiveFile.stream('$backupPhotosPrefix$rel', InputFileStream(source))
        ..compression = CompressionType.none
        ..lastModTime = File(source).lastModifiedSync().millisecondsSinceEpoch ~/ 1000;
      encoder.add(entry);
      job.progress?.send(++done);
    }
    encoder.endEncode();
  } finally {
    out.closeSync();
  }
}

// --- Lecture et validation ---

/// Archive à examiner.
class InspectJob {
  const InspectJob(this.path, this.maxSchemaVersion);

  final String path;
  final int maxSchemaVersion;
}

BackupException _notABackup(String why) => BackupException(
      BackupErrorKind.notABackup,
      'Ce fichier n\'est pas une sauvegarde Mycelium ($why).',
    );

BackupException _corrupted() => const BackupException(
      BackupErrorKind.corrupted,
      'La sauvegarde est endommagée ou incomplète : elle ne peut pas être lue.',
    );

bool _isSymlink(ZipFileHeader h) =>
    (h.versionMadeBy >> 8) == 3 && ((h.externalFileAttributes >> 16) & 0xF000) == 0xA000;

/// Lit l'archive et la VALIDE entièrement sans rien écrire : noms d'entrées
/// sûrs, manifeste, versions, JSON cohérent, photos présentes, sommes de
/// contrôle de `manifest.json` et `data.json`.
ParsedBackup inspectArchive(InspectJob job) {
  final file = File(job.path);
  if (!file.existsSync() || file.lengthSync() == 0) throw _notABackup('fichier vide ou introuvable');
  final input = InputFileStream(job.path);
  try {
    final decoder = ZipDecoder();
    final Archive archive;
    try {
      archive = decoder.decodeStream(input);
    } catch (_) {
      throw _notABackup('archive illisible');
    }
    final headers = decoder.directory.fileHeaders;
    if (headers.isEmpty) throw _notABackup('ce n\'est pas une archive .zip');
    if (headers.length > _maxEntries) throw _corrupted();

    final byName = <String, ZipFileHeader>{};
    for (final h in headers) {
      final name = h.filename;
      if (!isSafeEntryName(name)) {
        throw BackupException(
          BackupErrorKind.unsafe,
          'Sauvegarde refusée : elle contient un chemin dangereux (« $name »). '
          'Seules les sauvegardes créées par Mycelium sont acceptées.',
        );
      }
      if (_isSymlink(h) || byName.containsKey(name)) {
        throw BackupException(
          BackupErrorKind.unsafe,
          'Sauvegarde refusée : l\'archive contient un élément inattendu (« $name »).',
        );
      }
      if ((h.generalPurposeBitFlag & 1) != 0) throw _notABackup('archive protégée par un mot de passe');
      byName[name] = h;
    }

    Uint8List read(String name, int maxBytes) {
      final header = byName[name];
      if (header == null) throw _notABackup('« $name » est introuvable');
      if (header.uncompressedSize > maxBytes) {
        throw BackupException(BackupErrorKind.invalid, 'Sauvegarde illisible : « $name » est trop volumineux.');
      }
      final Uint8List bytes;
      try {
        bytes = archive.find(name)?.readBytes() ?? Uint8List(0);
      } catch (_) {
        throw _corrupted();
      }
      if (bytes.length != header.uncompressedSize || getCrc32(bytes) != header.crc32) throw _corrupted();
      return bytes;
    }

    String utf8Text(Uint8List bytes) {
      try {
        return utf8.decode(bytes);
      } on FormatException {
        throw _corrupted();
      }
    }

    final manifest = parseManifest(
      utf8Text(read(backupManifestEntry, _maxManifestBytes)),
      maxSchemaVersion: job.maxSchemaVersion,
    );
    final dataText = utf8Text(read(backupDataEntry, _maxDataBytes));

    // Photos de l'archive : seuls les chemins `photos/<dossier>/<fichier>` sont
    // pris en compte, les autres entrées (sûres) sont ignorées.
    final archivePhotos = <String>{
      for (final name in byName.keys)
        if (name.startsWith(backupPhotosPrefix) && !name.endsWith('/'))
          ?safePhotoPath(name.substring(backupPhotosPrefix.length)),
    };
    return parseData(dataText, manifest, archivePhotos: archivePhotos);
  } on BackupException {
    rethrow;
  } catch (_) {
    throw _corrupted();
  } finally {
    input.closeSync();
  }
}

// --- Extraction des photos ---

class ExtractJob {
  const ExtractJob({
    required this.zipPath,
    required this.targetPath,
    required this.photoPaths,
    this.progress,
  });

  final String zipPath;

  /// Dossier (de travail) où recopier les photos, sous leurs chemins relatifs.
  final String targetPath;
  final List<String> photoPaths;

  /// Reçoit le nombre de photos déjà extraites.
  final SendPort? progress;
}

/// Somme de contrôle d'un fichier, calculée par morceaux.
int _fileCrc(File file) {
  final raf = file.openSync();
  try {
    final buffer = Uint8List(1 << 20);
    var crc = 0;
    while (true) {
      final n = raf.readIntoSync(buffer);
      if (n <= 0) return crc;
      crc = getCrc32(Uint8List.sublistView(buffer, 0, n), crc);
    }
  } finally {
    raf.closeSync();
  }
}

/// Recopie les photos [ExtractJob.photoPaths] de l'archive sous
/// [ExtractJob.targetPath] et vérifie la taille et la somme de contrôle de
/// chacune. Renvoie le nombre de photos extraites.
int extractPhotos(ExtractJob job) {
  final input = InputFileStream(job.zipPath);
  try {
    final decoder = ZipDecoder();
    final archive = decoder.decodeStream(input);
    final headers = {for (final h in decoder.directory.fileHeaders) h.filename: h};
    var done = 0;
    for (final rel in job.photoPaths) {
      final name = '$backupPhotosPrefix$rel';
      final entry = archive.find(name);
      final header = headers[name];
      if (entry == null || header == null) {
        throw BackupException(BackupErrorKind.incomplete, 'La sauvegarde est incomplète : la photo « $rel » est absente.');
      }
      final target = File(p.join(job.targetPath, rel));
      // `rel` a déjà été validé (deux parties, dossier connu, nom sûr) : on le
      // revérifie avant d'écrire, c'est la dernière barrière contre le « zip-slip ».
      if (safePhotoPath(rel) == null || !p.isWithin(job.targetPath, target.path)) {
        throw BackupException(BackupErrorKind.unsafe, 'Sauvegarde refusée : chemin de photo dangereux (« $rel »).');
      }
      target.parent.createSync(recursive: true);
      final out = OutputFileStream(target.path);
      try {
        entry.writeContent(out);
      } finally {
        out.closeSync();
      }
      if (target.lengthSync() != header.uncompressedSize || _fileCrc(target) != header.crc32) {
        throw BackupException(BackupErrorKind.corrupted, 'La sauvegarde est endommagée : la photo « $rel » est illisible.');
      }
      job.progress?.send(++done);
    }
    return done;
  } on BackupException {
    rethrow;
  } on FileSystemException catch (e) {
    throw BackupException(
      BackupErrorKind.failed,
      'Impossible d\'écrire les photos (${e.osError?.message ?? e.message}). Vérifiez l\'espace disponible.',
    );
  } catch (_) {
    throw _corrupted();
  } finally {
    input.closeSync();
  }
}

// --- Exécution hors du fil principal ---
//
// Fonctions de premier niveau exprès : la fermeture envoyée à l'isolate ne
// capture alors que [job], jamais la base de données ni un widget.

Future<void> writeArchiveInBackground(WriteArchiveJob job) =>
    Isolate.run(() => writeArchive(job));

Future<ParsedBackup> inspectArchiveInBackground(InspectJob job) =>
    Isolate.run(() => inspectArchive(job));

Future<int> extractPhotosInBackground(ExtractJob job) =>
    Isolate.run(() => extractPhotos(job));
