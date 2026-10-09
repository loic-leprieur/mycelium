import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/rustic.dart';
import '../../../core/safety_widgets.dart';
import '../../../core/theme.dart';
import '../../../data/photo_store.dart';
import '../../../data/providers.dart';
import '../../journal/ui/harvest_form_sheet.dart';
import '../../map/location.dart';
import '../../species/data/species_seed.dart';
import '../../species/domain/species.dart';
import '../analysis/analysis_notes.dart';
import '../history/history_logic.dart';
import '../history/identification_saver.dart';
import '../history/place_sheet.dart';
import '../history/species_picker.dart';
import '../identifier.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key, required this.outcome});

  final IdentificationOutcome outcome;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _saving = false;
  SavedIdentification? _saved;

  IdentificationOutcome get outcome => widget.outcome;

  /// Une vraie identification (pas la démonstration) avec sa photo : l'utilisateur
  /// peut la confirmer et l'enregistrer (ID-5).
  bool get _canSave => !outcome.isDemo && outcome.imagePath != null;

  /// Enregistre l'identification et l'espèce retenue par l'utilisateur ([speciesId],
  /// null = « Je ne sais pas »). Le résultat du modèle est conservé à part (RM-3).
  ///
  /// Avec une espèce, on demande d'abord où elle a été trouvée ; fermer cette
  /// feuille annule tout, rien n'est écrit. Sans espèce, la photo et sa position
  /// éventuelle sont gardées sans coin.
  Future<void> _decide(String? speciesId) async {
    final path = outcome.imagePath;
    if (path == null || _saving) return;
    setState(() => _saving = true);

    final SavedIdentification saved;
    try {
      final PlaceChoice? place =
          speciesId == null ? const NoPlace() : await _askPlace(speciesId);
      if (place == null || !mounted) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      saved = await saveIdentification(
        ref.read(databaseProvider),
        outcome: outcome,
        speciesId: speciesId,
        place: place,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L\'enregistrement a échoué. Réessayez.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = saved;
    });
    final spotName = saved.spot?.name;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(speciesId == null
            ? 'Enregistré : espèce inconnue.'
            : spotName == null
                ? 'Identification enregistrée dans l\'historique.'
                : 'Identification enregistrée dans le coin « $spotName ».'),
      ),
    );
    if (speciesId != null) {
      final copy = await resolveStoredPhoto(saved.photoPath);
      await _offerHarvest(speciesId, copy?.path ?? path);
    }
  }

  /// Feuille « Où l'avez-vous trouvé ? » (null = l'utilisateur a renoncé).
  Future<PlaceChoice?> _askPlace(String speciesId) async {
    final db = ref.read(databaseProvider);
    final spots = await db.select(db.spots).get();
    if (!mounted) return null;
    final lat = outcome.latitude;
    final lon = outcome.longitude;
    return askPlace(
      context,
      speciesId: speciesId,
      speciesName: ref.read(speciesByIdProvider(speciesId))?.commonName ?? speciesId,
      spots: spots,
      now: DateTime.now(),
      photoPosition: lat != null && lon != null ? LatLng(lat, lon) : null,
      currentPosition: ref.read(locationProvider).value?.latLng,
    );
  }

  Future<void> _pickOther() async {
    final all = ref.read(allSpeciesProvider).value ?? speciesSeed;
    final choice = await pickSpecies(context, species: all);
    if (choice != null) await _decide(choice.speciesId);
  }

  /// Propose d'ajouter l'espèce retenue à une sortie, comme récolte (LOG-2).
  /// [photoPath] est un chemin ABSOLU : le formulaire de récolte copie la photo.
  Future<void> _offerHarvest(String speciesId, String photoPath) async {
    final db = ref.read(databaseProvider);
    final outings = await (db.select(db.outings)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
    final spotRows = await db.select(db.spots).get();
    if (outings.isEmpty || !mounted) return;
    // La notification d'enregistrement masquerait le bas de la feuille.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final spots = {for (final s in spotRows) s.id: s.name};
    final outingId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Ajouter à une sortie ?',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              for (final o in outings.take(6))
                ListTile(
                  minTileHeight: 56,
                  title: Text(DateFormat.yMMMMEEEEd('fr').format(o.startedAt)),
                  subtitle: o.spotId != null && spots[o.spotId] != null
                      ? Text(spots[o.spotId]!)
                      : null,
                  onTap: () => Navigator.of(context).pop(o.id),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Non merci'),
              ),
            ],
          ),
        ),
      ),
    );
    if (outingId != null && mounted) {
      await showHarvestForm(
        context,
        outingId,
        initialSpeciesId: speciesId,
        initialPhotoPath: photoPath,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = outcome.imagePath;
    return Scaffold(
      appBar: AppBar(title: const Text('Résultat')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (path != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(path),
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(height: 60),
                ),
              ),
            ),
          if (outcome.isDemo)
            InfoBanner(
              title: 'DÉMONSTRATION — résultat fictif',
              message: outcome.scenarioLabel ?? '',
              color: const Color(0xFFFFB74D),
            ),
          if (outcome.dangerousSpeciesIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoBanner(
              title: 'ATTENTION : espèce dangereuse parmi les candidats',
              message: _dangerNames(),
              color: const Color(0xFFC62828),
              icon: Icons.dangerous,
            )
                .animate()
                .fadeIn(duration: 250.ms)
                .then(delay: 150.ms)
                .shake(hz: 4, duration: 600.ms, offset: const Offset(6, 0)),
          ],
          const SizedBox(height: 16),
          if (outcome.isInsufficient)
            const InfoBanner(
              title: 'Identification insuffisante',
              message:
                  'Les propositions sont trop incertaines ou trop proches. Aucune '
                  'espèce ne peut être retenue. Photographiez le chapeau, le dessous, '
                  'le pied et la base, puis faites contrôler le champignon.',
              color: Color(0xFFE0E0E0),
              icon: Icons.help_outline,
            )
          else
            Text('Identification probable', style: theme.textTheme.titleMedium),
          if (!outcome.isDemo && outcome.unknownScore >= unknownScoreNoteThreshold) ...[
            const SizedBox(height: 10),
            InfoBanner(
              title: 'Peut-être une espèce hors de la base',
              message:
                  'Le modèle estime à ${(outcome.unknownScore * 100).round()} % la '
                  'probabilité que cette photo ne corresponde à aucune des espèces '
                  'connues de l\'application. Ne vous fiez pas aux propositions.',
              color: const Color(0xFFE0E0E0),
              icon: Icons.help_outline,
            ),
          ],
          AnalysisNotes(outcome: outcome),
          const SizedBox(height: 8),
          for (var i = 0; i < outcome.candidates.length; i++)
            _CandidateTile(
              rank: i + 1,
              candidate: outcome.candidates[i],
              muted: outcome.isInsufficient,
            ).stagger(i + 1),
          const SizedBox(height: 16),
          const SafetyDisclaimer(),
          if (_canSave) ...[
            const SizedBox(height: 18),
            _Decision(
              saving: _saving,
              saved: _saved,
              suggestedId: outcome.isInsufficient || outcome.candidates.isEmpty
                  ? null
                  : outcome.candidates.first.speciesId,
              onConfirm: _decide,
              onOther: _pickOther,
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  String _dangerNames() {
    final names = [
      for (final id in outcome.dangerousSpeciesIds)
        ref.read(speciesByIdProvider(id))?.commonName ?? id,
    ];
    return '${names.join(', ')}. Ne cueillez ni ne consommez ce champignon '
        'en cas de doute.';
  }
}

/// « Votre décision » : l'espèce enregistrée est toujours celle que choisit
/// l'utilisateur, jamais celle de l'IA par défaut (RM-3).
class _Decision extends ConsumerWidget {
  const _Decision({
    required this.saving,
    required this.saved,
    required this.suggestedId,
    required this.onConfirm,
    required this.onOther,
  });

  final bool saving;
  final SavedIdentification? saved;
  final String? suggestedId;
  final Future<void> Function(String? speciesId) onConfirm;
  final Future<void> Function() onOther;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final done = saved;
    if (done != null) {
      final spotName = done.spot?.name;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoBanner(
            title: 'Enregistré',
            message: done.speciesId == null
                ? 'Cette photo est dans votre historique, sans nom d\'espèce.'
                : spotName == null
                    ? 'Cette identification est dans votre historique, avec '
                        'l\'espèce que vous avez retenue.'
                    : 'Cette identification est dans votre historique, rangée '
                        'dans le coin « $spotName ».',
            color: Palette.sage,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/identify/history'),
            icon: const Icon(Icons.history),
            label: const Text('Voir mes identifications'),
          ),
        ],
      );
    }
    final suggested = suggestedId == null
        ? null
        : ref.watch(speciesByIdProvider(suggestedId!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Votre décision', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Vous restez seul juge : l\'espèce enregistrée est celle que vous choisissez.',
        ),
        const SizedBox(height: 10),
        if (suggested != null) ...[
          FilledButton.icon(
            onPressed: saving ? null : () => onConfirm(suggested.id),
            icon: const Icon(Icons.check),
            label: Text('C\'est bien : ${suggested.commonName}'),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: saving ? null : onOther,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Une autre espèce…'),
        ),
        TextButton(
          onPressed: saving ? null : () => onConfirm(null),
          child: const Text('Je ne sais pas'),
        ),
      ],
    );
  }
}

