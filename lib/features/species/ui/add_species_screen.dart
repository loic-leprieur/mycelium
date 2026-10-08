import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/safety_widgets.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';

/// Ajout d'une espèce personnelle (ENC-7).
class AddSpeciesScreen extends ConsumerStatefulWidget {
  const AddSpeciesScreen({super.key});

  @override
  ConsumerState<AddSpeciesScreen> createState() => _AddSpeciesScreenState();
}

class _AddSpeciesScreenState extends ConsumerState<AddSpeciesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  String? _pickedPath;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600);
      if (file != null) setState(() => _pickedPath = file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'accéder à la photo.')),
      );
    }
  }

  Future<String?> _persistPhoto(String id) async {
    final source = _pickedPath;
    if (source == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final photos = Directory(p.join(dir.path, 'species_photos'));
    await photos.create(recursive: true);
    final dest = p.join(photos.path, '$id${p.extension(source)}');
    await File(source).copy(dest);
    return dest;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final id = const Uuid().v4();
    final photoPath = await _persistPhoto(id);
    await ref.read(databaseProvider).upsertCustomSpecies(
          CustomSpeciesCompanion.insert(
            id: id,
            commonName: _name.text.trim(),
            description: Value(_description.text.trim()),
            photoPath: Value(photoPath),
            createdAt: DateTime.now(),
          ),
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle espèce')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const InfoBanner(
              title: 'Fiche personnelle',
              message:
                  'Cette fiche reste sur votre téléphone. Elle n\'est pas vérifiée '
                  'et n\'indique jamais si le champignon est comestible.',
              color: Color(0xFFE0E0E0),
              icon: Icons.person,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Indiquez un nom' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            if (_pickedPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(_pickedPath!), height: 200, fit: BoxFit.cover),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Prendre une photo'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galerie'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
