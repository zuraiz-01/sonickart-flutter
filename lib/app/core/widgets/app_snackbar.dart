import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

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

    toastification.show(
      context: context,
      type: _toastTypeFor(title, message),
      style: ToastificationStyle.flatColored,
      alignment: snackPosition == SnackPosition.TOP
          ? Alignment.topCenter
          : Alignment.bottomCenter,
      autoCloseDuration: duration ?? const Duration(seconds: 4),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      description: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
      showProgressBar: false,
      closeOnClick: true,
      dragToClose: true,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 14,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  static ToastificationType _toastTypeFor(String title, String message) {
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
      return ToastificationType.success;
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
      return ToastificationType.warning;
    }
    if (_containsAny(text, const [
      'help',
      'try',
      'check',
      'available',
      'location',
    ])) {
      return ToastificationType.info;
    }
    return ToastificationType.error;
  }

  static bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }
}
