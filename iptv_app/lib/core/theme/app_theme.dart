import 'package:flutter/material.dart';

class AppTheme {
  // Teeglo Brand Colors
  static const Color teegloBlue = Color(0xFF0066FF);
  static const Color teegloCyan = Color(0xFF00D4FF);
  static const Color teegloPurple = Color(0xFF8B5CF6);
  
  // Netflix-style Dark Theme Colors
  static const Color bgDark = Color(0xFF000000); // Pure black to match logos
  static const Color bgSurface = Color(0xFF141420);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color liveIndicator = Color(0xFFE50914);

  static ThemeData get lightTheme {
    return darkTheme; // Force dark theme for Netflix aesthetic
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: teegloCyan,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: teegloCyan,
        secondary: teegloPurple,
        surface: bgSurface,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgSurface,
        selectedItemColor: teegloCyan,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      useMaterial3: true,
      fontFamily: 'Roboto', // Modern sans-serif
    );
  }
}
