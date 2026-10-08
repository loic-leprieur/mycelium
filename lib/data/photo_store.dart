import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copie une photo choisie par l'utilisateur dans le dossier de l'application
/// (les photos restent sur l'appareil) et renvoie le nouveau chemin.
Future<String> savePhoto(String sourcePath, {required String folder, required String id}) async {
  final dir = await getApplicationDocumentsDirectory();
  final target = Directory(p.join(dir.path, folder));
  await target.create(recursive: true);
  final dest = p.join(target.path, '$id${p.extension(sourcePath)}');
  await File(sourcePath).copy(dest);
  return dest;
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
