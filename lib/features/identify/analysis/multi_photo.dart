import 'dart:math' as math;

import '../identifier.dart';

/// Moyenne des vecteurs-photos normalisés (ID-6).
///
/// Chaque vecteur est ramené à une norme 1 (une photo ne pèse pas plus qu'une
/// autre), puis on fait la moyenne : méthode classique pour combiner plusieurs
/// vues d'un même objet avec un modèle de type CLIP. Le vecteur obtenu est
/// ensuite classé comme celui d'une photo seule (la banque de classes le
/// normalise). NON validée sur de vraies photos de champignons.
List<double> fuseEmbeddings(List<List<double>> embeddings) {
  if (embeddings.isEmpty) throw ArgumentError('Aucun vecteur à fusionner.');
  final dim = embeddings.first.length;
  final mean = List<double>.filled(dim, 0);
  for (final e in embeddings) {
    if (e.length != dim) throw ArgumentError('Vecteurs de tailles différentes.');
    var norm = 0.0;
    for (final v in e) {
      norm += v * v;
    }
    norm = math.sqrt(norm);
    if (norm == 0) throw ArgumentError('Vecteur nul.');
    for (var i = 0; i < dim; i++) {
      mean[i] += e[i] / norm / embeddings.length;
    }
  }
  return mean;
}

/// Résultat de l'analyse de plusieurs photos : UN résultat fusionné, et celui
/// de chaque photo seule (pour que la fusion n'efface jamais une alerte, RM-6).
class MultiIdentification {
  const MultiIdentification({required this.fused, required this.perPhoto});

  final RawIdentification fused;
  final List<RawIdentification> perPhoto;
}

extension MultiPhotoIdentifier on EmbeddingIdentifier {
  /// Analyse [imagePaths] et les combine en un seul résultat. [onProgress] reçoit
  /// le nombre de photos déjà analysées.
  Future<MultiIdentification> identifyMany(
    List<String> imagePaths, {
    void Function(int done)? onProgress,
  }) async {
    if (imagePaths.isEmpty) throw ArgumentError('Aucune photo à analyser.');
    final vectors = <List<double>>[];
    for (final path in imagePaths) {
      vectors.add(await embed(path));
      onProgress?.call(vectors.length);
    }
    return MultiIdentification(
      fused: classify(fuseEmbeddings(vectors)),
      perPhoto: [for (final v in vectors) classify(v)],
    );
  }
}
