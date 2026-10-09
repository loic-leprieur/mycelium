const _accented = 'àâäáãåçéèêëíìîïñóòôöõùúûüýÿ';
const _plain = 'aaaaaaceeeeiiiinooooouuuuyy';

/// Minuscules sans accents : « Cèpe », « cepe » et « CÈPE » se comparent égaux.
/// Sert à la recherche, au tri alphabétique et à la lecture des habitats.
String foldAccents(String text) {
  final out = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final i = _accented.indexOf(char);
    if (i >= 0) {
      out.write(_plain[i]);
    } else if (char == 'œ') {
      out.write('oe');
    } else if (char == 'æ') {
      out.write('ae');
    } else {
      out.write(char);
    }
  }
  return out.toString();
}
