import 'package:flutter/material.dart';

class NiceOSTheme {
  static const String fontFamily = 'RobotoMono';

  // Core palette
  static const Color background = Color(0xFF1C1D21);
  static const Color surface = Color(0xFF26282E);
  static const Color surfaceAlt = Color(0xFF2D3037);
  static const Color surfaceElevated = Color(0xFF323640);
  static const Color accentBlue = Color(0xFF3DAEE9);
  static const Color accentTeal = Color(0xFF4DD0E1);
  static const Color accentViolet = Color(0xFF9FA8DA);
  static const Color border = Color(0xFF353944);
  static const Color textPrimary = Color(0xFFE6E6E6);
  static const Color textSecondary = Color(0xFFB6B8BD);
  static const Color textMuted = Color(0xFF8F939C);

  // Interaction
  static const Color hover = Color(0xFF31343C);
  static const Color focus = Color(0xFF3B4050);
  static const Color selection = Color(0xFF2E3A4A);

  // Radii
  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 14;

  static ThemeData get themeData => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: fontFamily,
        scaffoldBackgroundColor: background,
        primaryColor: accentBlue,
        colorScheme: const ColorScheme.dark(
          surface: surface,
          surfaceContainerHighest: surfaceAlt,
          primary: accentBlue,
          secondary: accentTeal,
          tertiary: accentViolet,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: textPrimary,
          onSurfaceVariant: textSecondary,
          outline: border,
          error: accentViolet,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 15,
            color: textPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: textSecondary,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            color: textMuted,
          ),
          labelLarge: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          iconTheme: IconThemeData(color: accentBlue),
        ),
        iconTheme: const IconThemeData(color: accentTeal, size: 20),
        dividerColor: border,
        cardColor: surface,
        shadowColor: Colors.black54,
        splashColor: selection,
        hoverColor: hover,
        focusColor: focus,
        listTileTheme: ListTileThemeData(
          dense: true,
          iconColor: accentTeal,
          textColor: textPrimary,
          selectedTileColor: selection,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
        tooltipTheme: const TooltipThemeData(
          decoration: BoxDecoration(
            color: surfaceElevated,
            borderRadius: BorderRadius.all(Radius.circular(radiusSm)),
          ),
          textStyle: TextStyle(
            fontSize: 12,
            color: textPrimary,
          ),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: surfaceElevated,
          textStyle: TextStyle(color: textPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusLg)),
          ),
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          contentTextStyle: TextStyle(
            fontSize: 14,
            color: textSecondary,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: surfaceElevated,
          contentTextStyle: TextStyle(
            fontSize: 13,
            color: textPrimary,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusSm)),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusSm)),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusSm)),
            borderSide: BorderSide(color: accentBlue),
          ),
          filled: true,
          fillColor: surfaceAlt,
          hintStyle: TextStyle(color: textMuted),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentBlue,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accentBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: textPrimary,
            side: const BorderSide(color: border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ),
        ),
      );
}
