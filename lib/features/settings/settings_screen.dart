import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Réglages : point d'entrée des sous-écrans. Chaque sous-écran est tenu par son
/// propre module (`settings/data`, `safety`).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Réglages')),
        body: ListView(
          children: [
            ListTile(
              minTileHeight: 72,
              leading: const Icon(Icons.text_fields),
              title: const Text('Affichage'),
              subtitle: const Text('Taille du texte'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/display'),
            ),
            ListTile(
              minTileHeight: 72,
              leading: const Icon(Icons.save_alt),
              title: const Text('Sauvegarde et données'),
              subtitle: const Text('Exporter, importer ou supprimer vos données'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/data'),
            ),
            ListTile(
              minTileHeight: 72,
              leading: const Icon(Icons.health_and_safety_outlined),
              title: const Text('Intoxication : que faire ?'),
              subtitle: const Text('Numéros d\'urgence, consultable hors ligne'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/safety'),
            ),
            ListTile(
              minTileHeight: 72,
              leading: const Icon(Icons.description_outlined),
              title: const Text('Licences'),
              subtitle: const Text('Licence de l\'application et composants tiers'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Mycelium',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 Loïc Leprieur. Tous droits réservés.\n'
                    'Cartes © contributeurs OpenStreetMap (ODbL).',
              ),
            ),
          ],
        ),
      );
}
