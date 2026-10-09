import 'dart:convert';

import '../database.dart';
import 'backup_format.dart';

/// Manifeste de l'archive (`manifest.json`).
class BackupManifest {
  const BackupManifest({
    required this.appVersion,
    required this.schemaVersion,
    required this.createdAt,
    required this.counts,
    this.missingPhotos = const [],
  });

  final String appVersion;
  final int schemaVersion;
  final DateTime createdAt;
  final BackupCounts counts;

  /// Photos référencées par la base mais introuvables sur l'appareil au moment
  /// de l'export : elles ne sont pas dans l'archive, et ce n'est pas une erreur.
  final List<String> missingPhotos;

  String toJsonText() => const JsonEncoder.withIndent('  ').convert({
        'format': backupFormat,
        'formatVersion': backupFormatVersion,
        'appVersion': appVersion,
        'schemaVersion': schemaVersion,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'counts': counts.toJson(),
        'missingPhotos': missingPhotos,
      });
}

/// Contenu d'une archive lue et validée, prêt à être écrit en base.
class ParsedBackup {
  const ParsedBackup({
    required this.manifest,
    required this.spots,
    required this.outings,
    required this.harvests,
    required this.customSpecies,
    required this.identifications,
    required this.spotSpecies,
    required this.appMeta,
    required this.photoPaths,
  });

  final BackupManifest manifest;
  final List<Spot> spots;
  final List<Outing> outings;
  final List<Harvest> harvests;
  final List<CustomSpeciesRow> customSpecies;
  final List<Identification> identifications;
  final List<SpotSpeciesRow> spotSpecies;

  /// Valeurs persistantes, sans les clés de consentement.
  final Map<String, String> appMeta;

  /// Chemins relatifs des photos présentes dans l'archive ET utilisées par une ligne.
  final List<String> photoPaths;

  BackupCounts get counts => BackupCounts(
        spots: spots.length,
        outings: outings.length,
        harvests: harvests.length,
        customSpecies: customSpecies.length,
        identifications: identifications.length,
        spotSpecies: spotSpecies.length,
        appMeta: appMeta.length,
        photos: photoPaths.length,
      );
}

// --- Écriture ---

String _date(DateTime d) => d.toUtc().toIso8601String();

Map<String, Object?> spotJson(Spot s) => {
      'id': s.id,
      'name': s.name,
      'latitude': s.latitude,
      'longitude': s.longitude,
      'forestType': s.forestType,
      'notes': s.notes,
      'isFavorite': s.isFavorite,
      'createdAt': _date(s.createdAt),
      'updatedAt': _date(s.updatedAt),
    };

Map<String, Object?> outingJson(Outing o) => {
      'id': o.id,
      'spotId': o.spotId,
      'startedAt': _date(o.startedAt),
      'durationMin': o.durationMin,
      'notes': o.notes,
    };

/// [photoPath] : chemin RELATIF de l'archive (voir `archivePhotoPath`).
Map<String, Object?> harvestJson(Harvest h, String? photoPath) => {
      'id': h.id,
      'outingId': h.outingId,
      'speciesId': h.speciesId,
      'quantityCount': h.quantityCount,
      'weightGrams': h.weightGrams,
      'photoPath': photoPath,
      'notes': h.notes,
    };

Map<String, Object?> customSpeciesJson(CustomSpeciesRow r, String? photoPath) => {
      'id': r.id,
      'commonName': r.commonName,
      'description': r.description,
      'photoPath': photoPath,
      'createdAt': _date(r.createdAt),
    };

Map<String, Object?> identificationJson(Identification i, String photoPath) => {
      'id': i.id,
      'photoPath': photoPath,
      'modelVersion': i.modelVersion,
      'top5Json': i.top5Json,
      'unknownScore': i.unknownScore,
      'chosenSpeciesId': i.chosenSpeciesId,
      'createdAt': _date(i.createdAt),
      'latitude': i.latitude,
      'longitude': i.longitude,
      'spotId': i.spotId,
    };

Map<String, Object?> spotSpeciesJson(SpotSpeciesRow r) => {
      'spotId': r.spotId,
      'speciesId': r.speciesId,
      'lastSeenAt': _date(r.lastSeenAt),
    };

// --- Lecture ---

BackupException _invalid(String message) =>
    BackupException(BackupErrorKind.invalid, 'Sauvegarde illisible : $message');

