import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/safety_widgets.dart';
import '../../../core/theme.dart';
import '../../../data/backup/backup_format.dart';
import '../../../data/backup/backup_providers.dart';
import '../../../data/backup/backup_service.dart';
import '../../../data/backup/backup_system.dart';

/// Sauvegarde et données : export/import d'une archive complète (DATA-2) et
/// suppression de toutes les données (DATA-4).
class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  /// Opération en cours (texte + avancement) ; null = écran libre.
  String? _busy;
  double? _progress;

  void _setBusy(String? message, [double? progress]) {
    if (!mounted) return;
    setState(() {
      _busy = message;
      _progress = progress;
    });
  }

  void _onProgress(BackupProgress p) {
    final text = switch (p.phase) {
      BackupPhase.collecting => 'Lecture de vos données…',
      BackupPhase.packing => p.total > 0 ? 'Photos : ${p.done} sur ${p.total}' : 'Création de la sauvegarde…',
      BackupPhase.reading => 'Vérification de la sauvegarde…',
      BackupPhase.photos => 'Copie des photos : ${p.done} sur ${p.total}',
      BackupPhase.saving => 'Enregistrement de vos données…',
    };
    _setBusy(text, p.fraction);
  }

  Future<void> _message(String title, String text, {String? detail}) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text),
                if (detail != null) ...[
                  const SizedBox(height: 10),
                  Text(detail, style: Theme.of(ctx).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );

  Future<void> _fail(Object error, String title) {
    if (error is BackupException) return _message(title, error.message, detail: error.detail);
    return _message(title, 'Une erreur inattendue est survenue. Vos données n\'ont pas été modifiées.',
        detail: '$error');
  }

  Rect? _origin(BuildContext buttonContext) {
    final box = buttonContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  // --- Créer ---

  Future<void> _create(BuildContext buttonContext) async {
    final origin = _origin(buttonContext);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Créer une sauvegarde'),
        content: const Text(
          'Attention : ce fichier contient VOS COINS ET VOS POSITIONS GPS. '
          'Ne le partagez avec personne : un coin à champignons est un secret.\n\n'
          'Rangez-le dans un endroit privé, par exemple l\'application Fichiers.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuer')),
        ],
      ),
    );
    if (go != true || !mounted) return;

    _setBusy('Création de la sauvegarde…');
    final system = ref.read(backupSystemProvider);
    File? file;
    try {
      final service = await ref.read(backupServiceProvider.future);
      final archive = await service.createArchive(
        outputDir: await system.workDirectory(),
        onProgress: _onProgress,
      );
      file = archive.file;
      _setBusy('Enregistrement de la sauvegarde…');
      final delivery = await system.deliver(archive.file, origin: origin);
      if (delivery == BackupDelivery.cancelled) {
        await archive.file.delete();
        _setBusy(null);
        if (mounted) {
          await _message('Sauvegarde non enregistrée',
              'Vous avez fermé la fenêtre sans choisir où ranger le fichier : aucune sauvegarde n\'a été faite.');
        }
        return;
      }
      await service.markBackupDone(archive.createdAt);
      _setBusy(null);
      if (!mounted) return;
      final missing = archive.missingPhotos;
      await _message(
        'Sauvegarde terminée',
        '${archive.counts.describe()} ont été sauvegardés.'
        '${missing > 0 ? '\n\n$missing photo(s) étaient introuvables sur l\'appareil et n\'ont pas pu être incluses.' : ''}',
      );
    } catch (e) {
      _setBusy(null);
      if (file != null && await file.exists()) await file.delete();
      if (mounted) await _fail(e, 'La sauvegarde a échoué');
    }
  }

  // --- Restaurer ---

  Future<void> _restore() async {
    final system = ref.read(backupSystemProvider);
    final File? picked;
    try {
      picked = await system.pickArchive();
    } catch (e) {
      if (mounted) await _fail(e, 'Impossible d\'ouvrir le fichier');
      return;
    }
    if (picked == null || !mounted) return;

    _setBusy('Vérification de la sauvegarde…');
    final BackupService service;
    final BackupPreview preview;
    try {
      service = await ref.read(backupServiceProvider.future);
      preview = await service.inspect(picked);
    } catch (e) {
      _setBusy(null);
      if (mounted) await _fail(e, 'Cette sauvegarde ne peut pas être restaurée');
      return;
    }
    _setBusy(null);
    if (!mounted) return;

    final mode = await showDialog<RestoreMode>(
      context: context,
      builder: (ctx) => _RestoreDialog(preview: preview),
    );
    if (mode == null || !mounted) return;
    if (mode == RestoreMode.replace) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tout remplacer ?'),
          content: Text(
            preview.counts.userItems == 0
                ? 'Cette sauvegarde est vide : toutes vos données actuelles seront effacées.'
                : 'Vos coins, sorties, récoltes, identifications et photos actuels seront '
                    'EFFACÉS, puis remplacés par ceux de la sauvegarde. Vous ne pourrez pas revenir en arrière.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Palette.berry),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tout remplacer'),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }

    _setBusy('Restauration en cours…');
    try {
      final report = await service.restore(picked, mode: mode, onProgress: _onProgress);
      _setBusy(null);
      if (!mounted) return;
      final text = mode == RestoreMode.replace
          ? 'Vos données ont été remplacées : ${report.added.copyWith(photos: report.photosCopied).describe()}.'
          : 'Ajouté : ${report.added.copyWith(photos: report.photosCopied).describe()}.'
              '${report.alreadyPresent.userItems > 0 ? '\nDéjà présents, laissés tels quels : ${report.alreadyPresent.describe()}.' : ''}';
      await _message('Restauration terminée', text);
    } catch (e) {
      _setBusy(null);
      if (mounted) await _fail(e, 'La restauration a échoué');
    }
  }

  // --- Supprimer ---

  Future<void> _delete() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer toutes vos données ?'),
        content: const Text(
          'Coins, sorties, récoltes, identifications, espèces ajoutées et photos seront '
          'effacés de cet appareil, définitivement. L\'application redeviendra comme neuve.\n\n'
          'Créez d\'abord une sauvegarde si vous voulez pouvoir les retrouver.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.berry),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;
    final typed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _TypeToConfirmDialog(),
    );
    if (typed != true || !mounted) return;

    _setBusy('Suppression en cours…');
    try {
      final system = ref.read(backupSystemProvider);
      final service = await ref.read(backupServiceProvider.future);
      await service.deleteEverything(archiveDir: await system.workDirectory());
      _setBusy(null);
      if (mounted) context.go('/splash');
    } catch (e) {
      _setBusy(null);
      if (mounted) await _fail(e, 'La suppression a échoué');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = ref.watch(lastBackupProvider).value;
    final now = ref.watch(backupClockProvider)();
    final overdue = backupIsOverdue(last, now);
    final busy = _busy != null;

    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Sauvegarde et données')),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              children: [
                _LastBackupCard(last: last, now: now),
                if (overdue) ...[
                  const SizedBox(height: 12),
                  InfoBanner(
                    title: 'Pensez à sauvegarder',
                    message: last == null
                        ? 'Vous n\'avez encore jamais fait de sauvegarde. '
                        : 'Votre dernière sauvegarde date de plus de 7 jours. ',
                    color: const Color(0xFFFFCC80),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Avec un compte Apple gratuit, l\'application doit être réinstallée '
                    'toutes les semaines : sans sauvegarde récente, vous perdriez vos coins et vos photos.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 24),
                Text('Créer une sauvegarde', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Un seul fichier (.zip) avec tous vos coins, sorties, récoltes, '
                  'identifications et photos.',
                ),
                const SizedBox(height: 10),
                const InfoBanner(
                  title: 'Fichier privé',
                  message: 'Il contient VOS COINS ET VOS POSITIONS GPS. Ne le partagez pas.',
                  color: Color(0xFFFFE082),
                  icon: Icons.lock_outline,
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (buttonContext) => FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: busy ? null : () => _create(buttonContext),
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Créer une sauvegarde'),
                  ),
                ),
                const SizedBox(height: 28),
                Text('Restaurer une sauvegarde', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Retrouvez vos données à partir d\'un fichier créé par Mycelium '
                  '(changement de téléphone, réinstallation…).',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: busy ? null : _restore,
                  icon: const Icon(Icons.restore),
                  label: const Text('Restaurer une sauvegarde'),
                ),
                const SizedBox(height: 28),
                Text('Supprimer toutes mes données', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Efface tout de cet appareil. L\'application redevient comme neuve.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    foregroundColor: Palette.berry,
                    side: const BorderSide(color: Palette.berry),
                  ),
                  onPressed: busy ? null : _delete,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Supprimer toutes mes données'),
                ),
              ],
            ),
            if (busy) ...[
              const ModalBarrier(dismissible: false, color: Colors.black38),
              Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_busy!, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        SizedBox(width: 240, child: LinearProgressIndicator(value: _progress)),
                        const SizedBox(height: 12),
                        const Text('Ne quittez pas l\'application.'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension on BackupCounts {
  BackupCounts copyWith({int? photos}) => BackupCounts(
        spots: spots,
        outings: outings,
        harvests: harvests,
        customSpecies: customSpecies,
        identifications: identifications,
        spotSpecies: spotSpecies,
        appMeta: appMeta,
        photos: photos ?? this.photos,
      );
}

class _LastBackupCard extends StatelessWidget {
  const _LastBackupCard({required this.last, required this.now});

  final DateTime? last;
  final DateTime now;

  static String _age(DateTime last, DateTime now) {
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(last.year, last.month, last.day)).inDays;
    if (days <= 0) return 'aujourd\'hui';
    if (days == 1) return 'hier';
    return 'il y a $days jours';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = last;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.history, size: 32, color: Palette.forest),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date == null ? 'Dernière sauvegarde : jamais' : 'Dernière sauvegarde :',
                    style: theme.textTheme.titleMedium,
                  ),
                  if (date != null)
                    Text('${DateFormat.yMMMMd('fr').format(date)} (${_age(date, now)})',
                        style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Récapitulatif de l'archive et choix Fusionner / Remplacer tout.
class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog({required this.preview});

  final BackupPreview preview;

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  RestoreMode _mode = RestoreMode.merge;

  Widget _choice(RestoreMode mode, String title, String subtitle) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          minTileHeight: 72,
          selected: _mode == mode,
          leading: Icon(_mode == mode ? Icons.radio_button_checked : Icons.radio_button_unchecked),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          onTap: () => setState(() => _mode = mode),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    return AlertDialog(
      title: const Text('Restaurer cette sauvegarde ?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sauvegarde du ${DateFormat.yMMMMd('fr').format(preview.createdAt.toLocal())} :'),
            const SizedBox(height: 4),
            Text(preview.counts.describe(), style: Theme.of(context).textTheme.titleMedium),
            if (preview.missingPhotos > 0)
              Text('${preview.missingPhotos} photo(s) n\'étaient déjà plus sur l\'appareil lors de la sauvegarde.'),
            const SizedBox(height: 12),
            _choice(RestoreMode.merge, 'Fusionner',
                'Ajoute ce qui manque, sans rien supprimer (conseillé).'),
            _choice(RestoreMode.replace, 'Remplacer tout',
                'Efface vos données actuelles, puis importe la sauvegarde.'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, _mode), child: const Text('Restaurer')),
      ],
    );
  }
}

/// Seconde confirmation de la suppression : il faut écrire le mot SUPPRIMER.
class _TypeToConfirmDialog extends StatefulWidget {
  const _TypeToConfirmDialog();

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _ok => _controller.text.trim().toUpperCase() == 'SUPPRIMER';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Dernière confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pour confirmer, écrivez le mot SUPPRIMER ci-dessous.'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'SUPPRIMER'),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.berry),
            onPressed: _ok ? () => Navigator.pop(context, true) : null,
            child: const Text('Tout supprimer'),
          ),
        ],
      );
}
