import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'theme_controller.dart';

class AppColors {
  static const lightPrimary = Color(0xFF092774);
  static const lightPrimaryDark = Color(0xFF001F50);
  static const lightSecondaryBlue = Color(0xFF043FA8);
  static const lightSurface = Color(0xFFE8EEFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE8EEFF);
  static const lightTextPrimary = Color(0xFF092774);
  static const lightTextSecondary = Color(0xFF6E6E6E);
  static const lightInputFill = Color(0xFFFAFBFF);
  static const lightNavBg = Color(0xFFFFFFFF);

  static const darkSurface = Color(0xFF020815);
  static const darkCard = Color(0xFF07162D);
  static const darkCardElevated = Color(0xFF0A1B35);
  static const darkBorder = Color(0xFF123158);
  static const darkTextPrimary = Color(0xFFF4F8FF);
  static const darkTextSecondary = Color(0xFF8FA3C2);
  static const darkPrimaryFill = Color(0xFF082459);
  static const darkWalletCard = Color(0xFF06225B);
  static const darkNavBg = Color(0xFF07162D);

  static const accent = Color(0xFFFFC727);
  static const success = Color(0xFF28A745);
  static const error = Color(0xFFD64545);
  static const bgDark = Color(0xFF020B1C);

  static bool get isDarkMode {
    if (!Get.isRegistered<AppThemeController>()) return false;
    return Get.find<AppThemeController>().isDarkMode.value;
  }

  static Color get primary => isDarkMode ? darkTextPrimary : lightPrimary;
  static Color get primaryDark =>
      isDarkMode ? darkPrimaryFill : lightPrimaryDark;
  static Color get secondaryBlue =>
      isDarkMode ? const Color(0xFF5A8DFF) : lightSecondaryBlue;

  static Color get surface => isDarkMode ? darkSurface : lightSurface;
  static Color get card => isDarkMode ? darkCard : lightCard;
  static Color get border => isDarkMode ? darkBorder : lightBorder;
  static Color get muted => isDarkMode ? darkCardElevated : lightSurface;

  static Color get textPrimary =>
      isDarkMode ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondary =>
      isDarkMode ? darkTextSecondary : lightTextSecondary;

  static Color get white => isDarkMode ? darkCard : lightCard;
  static Color get black =>
      isDarkMode ? darkTextPrimary : const Color(0xFF000000);

  static Color get overlayBlue =>
      isDarkMode ? const Color(0xB0020815) : const Color(0x66092774);

  static Color get inputFill => isDarkMode ? darkCardElevated : lightInputFill;
  static Color get navBg => isDarkMode ? darkNavBg : lightNavBg;
  static Color get walletCard => isDarkMode ? darkWalletCard : lightPrimary;
  static Color get buttonFill => isDarkMode ? accent : lightPrimary;
  static Color get onButtonFill => isDarkMode ? bgDark : lightCard;
  static Color get onColored => lightCard;
  static Color get activeNav => isDarkMode ? accent : lightPrimary;
  static Color get price => isDarkMode ? accent : lightPrimary;
  static Color get productImageFill =>
      isDarkMode ? darkCardElevated : lightSurface;
  static Color get cardShadow =>
      isDarkMode ? const Color(0x66000000) : const Color(0x1A000000);
  static Color get softCardShadow =>
      isDarkMode ? const Color(0x4D000000) : const Color(0x14000000);
}
