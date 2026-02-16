import 'package:flutter/material.dart';

/// App theme configuration
class AppTheme {
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFFFFC107);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);
  static const Color backgroundColor = Color(0xFFFAFAFA);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textDarkColor = Color(0xFF212121);
  static const Color textLightColor = Color(0xFF757575);
  static const Color dividerColor = Color(0xFFBDBDBD);

  // Risk Colors
  static const Color lowRiskColor = Color(0xFF4CAF50);
  static const Color mediumRiskColor = Color(0xFFFFC107);
  static const Color highRiskColor = Color(0xFFFF9800);
  static const Color criticalRiskColor = Color(0xFFF44336);

  // Domain Colors
  static const Map<String, Color> domainColors = {
    'GM': Color(0xFF66BB6A),
    'FM': Color(0xFF42A5F5),
    'LC': Color(0xFFAB47BC),
    'COG': Color(0xFFFFA726),
    'SE': Color(0xFFEC407A),
  };

  /// Light Theme
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: primaryColor, width: 2),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: errorColor),
        ),
        labelStyle: const TextStyle(color: textLightColor),
        hintStyle: const TextStyle(color: textLightColor),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      iconTheme: const IconThemeData(color: textDarkColor),
      dividerTheme: DividerThemeData(color: dividerColor),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: const TextStyle(color: textDarkColor),
        side: BorderSide(color: dividerColor),
      ),
      textTheme: TextTheme(
        displayLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textDarkColor),
        displayMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textDarkColor),
        displaySmall: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDarkColor),
        headlineMedium: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDarkColor),
        headlineSmall: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textDarkColor),
        titleLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDarkColor),
        titleMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDarkColor),
        titleSmall: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textDarkColor),
        bodyLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: textDarkColor),
        bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: textDarkColor),
        bodySmall: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: textLightColor),
        labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
      ),
    );
  }

  /// Dark Theme (optional)
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFF121212),
    );
  }
}