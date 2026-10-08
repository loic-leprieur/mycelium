import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database.dart';
import '../../../data/providers.dart';

class OutingFormScreen extends ConsumerStatefulWidget {
  const OutingFormScreen({super.key});

  @override
  ConsumerState<OutingFormScreen> createState() => _OutingFormScreenState();
}

class _OutingFormScreenState extends ConsumerState<OutingFormScreen> {
  DateTime _date = DateTime.now();
  String? _spotId;
  final _notes = TextEditingController();
  final _duration = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('fr'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final id = const Uuid().v4();
    final notes = _notes.text.trim();
    await ref.read(databaseProvider).upsertOuting(
          OutingsCompanion.insert(
            id: id,
            startedAt: _date,
            spotId: Value(_spotId),
            durationMin: Value(int.tryParse(_duration.text.trim())),
            notes: Value(notes.isEmpty ? null : notes),
          ),
        );
    if (!mounted) return;
    context.pushReplacement('/journal/$id');
  }

  @override
  Widget build(BuildContext context) {
    final spots = ref.watch(spotsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle sortie')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text(DateFormat.yMMMMEEEEd('fr').format(_date)),
            trailing: const Icon(Icons.edit),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _spotId,
            decoration: const InputDecoration(labelText: 'Coin visité'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Aucun / autre lieu')),
              for (final s in spots) DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setState(() => _spotId = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Durée (minutes)'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Créer la sortie')),
        ],
      ),
    );
  }
}
