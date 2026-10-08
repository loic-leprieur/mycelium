/// Poids lisible : « 850 g », « 1,25 kg ».
String formatWeight(int grams) {
  if (grams < 1000) return '$grams g';
  final kg = grams / 1000;
  final text = kg.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return '${text.replaceAll('.', ',')} kg';
}

/// « 3 pièces », « 1 pièce ».
String formatPieces(int count) => count <= 1 ? '$count pièce' : '$count pièces';
