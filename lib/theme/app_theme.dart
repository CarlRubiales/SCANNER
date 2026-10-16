import 'package:flutter/material.dart';

class AppTheme {
  // Lumora Brand Palette
  static const Color plum = Color(0xFF3D1B3D);
  static const Color plumDark = Color(0xFF261026);
  static const Color plumLight = Color(0xFF5A2A5A);
  
  static const Color orange = Color(0xFFE2703A);
  static const Color orangeHover = Color(0xFFCC5F2B);
  static const Color orangeLight = Color(0xFFFFF1EB);
  
  static const Color creamBg = Color(0xFFFFFDFB);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFEFE8E2);
  
  static const Color textDark = Color(0xFF1E1B1E);
  static const Color textMuted = Color(0xFF7A7079);
  
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFECFDF5);
  
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFEFF6FF);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: creamBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: plum,
        primary: plum,
        secondary: orange,
        surface: cardBg,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: plum,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: textDark,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
        titleMedium: TextStyle(
          color: textDark,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyLarge: TextStyle(
          color: textDark,
          fontSize: 15,
        ),
        bodyMedium: TextStyle(
          color: textMuted,
          fontSize: 13,
        ),
      ),
    );
  }
}

