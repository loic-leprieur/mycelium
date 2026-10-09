import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Dossier qui contient les photos de l'application (les « Documents »).
/// Remplaçable dans les tests.
@visibleForTesting
Future<Directory> Function() photoRoot = getApplicationDocumentsDirectory;

/// Copie une photo choisie par l'utilisateur dans le dossier de l'application
/// (les photos restent sur l'appareil) et renvoie son chemin ABSOLU.
///
/// Ancien format, conservé pour les coins, récoltes et espèces déjà enregistrés.
/// Pour toute nouvelle donnée, préférer [savePhotoRelative].
Future<String> savePhoto(String sourcePath, {required String folder, required String id}) async {
  final dir = await photoRoot();
  final target = Directory(p.join(dir.path, folder));
  await target.create(recursive: true);
  final dest = p.join(target.path, '$id${p.extension(sourcePath)}');
  await File(sourcePath).copy(dest);
  return dest;
}

/// Copie une photo dans `<Documents>/<folder>/<id>.<ext>` et renvoie le chemin
/// RELATIF `folder/id.ext`, à enregistrer en base.
///
/// Un chemin relatif survit à un changement du dossier de l'application
/// (réinstallation, mise à jour, nouveau téléphone), contrairement à un chemin
/// absolu : indispensable avec un compte Apple gratuit, où l'application est
/// réinstallée toutes les semaines. Retrouver le fichier avec [resolveStoredPhoto].
Future<String> savePhotoRelative(String sourcePath, {required String folder, required String id}) async {
  final dir = await photoRoot();
  final target = Directory(p.join(dir.path, folder));
  await target.create(recursive: true);
  final name = '$id${p.extension(sourcePath)}';
  await File(sourcePath).copy(p.join(target.path, name));
  return p.posix.join(folder, name);
}

/// Retrouve le fichier d'une photo enregistrée en base : chemin relatif (nouveau
/// format) ou ancien chemin absolu. Si l'ancien chemin n'existe plus (le dossier de
/// l'application a changé), on le recherche sous les Documents actuels. Renvoie null
/// si la photo est introuvable.
Future<File?> resolveStoredPhoto(String? stored) async {
  if (stored == null || stored.isEmpty) return null;
  final root = (await photoRoot()).path;
  if (p.isAbsolute(stored)) {
    final direct = File(stored);
    if (await direct.exists()) return direct;
    // Ancien chemin d'un autre conteneur : …/Documents/<dossier>/<fichier>.
    const marker = 'Documents${'/'}';
    final cut = stored.lastIndexOf(marker);
    if (cut < 0) return null;
    final moved = File(p.join(root, stored.substring(cut + marker.length)));
    return await moved.exists() ? moved : null;
  }
  final file = File(p.join(root, stored));
  return await file.exists() ? file : null;
}

/// Supprime un fichier photo s'il existe (sans erreur sinon).
Future<void> deletePhoto(String? path) async {
  if (path == null) return;
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Une photo orpheline n'est pas bloquante.
  }
}

/// Supprime la photo enregistrée en base ([stored] : chemin relatif ou absolu).
Future<void> deleteStoredPhoto(String? stored) async {
  final file = await resolveStoredPhoto(stored);
  if (file != null) await deletePhoto(file.path);
}
