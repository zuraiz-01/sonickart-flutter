import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      primary: AppColors.lightPrimary,
      surface: AppColors.lightSurface,
      card: AppColors.lightCard,
      border: AppColors.lightBorder,
      textPrimary: AppColors.lightTextPrimary,
      textSecondary: AppColors.lightTextSecondary,
      inputFill: AppColors.lightCard,
    );
  }

  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      surface: AppColors.darkSurface,
      card: AppColors.darkCard,
      border: AppColors.darkBorder,
      textPrimary: AppColors.darkTextPrimary,
      textSecondary: AppColors.darkTextSecondary,
      inputFill: AppColors.darkCardElevated,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color surface,
    required Color card,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required Color inputFill,
  }) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Okra',
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        surface: surface,
      ),
      scaffoldBackgroundColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17.spx,
          fontWeight: FontWeight.w900,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.wpx,
          vertical: 14.hpx,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.rpx),
          borderSide: BorderSide(color: border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.rpx),
          borderSide: BorderSide(color: border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.rpx),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.rpx),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.rpx),
          borderSide: BorderSide(color: AppColors.error),
        ),
        hintStyle: TextStyle(color: textSecondary, fontSize: 14.spx),
        labelStyle: TextStyle(color: textSecondary),
        prefixIconColor: isDark ? AppColors.accent : AppColors.lightPrimary,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.rpx),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? AppColors.accent : AppColors.lightPrimary,
          foregroundColor: isDark ? AppColors.bgDark : AppColors.lightCard,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accent
              : textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accent.withValues(alpha: 0.38)
              : border,
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 34,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 28,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 24,
        ),
        titleLarge: TextStyle(color: textPrimary),
        titleMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        titleSmall: TextStyle(color: textPrimary),
        labelLarge: TextStyle(color: textPrimary),
        labelMedium: TextStyle(color: textPrimary),
        labelSmall: TextStyle(color: textSecondary),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16, height: 1.45),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14, height: 1.45),
        bodySmall: TextStyle(color: textSecondary),
      ),
    );
  }
}
