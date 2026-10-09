import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Composants hors paquets Dart, ajoutés à l'écran « Licences ».
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(['BioCLIP (imageomics/bioclip)'],
        'Licence MIT (d\'après la fiche du modèle). Modèle de reconnaissance du vivant '
        'utilisé pour l\'identification hors ligne.');
    yield const LicenseEntryWithLineBreaks(['ONNX Runtime'], 'Licence MIT. Microsoft.');
    yield const LicenseEntryWithLineBreaks(['OpenStreetMap'],
        'Données © contributeurs OpenStreetMap, licence ODbL 1.0 : '
        'https://www.openstreetmap.org/copyright');
  });
  await initializeDateFormatting('fr');
  runApp(const ProviderScope(child: MyceliumApp()));
}
