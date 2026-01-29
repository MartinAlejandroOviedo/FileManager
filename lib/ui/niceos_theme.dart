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

  // Light palette
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF0F2F5);
  static const Color lightSurfaceElevated = Color(0xFFE8EBF0);
  static const Color lightBorder = Color(0xFFD7DCE3);
  static const Color lightTextPrimary = Color(0xFF1D2026);
  static const Color lightTextSecondary = Color(0xFF4E5563);
  static const Color lightTextMuted = Color(0xFF6F7684);
  static const Color lightHover = Color(0xFFE7EBF1);
  static const Color lightFocus = Color(0xFFDDE4EF);
  static const Color lightSelection = Color(0xFFD7E3F2);

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

  static ThemeData get lightThemeData => ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: fontFamily,
        scaffoldBackgroundColor: lightBackground,
        primaryColor: accentBlue,
        colorScheme: const ColorScheme.light(
          surface: lightSurface,
          surfaceContainerHighest: lightSurfaceAlt,
          primary: accentBlue,
          secondary: accentTeal,
          tertiary: accentViolet,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: lightTextPrimary,
          onSurfaceVariant: lightTextSecondary,
          outline: lightBorder,
          error: Colors.redAccent,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: lightTextPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: lightTextPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: lightTextPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 15,
            color: lightTextPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: lightTextSecondary,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            color: lightTextMuted,
          ),
          labelLarge: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: lightTextPrimary,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: lightSurface,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: lightTextPrimary,
          ),
          iconTheme: IconThemeData(color: accentBlue),
        ),
        iconTheme: const IconThemeData(color: accentTeal, size: 20),
        dividerColor: lightBorder,
        cardColor: lightSurface,
        shadowColor: Colors.black12,
        splashColor: lightSelection,
        hoverColor: lightHover,
        focusColor: lightFocus,
        listTileTheme: ListTileThemeData(
          dense: true,
          iconColor: accentTeal,
          textColor: lightTextPrimary,
          selectedTileColor: lightSelection,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
        tooltipTheme: const TooltipThemeData(
          decoration: BoxDecoration(
            color: lightSurfaceElevated,
            borderRadius: BorderRadius.all(Radius.circular(radiusSm)),
          ),
          textStyle: TextStyle(
            fontSize: 12,
            color: lightTextPrimary,
          ),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: lightSurfaceElevated,
          textStyle: TextStyle(color: lightTextPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: lightSurfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusLg)),
          ),
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: lightTextPrimary,
          ),
          contentTextStyle: TextStyle(
            fontSize: 14,
            color: lightTextSecondary,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: lightSurfaceElevated,
          contentTextStyle: TextStyle(
            fontSize: 13,
            color: lightTextPrimary,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusSm)),
            borderSide: BorderSide(color: lightBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusSm)),
            borderSide: BorderSide(color: lightBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusSm)),
            borderSide: BorderSide(color: accentBlue),
          ),
          filled: true,
          fillColor: lightSurfaceAlt,
          hintStyle: TextStyle(color: lightTextMuted),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentBlue,
            foregroundColor: Colors.white,
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
            foregroundColor: lightTextPrimary,
            side: const BorderSide(color: lightBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ),
        ),
      );
}
