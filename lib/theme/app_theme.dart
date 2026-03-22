import 'package:flutter/material.dart';

class AppColors {
  static const Color azulAustral = Color(0xFF2E3192);
  static const Color verdeAustral = Color(0xFF00BF6F);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color darkGray = Color(0xFF333333);

  static const LinearGradient australGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [azulAustral, verdeAustral],
  );
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.azulAustral,
        primary: AppColors.azulAustral,
        secondary: AppColors.verdeAustral,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.backgroundWhite,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.azulAustral,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}