/// Accès typé aux champs d'un objet JSON, avec des erreurs qui disent où
/// (« spots[3].latitude ») et ce qui était attendu.
class _Fields {
  _Fields(this.map, this.where);

  final Map<String, Object?> map;
  final String where;

  Never _bad(String key, String expected) =>
      throw _invalid('$where.$key doit être $expected.');

  Object? _get(String key) => map[key];

  String id(String key) {
    final v = _get(key);
    if (v is! String || v.isEmpty || v.length > 256) _bad(key, 'un identifiant (texte non vide)');
    return v;
  }

  String text(String key) {
    final v = _get(key);
    if (v is! String) _bad(key, 'un texte');
    return v;
  }

  String textOr(String key, String fallback) => _get(key) == null ? fallback : text(key);

  String? textOrNull(String key) => _get(key) == null ? null : text(key);

  /// Chemin de photo relatif, ou null s'il n'y en a pas.
  String? photoOrNull(String key) {
    final v = textOrNull(key);
    if (v == null || v.isEmpty) return null;
    if (safePhotoPath(v) == null) {
      throw BackupException(
        BackupErrorKind.unsafe,
        'Sauvegarde refusée : le chemin de photo « $v » ($where) n\'est pas valide.',
      );
    }
    return v;
  }

  int? _intOrNull(String key) {
    final v = _get(key);
    if (v == null) return null;
    if (v is int) return v;
    if (v is double && v.isFinite && v == v.truncateToDouble()) return v.toInt();
    _bad(key, 'un nombre entier');
  }

  int integer(String key) => _intOrNull(key) ?? _bad(key, 'un nombre entier');

  int? integerOrNull(String key) => _intOrNull(key);

  double? _realOrNull(String key) {
    final v = _get(key);
    if (v == null) return null;
    if (v is num && v.isFinite) return v.toDouble();
    _bad(key, 'un nombre');
  }

  double real(String key) => _realOrNull(key) ?? _bad(key, 'un nombre');

  double realOr(String key, double fallback) => _realOrNull(key) ?? fallback;

  double? realOrNull(String key) => _realOrNull(key);

  double latitude(String key) => _inRange(real(key), key, -90, 90);

  double longitude(String key) => _inRange(real(key), key, -180, 180);

  double? latitudeOrNull(String key) {
    final v = _realOrNull(key);
    return v == null ? null : _inRange(v, key, -90, 90);
  }

  double? longitudeOrNull(String key) {
    final v = _realOrNull(key);
    return v == null ? null : _inRange(v, key, -180, 180);
  }

  double _inRange(double v, String key, double min, double max) {
    if (v < min || v > max) _bad(key, 'compris entre ${min.toInt()} et ${max.toInt()}');
    return v;
  }

  bool flag(String key, {bool fallback = false}) {
    final v = _get(key);
    if (v == null) return fallback;
    if (v is! bool) _bad(key, 'vrai ou faux');
    return v;
  }

  DateTime date(String key) {
    final v = _get(key);
    final parsed = v is String ? DateTime.tryParse(v) : null;
    if (parsed == null) _bad(key, 'une date (ISO 8601)');
    return parsed;
  }
}

/// Liste d'objets JSON de la section [name] de `data.json`.
List<_Fields> _rows(Map<String, Object?> data, String name) {
  final section = data[name];
  if (section is! List) throw _invalid('la section « $name » est absente ou n\'est pas une liste.');
  return [
    for (var i = 0; i < section.length; i++)
      if (section[i] is Map<String, Object?>)
        _Fields(section[i] as Map<String, Object?>, '$name[$i]')
      else
        throw _invalid('$name[$i] n\'est pas un objet.'),
  ];
}

void _requireUnique(String section, Iterable<String> keys) {
  final seen = <String>{};
  for (final k in keys) {
    if (!seen.add(k)) throw _invalid('« $k » apparaît deux fois dans « $section ».');
  }
}

/// Décode un texte JSON qui doit être un objet.
Map<String, Object?> decodeJsonObject(String text, String what) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    throw _invalid('$what n\'est pas un JSON valide.');
  }
  if (decoded is! Map<String, Object?>) throw _invalid('$what doit être un objet JSON.');
  return decoded;
}

