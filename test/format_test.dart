import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/core/format.dart';

void main() {
  test('poids lisible', () {
    expect(formatWeight(0), '0 g');
    expect(formatWeight(850), '850 g');
    expect(formatWeight(1000), '1 kg');
    expect(formatWeight(1250), '1,25 kg');
    expect(formatWeight(2300), '2,3 kg');
  });

  test('pluriel des pièces', () {
    expect(formatPieces(1), '1 pièce');
    expect(formatPieces(3), '3 pièces');
  });
}
