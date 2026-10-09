import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';
import '../../../data/database.dart';
import 'place_logic.dart';

/// Où ranger une identification (réponse de la feuille « Où l'avez-vous trouvé ? »).
sealed class PlaceChoice {
  const PlaceChoice();
}

/// Un coin déjà enregistré.
class ExistingSpot extends PlaceChoice {
  const ExistingSpot(this.spot);

  final Spot spot;
}

/// Un coin à créer à cette position, avec le nom choisi par l'utilisateur.
class NewSpot extends PlaceChoice {
  const NewSpot({required this.name, required this.latitude, required this.longitude});

  final String name;
  final double latitude;
  final double longitude;
}

/// Aucun emplacement : on ne garde que la photo et l'espèce.
class NoPlace extends PlaceChoice {
  const NoPlace();
}

/// Demande où l'espèce [speciesId] a été trouvée. Renvoie null si l'utilisateur
/// annule : rien ne doit alors être enregistré.
///
/// [photoPosition] est l'endroit où la photo a été prise (appareil photo seulement),
/// [currentPosition] la position GPS actuelle ; l'une comme l'autre peut manquer.
Future<PlaceChoice?> askPlace(
  BuildContext context, {
  required String speciesId,
  required String speciesName,
  required List<Spot> spots,
  required DateTime now,
  LatLng? photoPosition,
  LatLng? currentPosition,
}) =>
    showModalBottomSheet<PlaceChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => PlaceSheet(
        speciesId: speciesId,
        speciesName: speciesName,
        spots: spots,
        now: now,
        photoPosition: photoPosition,
        currentPosition: currentPosition,
      ),
    );

/// Feuille « Où l'avez-vous trouvé ? » : le coin le plus proche de la photo s'il y
/// en a un, un nouveau coin ici, un autre coin, ou aucun emplacement.
class PlaceSheet extends StatelessWidget {
  const PlaceSheet({
    super.key,
    required this.speciesId,
    required this.speciesName,
    required this.spots,
    required this.now,
    this.photoPosition,
    this.currentPosition,
  });

  final String speciesId;
  final String speciesName;
  final List<Spot> spots;
  final DateTime now;
  final LatLng? photoPosition;
  final LatLng? currentPosition;

  /// Position qui sert de repère : celle de la photo, sinon celle du téléphone.
  LatLng? get _reference => photoPosition ?? currentPosition;

  Future<void> _createHere(BuildContext context) async {
    final here = _reference;
    if (here == null) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _SpotNameDialog(
        initial: defaultSpotName(speciesId: speciesId, speciesName: speciesName, at: now),
      ),
    );
    if (name == null || !context.mounted) return;
    Navigator.of(context).pop(
      NewSpot(name: name, latitude: here.latitude, longitude: here.longitude),
    );
  }

  Future<void> _pickAnother(BuildContext context) async {
    final spot = await showModalBottomSheet<Spot>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _SpotListSheet(rows: sortedSpots(spots, from: _reference)),
    );
    if (spot == null || !context.mounted) return;
    Navigator.of(context).pop(ExistingSpot(spot));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoAt = photoPosition;
    final nearby = photoAt == null ? null : nearestSpot(spots, photoAt);
    final String hereLabel;
    if (_reference == null) {
      hereLabel = 'Position GPS indisponible';
    } else if (photoAt != null) {
      hereLabel = 'Coin créé à l\'endroit de la photo';
    } else {
      hereLabel = 'Coin créé à ma position actuelle';
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Où l\'avez-vous trouvé ?', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Espèce retenue : $speciesName'),
            const SizedBox(height: 12),
            if (nearby != null) ...[
              Card(
                margin: EdgeInsets.zero,
                color: Palette.sage,
                child: ListTile(
                  minTileHeight: 72,
                  leading: const Icon(Icons.place, color: Palette.forestDark),
                  title: Text(
                    nearby.spot.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Coin le plus proche, ${distanceLabel(nearby.meters)} de la photo',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pop(ExistingSpot(nearby.spot)),
                ),
              ),
              const SizedBox(height: 4),
            ],
            ListTile(
              minTileHeight: 64,
              enabled: _reference != null,
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Nouveau coin ici'),
              subtitle: Text(hereLabel),
              onTap: () => _createHere(context),
            ),
            if (spots.isNotEmpty)
              ListTile(
                minTileHeight: 64,
                leading: const Icon(Icons.list_alt),
                title: const Text('Un autre coin…'),
                subtitle: Text(
                  spots.length == 1 ? 'Parmi votre coin' : 'Parmi vos ${spots.length} coins',
                ),
                onTap: () => _pickAnother(context),
              ),
            ListTile(
              minTileHeight: 64,
              leading: const Icon(Icons.location_off_outlined),
              title: const Text('Sans emplacement'),
              subtitle: const Text('Garder seulement la photo et l\'espèce'),
              onTap: () => Navigator.of(context).pop(const NoPlace()),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saisie du nom d'un nouveau coin (RM-1 : un coin a toujours un nom).
class _SpotNameDialog extends StatefulWidget {
  const _SpotNameDialog({required this.initial});

  final String initial;

  @override
  State<_SpotNameDialog> createState() => _SpotNameDialogState();
}

class _SpotNameDialogState extends State<_SpotNameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.trim().isNotEmpty;

  void _submit() {
    if (_valid) Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Nom du nouveau coin'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nom du coin'),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: _valid ? _submit : null,
            child: const Text('Créer le coin'),
          ),
        ],
      );
}

/// Liste des coins, du plus proche au plus éloigné (ou par nom sans position).
class _SpotListSheet extends StatelessWidget {
  const _SpotListSheet({required this.rows});

  final List<SpotAt> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byDistance = rows.isNotEmpty && rows.first.meters != null;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choisir un coin', style: theme.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(byDistance ? 'Du plus proche au plus éloigné' : 'Par ordre alphabétique'),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                final details = [
                  if (row.meters != null) distanceLabel(row.meters!),
                  if (row.spot.forestType != null) row.spot.forestType!,
                ];
                return ListTile(
                  minTileHeight: 60,
                  leading: Icon(
                    row.spot.isFavorite ? Icons.star : Icons.park_outlined,
                    color: row.spot.isFavorite ? Palette.chanterelle : Palette.forest,
                  ),
                  title: Text(row.spot.name),
                  subtitle: details.isEmpty ? null : Text(details.join(' · ')),
                  onTap: () => Navigator.of(context).pop(row.spot),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
