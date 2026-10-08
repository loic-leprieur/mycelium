import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

/// Palette « sous-bois » : verts de forêt, mousse, écorce et papier crème.
abstract final class Palette {
  static const forest = Color(0xFF2F5233);
  static const forestDark = Color(0xFF1F3A24);
  static const moss = Color(0xFF6B8E4E);
  static const sage = Color(0xFFCFDDB8);
  static const bark = Color(0xFF6F4E37);
  static const cream = Color(0xFFF6EFDC);
  static const paper = Color(0xFFFFFBF0);
  static const chanterelle = Color(0xFFE0A030);
  static const berry = Color(0xFFA23B3B);
}

/// Police à empattements pour les titres : Georgia sur iOS/Windows, Noto Serif
/// sur Android. Aucune police à télécharger, donc utilisable hors connexion.
const _serif = TextStyle(
  fontFamily: 'Georgia',
  fontFamilyFallback: ['Noto Serif', 'serif'],
  fontWeight: FontWeight.w700,
);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.forest,
    brightness: Brightness.light,
  ).copyWith(
    primary: Palette.forest,
    onPrimary: Palette.cream,
    primaryContainer: Palette.sage,
    onPrimaryContainer: Palette.forestDark,
    secondary: Palette.bark,
    onSecondary: Palette.cream,
    tertiary: Palette.chanterelle,
    surface: Palette.paper,
    onSurface: const Color(0xFF2B2A24),
    error: Palette.berry,
  );

  const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(18)),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.cream,
    textTheme: TextTheme(
      headlineMedium: _serif,
      headlineSmall: _serif,
      titleLarge: _serif,
      titleMedium: _serif.copyWith(fontWeight: FontWeight.w600),
      titleSmall: _serif.copyWith(fontWeight: FontWeight.w600),
    ),
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Palette.forest,
      foregroundColor: Palette.cream,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: _serif.copyWith(fontSize: 24, color: Palette.cream),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
    ),
    cardTheme: CardThemeData(
      color: Palette.paper,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Palette.bark.withValues(alpha: 0.18)),
      ),
    ),
    listTileTheme: const ListTileThemeData(shape: shape),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.paper,
      indicatorColor: Palette.sage,
      surfaceTintColor: Colors.transparent,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12.5,
          fontWeight:
              states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: Palette.forestDark,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? Palette.forestDark
              : Palette.bark,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.paper,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Palette.bark.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Palette.bark.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Palette.forest, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: Palette.forest,
        side: const BorderSide(color: Palette.forest),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Palette.chanterelle,
      foregroundColor: Palette.forestDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Palette.paper,
      selectedColor: Palette.sage,
      side: BorderSide(color: Palette.bark.withValues(alpha: 0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.forestDark,
      contentTextStyle: const TextStyle(color: Palette.cream),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
  );
}
