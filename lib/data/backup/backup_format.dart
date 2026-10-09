/// Format de la sauvegarde manuelle (DATA-2) : une archive `.zip` qui contient
///
///   manifest.json                    format, versions, date et comptes par table
///   data.json                        toutes les tables
///   photos/DOSSIER/FICHIER           les photos, sous leur chemin RELATIF
///
/// Ce fichier regroupe les constantes, les erreurs et les règles de chemins
/// (pures, sans accès disque) ; la lecture et l'écriture sont dans
/// `backup_codec.dart`, `backup_zip.dart` et `backup_service.dart`.
library;

/// Identifiant du format, écrit dans le manifeste.
const backupFormat = 'mycelium-backup';

/// Version du CONTENEUR (noms des fichiers, structure du manifeste). À
/// incrémenter si ce conteneur change de façon incompatible.
const backupFormatVersion = 1;

/// Plus ancienne version du schéma de base que ce format sait décrire (v4 :
/// première version qui a une sauvegarde). Les archives d'une version plus
/// récente que celle de l'application sont refusées.
const backupMinSchemaVersion = 4;

/// Version de l'application écrite dans le manifeste. À tenir à jour avec la
/// ligne `version:` de `pubspec.yaml` (un test le vérifie) : aucun plugin
/// n'est déclaré pour la lire à l'exécution.
const backupAppVersion = '1.0.0+1';

const backupManifestEntry = 'manifest.json';
const backupDataEntry = 'data.json';
const backupPhotosPrefix = 'photos/';

/// Dossiers de photos sous les Documents de l'application : seuls chemins
/// acceptés à l'export, à l'import et à la suppression.
const photoFolders = ['harvest_photos', 'species_photos', 'identification_photos'];

/// Dossier par défaut d'une photo, selon la colonne qui la référence.
const harvestPhotoFolder = 'harvest_photos';
const speciesPhotoFolder = 'species_photos';
const identificationPhotoFolder = 'identification_photos';

/// Clés de `appMeta` du consentement (agent « Sécurité »). Jamais exportées ni
/// importées : le consentement se donne sur l'appareil, il ne se « restaure » pas.
const consentKeyPrefix = 'consent_';

/// Date de la dernière sauvegarde (texte ISO 8601 UTC dans `appMeta`).
const lastBackupKey = 'last_backup_at';

/// Au-delà, l'écran rappelle de sauvegarder : avec un compte Apple gratuit,
/// l'application doit être réinstallée toutes les semaines (cahier des charges §17).
const backupMaxAge = Duration(days: 7);

bool isConsentKey(String key) => key.startsWith(consentKeyPrefix);

/// Vrai s'il n'y a jamais eu de sauvegarde, ou si la dernière a plus de 7 jours.
bool backupIsOverdue(DateTime? last, DateTime now) =>
    last == null || now.difference(last) > backupMaxAge;

/// `mycelium-sauvegarde-2026-10-09.zip`.
String backupFileName(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'mycelium-sauvegarde-${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}.zip';
}

/// Famille d'erreurs, pour que l'écran et les tests distinguent les cas.
enum BackupErrorKind {
  /// Ce n'est pas une sauvegarde Mycelium (pas une archive, ou autre format).
  notABackup,

  /// Sauvegarde créée par une version plus récente de l'application.
  tooNew,

  /// Chemins dangereux dans l'archive (sortie du dossier, chemin absolu…).
  unsafe,

  /// Archive incomplète : fichier ou photo manquant.
  incomplete,

  /// Archive endommagée : taille ou somme de contrôle incorrecte.
  corrupted,

  /// Contenu incohérent : JSON mal formé, champ manquant ou de mauvais type.
  invalid,

  /// Échec d'une opération (disque plein, base…). Rien n'a été modifié.
  failed,
}

/// Erreur de sauvegarde ou de restauration. [message] est en français et
/// destiné à l'utilisateur ; [detail] (technique, facultatif) sert au
/// diagnostic et s'affiche en petit sous le message.
class BackupException implements Exception {
  const BackupException(this.kind, this.message, {this.detail});

  final BackupErrorKind kind;
  final String message;
  final String? detail;

  @override
  String toString() => 'BackupException(${kind.name}): $message${detail == null ? '' : ' [$detail]'}';
}

/// « 3 coins », « 1 coin », « 0 coin » (le français met 0 au singulier).
String _count(int n, String one, String many) => '$n ${n <= 1 ? one : many}';

/// Comptes par table (et nombre de photos) : manifeste, récapitulatif avant
/// restauration et compte rendu après restauration.
class BackupCounts {
  const BackupCounts({
    this.spots = 0,
    this.outings = 0,
    this.harvests = 0,
    this.customSpecies = 0,
    this.identifications = 0,
    this.spotSpecies = 0,
    this.appMeta = 0,
    this.photos = 0,
  });

  final int spots;
  final int outings;
  final int harvests;
  final int customSpecies;
  final int identifications;
  final int spotSpecies;
  final int appMeta;
  final int photos;

