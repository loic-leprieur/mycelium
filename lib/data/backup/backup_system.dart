import 'dart:io';
import 'dart:ui' show Rect;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Ce que l'utilisateur a fait de l'archive proposée.
enum BackupDelivery {
  /// Confiée à la feuille de partage (téléphone).
  shared,

  /// Enregistrée dans le fichier choisi (ordinateur).
  saved,

  /// Feuille ou fenêtre fermée sans rien choisir : la sauvegarde n'existe pas.
  cancelled,
}

/// Tout ce qui touche au système : dossiers, feuille de partage, sélecteurs de
/// fichier. Les tests le remplacent : jamais de fenêtre système en test.
abstract class BackupSystem {
  const BackupSystem();

  /// Documents de l'application (dossiers de photos).
  Future<Directory> photosDirectory();

  /// Dossier temporaire où l'archive est créée.
  Future<Directory> workDirectory();

  /// Remet [archive] à l'utilisateur. [origin] ancre la feuille de partage (iPad).
  Future<BackupDelivery> deliver(File archive, {Rect? origin});

  /// Fait choisir une archive à restaurer ; null si l'utilisateur annule.
  Future<File?> pickArchive();
}

const _zipType = XTypeGroup(
  label: 'Sauvegarde Mycelium (.zip)',
  extensions: ['zip'],
  mimeTypes: ['application/zip', 'application/x-zip-compressed'],
  uniformTypeIdentifiers: ['public.zip-archive'],
);

/// Implémentation réelle : feuille de partage sur téléphone, fenêtre
/// d'enregistrement sur ordinateur.
class DeviceBackupSystem extends BackupSystem {
  const DeviceBackupSystem();

  bool get _usesShareSheet =>
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<Directory> photosDirectory() => getApplicationDocumentsDirectory();

  @override
  Future<Directory> workDirectory() async =>
      Directory(p.join((await getTemporaryDirectory()).path, 'mycelium_sauvegardes'));

  @override
  Future<BackupDelivery> deliver(File archive, {Rect? origin}) async {
    final name = p.basename(archive.path);
    if (_usesShareSheet) {
      final result = await SharePlus.instance.share(ShareParams(
        files: [XFile(archive.path, mimeType: 'application/zip', name: name)],
        subject: 'Sauvegarde Mycelium',
        sharePositionOrigin: origin,
      ));
      return result.status == ShareResultStatus.dismissed
          ? BackupDelivery.cancelled
          : BackupDelivery.shared;
    }
    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: const [_zipType],
      confirmButtonText: 'Enregistrer',
    );
    if (location == null) return BackupDelivery.cancelled;
    final path = location.path.toLowerCase().endsWith('.zip') ? location.path : '${location.path}.zip';
    await archive.copy(path);
    return BackupDelivery.saved;
  }

  @override
  Future<File?> pickArchive() async {
    final picked = await openFile(
      acceptedTypeGroups: const [_zipType],
      confirmButtonText: 'Restaurer',
    );
    return picked == null ? null : File(picked.path);
  }
}
