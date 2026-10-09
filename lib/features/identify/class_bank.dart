import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'identifier.dart';

enum ClassKind { species, other, background }

class BankClass {
  const BankClass({required this.kind, required this.name, this.speciesId});

  final ClassKind kind;

  /// Nom scientifique ou description (affichage de contrôle uniquement).
  final String name;

  /// Identifiant de l'espèce de l'application (classes `species` seulement).
  final String? speciesId;
}

/// Vecteurs-texte précalculés des classes (`tools/bioclip/export_bioclip.py`).
///
/// Classification « zero-shot » : l'encodeur de texte n'est pas embarqué. La
/// photo est encodée en un vecteur de [dim] nombres ; sa ressemblance avec chaque
/// classe (produit scalaire de vecteurs normalisés, multiplié par [logitScale])
/// donne, après softmax, une probabilité par classe. Les classes « hors base »
/// absorbent la probabilité des espèces que le modèle ne connaît pas.
class ClassBank {
  ClassBank({
    required this.modelVersion,
    required this.logitScale,
    required this.dim,
    required this.classes,
    required this.embeddings,
    this.inputSize = 224,
    this.mean,
    this.std,
  }) : assert(embeddings.length == classes.length * dim);

  factory ClassBank.fromJson(Map<String, dynamic> json) {
    final dim = json['dim'] as int;
    final classes = [
      for (final c in (json['classes'] as List).cast<Map<String, dynamic>>())
        BankClass(
          kind: ClassKind.values.byName(c['kind'] as String),
          name: (c['name'] ?? '') as String,
          speciesId: c['id'] as String?,
        ),
    ];
    // Copie pour garantir l'alignement mémoire exigé par Float32List.
    final bytes = Uint8List.fromList(base64Decode(json['embeddings'] as String));
    final floats = bytes.buffer.asFloat32List(0, classes.length * dim);
    return ClassBank(
      modelVersion: json['version'] as String,
      logitScale: (json['logitScale'] as num).toDouble(),
      dim: dim,
      classes: classes,
      embeddings: floats,
      inputSize: (json['inputSize'] as num?)?.toInt() ?? 224,
      mean: (json['mean'] as List?)?.map((e) => (e as num).toDouble()).toList(),
      std: (json['std'] as List?)?.map((e) => (e as num).toDouble()).toList(),
    );
  }

  final String modelVersion;
  final double logitScale;
  final int dim;
  final List<BankClass> classes;

  /// Une ligne de [dim] nombres par classe, normalisée.
  final Float32List embeddings;
  final int inputSize;
  final List<double>? mean;
  final List<double>? std;

  int get speciesCount =>
      classes.where((c) => c.kind == ClassKind.species).length;

  /// Probabilité de chaque classe pour le vecteur-photo [embedding].
  List<double> probabilities(List<double> embedding) {
    if (embedding.length != dim) {
      throw ArgumentError('Vecteur de taille ${embedding.length}, attendu $dim.');
    }
    var norm = 0.0;
    for (final v in embedding) {
      norm += v * v;
    }
    norm = math.sqrt(norm);
    if (norm == 0) throw ArgumentError('Vecteur nul.');

    final logits = List<double>.filled(classes.length, 0);
    var maxLogit = double.negativeInfinity;
    for (var i = 0; i < classes.length; i++) {
      var dot = 0.0;
      final row = i * dim;
      for (var j = 0; j < dim; j++) {
        dot += embedding[j] * embeddings[row + j];
      }
      logits[i] = logitScale * dot / norm;
      if (logits[i] > maxLogit) maxLogit = logits[i];
    }
    var sum = 0.0;
    for (var i = 0; i < logits.length; i++) {
      logits[i] = math.exp(logits[i] - maxLogit);
      sum += logits[i];
    }
    return [for (final l in logits) l / sum];
  }

  /// Scores par espèce de l'application + probabilité « hors base ».
  RawIdentification score(List<double> embedding) {
    final p = probabilities(embedding);
    final candidates = <Candidate>[];
    var unknown = 0.0;
    for (var i = 0; i < classes.length; i++) {
      final c = classes[i];
      if (c.kind == ClassKind.species) {
        candidates.add(Candidate(speciesId: c.speciesId!, score: p[i]));
      } else {
        unknown += p[i];
      }
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return RawIdentification(
      candidates: candidates,
      modelVersion: modelVersion,
      unknownScore: unknown,
    );
  }
}
