// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppColors {
  // Cream palette
  static const cream   = Color(0xFFFAF8F3);
  static const cream2  = Color(0xFFF4F0E8);
  static const cream3  = Color(0xFFEDE8DC);
  static const ink     = Color(0xFF1A1814);
  static const ink2    = Color(0xFF3D3A34);
  static const ink3    = Color(0xFF7A7569);
  static const border  = Color(0x1A1A1814);

  // AQI semantic colors
  static const aqiGreen      = Color(0xFF2D7A4F);
  static const aqiGreenBg    = Color(0xFFE8F5EE);
  static const aqiYellow     = Color(0xFFC4880A);
  static const aqiYellowBg   = Color(0xFFFEF6E4);
  static const aqiOrange     = Color(0xFFC45A0A);
  static const aqiOrangeBg   = Color(0xFFFEF0E4);
  static const aqiRed        = Color(0xFFC41A1A);
  static const aqiRedBg      = Color(0xFFFEE8E8);
  static const aqiPurple     = Color(0xFF7B2DBF);
  static const aqiPurpleBg   = Color(0xFFF3E8FE);
  static const aqiMaroon     = Color(0xFF8B0A0A);
  static const aqiMaroonBg   = Color(0xFFFFE0E0);

  static const accent      = Color(0xFF2D5FA3);
  static const accentLight = Color(0xFFEAF0FB);

  // Semantic colors
  static const mapMiniBackground = Color(0xFFDCEFDC); // FIX-MINOR-04: extracted from screens
  static const whoThresholdRed   = Color(0xFFef4444); // FIX-MINOR-05: used in chart
  static const gradientGreen     = Color(0xFF22c55e); // FIX-MINOR-06: used in map legend
  static const gradientYellow    = Color(0xFFeab308);
  static const gradientOrange    = Color(0xFFf97316);
  static const gradientPurple    = Color(0xFFa855f7);
  static const gradientMaroon    = Color(0xFF7f1d1d);

  // Chart gradient colors
  static const chartGradientStart = Color(0xFF2D5FA3);
  static const chartGradientEnd   = Color(0x002D5FA3);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.cream,
    colorScheme: ColorScheme.light(
      primary: AppColors.accent,
      surface: AppColors.cream,
      onPrimary: Colors.white,
      onSurface: AppColors.ink,
    ),
    fontFamily: 'DMSans',
    textTheme: const TextTheme(
      displayLarge:  TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -3),
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -1),
      headlineMedium:TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
      titleLarge:    TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.ink),
      titleMedium:   TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
      titleSmall:    TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
      bodyLarge:     TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.ink2),
      bodyMedium:    TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.ink2),
      bodySmall:     TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.ink3),
      labelSmall:    TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.ink3, letterSpacing: 0.8),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.cream,
      selectedItemColor: AppColors.ink,
      unselectedItemColor: AppColors.ink3,
      selectedLabelStyle: TextStyle(fontFamily: 'DMSans', fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontFamily: 'DMSans', fontSize: 10, fontWeight: FontWeight.w600),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: AppColors.cream,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    dividerColor: AppColors.border,
  );

  /// FIX-MAJOR-05: Full dark theme with light text colors so text is visible
  /// on dark backgrounds. Previously only scaffold + colorScheme were overridden,
  /// leaving all TextStyles pointing to AppColors.ink (near-black = invisible).
  static ThemeData get dark => light.copyWith(
    scaffoldBackgroundColor: const Color(0xFF141210),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      surface: Color(0xFF1E1C18),
      onSurface: Color(0xFFF0EDE5),
    ),
    textTheme: const TextTheme(
      displayLarge:   TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: Color(0xFFF0EDE5), letterSpacing: -3),
      headlineLarge:  TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFFF0EDE5), letterSpacing: -1),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFF0EDE5)),
      titleLarge:     TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFFF0EDE5)),
      titleMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFF0EDE5)),
      titleSmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF0EDE5)),
      bodyLarge:      TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFFCCC8C0)),
      bodyMedium:     TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Color(0xFFCCC8C0)),
      bodySmall:      TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Color(0xFF8A8478)),
      labelSmall:     TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF8A8478), letterSpacing: 0.8),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1C18),
      foregroundColor: Color(0xFFF0EDE5),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontFamily: 'DMSans', fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFFF0EDE5)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1E1C18),
      selectedItemColor: Color(0xFFF0EDE5),
      unselectedItemColor: Color(0xFF8A8478),
      selectedLabelStyle: TextStyle(fontFamily: 'DMSans', fontSize: 10, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontFamily: 'DMSans', fontSize: 10, fontWeight: FontWeight.w500),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: const Color(0xFF1E1C18),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0x33F0EDE5), width: 1),
      ),
    ),
  );
}

// AQI color utilities
Color aqiColor(int aqi) {
  if (aqi <= 50)  return AppColors.aqiGreen;
  if (aqi <= 100) return AppColors.aqiYellow;
  if (aqi <= 150) return AppColors.aqiOrange;
  if (aqi <= 200) return AppColors.aqiRed;
  if (aqi <= 300) return AppColors.aqiPurple;
  return AppColors.aqiMaroon;
}

Color aqiBgColor(int aqi) {
  if (aqi <= 50)  return AppColors.aqiGreenBg;
  if (aqi <= 100) return AppColors.aqiYellowBg;
  if (aqi <= 150) return AppColors.aqiOrangeBg;
  if (aqi <= 200) return AppColors.aqiRedBg;
  if (aqi <= 300) return AppColors.aqiPurpleBg;
  return AppColors.aqiMaroonBg;
}
