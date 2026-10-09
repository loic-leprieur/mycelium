import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/safety_widgets.dart';
import '../../../core/theme.dart';
import '../../../data/database.dart';
import '../../../data/photo_store.dart';
import '../../../data/providers.dart';
import '../../map/navigation.dart';
import '../../species/data/species_seed.dart';
import 'history_logic.dart';
import 'species_picker.dart';
import 'stored_photo.dart';

/// Détail d'une identification enregistrée : photo, espèce retenue, propositions
/// du modèle, date, position et coin ; on peut corriger l'espèce ou la supprimer.
///
/// Aucune phrase sur la comestibilité ici (RM-4) : elle ne se lit que sur la fiche
/// de l'espèce, avec ses réserves.
class IdentificationDetailScreen extends ConsumerStatefulWidget {
  const IdentificationDetailScreen({super.key, required this.identificationId});

  final String identificationId;

  @override
  ConsumerState<IdentificationDetailScreen> createState() =>
      _IdentificationDetailScreenState();
}

class _IdentificationDetailScreenState
    extends ConsumerState<IdentificationDetailScreen> {
  /// Dernière version connue : l'écran reste rempli pendant qu'il se ferme après
  /// une suppression, au lieu d'afficher « introuvable » le temps de l'animation.
  Identification? _last;
  bool _closing = false;

  Future<void> _changeSpecies(Identification row) async {
    final all = ref.read(allSpeciesProvider).value ?? speciesSeed;
    final choice = await pickSpecies(
      context,
      species: all,
      currentId: row.chosenSpeciesId,
      allowUnknown: true,
      title: 'Changer l\'espèce',
    );
    if (choice == null || choice.speciesId == row.chosenSpeciesId || !mounted) return;

    final newId = choice.speciesId;
    final db = ref.read(databaseProvider);
    // Seule l'espèce retenue change : le résultat du modèle (top5Json) reste tel
    // qu'il était (RM-3). Si l'identification est rangée dans un coin, il y
    // retient aussi cette espèce, à la date de l'identification.
    await db.transaction(() async {
      await db.setIdentificationSpecies(row.id, newId);
      final spotId = row.spotId;
      if (newId != null && spotId != null && await db.spotById(spotId) != null) {
        await db.markSpeciesSeen(spotId, newId, row.createdAt);
      }
    });
    if (!mounted) return;
    final name = newId == null ? null : ref.read(speciesByIdProvider(newId))?.commonName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newId == null
            ? 'Cette photo est maintenant sans nom d\'espèce.'
            : 'Espèce corrigée : ${name ?? newId}.'),
      ),
    );
  }

  Future<void> _delete(Identification row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette identification ?'),
        content: const Text(
          'La photo et cet enregistrement seront supprimés de ce téléphone. '
          'Le coin et ses espèces ne sont pas modifiés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _closing = true);
    await ref.read(databaseProvider).deleteIdentification(row.id);
    await deleteStoredPhoto(row.photoPath);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/identify/history');
    }
  }

  /// Affiche le coin sur la carte et lance le guidage à vol d'oiseau (MAP-5).
  void _showSpot(Spot spot) {
    ref.read(navigationProvider.notifier).start(spot);
    context.go('/map');
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(identificationsProvider);
    final found = rows.value?.where((r) => r.id == widget.identificationId).firstOrNull;
    if (found != null) _last = found;
    final row = found ?? (_closing ? _last : null);

    if (row == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Identification')),
        body: rows.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    rows.hasError
                        ? 'Impossible de lire cette identification.'
                        : 'Cette identification n\'existe plus.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
      );
    }

    final theme = Theme.of(context);
    final spots = ref.watch(spotsProvider).value ?? const <Spot>[];
    final spot = row.spotId == null
        ? null
        : spots.where((s) => s.id == row.spotId).firstOrNull;
    final chosenId = row.chosenSpeciesId;
    final chosen = chosenId == null ? null : ref.watch(speciesByIdProvider(chosenId));
    final proposals = parseTop5(row.top5Json);

    // L'alerte ne disparaît jamais d'une identification passée : elle couvre les
    // propositions du modèle et l'espèce retenue.
    final dangerous = <String>[];
    for (final id in {...proposals.map((p) => p.speciesId), ?chosenId}) {
      final species = ref.watch(speciesByIdProvider(id));
      if (species != null && species.edibility.isDangerous) {
        dangerous.add(species.commonName);
      }
    }

    final lat = row.latitude;
    final lon = row.longitude;

    return Scaffold(
      appBar: AppBar(title: const Text('Identification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StoredPhoto(
              path: row.photoPath,
              height: 300,
              radius: 18,
              cacheWidth: 1600,
              zoomable: true,
              missingMessage: 'Photo introuvable sur cet appareil.',
            ),
            const SizedBox(height: 14),
            if (dangerous.isNotEmpty) ...[
              InfoBanner(
                title: 'ATTENTION : espèce dangereuse parmi les propositions',
                message: '${dangerous.join(', ')}. Ne cueillez ni ne consommez ce '
                    'champignon en cas de doute.',
                color: const Color(0xFFC62828),
                icon: Icons.dangerous,
              ),
              const SizedBox(height: 14),
            ],
            _Panel(
              children: [
                Text('Espèce retenue', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                if (chosenId == null) ...[
                  Text('Espèce inconnue', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  const Text('Vous n\'avez pas retenu d\'espèce pour cette photo.'),
                ] else if (chosen == null)
                  Text('Espèce supprimée', style: theme.textTheme.titleLarge)
                else
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/species/${chosen.id}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(chosen.commonName, style: theme.textTheme.titleLarge),
                                if (chosen.scientificName != null)
                                  Text(
                                    chosen.scientificName!,
                                    style: const TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                const SizedBox(height: 2),
                                const Text('Voir la fiche de l\'espèce'),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _closing ? null : () => _changeSpecies(row),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Changer l\'espèce'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Panel(
              children: [
                Text('Le modèle proposait', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                const Text(
                  'Propositions du moteur d\'identification au moment de la photo. '
                  'Elles ne changent pas quand vous corrigez l\'espèce.',
                ),
                const SizedBox(height: 8),
                if (proposals.isEmpty)
                  const Text('Aucune proposition n\'a été enregistrée.')
                else
                  for (var i = 0; i < proposals.length; i++)
                    _ProposalRow(rank: i + 1, proposal: proposals[i]),
                if (row.unknownScore >= unknownScoreNoteThreshold) ...[
                  const SizedBox(height: 8),
                  InfoBanner(
                    title: 'Peut-être une espèce hors de la base',
                    message: 'Le modèle estimait à ${percentLabel(row.unknownScore)} la '
                        'probabilité que cette photo ne corresponde à aucune des '
                        'espèces connues de l\'application. Ne vous fiez pas aux '
                        'propositions.',
                    color: const Color(0xFFE0E0E0),
                    icon: Icons.help_outline,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Version du modèle : ${row.modelVersion}',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Panel(
              children: [
                _InfoRow(
                  icon: Icons.event,
                  label: 'Date',
                  value: longDateTime(row.createdAt),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.place_outlined,
                  label: 'Coin',
                  value: spot?.name ?? 'Sans coin',
                ),
                if (spot != null) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _showSpot(spot),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Voir le coin'),
                  ),
                ],
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.my_location,
                  label: 'Position de la photo',
                  value: lat == null || lon == null
                      ? 'Inconnue'
                      : '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SafetyDisclaimer(),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _closing ? null : () => _delete(row),
              style: TextButton.styleFrom(foregroundColor: Palette.berry),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer cette identification'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bloc de contenu arrondi, comme les cartes du reste de l'application.
class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Palette.forest),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
                Text(value),
              ],
            ),
          ),
        ],
      );
}

/// Une proposition du modèle : rang, nom, barre et pourcentage.
class _ProposalRow extends ConsumerWidget {
  const _ProposalRow({required this.rank, required this.proposal});

  final int rank;
  final ModelProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final species = ref.watch(speciesByIdProvider(proposal.speciesId));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('$rank. ${species?.commonName ?? proposal.speciesId}')),
              const SizedBox(width: 8),
              Text(
                percentLabel(proposal.score),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: proposal.score,
              minHeight: 8,
              backgroundColor: Palette.sage.withValues(alpha: .5),
              color: (species?.edibility.isDangerous ?? false) ? Palette.berry : Palette.moss,
            ),
          ),
        ],
      ),
    );
  }
}
