import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/data/backup/backup_format.dart';

void main() {
  test('chemins de photos : relatifs, deux parties, dossier connu', () {
    expect(safePhotoPath('harvest_photos/a.jpg'), 'harvest_photos/a.jpg');
    for (final bad in [
      '/harvest_photos/a.jpg', '../a.jpg', 'harvest_photos/../a.jpg', 'harvest_photos/a/b.jpg',
      'ailleurs/a.jpg', 'harvest_photos/', 'harvest_photos/.cache', 'harvest_photos/a:b.jpg', 'a.jpg',
    ]) {
      expect(safePhotoPath(bad), isNull, reason: bad);
    }
  });

  test('ancien chemin absolu -> chemin relatif de l\'archive', () {
    expect(archivePhotoPath('/var/mobile/Containers/Data/Application/X/Documents/harvest_photos/h.JPG', 'harvest_photos'),
        'harvest_photos/h.JPG');
    expect(archivePhotoPath('identification_photos/i.jpg', 'harvest_photos'), 'identification_photos/i.jpg');
    expect(archivePhotoPath('/tmp/IMG 1.jpg', 'species_photos'), 'species_photos/IMG 1.jpg');
    expect(archivePhotoPath(r'C:\Users\x\Documents\species_photos\s.png', 'harvest_photos'), 'species_photos/s.png');
    expect(safePhotoPath(archivePhotoPath('/x/a:b?.jpg', 'harvest_photos')), isNotNull);
  });

  test('noms d\'entrées de l\'archive', () {
    for (final ok in ['manifest.json', 'photos/', 'photos/harvest_photos/a.jpg']) {
      expect(isSafeEntryName(ok), isTrue, reason: ok);
    }
    for (final bad in ['', '/a', '../a', 'a/../b', 'a\\b', 'C:/a', 'a//b', './a', 'a\u0000b']) {
      expect(isSafeEntryName(bad), isFalse, reason: bad);
    }
  });

  test('récapitulatif en français', () {
    expect(const BackupCounts(spots: 12, outings: 5, identifications: 34).describe(), '12 coins, 5 sorties, 34 identifications');
    expect(const BackupCounts(spots: 1, photos: 1).describe(), '1 coin, 1 photo');
    expect(const BackupCounts().describe(), 'aucune donnée');
  });

  test('rappel de sauvegarde : jamais ou plus de 7 jours', () {
    final now = DateTime(2026, 10, 9, 12);
    expect(backupIsOverdue(null, now), isTrue);
    expect(backupIsOverdue(now.subtract(const Duration(days: 7)), now), isFalse);
    expect(backupIsOverdue(now.subtract(const Duration(days: 7, minutes: 1)), now), isTrue);
    expect(backupFileName(DateTime(2026, 1, 5)), 'mycelium-sauvegarde-2026-01-05.zip');
  });
}
