import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routes/app_routes.dart';

class AuthController extends GetxController {
  AuthController(this._repository);

  static int otpResendSeconds = 60;
  static int phoneDigitLength = 10;
  static String dialCode = '+91';

  final AuthRepository _repository;
  final GetStorage _storage = GetStorage();

  final loginFormKey = GlobalKey<FormState>();
  final phoneController = TextEditingController();
  final otpController = TextEditingController();

  final isOtpSent = false.obs;
  final agreementChecked = true.obs;
  final isSendingOtp = false.obs;
  final isVerifyingOtp = false.obs;
  final resendTimer = 0.obs;
  final pendingPhone = ''.obs;
  final pendingUser = Rxn<UserModel>();
  final phoneInput = ''.obs;
  final otpInput = ''.obs;

  Timer? _resendTimerTicker;

  UserModel? get currentUser {
    final rawUser = _storage.read('currentUser');
    if (rawUser is Map) {
      return UserModel.fromJson(Map<String, dynamic>.from(rawUser));
    }
    return null;
  }

  bool get isLoggedIn => _storage.read('isLoggedIn') == true;

  String get enteredPhoneDigits =>
      phoneController.text.replaceAll(RegExp(r'\D'), '');

  String get normalizedPhone {
    final digits = enteredPhoneDigits;
    if (digits.length == phoneDigitLength + 1 && digits.startsWith('0')) {
      return digits.substring(1);
    }
    if (digits.length > phoneDigitLength) {
      return digits.substring(digits.length - phoneDigitLength);
    }
    return digits;
  }

  String get fullPhone => '$dialCode$normalizedPhone';

  bool get canSubmitPhone =>
      normalizedPhone.length == phoneDigitLength &&
      agreementChecked.value &&
      !isSendingOtp.value &&
      !isVerifyingOtp.value;

  bool get canSubmitOtp =>
      otpController.text.replaceAll(RegExp(r'\D'), '').length == 6 &&
      agreementChecked.value &&
      !isSendingOtp.value &&
      !isVerifyingOtp.value;

  String? validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return 'Phone number required hai.';
    }
    final normalized =
        (digits.length == phoneDigitLength + 1 && digits.startsWith('0'))
        ? digits.substring(1)
        : digits;
    if (normalized.length != phoneDigitLength) {
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
    if (!agreementChecked.value) {
      agreementChecked.value = true;
    }

    if (!(loginFormKey.currentState?.validate() ?? false)) return;

    if (isSendingOtp.value || isVerifyingOtp.value) return;
    await _requestOtp(phone: fullPhone);
  }

  Future<void> resendOtp() async {
    if (resendTimer.value > 0 || isSendingOtp.value || isVerifyingOtp.value)
      return;

    final phone = pendingPhone.value.isNotEmpty
        ? pendingPhone.value
        : fullPhone;
    if (phone.isEmpty) return;

    await _requestOtp(phone: phone, showResentMessage: true);
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

    final phoneForVerification = pendingPhone.value.isNotEmpty
        ? pendingPhone.value
        : fullPhone;
    final otpCode = otpController.text.replaceAll(RegExp(r'\D'), '');

    if (phoneForVerification.replaceAll(RegExp(r'\D'), '').length <
        phoneDigitLength) {
      Get.snackbar(
        'Invalid Number',
        'Mobile number incomplete hai. Number dobara enter karo.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isVerifyingOtp.value = true;
    try {
      final user = await _repository.verifyOtp(
        phone: phoneForVerification,
        otp: otpCode,
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
    agreementChecked.value = true;
    resetOtpFlow();
  }

  @override
  void onInit() {
    super.onInit();
    phoneController.addListener(() {
      phoneInput.value = phoneController.text;
    });
    otpController.addListener(() {
      otpInput.value = otpController.text;
    });
  }

  Future<void> _requestOtp({
    required String phone,
    bool showResentMessage = false,
  }) async {
    isSendingOtp.value = true;
    try {
      await _repository.sendOtp(phone: phone);
      pendingPhone.value = phone;
      pendingUser.value = _repository.buildPendingUser(phone: phone);
      isOtpSent.value = true;
      otpController.clear();
      _startResendTimer();

      Get.snackbar(
        showResentMessage ? 'OTP Resent' : 'OTP Sent',
        'A verification code has been sent to $phone. Demo OTP 123456 hai.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isSendingOtp.value = false;
    }
  }

  void _startResendTimer() {
    _resendTimerTicker?.cancel();
    resendTimer.value = otpResendSeconds;
    _resendTimerTicker = Timer.periodic(Duration(seconds: 1), (timer) {
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