class _CandidateTile extends ConsumerWidget {
  const _CandidateTile({
    required this.rank,
    required this.candidate,
    required this.muted,
  });

  final int rank;
  final Candidate candidate;
  final bool muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final species = ref.watch(speciesByIdProvider(candidate.speciesId));
    final pct = (candidate.score * 100).round();
    final confusions = species?.confusions ?? const <Confusion>[];
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: species?.edibility.color.withValues(alpha: 0.15),
          child: Text('$rank'),
        ),
        title: Text(species?.commonName ?? candidate.speciesId),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (species?.scientificName != null)
              Text(
                species!.scientificName!,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: 4),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: candidate.score),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 9,
                  backgroundColor: Palette.sage.withValues(alpha: .5),
                  color: muted
                      ? Colors.grey
                      : (species?.edibility.isDangerous ?? false)
                          ? Palette.berry
                          : Palette.moss,
                ),
              ),
            ),
            // ID-3 : les confusions de chaque candidat, à chaque résultat.
            if (confusions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Confusions possibles : ${confusions.map((c) => c.name).join(', ')}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
        trailing: Text(
          '$pct %',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: muted ? Colors.grey : null,
              ),
        ),
        onTap: species == null
            ? null
            : () => context.push('/species/${species.id}'),
      ),
    );
  }
}
