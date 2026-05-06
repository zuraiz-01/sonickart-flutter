import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
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
    final context = Get.context ?? Get.overlayContext;
    if (context == null) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          duration: duration ?? const Duration(seconds: 4),
          content: AwesomeSnackbarContent(
            title: title,
            message: message,
            contentType: _contentTypeFor(title, message),
          ),
        ),
      );
  }

  static ContentType _contentTypeFor(String title, String message) {
    final text = '$title $message'.toLowerCase();
    if (_containsAny(text, const [
      'success',
      'saved',
      'updated',
      'sent',
      'resent',
      'added',
      'placed',
      'verified',
    ])) {
      return ContentType.success;
    }
    if (_containsAny(text, const [
      'invalid',
      'required',
      'empty',
      'incomplete',
      'permission',
      'needed',
      'off',
      'expired',
    ])) {
      return ContentType.warning;
    }
    if (_containsAny(text, const [
      'help',
      'try',
      'check',
      'available',
      'location',
    ])) {
      return ContentType.help;
    }
    return ContentType.failure;
  }

  static bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }
}
