import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WaslaTheme {
  // Brand Colors
  static const Color primaryTeal = Color(0xFF0D7A84);
  static const Color primaryTealDark = Color(0xFF0A606A);
  static const Color primaryTealLight = Color(0xFFE4F4F6);

  static const Color secondaryGold = Color(0xFFE89510);
  static const Color secondaryGoldDark = Color(0xFFC97C0C);
  static const Color secondaryGoldLight = Color(0xFFFEF5E4);

  // Neutrals
  static const Color backgroundSand = Color(0xFFF9F7F3);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF161210);
  static const Color textMuted = Color(0xFF8A8278);

  // Semantic
  static const Color errorRed = Color(0xFFDC2626);
  static const Color successGreen = Color(0xFF16A34A);

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.cairoTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primaryTeal,
        onPrimary: surfaceWhite,
        primaryContainer: primaryTealLight,
        onPrimaryContainer: primaryTealDark,
        secondary: secondaryGold,
        onSecondary: surfaceWhite,
        secondaryContainer: secondaryGoldLight,
        onSecondaryContainer: secondaryGoldDark,
        background: backgroundSand,
        onBackground: textDark,
        surface: surfaceWhite,
        onSurface: textDark,
        error: errorRed,
        onError: surfaceWhite,
      ),
      scaffoldBackgroundColor: backgroundSand,
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(color: textDark, fontWeight: FontWeight.w900),
        displayMedium: baseTextTheme.displayMedium?.copyWith(color: textDark, fontWeight: FontWeight.w800),
        displaySmall: baseTextTheme.displaySmall?.copyWith(color: textDark, fontWeight: FontWeight.w700),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(color: textDark, fontWeight: FontWeight.w700),
        titleLarge: baseTextTheme.titleLarge?.copyWith(color: textDark, fontWeight: FontWeight.w700),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: textDark),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textDark),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryTeal,
        foregroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: surfaceWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEAE4DA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEAE4DA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryTeal, width: 2),
        ),
        hintStyle: GoogleFonts.cairo(color: textMuted),
      ),
    );
  }
}
