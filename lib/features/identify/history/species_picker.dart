import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../species/domain/species.dart';
import 'text_fold.dart';

/// Choix fait dans [pickSpecies] : [speciesId] vaut null pour « Je ne sais pas ».
typedef SpeciesChoice = ({String? speciesId});

/// Fenêtre « Quelle espèce ? » : liste alphabétique des [species] avec recherche
/// (sans tenir compte des accents). Renvoie null si on annule.
///
/// Aucune comestibilité n'y est affichée : elle ne se lit que sur la fiche de
/// l'espèce, avec ses réserves (RM-4).
Future<SpeciesChoice?> pickSpecies(
  BuildContext context, {
  required List<Species> species,
  String? currentId,
  bool allowUnknown = false,
  String title = 'Quelle espèce ?',
}) =>
    showDialog<SpeciesChoice>(
      context: context,
      builder: (_) => _SpeciesPickerDialog(
        species: species,
        currentId: currentId,
        allowUnknown: allowUnknown,
        title: title,
      ),
    );

class _SpeciesPickerDialog extends StatefulWidget {
  const _SpeciesPickerDialog({
    required this.species,
    required this.currentId,
    required this.allowUnknown,
    required this.title,
  });

  final List<Species> species;
  final String? currentId;
  final bool allowUnknown;
  final String title;

  @override
  State<_SpeciesPickerDialog> createState() => _SpeciesPickerDialogState();
}

class _SpeciesPickerDialogState extends State<_SpeciesPickerDialog> {
  String _query = '';

  late final List<Species> _sorted = [...widget.species]
    ..sort((a, b) => foldAccents(a.commonName).compareTo(foldAccents(b.commonName)));

  bool _matches(Species s, String query) =>
      foldAccents(s.commonName).contains(query) ||
      foldAccents(s.scientificName ?? '').contains(query);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = foldAccents(_query.trim());
    final shown = [
      for (final s in _sorted)
        if (query.isEmpty || _matches(s, query)) s,
    ];
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(widget.title, style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Rechercher un champignon…',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (widget.allowUnknown && query.isEmpty)
                    ListTile(
                      minTileHeight: 56,
                      leading: const Icon(Icons.help_outline),
                      title: const Text('Je ne sais pas'),
                      subtitle: const Text('Garder la photo sans nom d\'espèce'),
                      selected: widget.currentId == null,
                      selectedTileColor: Palette.sage,
                      onTap: () => Navigator.of(context).pop<SpeciesChoice>((speciesId: null)),
                    ),
                  for (final s in shown)
                    ListTile(
                      minTileHeight: 56,
                      title: Text(s.commonName),
                      subtitle: s.isCustom
                          ? const Text('Fiche personnelle, non vérifiée')
                          : s.scientificName == null
                              ? null
                              : Text(
                                  s.scientificName!,
                                  style: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                      trailing: s.id == widget.currentId ? const Icon(Icons.check) : null,
                      selected: s.id == widget.currentId,
                      selectedTileColor: Palette.sage,
                      onTap: () => Navigator.of(context).pop<SpeciesChoice>((speciesId: s.id)),
                    ),
                  if (shown.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Aucune espèce ne correspond à cette recherche.'),
                    ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 10),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
