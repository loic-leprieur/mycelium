import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'backup_format.dart';
import 'backup_service.dart';
import 'backup_system.dart';

/// Accès au système (partage, sélecteurs, dossiers) ; remplacé dans les tests.
final backupSystemProvider = Provider<BackupSystem>((ref) => const DeviceBackupSystem());

/// Horloge de l'écran (remplacée dans les tests).
final backupClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  final system = ref.watch(backupSystemProvider);
  return BackupService(
    db: ref.watch(databaseProvider),
    photosRoot: await system.photosDirectory(),
    clock: ref.watch(backupClockProvider),
  );
});

/// Date de la dernière sauvegarde (null = jamais), mise à jour en direct.
final lastBackupProvider = StreamProvider<DateTime?>(
  (ref) => ref.watch(databaseProvider).select(ref.watch(databaseProvider).appMeta).watch().map((rows) {
    for (final r in rows) {
      if (r.key == lastBackupKey) return DateTime.tryParse(r.value)?.toLocal();
    }
    return null;
  }),
);
