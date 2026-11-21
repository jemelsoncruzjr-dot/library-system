import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const green = Color(0xFF0D58BB);
  static const greenDark = Color(0xFF0A3F8F);
  static const brass = Color(0xFFE6A317);
  static const paper = Color(0xFFFFF6E6);
  static const ink = Color(0xFF2A1E14);
  static const muted = Color(0xFF6B5E52);
  static const line = Color(0xFFE8DCC6);
  static const danger = Color(0xFFB3261E);
  static const warning = Color(0xFF9A5B00);
  static const success = Color(0xFF1E7B4F);
  static const logoTop = Color(0xFFFFC36B);
  static const logoBottom = Color(0xFF3172EF);
  static const brown = Color(0xFF3B1F0B);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.green,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.green,
        onPrimary: Colors.white,
        surface: Colors.white,
        error: AppColors.danger,
      ),
    );

    final body = GoogleFonts.publicSansTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    final textTheme = body.copyWith(
      headlineLarge: GoogleFonts.newsreader(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        height: 1.1,
        color: AppColors.ink,
      ),
      headlineMedium: GoogleFonts.newsreader(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: AppColors.ink,
      ),
      headlineSmall: GoogleFonts.newsreader(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.ink,
      ),
      titleLarge: GoogleFonts.newsreader(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    );

    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.paper,
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: border(AppColors.line),
        enabledBorder: border(AppColors.line),
        focusedBorder: border(AppColors.green, 2),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger, 2),
        labelStyle: const TextStyle(color: AppColors.muted),
        floatingLabelStyle: const TextStyle(color: AppColors.green),
        helperStyle: const TextStyle(color: AppColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.publicSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.green,
          textStyle: GoogleFonts.publicSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: const BorderSide(color: AppColors.muted, width: 1.4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
    );
  }
}