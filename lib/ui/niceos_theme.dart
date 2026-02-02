import 'package:flutter/material.dart';

class NiceOSTheme {
  static const String fontFamily = 'RobotoMono';

  static const Color accentBlue = Color(0xFF3DAEE9);
  static const Color accentTeal = Color(0xFF4DD0E1);
  static const Color accentViolet = Color(0xFF9FA8DA);
  static const Color nicePrimary = Color(0xFF46C2B6);
  static const Color niceSecondary = Color(0xFF7ED957);
  static const Color niceTertiary = Color(0xFFFFB74D);

  // Radii
  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 14;

  static const _Palette _darkPalette = _Palette(
    background: Color(0xFF1C1D21),
    surface: Color(0xFF26282E),
    surfaceAlt: Color(0xFF2D3037),
    surfaceElevated: Color(0xFF323640),
    border: Color(0xFF353944),
    textPrimary: Color(0xFFE6E6E6),
    textSecondary: Color(0xFFB6B8BD),
    textMuted: Color(0xFF8F939C),
    hover: Color(0xFF31343C),
    focus: Color(0xFF3B4050),
    selection: Color(0xFF2E3A4A),
    shadowColor: Colors.black54,
    popupMenuElevation: 8,
    primary: accentBlue,
    secondary: accentTeal,
    tertiary: accentViolet,
    onPrimary: Colors.black,
    error: accentViolet,
  );

  static const _Palette _lightPalette = _Palette(
    background: Color(0xFFF5F7FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0F2F5),
    surfaceElevated: Color(0xFFE8EBF0),
    border: Color(0xFFD7DCE3),
    textPrimary: Color(0xFF1D2026),
    textSecondary: Color(0xFF4E5563),
    textMuted: Color(0xFF6F7684),
    hover: Color(0xFFE7EBF1),
    focus: Color(0xFFDDE4EF),
    selection: Color(0xFFD7E3F2),
    shadowColor: Colors.black12,
    popupMenuElevation: 6,
    primary: accentBlue,
    secondary: accentTeal,
    tertiary: accentViolet,
    onPrimary: Colors.white,
    error: Colors.redAccent,
  );

  static const _Palette _pureDarkPalette = _Palette(
    background: Color(0xFF0F1419),
    surface: Color(0xFF1A2026),
    surfaceAlt: Color(0xFF202730),
    surfaceElevated: Color(0xFF26303A),
    border: Color(0xFF2E3742),
    textPrimary: Color(0xFFE6EDF3),
    textSecondary: Color(0xFFB6C0CC),
    textMuted: Color(0xFF8B95A3),
    hover: Color(0xFF23303A),
    focus: Color(0xFF2B3A46),
    selection: Color(0xFF1E3A3E),
    shadowColor: Colors.black54,
    popupMenuElevation: 8,
    primary: nicePrimary,
    secondary: niceSecondary,
    tertiary: niceTertiary,
    onPrimary: Colors.black,
    error: Color(0xFFFF6B6B),
  );

  static const _Palette _pureLightPalette = _Palette(
    background: Color(0xFFF7FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFF4F8),
    surfaceElevated: Color(0xFFE7EDF3),
    border: Color(0xFFD8E1EA),
    textPrimary: Color(0xFF1B252E),
    textSecondary: Color(0xFF4A5868),
    textMuted: Color(0xFF6B7684),
    hover: Color(0xFFE2EBF2),
    focus: Color(0xFFD6E3EE),
    selection: Color(0xFFD3EAE6),
    shadowColor: Colors.black12,
    popupMenuElevation: 6,
    primary: nicePrimary,
    secondary: niceSecondary,
    tertiary: niceTertiary,
    onPrimary: Colors.black,
    error: Color(0xFFE85D5D),
  );

  static ThemeData get themeData =>
      _buildTheme(palette: _darkPalette, brightness: Brightness.dark);

  static ThemeData get lightThemeData =>
      _buildTheme(palette: _lightPalette, brightness: Brightness.light);

  static ThemeData get pureDarkThemeData =>
      _buildTheme(palette: _pureDarkPalette, brightness: Brightness.dark);

  static ThemeData get pureLightThemeData =>
      _buildTheme(palette: _pureLightPalette, brightness: Brightness.light);