  /// Noms écrits dans le manifeste (ceux des tables, plus `photos`).
  Map<String, int> toJson() => {
        'spots': spots,
        'outings': outings,
        'harvests': harvests,
        'customSpecies': customSpecies,
        'identifications': identifications,
        'spotSpecies': spotSpecies,
        'appMeta': appMeta,
        'photos': photos,
      };

  /// Nombre d'éléments que l'utilisateur a saisis ou enregistrés.
  int get userItems =>
      spots + outings + harvests + customSpecies + identifications;

  BackupCounts operator +(BackupCounts o) => BackupCounts(
        spots: spots + o.spots,
        outings: outings + o.outings,
        harvests: harvests + o.harvests,
        customSpecies: customSpecies + o.customSpecies,
        identifications: identifications + o.identifications,
        spotSpecies: spotSpecies + o.spotSpecies,
        appMeta: appMeta + o.appMeta,
        photos: photos + o.photos,
      );

  @override
  bool operator ==(Object other) =>
      other is BackupCounts && _sameCounts(toJson(), other.toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);

  @override
  String toString() => 'BackupCounts(${toJson()})';

  /// « 12 coins, 5 sorties, 34 identifications… » (sans les zéros), ou
  /// « aucune donnée ».
  String describe() {
    final parts = [
      if (spots > 0) _count(spots, 'coin', 'coins'),
      if (outings > 0) _count(outings, 'sortie', 'sorties'),
      if (harvests > 0) _count(harvests, 'récolte', 'récoltes'),
      if (identifications > 0) _count(identifications, 'identification', 'identifications'),
      if (customSpecies > 0) _count(customSpecies, 'espèce personnelle', 'espèces personnelles'),
      if (photos > 0) _count(photos, 'photo', 'photos'),
    ];
    return parts.isEmpty ? 'aucune donnée' : parts.join(', ');
  }
}

bool _sameCounts(Map<String, int> a, Map<String, int> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

// --- Chemins ---

final _forbiddenInName = RegExp(r'[\x00-\x1f\x7f\\/:*?"<>|]');

/// Nom de fichier acceptable sur tous les systèmes : ni séparateur, ni
/// caractère de contrôle, ni nom caché ou finissant par un point ou un espace.
bool isSafeFileName(String name) =>
    name.isNotEmpty &&
    name.length <= 200 &&
    !name.startsWith('.') &&
    !name.endsWith('.') &&
    !name.endsWith(' ') &&
    !_forbiddenInName.hasMatch(name);

/// Transforme [name] en un nom qui passe [isSafeFileName] (les photos de
/// l'application s'appellent `<uuid>.jpg` : ce cas ne change rien).
String cleanFileName(String name) {
  var out = name.replaceAll(_forbiddenInName, '_');
  out = out.replaceFirst(RegExp(r'^\.+'), '').replaceFirst(RegExp(r'[. ]+$'), '');
  if (out.length > 200) {
    final dot = out.lastIndexOf('.');
    final ext = dot > 0 && out.length - dot <= 12 ? out.substring(dot) : '';
    out = out.substring(0, 200 - ext.length) + ext;
  }
  return out.isEmpty ? 'photo' : out;
}

/// Un chemin de photo de l'archive (`dossier/fichier`, relatif aux Documents)
/// est accepté s'il a exactement deux parties, un dossier connu et un nom sûr.
/// Renvoie [raw] s'il est accepté, sinon null.
String? safePhotoPath(String raw) {
  final parts = raw.split('/');
  if (parts.length != 2) return null;
  if (!photoFolders.contains(parts[0])) return null;
  return isSafeFileName(parts[1]) ? raw : null;
}

/// Chemin relatif sous lequel une photo est rangée dans l'archive, à partir de
/// ce qui est enregistré en base ([stored] : chemin relatif `dossier/fichier`,
/// ou ancien chemin absolu `…/Documents/dossier/fichier`, éventuellement d'un
/// ancien conteneur de l'application). Le dossier retenu est celui qui précède
/// le nom s'il est connu, sinon [defaultFolder].
String archivePhotoPath(String stored, String defaultFolder) {
  final parts = stored
      .replaceAll('\\', '/')
      .split('/')
      .where((s) => s.isNotEmpty && s != '.')
      .toList();
  final name = cleanFileName(parts.isEmpty ? '' : parts.last);
  final parent = parts.length >= 2 ? parts[parts.length - 2] : '';
  return '${photoFolders.contains(parent) ? parent : defaultFolder}/$name';
}

/// Nom d'entrée de l'archive acceptable : pas de chemin absolu, de lecteur
/// (`C:`), de séparateur `\`, de caractère de contrôle ni de segment `.` ou
/// `..` (protection « zip-slip »). Un `/` final désigne un dossier.
bool isSafeEntryName(String name) {
  if (name.isEmpty || name.length > 1024) return false;
  if (name.startsWith('/')) return false;
  if (name.contains('\\') || name.contains(':')) return false;
  if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) return false;
  final parts = name.endsWith('/') ? name.substring(0, name.length - 1).split('/') : name.split('/');
  return parts.every((s) => s.isNotEmpty && s != '.' && s != '..');
}
