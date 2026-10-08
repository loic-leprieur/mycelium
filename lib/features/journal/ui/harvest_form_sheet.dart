import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database.dart';
import '../../../data/photo_store.dart';
import '../../../data/providers.dart';
import '../../species/domain/species.dart';

/// Formulaire d'ajout d'une récolte : espèce, quantité, poids en grammes, photo.
Future<void> showHarvestForm(BuildContext context, String outingId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => HarvestFormSheet(outingId: outingId),
    );

class HarvestFormSheet extends ConsumerStatefulWidget {
  const HarvestFormSheet({super.key, required this.outingId});

  final String outingId;

  @override
  ConsumerState<HarvestFormSheet> createState() => _HarvestFormSheetState();
}

class _HarvestFormSheetState extends ConsumerState<HarvestFormSheet> {
  final _count = TextEditingController();
  final _weight = TextEditingController();
  final _notes = TextEditingController();
  String? _speciesId;
  String? _pickedPath;
  bool _saving = false;

  @override
  void dispose() {
    _count.dispose();
    _weight.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600);
      if (file != null) setState(() => _pickedPath = file.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'accéder à la photo.")),
      );
    }
  }

  Future<void> _save() async {
    final speciesId = _speciesId;
    if (speciesId == null) return;
    setState(() => _saving = true);

    final id = const Uuid().v4();
    final photo = _pickedPath == null
        ? null
        : await savePhoto(_pickedPath!, folder: 'harvest_photos', id: id);
    final notes = _notes.text.trim();

    await ref.read(databaseProvider).addHarvest(
          HarvestsCompanion.insert(
            id: id,
            outingId: widget.outingId,
            speciesId: speciesId,
            quantityCount: Value(int.tryParse(_count.text.trim())),
            weightGrams: Value(int.tryParse(_weight.text.trim())),
            photoPath: Value(photo),
            notes: Value(notes.isEmpty ? null : notes),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final species = [...(ref.watch(allSpeciesProvider).value ?? const <Species>[])]
      ..sort((a, b) => a.commonName.compareTo(b.commonName));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ajouter une récolte', style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _speciesId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Espèce'),
              items: [
                for (final s in species)
                  DropdownMenuItem(value: s.id, child: Text(s.commonName)),
              ],
              onChanged: (v) => setState(() => _speciesId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _count,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantité'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _weight,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Poids (g)',
                      suffixText: 'g',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 14),
            if (_pickedPath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(File(_pickedPath!), height: 170, fit: BoxFit.cover),
                ),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Photo de la récolte'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galerie'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: (_speciesId == null || _saving) ? null : _save,
                    child: const Text('Ajouter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