/// Lit `manifest.json`. Refuse un autre format, un conteneur ou un schéma plus
/// récent que ceux de l'application ([maxSchemaVersion]).
BackupManifest parseManifest(String text, {required int maxSchemaVersion}) {
  final Map<String, Object?> json;
  try {
    json = decodeJsonObject(text, 'Le manifeste');
  } on BackupException {
    throw const BackupException(
      BackupErrorKind.notABackup,
      'Ce fichier n\'est pas une sauvegarde Mycelium (manifeste illisible).',
    );
  }
  final f = _Fields(json, 'manifest');
  if (json['format'] != backupFormat) {
    throw const BackupException(
      BackupErrorKind.notABackup,
      'Ce fichier n\'est pas une sauvegarde Mycelium.',
    );
  }
  final formatVersion = f.integer('formatVersion');
  final schemaVersion = f.integer('schemaVersion');
  if (formatVersion > backupFormatVersion || schemaVersion > maxSchemaVersion) {
    throw const BackupException(
      BackupErrorKind.tooNew,
      'Cette sauvegarde vient d\'une version plus récente de Mycelium. '
      'Mettez l\'application à jour, puis recommencez.',
    );
  }
  if (formatVersion < 1 || schemaVersion < backupMinSchemaVersion) {
    throw const BackupException(
      BackupErrorKind.invalid,
      'Cette sauvegarde est trop ancienne ou ne peut pas être lue par cette version de Mycelium.',
    );
  }
  final countsJson = json['counts'];
  if (countsJson is! Map<String, Object?>) throw _invalid('le manifeste n\'indique pas les comptes par table.');
  final c = _Fields(countsJson, 'manifest.counts');
  final missing = json['missingPhotos'];
  if (missing != null && (missing is! List || missing.any((e) => e is! String))) {
    throw _invalid('manifest.missingPhotos doit être une liste de chemins.');
  }
  final missingPhotos = [...?(missing as List?)?.cast<String>()];
  for (final path in missingPhotos) {
    if (safePhotoPath(path) == null) {
      throw BackupException(BackupErrorKind.unsafe, 'Sauvegarde refusée : le chemin « $path » n\'est pas valide.');
    }
  }
  return BackupManifest(
    appVersion: f.text('appVersion'),
    schemaVersion: schemaVersion,
    createdAt: f.date('createdAt'),
    counts: BackupCounts(
      spots: c.integer('spots'),
      outings: c.integer('outings'),
      harvests: c.integer('harvests'),
      customSpecies: c.integer('customSpecies'),
      identifications: c.integer('identifications'),
      spotSpecies: c.integer('spotSpecies'),
      appMeta: c.integer('appMeta'),
      photos: c.integer('photos'),
    ),
    missingPhotos: missingPhotos,
  );
}

