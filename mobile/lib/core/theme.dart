import 'package:flutter/material.dart';

/// Colors come from the logo. The red is only for "call now" moments,
/// if everything is red nothing is.
class AppColors {
  static const ink = Color(0xFF0D2B33);
  static const inkSoft = Color(0xFF4A6168);
  static const brand = Color(0xFF1290B2);
  static const brandDeep = Color(0xFF0B5E75);
  static const aqua = Color(0xFF88CCD2);
  static const mist = Color(0xFFE6F4F5);
  static const paper = Color(0xFFF6F3EE);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE3DED5);

  static const signal = Color(0xFFE2483D);
  static const signalSoft = Color(0xFFFCE9E7);
  static const amber = Color(0xFFE8A33B);
  static const amberSoft = Color(0xFFFDF2DF);
  static const calm = Color(0xFF3C9A6E);
  static const calmSoft = Color(0xFFE5F3EC);

  static Color severity(String s) => switch (s) {
        'critical' => signal,
        'high' => const Color(0xFFD9692E),
        'moderate' => amber,
        _ => calm,
      };

  static Color severitySoft(String s) => switch (s) {
        'critical' => signalSoft,
        'high' => const Color(0xFFFBEADF),
        'moderate' => amberSoft,
        _ => calmSoft,
      };
}

String severityLabel(String s) => switch (s) {
      'critical' => 'خطيرة جداً',
      'high' => 'خطيرة',
      'moderate' => 'متوسطة',
      'low' => 'بسيطة',
      _ => 'غير محددة',
    };

ThemeData buildTheme() {
  const font = 'Plex';
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: font,
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      primary: AppColors.brand,
      secondary: AppColors.brandDeep,
      error: AppColors.signal,
      surface: AppColors.paper,
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink).copyWith(
          headlineMedium: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.3, color: AppColors.ink),
          titleLarge: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.ink),
          titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.6, color: AppColors.ink),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.55, color: AppColors.inkSoft),
          labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: font, fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: font, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.line, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: font, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
      ),
      labelStyle: const TextStyle(color: AppColors.inkSoft),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.ink,
      side: const BorderSide(color: AppColors.line),
      labelStyle: const TextStyle(fontFamily: font, fontSize: 14, color: AppColors.ink),
      secondaryLabelStyle: const TextStyle(fontFamily: font, fontSize: 14, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.mist,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontFamily: font, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
  );
}
