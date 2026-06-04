import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class AppThemeController extends GetxController {
  AppThemeController(this._storage);

  static const _storageKey = 'dark_mode_enabled';

  final GetStorage _storage;
  final isDarkMode = false.obs;

  ThemeMode get themeMode =>
      isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  @override
  void onInit() {
    super.onInit();
    isDarkMode.value = _storage.read<bool>(_storageKey) == true;
  }

  Future<void> setDarkMode(bool value) async {
    if (isDarkMode.value == value) return;
    isDarkMode.value = value;
    await _storage.write(_storageKey, value);
    Get.changeThemeMode(themeMode);
    await Get.forceAppUpdate();
  }
}