/// Lit `data.json` : valide chaque ligne (types, bornes, identifiants uniques,
/// chemins de photos) et vérifie que les comptes annoncés par le manifeste
/// sont exacts. [archivePhotos] : chemins relatifs des photos réellement
/// présents dans l'archive.
ParsedBackup parseData(
  String text,
  BackupManifest manifest, {
  required Set<String> archivePhotos,
}) {
  final data = decodeJsonObject(text, 'data.json');

  final spots = [
    for (final f in _rows(data, 'spots'))
      Spot(
        id: f.id('id'),
        name: f.text('name'),
        latitude: f.latitude('latitude'),
        longitude: f.longitude('longitude'),
        forestType: f.textOrNull('forestType'),
        notes: f.textOrNull('notes'),
        isFavorite: f.flag('isFavorite'),
        createdAt: f.date('createdAt'),
        updatedAt: f.date('updatedAt'),
      ),
  ];
  final outings = [
    for (final f in _rows(data, 'outings'))
      Outing(
        id: f.id('id'),
        spotId: f.textOrNull('spotId'),
        startedAt: f.date('startedAt'),
        durationMin: f.integerOrNull('durationMin'),
        notes: f.textOrNull('notes'),
      ),
  ];
  final harvests = [
    for (final f in _rows(data, 'harvests'))
      Harvest(
        id: f.id('id'),
        outingId: f.id('outingId'),
        speciesId: f.id('speciesId'),
        quantityCount: f.integerOrNull('quantityCount'),
        weightGrams: f.integerOrNull('weightGrams'),
        photoPath: f.photoOrNull('photoPath'),
        notes: f.textOrNull('notes'),
      ),
  ];
  final customSpecies = [
    for (final f in _rows(data, 'customSpecies'))
      CustomSpeciesRow(
        id: f.id('id'),
        commonName: f.text('commonName'),
        description: f.textOr('description', ''),
        photoPath: f.photoOrNull('photoPath'),
        createdAt: f.date('createdAt'),
      ),
  ];
  final identifications = [
    for (final f in _rows(data, 'identifications'))
      Identification(
        id: f.id('id'),
        photoPath: f.photoOrNull('photoPath') ??
            (throw _invalid('${f.where}.photoPath doit être un chemin de photo.')),
        modelVersion: f.text('modelVersion'),
        top5Json: _top5(f),
        unknownScore: f.realOr('unknownScore', 0),
        chosenSpeciesId: f.textOrNull('chosenSpeciesId'),
        createdAt: f.date('createdAt'),
        latitude: f.latitudeOrNull('latitude'),
        longitude: f.longitudeOrNull('longitude'),
        spotId: f.textOrNull('spotId'),
      ),
  ];
  final spotSpecies = [
    for (final f in _rows(data, 'spotSpecies'))
      SpotSpeciesRow(
        spotId: f.id('spotId'),
        speciesId: f.id('speciesId'),
        lastSeenAt: f.date('lastSeenAt'),
      ),
  ];

  final metaJson = data['appMeta'];
  if (metaJson is! Map<String, Object?>) {
    throw _invalid('la section « appMeta » est absente ou n\'est pas un objet.');
  }
  final appMeta = <String, String>{};
  for (final e in metaJson.entries) {
    final value = e.value;
    if (e.key.isEmpty || value is! String) throw _invalid('appMeta.${e.key} doit être un texte.');
    // Le consentement se donne sur l'appareil : une archive ne peut pas le poser.
    if (!isConsentKey(e.key)) appMeta[e.key] = value;
  }

  _requireUnique('spots', spots.map((r) => r.id));
  _requireUnique('outings', outings.map((r) => r.id));
  _requireUnique('harvests', harvests.map((r) => r.id));
  _requireUnique('customSpecies', customSpecies.map((r) => r.id));
  _requireUnique('identifications', identifications.map((r) => r.id));
  _requireUnique('spotSpecies', spotSpecies.map((r) => '${r.spotId}/${r.speciesId}'));

  // Photos utilisées : présentes dans l'archive, ou signalées introuvables à l'export.
  final used = <String>{
    for (final h in harvests) ?h.photoPath,
    for (final r in customSpecies) ?r.photoPath,
    for (final i in identifications) i.photoPath,
  };
  final missing = manifest.missingPhotos.toSet();
  for (final path in used) {
    if (!archivePhotos.contains(path) && !missing.contains(path)) {
      throw BackupException(
        BackupErrorKind.incomplete,
        'La sauvegarde est incomplète : la photo « $path » est absente de l\'archive.',
      );
    }
  }
  final photoPaths = used.where(archivePhotos.contains).toList()..sort();

  final parsed = ParsedBackup(
    manifest: manifest,
    spots: spots,
    outings: outings,
    harvests: harvests,
    customSpecies: customSpecies,
    identifications: identifications,
    spotSpecies: spotSpecies,
    appMeta: appMeta,
    photoPaths: photoPaths,
  );
  if (parsed.counts != manifest.counts) {
    throw _invalid('les comptes du manifeste ne correspondent pas au contenu '
        '(annoncé : ${manifest.counts.describe()} ; trouvé : ${parsed.counts.describe()}).');
  }
  return parsed;
}

/// `top5Json` est un texte JSON (liste des candidats du modèle) : on s'assure
/// seulement qu'il est décodable, l'écran d'historique le relit tel quel.
String _top5(_Fields f) {
  final text = f.text('top5Json');
  try {
    jsonDecode(text);
  } on FormatException {
    throw _invalid('${f.where}.top5Json n\'est pas un JSON valide.');
  }
  return text;
}

/// Texte de `data.json`.
String encodeData({
  required List<Map<String, Object?>> spots,
  required List<Map<String, Object?>> outings,
  required List<Map<String, Object?>> harvests,
  required List<Map<String, Object?>> customSpecies,
  required List<Map<String, Object?>> identifications,
  required List<Map<String, Object?>> spotSpecies,
  required Map<String, String> appMeta,
}) =>
    jsonEncode({
      'spots': spots,
      'outings': outings,
      'harvests': harvests,
      'customSpecies': customSpecies,
      'identifications': identifications,
      'spotSpecies': spotSpecies,
      'appMeta': appMeta,
    });
