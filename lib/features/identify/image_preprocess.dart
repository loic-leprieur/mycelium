import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Image 8 bits à 3 canaux (RVB entrelacés).
class RgbImage {
  RgbImage(this.width, this.height, this.data)
      : assert(data.length == width * height * 3);

  final int width;
  final int height;
  final Uint8List data;
}

/// Moyenne et écart-type par canal de BioCLIP (constantes de CLIP d'OpenAI).
const clipMean = [0.48145466, 0.4578275, 0.40821073];
const clipStd = [0.26862954, 0.26130258, 0.27577711];

/// Décode une photo (JPEG, PNG…), applique l'orientation EXIF et garde RVB.
RgbImage decodeRgb(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    // Octets corrompus : la bibliothèque lève selon le format détecté.
  }
  if (decoded == null) throw const FormatException('Photo illisible.');
  final rgb = img
      .bakeOrientation(decoded)
      .convert(numChannels: 3, format: img.Format.uint8);
  return RgbImage(
    rgb.width,
    rgb.height,
    Uint8List.fromList(rgb.getBytes(order: img.ChannelOrder.rgb)),
  );
}

/// Prétraitement de BioCLIP (open_clip) : plus petit côté ramené à [size] px
/// (bicubique), recadrage central [size]×[size], valeurs normalisées, rangées
/// canal par canal (1×3×size×size). Identique à PIL pour que les vecteurs
/// concordent avec ceux calculés en Python.
Float32List preprocessClip(
  Uint8List bytes, {
  int size = 224,
  List<double> mean = clipMean,
  List<double> std = clipStd,
}) {
  final resized = resizeShortSide(decodeRgb(bytes), size);
  return toClipTensor(centerCrop(resized, size), mean: mean, std: std);
}

/// Variante qui lit le fichier : à exécuter hors du fil principal (`Isolate.run`).
Float32List preprocessClipFile(
  String path, {
  int size = 224,
  List<double> mean = clipMean,
  List<double> std = clipStd,
}) =>
    preprocessClip(File(path).readAsBytesSync(), size: size, mean: mean, std: std);

/// Plus petit côté ramené à [size], proportions conservées (torchvision `Resize`).
RgbImage resizeShortSide(RgbImage src, int size) {
  final short = math.min(src.width, src.height);
  final long = math.max(src.width, src.height);
  if (short == size) return src;
  final newLong = (size * long) ~/ short;
  return src.width <= src.height
      ? resizeBicubic(src, size, newLong)
      : resizeBicubic(src, newLong, size);
}

/// Recadrage central (torchvision `CenterCrop`, arrondi « pair » comme Python).
RgbImage centerCrop(RgbImage src, int size) {
  final top = _pyRound((src.height - size) / 2);
  final left = _pyRound((src.width - size) / 2);
  final out = Uint8List(size * size * 3);
  for (var y = 0; y < size; y++) {
    final from = ((y + top) * src.width + left) * 3;
    out.setRange(y * size * 3, (y + 1) * size * 3, src.data, from);
  }
  return RgbImage(size, size, out);
}

/// Arrondi de Python 3 : à la moitié, vers l'entier pair.
int _pyRound(double x) {
  final floor = x.floor();
  final diff = x - floor;
  if (diff < .5) return floor;
  if (diff > .5) return floor + 1;
  return floor.isEven ? floor : floor + 1;
}

/// Valeurs 0–255 -> (v/255 − moyenne) / écart-type, en 3 plans.
Float32List toClipTensor(
  RgbImage image, {
  List<double> mean = clipMean,
  List<double> std = clipStd,
}) {
  final plane = image.width * image.height;
  final out = Float32List(3 * plane);
  for (var i = 0; i < plane; i++) {
    for (var c = 0; c < 3; c++) {
      out[c * plane + i] = (image.data[i * 3 + c] / 255 - mean[c]) / std[c];
    }
  }
  return out;
}

/// Rééchantillonnage bicubique avec anti-crénelage, identique à Pillow
/// (`Image.resize(..., BICUBIC)`) : passe horizontale puis verticale, chacune
/// arrondie à 8 bits.
RgbImage resizeBicubic(RgbImage src, int outW, int outH) {
  final horizontal = _Coefficients(src.width, outW);
  final vertical = _Coefficients(src.height, outH);

  // Passe horizontale : outW × src.height.
  final mid = Uint8List(outW * src.height * 3);
  for (var y = 0; y < src.height; y++) {
    final row = y * src.width * 3;
    for (var x = 0; x < outW; x++) {
      final start = horizontal.starts[x];
      final count = horizontal.counts[x];
      final base = x * horizontal.stride;
      var r = 0.0, g = 0.0, b = 0.0;
      for (var k = 0; k < count; k++) {
        final w = horizontal.weights[base + k];
        final p = row + (start + k) * 3;
        r += src.data[p] * w;
        g += src.data[p + 1] * w;
        b += src.data[p + 2] * w;
      }
      final o = (y * outW + x) * 3;
      mid[o] = _clip8(r);
      mid[o + 1] = _clip8(g);
      mid[o + 2] = _clip8(b);
    }
  }

  // Passe verticale : outW × outH.
  final out = Uint8List(outW * outH * 3);
  for (var y = 0; y < outH; y++) {
    final start = vertical.starts[y];
    final count = vertical.counts[y];
    final base = y * vertical.stride;
    for (var x = 0; x < outW; x++) {
      var r = 0.0, g = 0.0, b = 0.0;
      for (var k = 0; k < count; k++) {
        final w = vertical.weights[base + k];
        final p = ((start + k) * outW + x) * 3;
        r += mid[p] * w;
        g += mid[p + 1] * w;
        b += mid[p + 2] * w;
      }
      final o = (y * outW + x) * 3;
      out[o] = _clip8(r);
      out[o + 1] = _clip8(g);
      out[o + 2] = _clip8(b);
    }
  }
  return RgbImage(outW, outH, out);
}

int _clip8(double v) {
  final r = (v + .5).floor();
  return r < 0 ? 0 : (r > 255 ? 255 : r);
}

/// Poids du filtre bicubique (a = −0,5) pour passer de [inSize] à [outSize]
/// pixels, calculés comme dans Pillow (`precompute_coeffs`).
class _Coefficients {
  _Coefficients(int inSize, int outSize) {
    final scale = inSize / outSize;
    final filterScale = math.max(scale, 1.0);
    final support = 2.0 * filterScale;
    stride = support.ceil() * 2 + 1;
    starts = Int32List(outSize);
    counts = Int32List(outSize);
    weights = Float64List(outSize * stride);

    for (var i = 0; i < outSize; i++) {
      final center = (i + .5) * scale;
      final min = math.max((center - support + .5).floor(), 0);
      final max = math.min((center + support + .5).floor(), inSize);
      final count = max - min;
      var sum = 0.0;
      for (var k = 0; k < count; k++) {
        final w = _bicubic((k + min - center + .5) / filterScale);
        weights[i * stride + k] = w;
        sum += w;
      }
      if (sum != 0) {
        for (var k = 0; k < count; k++) {
          weights[i * stride + k] /= sum;
        }
      }
      starts[i] = min;
      counts[i] = count;
    }
  }

  late final int stride;
  late final Int32List starts;
  late final Int32List counts;
  late final Float64List weights;

  static double _bicubic(double x) {
    const a = -0.5;
    x = x.abs();
    if (x < 1) return ((a + 2) * x - (a + 3)) * x * x + 1;
    if (x < 2) return (((x - 5) * x + 8) * x - 4) * a;
    return 0;
  }
}
