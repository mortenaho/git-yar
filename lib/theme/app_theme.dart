import 'package:flutter/material.dart';

class AppTheme {
  // Classic light (simple mode)
  static const Color ink = Color(0xFF14201B);
  static const Color moss = Color(0xFF1F3D32);
  static const Color leaf = Color(0xFF2F6B4F);
  static const Color amber = Color(0xFFE2A93B);
  static const Color sand = Color(0xFFDCE6E0);
  static const Color mist = Color(0xFFECF2EE);
  static const Color danger = Color(0xFFB23A2F);

  // Modern pro — deep graphite + cyan accent
  static const Color proBg = Color(0xFF0B0D12);
  static const Color proPanel = Color(0xFF12151C);
  static const Color proPanelAlt = Color(0xFF181C26);
  static const Color proElevated = Color(0xFF1E2430);
  static const Color proBorder = Color(0xFF2A3140);
  static const Color proBorderSoft = Color(0xFF222836);
  static const Color proText = Color(0xFFF2F4F8);
  static const Color proMuted = Color(0xFF8B95A8);
  static const Color proAccent = Color(0xFF3DDC97);
  static const Color proAccent2 = Color(0xFF5B8CFF);
  static const Color proWarn = Color(0xFFFFC857);
  static const Color proDanger = Color(0xFFFF6B7A);
  static const Color proGreen = Color(0xFF5FE08A);
  static const Color proPurple = Color(0xFFB388FF);

  static const List<Color> graphColors = [
    Color(0xFF3DDC97),
    Color(0xFF5B8CFF),
    Color(0xFFFFC857),
    Color(0xFFB388FF),
    Color(0xFFFF6B7A),
    Color(0xFF5FE08A),
    Color(0xFF4FD1C5),
    Color(0xFFFF9F63),
  ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: leaf,
      brightness: Brightness.light,
      primary: leaf,
      secondary: amber,
      surface: mist,
      error: danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base.copyWith(
        primary: leaf,
        secondary: amber,
        surface: mist,
        onPrimary: mist,
        onSecondary: ink,
        onSurface: ink,
      ),
      scaffoldBackgroundColor: mist,
      fontFamily: 'Vazirmatn',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: leaf,
          foregroundColor: mist,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: moss,
          side: const BorderSide(color: Color(0xFFB9C7BE)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD5D0C4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD5D0C4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: leaf, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(fontFamily: 'Vazirmatn', color: mist),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerColor: const Color(0xFFD8D2C6),
    );
  }

  static ThemeData pro() {
    const scheme = ColorScheme.dark(
      primary: proAccent,
      secondary: proAccent2,
      surface: proPanel,
      error: proDanger,
      onPrimary: Color(0xFF06140F),
      onSecondary: Color(0xFF0A0E18),
      onSurface: proText,
      onError: Color(0xFF0B0D12),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: proBg,
      fontFamily: 'Vazirmatn',
      dividerColor: proBorderSoft,
      dialogTheme: DialogThemeData(
        backgroundColor: proPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: proElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(color: proText, fontFamily: 'Vazirmatn'),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: proPanel,
        foregroundColor: proText,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: proAccent,
          foregroundColor: const Color(0xFF06140F),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: proText,
          side: const BorderSide(color: proBorder),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: proAccent2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: proBg,
        hintStyle: const TextStyle(color: proMuted),
        labelStyle: const TextStyle(color: proMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: proBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: proBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: proAccent, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: proElevated,
        contentTextStyle: const TextStyle(fontFamily: 'Vazirmatn', color: proText),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 350),
      ),
    );
  }
}