  static ThemeData _buildTheme({
    required _Palette palette,
    required Brightness brightness,
  }) {
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: palette.background,
      primaryColor: palette.primary,
      colorScheme: _colorScheme(palette, brightness),
      textTheme: _textTheme(palette),
      appBarTheme: _appBarTheme(palette),
      iconTheme: IconThemeData(color: palette.secondary, size: 18),
      dividerColor: palette.border,
      cardColor: palette.surface,
      shadowColor: palette.shadowColor,
      splashColor: palette.selection,
      hoverColor: palette.hover,
      focusColor: palette.focus,
      listTileTheme: _listTileTheme(palette),
      tooltipTheme: _tooltipTheme(palette),
      popupMenuTheme: _popupMenuTheme(palette),
      dialogTheme: _dialogTheme(palette),
      snackBarTheme: _snackBarTheme(palette),
      inputDecorationTheme: _inputDecorationTheme(palette),
      elevatedButtonTheme: _elevatedButtonTheme(palette),
      textButtonTheme: _textButtonTheme(palette),
      outlinedButtonTheme: _outlinedButtonTheme(palette),
    );
  }

  static ColorScheme _colorScheme(_Palette palette, Brightness brightness) {
    if (brightness == Brightness.dark) {
      return ColorScheme.dark(
        surface: palette.surface,
        surfaceContainerHighest: palette.surfaceAlt,
        primary: palette.primary,
        secondary: palette.secondary,
        tertiary: palette.tertiary,
        onPrimary: palette.onPrimary,
        onSecondary: Colors.black,
        onSurface: palette.textPrimary,
        onSurfaceVariant: palette.textSecondary,
        outline: palette.border,
        error: palette.error,
      );
    }

    return ColorScheme.light(
      surface: palette.surface,
      surfaceContainerHighest: palette.surfaceAlt,
      primary: palette.primary,
      secondary: palette.secondary,
      tertiary: palette.tertiary,
      onPrimary: palette.onPrimary,
      onSecondary: Colors.black,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.border,
      error: palette.error,
    );
  }

  static TextTheme _textTheme(_Palette palette) {
    return TextTheme(
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: palette.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 14,
        color: palette.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        color: palette.textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: palette.textMuted,
      ),
      labelLarge: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: palette.textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: palette.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: palette.textMuted,
      ),
    );
  }

  static AppBarTheme _appBarTheme(_Palette palette) {
    return AppBarTheme(
      backgroundColor: palette.surface,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      iconTheme: IconThemeData(color: palette.primary),
    );
  }

  static ListTileThemeData _listTileTheme(_Palette palette) {
    return ListTileThemeData(
      dense: true,
      iconColor: palette.secondary,
      textColor: palette.textPrimary,
      selectedTileColor: palette.selection,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
    );
  }

  static TooltipThemeData _tooltipTheme(_Palette palette) {
    return TooltipThemeData(
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: const BorderRadius.all(Radius.circular(radiusSm)),
      ),
      textStyle: TextStyle(
        fontSize: 12,
        color: palette.textPrimary,
      ),
    );
  }

  static PopupMenuThemeData _popupMenuTheme(_Palette palette) {
    return PopupMenuThemeData(
      color: palette.surfaceElevated,
      textStyle: TextStyle(color: palette.textPrimary),
      elevation: palette.popupMenuElevation,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
      ),
    );
  }

  static DialogThemeData _dialogTheme(_Palette palette) {
    return DialogThemeData(
      backgroundColor: palette.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusLg)),
      ),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      contentTextStyle: TextStyle(
        fontSize: 14,
        color: palette.textSecondary,
      ),
    );
  }

  static SnackBarThemeData _snackBarTheme(_Palette palette) {
    return SnackBarThemeData(
      backgroundColor: palette.surfaceElevated,
      contentTextStyle: TextStyle(
        fontSize: 13,
        color: palette.textPrimary,
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(_Palette palette) {
    return InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(radiusSm)),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(radiusSm)),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(radiusSm)),
        borderSide: BorderSide(color: palette.primary),
      ),
      filled: true,
      fillColor: palette.surfaceAlt,
      hintStyle: TextStyle(color: palette.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(_Palette palette) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(_Palette palette) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(_Palette palette) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
    );
  }

}

class _Palette {
  const _Palette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.hover,
    required this.focus,
    required this.selection,
    required this.shadowColor,
    required this.popupMenuElevation,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.onPrimary,
    required this.error,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceElevated;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color hover;
  final Color focus;
  final Color selection;
  final Color shadowColor;
  final double popupMenuElevation;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color onPrimary;
  final Color error;
}
