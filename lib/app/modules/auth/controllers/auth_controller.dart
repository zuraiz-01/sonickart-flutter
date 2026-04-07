import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routes/app_routes.dart';

class AuthController extends GetxController {
  AuthController(this._repository);

  static const int otpResendSeconds = 60;
  static const String dialCode = '+91';

  final AuthRepository _repository;
  final GetStorage _storage = GetStorage();

  final loginFormKey = GlobalKey<FormState>();
  final phoneController = TextEditingController();
  final otpController = TextEditingController();

  final isOtpSent = false.obs;
  final agreementChecked = false.obs;
  final isSendingOtp = false.obs;
  final isVerifyingOtp = false.obs;
  final resendTimer = 0.obs;
  final pendingPhone = ''.obs;
  final pendingUser = Rxn<UserModel>();

  Timer? _resendTimerTicker;

  UserModel? get currentUser {
    final rawUser = _storage.read('currentUser');
    if (rawUser is Map) {
      return UserModel.fromJson(Map<String, dynamic>.from(rawUser));
    }
    return null;
  }

  bool get isLoggedIn => _storage.read('isLoggedIn') == true;

  String get normalizedPhone => phoneController.text.replaceAll(RegExp(r'\D'), '');

  String get fullPhone => '$dialCode$normalizedPhone';

  String? validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return 'Phone number required hai.';
    }
    if (digits.length != 10) {
      return 'Valid 10 digit mobile number enter karo.';
    }
    return null;
  }

  String? validateOtp(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) {
      return 'Valid 6 digit OTP enter karo.';
    }
    return null;
  }

  void toggleAgreement() {
    agreementChecked.toggle();
  }

  void resetOtpFlow() {
    isOtpSent.value = false;
    otpController.clear();
    pendingPhone.value = '';
    pendingUser.value = null;
    isVerifyingOtp.value = false;
    isSendingOtp.value = false;
    resendTimer.value = 0;
    _resendTimerTicker?.cancel();
  }

  Future<void> sendOtp() async {
    if (!(loginFormKey.currentState?.validate() ?? false)) return;

    if (!agreementChecked.value) {
      Get.snackbar(
        'Agreement Required',
        'Please agree to Terms & Conditions and Privacy Policy to continue.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (isSendingOtp.value || isVerifyingOtp.value) return;

    isSendingOtp.value = true;
    try {
      await _repository.sendOtp(phone: fullPhone);
      pendingPhone.value = fullPhone;
      pendingUser.value = _repository.buildPendingUser(phone: fullPhone);
      isOtpSent.value = true;
      otpController.clear();
      _startResendTimer();

      Get.snackbar(
        'OTP Sent',
        'A verification code has been sent to $fullPhone. Demo OTP 123456 hai.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isSendingOtp.value = false;
    }
  }

  Future<void> resendOtp() async {
    if (resendTimer.value > 0) return;
    await sendOtp();
  }

  Future<void> verifyOtp() async {
    if (!agreementChecked.value) {
      Get.snackbar(
        'Agreement Required',
        'Please agree to Terms & Conditions and Privacy Policy to continue.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (validateOtp(otpController.text) != null) {
      Get.snackbar(
        'Invalid OTP',
        'Please enter a valid 6 digit OTP.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (isVerifyingOtp.value || isSendingOtp.value) return;

    isVerifyingOtp.value = true;
    try {
      final user = await _repository.verifyOtp(
        phone: pendingPhone.value,
        otp: otpController.text.replaceAll(RegExp(r'\D'), ''),
      );

      if (user == null) {
        otpController.clear();
        Get.snackbar(
          'Verification Failed',
          'Invalid OTP. Demo code 123456 hai.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      await _storage.write('isLoggedIn', true);
      await _storage.write('currentUser', user.toJson());

      resetOtpFlow();
      Get.offAllNamed(AppRoutes.dashboard);
    } finally {
      isVerifyingOtp.value = false;
    }
  }

  void changeNumber() {
    resetOtpFlow();
  }

  Future<void> logout() async {
    await _storage.erase();
    clearForms();
    Get.offAllNamed(AppRoutes.login);
  }

  void clearForms() {
    phoneController.clear();
    otpController.clear();
    agreementChecked.value = false;
    resetOtpFlow();
  }

  void _startResendTimer() {
    _resendTimerTicker?.cancel();
    resendTimer.value = otpResendSeconds;
    _resendTimerTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendTimer.value <= 1) {
        resendTimer.value = 0;
        timer.cancel();
        return;
      }
      resendTimer.value -= 1;
    });
  }

  @override
  void onClose() {
    _resendTimerTicker?.cancel();
    phoneController.dispose();
    otpController.dispose();
    super.onClose();
  }
}
