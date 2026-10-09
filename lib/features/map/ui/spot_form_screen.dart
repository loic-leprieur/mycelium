import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../spot_form_sections.dart';

const _forestTypes = ['Feuillus', 'Conifères', 'Mixte', 'Autre'];

/// Création / modification / suppression d'un coin (SPOT-1 à SPOT-3), avec ses
/// espèces observées (SPOT-4) et, une fois créé, les sorties qui y ont eu lieu
/// (SPOT-5).
class SpotFormScreen extends ConsumerStatefulWidget {
  const SpotFormScreen({super.key, this.spotId, this.latitude, this.longitude});

  final String? spotId;
  final double? latitude;
  final double? longitude;

  @override
  ConsumerState<SpotFormScreen> createState() => _SpotFormScreenState();
}

class _SpotFormScreenState extends ConsumerState<SpotFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  String? _forestType;
  bool _favorite = false;
  bool _loaded = false;
  DateTime? _createdAt;

  /// Espèces observées (espèce -> dernière observation) : copie de travail,
  /// écrite en base à l'enregistrement, comme le reste du formulaire. Un coin
  /// pas encore créé n'a pas de ligne en base où les noter avant.
  final Map<String, DateTime> _seen = {};

  /// Ce que la base contenait à l'ouverture, pour n'écrire que les différences.
  Map<String, DateTime> _savedSeen = const {};

  bool get _isEdit => widget.spotId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _load();
    } else {
      _lat.text = (widget.latitude ?? 0).toStringAsFixed(6);
      _lon.text = (widget.longitude ?? 0).toStringAsFixed(6);
      _loaded = true;
    }
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final spot = await db.spotById(widget.spotId!);
    final observed = await db.watchSpotSpecies().first;
    if (!mounted) return;
    if (spot == null) {
      context.pop();
      return;
    }
    setState(() {
      _name.text = spot.name;
      _notes.text = spot.notes ?? '';
      _lat.text = spot.latitude.toStringAsFixed(6);
      _lon.text = spot.longitude.toStringAsFixed(6);
      _forestType = spot.forestType;
      _favorite = spot.isFavorite;
      _createdAt = spot.createdAt;
      _savedSeen = {
        for (final row in observed)
          if (row.spotId == spot.id) row.speciesId: row.lastSeenAt,
      };
      _seen.addAll(_savedSeen);
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  String? _validateCoord(String? v, double min, double max) {
    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (n == null || n < min || n > max) return 'Valeur invalide';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final notes = _notes.text.trim();
    final spotId = widget.spotId ?? const Uuid().v4();
    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      await db.upsertSpot(
        SpotsCompanion.insert(
          id: spotId,
          name: _name.text.trim(),
          latitude: double.parse(_lat.text.replaceAll(',', '.')),
          longitude: double.parse(_lon.text.replaceAll(',', '.')),
          forestType: Value(_forestType),
          notes: Value(notes.isEmpty ? null : notes),
          isFavorite: Value(_favorite),
          createdAt: _createdAt ?? now,
          updatedAt: now,
        ),
      );
      // Espèces retirées, puis espèces ajoutées (ou revues plus récemment).
      for (final speciesId in _savedSeen.keys) {
        if (!_seen.containsKey(speciesId)) await db.unmarkSpecies(spotId, speciesId);
      }
      for (final MapEntry(key: speciesId, value: seenAt) in _seen.entries) {
        final before = _savedSeen[speciesId];
        if (before == null || seenAt.isAfter(before)) {
          await db.markSpeciesSeen(spotId, speciesId, seenAt);
        }
      }
    });
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce coin ?'),
        content: const Text('Cette action est définitive.'),
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
    if (ok == true) {
      await ref.read(databaseProvider).deleteSpot(widget.spotId!);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le coin' : 'Nouveau coin'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Nom du coin'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Indiquez un nom'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _lat,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(labelText: 'Latitude'),
                          validator: (v) => _validateCoord(v, -90, 90),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lon,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(labelText: 'Longitude'),
                          validator: (v) => _validateCoord(v, -180, 180),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: _forestType,
                    decoration: const InputDecoration(labelText: 'Type de forêt'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Non précisé')),
                      for (final t in _forestTypes)
                        DropdownMenuItem(value: t, child: Text(t)),
                    ],
                    onChanged: (v) => setState(() => _forestType = v),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notes,
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      alignLabelWithHint: true,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Coin favori'),
                    secondary: const Icon(Icons.star),
                    value: _favorite,
                    onChanged: (v) => setState(() => _favorite = v),
                  ),
                  const SizedBox(height: 16),
                  SpotSpeciesSection(
                    seen: _seen,
                    onAdd: (speciesId) =>
                        setState(() => _seen[speciesId] = DateTime.now()),
                    onRemove: (speciesId) => setState(() => _seen.remove(speciesId)),
                  ),
                  if (_isEdit) ...[
                    const SizedBox(height: 24),
                    SpotVisitsSection(spotId: widget.spotId!),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(onPressed: _save, child: const Text('Enregistrer')),
                ],
              ),
            ),
    );
  }
}
