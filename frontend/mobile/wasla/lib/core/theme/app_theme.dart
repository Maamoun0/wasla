import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  // ── Light Theme ──────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: _lightColorScheme,
    scaffoldBackgroundColor: AppColors.neutral50,
    fontFamily: 'Cairo',

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.neutral900,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.neutral200,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.neutral900,
      ),
      iconTheme: IconThemeData(color: AppColors.neutral700),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
      ),
    ),

    // Card
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.neutral200, width: 1),
      ),
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary600,
        foregroundColor: AppColors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // Outlined Button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary600,
        side: const BorderSide(color: AppColors.primary600, width: 1.5),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // Text Button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary600,
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.neutral50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.neutral200, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.neutral200, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary600, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Cairo',
        color: AppColors.neutral400,
        fontSize: 14,
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Cairo',
        color: AppColors.neutral600,
        fontSize: 14,
      ),
    ),

    // Bottom Navigation
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.white,
      selectedItemColor: AppColors.primary600,
      unselectedItemColor: AppColors.neutral400,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.neutral100,
      labelStyle: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.neutral700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.neutral100,
      thickness: 1,
      space: 0,
    ),

    // Tab Bar
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary600,
      unselectedLabelColor: AppColors.neutral500,
      indicatorColor: AppColors.primary600,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),

    // Text Theme
    textTheme: _textTheme,
  );

  // ── Color Scheme ─────────────────────────────────────────────────
  static const ColorScheme _lightColorScheme = ColorScheme.light(
    primary:          AppColors.primary600,
    primaryContainer: AppColors.primary50,
    secondary:        AppColors.accent500,
    secondaryContainer: AppColors.accent50,
    surface:          AppColors.white,
    error:            AppColors.error,
    onPrimary:        AppColors.white,
    onSecondary:      AppColors.white,
    onSurface:        AppColors.neutral900,
    onError:          AppColors.white,
  );

  // ── Text Theme (Cairo) ───────────────────────────────────────────
  static const TextTheme _textTheme = TextTheme(
    // Display
    displayLarge:  TextStyle(fontFamily:'Cairo', fontSize:52, fontWeight:FontWeight.w900, color:AppColors.neutral900, height:1.1),
    displayMedium: TextStyle(fontFamily:'Cairo', fontSize:40, fontWeight:FontWeight.w800, color:AppColors.neutral900, height:1.2),
    displaySmall:  TextStyle(fontFamily:'Cairo', fontSize:32, fontWeight:FontWeight.w800, color:AppColors.neutral900, height:1.2),
    // Headline
    headlineLarge: TextStyle(fontFamily:'Cairo', fontSize:28, fontWeight:FontWeight.w700, color:AppColors.neutral900, height:1.3),
    headlineMedium:TextStyle(fontFamily:'Cairo', fontSize:24, fontWeight:FontWeight.w700, color:AppColors.neutral900, height:1.3),
    headlineSmall: TextStyle(fontFamily:'Cairo', fontSize:20, fontWeight:FontWeight.w700, color:AppColors.neutral900, height:1.3),
    // Title
    titleLarge:    TextStyle(fontFamily:'Cairo', fontSize:18, fontWeight:FontWeight.w700, color:AppColors.neutral900, height:1.4),
    titleMedium:   TextStyle(fontFamily:'Cairo', fontSize:16, fontWeight:FontWeight.w600, color:AppColors.neutral900, height:1.4),
    titleSmall:    TextStyle(fontFamily:'Cairo', fontSize:14, fontWeight:FontWeight.w600, color:AppColors.neutral900, height:1.4),
    // Body
    bodyLarge:     TextStyle(fontFamily:'Cairo', fontSize:16, fontWeight:FontWeight.w400, color:AppColors.neutral700, height:1.7),
    bodyMedium:    TextStyle(fontFamily:'Cairo', fontSize:14, fontWeight:FontWeight.w400, color:AppColors.neutral700, height:1.7),
    bodySmall:     TextStyle(fontFamily:'Cairo', fontSize:12, fontWeight:FontWeight.w400, color:AppColors.neutral500, height:1.6),
    // Label
    labelLarge:    TextStyle(fontFamily:'Cairo', fontSize:14, fontWeight:FontWeight.w600, color:AppColors.neutral700, height:1.4),
    labelMedium:   TextStyle(fontFamily:'Cairo', fontSize:12, fontWeight:FontWeight.w600, color:AppColors.neutral600, height:1.4),
    labelSmall:    TextStyle(fontFamily:'Cairo', fontSize:11, fontWeight:FontWeight.w500, color:AppColors.neutral500, height:1.4),
  );
}
