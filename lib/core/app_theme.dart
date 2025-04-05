// define app theme
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData appTheme() {
  return ThemeData(
    scaffoldBackgroundColor: const Color(0xFF121212), // Primary Dark
    textTheme: GoogleFonts.poppinsTextTheme().apply(
      bodyColor: const Color(0xFFFFFFFF), // Text
      displayColor: const Color(0xFFFFFFFF),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4CAF50), // Accent Green
        foregroundColor: const Color(0xFFFFFFFF),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30), // Rounded corners
        ),
        elevation: 4,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFB3B3B3), // Secondary Text
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E1E1E), // Secondary Dark
      hintStyle: const TextStyle(color: Color(0xFFB3B3B3)), // Secondary Text
      prefixIconColor: const Color(0xFFB3B3B3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF4CAF50), // Accent Green
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF2E7D32), // Highlight
      onSecondary: Color(0xFFFFFFFF),
      surface: Color(0xFF1E1E1E), // Secondary Dark
      onSurface: Color(0xFFFFFFFF),
    ),
  );
}