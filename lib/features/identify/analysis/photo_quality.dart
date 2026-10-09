import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../image_preprocess.dart';

/// Défauts détectables d'une photo (ID-8).
enum QualityIssue { blurry, tooDark, tooBright, tooSmall }

/// Seuils de qualité. Valeurs initiales calibrées sur 16 vraies photos
/// (paysages et plats, dégradées par flou gaussien, flou de bougé, assombrissement,
/// bruit) et NON sur des photos de champignons : à recalibrer avec celles du père.
class QualityThresholds {
  const QualityThresholds({
    this.minShortSide = 320,
    this.minSharpness = 2.2,
    this.minMeanBrightness = 40,
    this.maxMeanBrightness = 200,
    this.maxBrightShare = 0.35,
    this.analysisSize = 512,
  });

  /// Plus petit côté minimal (px) : le modèle travaille sur 224 px, en dessous
  /// d'environ 1,4 fois cette taille le cadrage central manque de détails.
  final int minShortSide;

  /// Netteté minimale (rapport de « re-flou », voir [measureQuality]). Photos
  /// nettes mesurées : 3,1 à 8,3 ; flou gaussien de 2,7 px (sur 1600 px) : 1,8 à 2,3.
  final double minSharpness;

  /// Luminosité moyenne (0–255) sous laquelle la photo est trop sombre.
  final double minMeanBrightness;

  /// Luminosité moyenne au-dessus de laquelle la photo est surexposée.
  final double maxMeanBrightness;

  /// Part de pixels quasi blancs (≥ 245) au-delà de laquelle elle est surexposée.
  final double maxBrightShare;

  /// Plus grand côté (px) de l'image réduite sur laquelle on mesure.
  final int analysisSize;
}

/// Résultat de la mesure de qualité d'une photo.
class QualityReport {
  const QualityReport({
    required this.width,
    required this.height,
    required this.sharpness,
    required this.meanBrightness,
    required this.brightShare,
    required this.issues,
  });

  /// Taille de la photo d'origine.
  final int width;
  final int height;

  /// Netteté : plus c'est haut, plus la photo est nette (indépendant du sujet).
  final double sharpness;

  /// Luminosité moyenne, 0 (noir) à 255 (blanc).
  final double meanBrightness;

  /// Part de pixels quasi blancs (0–1).
  final double brightShare;

  final List<QualityIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
  bool has(QualityIssue issue) => issues.contains(issue);
}

/// Mesure la qualité d'une photo décodée, en Dart pur.
///
/// - Netteté : l'image réduite (grand côté [QualityThresholds.analysisSize]) est
///   passée en gris, puis on compare l'énergie des détails fins (second dérivé,
///   par direction) avant et après un léger flou 1×3. Une photo nette perd
///   beaucoup de détails, une photo déjà floue presque aucun : le rapport est
///   indépendant du sujet (contrairement à la variance du laplacien brute, qui
///   varie de 1 à 100 selon la scène) et on garde la direction la plus floue,
///   ce qui détecte aussi le flou de bougé.
/// - Exposition : luminosité moyenne et part de pixels quasi blancs. Une photo
///   trop sombre ou trop claire fausse la netteté : on ne la juge alors pas.
/// - Taille : plus petit côté de la photo d'origine.
///
/// Le cadrage n'est pas mesuré (aucune mesure fiable sans détecteur d'objet).
QualityReport measureQuality(
  RgbImage photo, {
  QualityThresholds thresholds = const QualityThresholds(),
}) {
  final long = math.max(photo.width, photo.height);
  final scaled = long <= thresholds.analysisSize
      ? photo
      : resizeBicubic(
          photo,
          math.max(1, (photo.width * thresholds.analysisSize / long).round()),
          math.max(1, (photo.height * thresholds.analysisSize / long).round()),
        );
  final w = scaled.width, h = scaled.height;
  final gray = Float64List(w * h);
  var sum = 0.0;
  var bright = 0;
  for (var i = 0; i < gray.length; i++) {
    final v = 0.299 * scaled.data[i * 3] +
        0.587 * scaled.data[i * 3 + 1] +
        0.114 * scaled.data[i * 3 + 2];
    gray[i] = v;
    sum += v;
    if (v >= 245) bright++;
  }
  final mean = sum / gray.length;
  final brightShare = bright / gray.length;
  final sharpness = _sharpness(gray, w, h);

  final issues = <QualityIssue>[];
  if (math.min(photo.width, photo.height) < thresholds.minShortSide) {
    issues.add(QualityIssue.tooSmall);
  }
  final dark = mean < thresholds.minMeanBrightness;
  final bri = mean > thresholds.maxMeanBrightness ||
      brightShare > thresholds.maxBrightShare;
  if (dark) issues.add(QualityIssue.tooDark);
  if (bri) issues.add(QualityIssue.tooBright);
  if (!dark && !bri && sharpness < thresholds.minSharpness) {
    issues.add(QualityIssue.blurry);
  }
  return QualityReport(
    width: photo.width,
    height: photo.height,
    sharpness: sharpness,
    meanBrightness: mean,
    brightShare: brightShare,
    issues: issues,
  );
}

/// Rapport (énergie du second dérivé) / (même énergie après flou 1×3), dans la
/// direction la plus floue. Vaut ~1 pour une image sans détail fin.
double _sharpness(Float64List g, int w, int h) {
  if (w < 8 || h < 8) return 0;
  final bx = Float64List(w * h);
  final by = Float64List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (x > 0 && x < w - 1) bx[i] = (g[i - 1] + g[i] + g[i + 1]) / 3;
      if (y > 0 && y < h - 1) by[i] = (g[i - w] + g[i] + g[i + w]) / 3;
    }
  }
  double energy(Float64List a, int step) {
    var s = 0.0, s2 = 0.0, n = 0;
    for (var y = 2; y < h - 2; y++) {
      for (var x = 2; x < w - 2; x++) {
        final i = y * w + x;
        final d = a[i - step] + a[i + step] - 2 * a[i];
        s += d;
        s2 += d * d;
        n++;
      }
    }
    final m = s / n;
    return s2 / n - m * m;
  }

  // Plancher : le bruit d'arrondi à 8 bits d'une image floue ressemblerait sinon
  // à du détail fin (ratio gonflé) ; une image unie donne alors exactement 1.
  const floor = 0.5;
  final rx = (energy(g, 1) + floor) / (energy(bx, 1) + floor);
  final ry = (energy(g, w) + floor) / (energy(by, w) + floor);
  return math.min(rx, ry);
}

/// Lit et mesure un fichier (synchrone : à exécuter hors du fil principal).
QualityReport measureQualityFile(
  String path, {
  QualityThresholds thresholds = const QualityThresholds(),
}) =>
    measureQuality(decodeRgb(File(path).readAsBytesSync()), thresholds: thresholds);

/// Mesure la qualité d'une photo sans bloquer l'interface.
Future<QualityReport> analyzePhotoQuality(String path) =>
    Isolate.run(() => measureQualityFile(path));
