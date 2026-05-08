import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class AppSnackBar {
  const AppSnackBar._();

  static void show(
    String title,
    String message, {
    SnackPosition snackPosition = SnackPosition.BOTTOM,
    Duration? duration,
    Widget? mainButton,
  }) {
    // Snackbars/toasts are intentionally disabled app-wide.
  }
}
