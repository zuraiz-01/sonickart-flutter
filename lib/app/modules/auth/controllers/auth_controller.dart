import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/services/firebase_bootstrap.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routes/app_routes.dart';
import '../../profile/controllers/profile_controller.dart';

class AuthController extends GetxController {
  AuthController(this._repository);

  static int otpResendSeconds = 60;
  static int phoneDigitLength = 10;
  static String dialCode = '+91';

  final AuthRepository _repository;
  final GetStorage _storage = GetStorage();

  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;

  final loginFormKey = GlobalKey<FormState>();
  final phoneController = TextEditingController();
  final otpController = TextEditingController();

  final isOtpSent = false.obs;
  final agreementChecked = false.obs;
  final isSendingOtp = false.obs;
  final isVerifyingOtp = false.obs;
  final resendTimer = 0.obs;
  final pendingPhone = ''.obs;
  final phoneInput = ''.obs;
  final otpInput = ''.obs;

  Timer? _resendTimerTicker;
  String? _verificationId;
  int? _resendToken;
  bool _loginInProgress = false;

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
      !isVerifyingOtp.value &&
      !_loginInProgress;

  bool get canSubmitOtp =>
      otpController.text.replaceAll(RegExp(r'\D'), '').length == 6 &&
      agreementChecked.value &&
      !isSendingOtp.value &&
      !isVerifyingOtp.value &&
      !_loginInProgress;

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
    isVerifyingOtp.value = false;
    isSendingOtp.value = false;
    _loginInProgress = false;
    resendTimer.value = 0;
    _verificationId = null;
    _resendToken = null;
    _resendTimerTicker?.cancel();
  }

  Future<void> sendOtp() async {
    if (!agreementChecked.value) {
      Get.snackbar(
        'Agreement Required',
        'Please agree to Terms & Conditions and Privacy Policy to continue.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!(loginFormKey.currentState?.validate() ?? false)) return;
    if (isSendingOtp.value || isVerifyingOtp.value) return;
    if (!_ensureFirebaseReady()) return;

    await _requestFirebaseOtp(phone: fullPhone, forceResend: false);
  }

  Future<void> resendOtp() async {
    if (resendTimer.value > 0 || isSendingOtp.value || isVerifyingOtp.value) {
      return;
    }
    if (!_ensureFirebaseReady()) return;

    final phone = pendingPhone.value.isNotEmpty
        ? pendingPhone.value
        : fullPhone;
    if (phone.isEmpty) return;

    await _requestFirebaseOtp(phone: phone, forceResend: true);
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
    if (!_ensureFirebaseReady()) return;

    final phoneForVerification = pendingPhone.value.isNotEmpty
        ? pendingPhone.value
        : fullPhone;
    if (phoneForVerification.replaceAll(RegExp(r'\D'), '').length <
        phoneDigitLength) {
      Get.snackbar(
        'Invalid Number',
        'Mobile number incomplete hai. Number dobara enter karo.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final currentUser = _firebaseAuth.currentUser;
    final expectedPhone = _normalizeE164(phoneForVerification);
    final currentUserPhone = _normalizeE164(currentUser?.phoneNumber ?? '');

    isVerifyingOtp.value = true;
    try {
      if (currentUser != null && currentUserPhone == expectedPhone) {
        await _completeBackendLogin(currentUser);
        return;
      }

      if (_verificationId == null || _verificationId!.trim().isEmpty) {
        throw AuthFlowException(
          'OTP session expire ho gayi. Dobara OTP request karo.',
        );
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpController.text.replaceAll(RegExp(r'\D'), ''),
      );
      final result = await _firebaseAuth.signInWithCredential(credential);
      final user = result.user ?? _firebaseAuth.currentUser;
      if (user == null) {
        throw AuthFlowException(
          'Verification successful hui lekin user session nahi mila.',
        );
      }
      await _completeBackendLogin(user);
    } on FirebaseAuthException catch (error) {
      _logFirebaseAuthError('verifyOtp', error);
      if (error.code == 'session-expired') {
        resetOtpFlow();
      } else if (error.code == 'invalid-verification-code') {
        otpController.clear();
      }
      Get.snackbar(
        _firebaseErrorTitle(error),
        _firebaseErrorMessage(error),
        snackPosition: SnackPosition.BOTTOM,
      );
    } on AuthFlowException catch (error) {
      await _clearFirebaseUser();
      resetOtpFlow();
      Get.snackbar(
        'Login Failed',
        '${error.message} Please request OTP again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isVerifyingOtp.value = false;
    }
  }

  void changeNumber() {
    unawaited(_clearFirebaseUser());
    resetOtpFlow();
  }

  Future<void> logout() async {
    if (Get.isRegistered<ProfileController>()) {
      Get.find<ProfileController>().clearSessionState();
    }
    await _clearFirebaseUser();
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

  Future<void> _requestFirebaseOtp({
    required String phone,
    required bool forceResend,
  }) async {
    try {
      if (!forceResend) {
        await _clearFirebaseUser();
        resetOtpFlow();
      }
      pendingPhone.value = phone;
      isSendingOtp.value = true;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _firebaseAuth.setSettings(forceRecaptchaFlow: false);
      }
      await _startPhoneNumberVerification(
        phone: phone,
        forceResend: forceResend,
      );
    } on FirebaseAuthException catch (error) {
      _logFirebaseAuthError('_requestFirebaseOtp', error);
      isSendingOtp.value = false;
      Get.snackbar(
        _firebaseErrorTitle(error),
        _firebaseErrorMessage(error),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      isSendingOtp.value = false;
      Get.snackbar(
        'OTP Failed',
        'Firebase OTP start nahi ho saka. Dobara try karo.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _startPhoneNumberVerification({
    required String phone,
    required bool forceResend,
  }) {
    return _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: Duration(seconds: otpResendSeconds),
      forceResendingToken: forceResend ? _resendToken : null,
      verificationCompleted: (credential) async {
        try {
          isSendingOtp.value = false;
          isVerifyingOtp.value = true;
          final result = await _firebaseAuth.signInWithCredential(credential);
          final user = result.user ?? _firebaseAuth.currentUser;
          if (user != null && agreementChecked.value) {
            await _completeBackendLogin(user);
          }
        } on FirebaseAuthException catch (error) {
          _logFirebaseAuthError('verificationCompleted', error);
          Get.snackbar(
            _firebaseErrorTitle(error),
            _firebaseErrorMessage(error),
            snackPosition: SnackPosition.BOTTOM,
          );
        } on AuthFlowException catch (error) {
          await _clearFirebaseUser();
          resetOtpFlow();
          Get.snackbar(
            'Login Failed',
            '${error.message} Please request OTP again.',
            snackPosition: SnackPosition.BOTTOM,
          );
        } finally {
          isVerifyingOtp.value = false;
        }
      },
      verificationFailed: (error) {
        _logFirebaseAuthError('verificationFailed', error);
        unawaited(_handleVerificationFailure(error: error));
      },
      codeSent: (verificationId, forceResendingToken) {
        _verificationId = verificationId;
        _resendToken = forceResendingToken;
        pendingPhone.value = phone;
        isOtpSent.value = true;
        otpController.clear();
        isSendingOtp.value = false;
        _startResendTimer();
        Get.snackbar(
          forceResend ? 'OTP Resent' : 'OTP Sent',
          'A verification code has been sent to $phone.',
          snackPosition: SnackPosition.BOTTOM,
        );
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
        isSendingOtp.value = false;
      },
    );
  }

  Future<void> _handleVerificationFailure({
    required FirebaseAuthException error,
  }) async {
    isSendingOtp.value = false;
    isVerifyingOtp.value = false;
    Get.snackbar(
      _firebaseErrorTitle(error),
      _firebaseErrorMessage(error),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _completeBackendLogin(User user) async {
    if (_loginInProgress) return;

    final verifiedPhone = _normalizeE164(user.phoneNumber ?? '');
    final expectedPhone = _normalizeE164(
      pendingPhone.value.isNotEmpty ? pendingPhone.value : fullPhone,
    );
    debugPrint(
      'AuthController._completeBackendLogin: verifiedPhone=$verifiedPhone expectedPhone=$expectedPhone',
    );

    if (verifiedPhone.isEmpty || verifiedPhone != expectedPhone) {
      throw AuthFlowException(
        'Verified phone entered number se match nahi karta. Dobara OTP request karo.',
      );
    }

    final firebaseIdToken = await user.getIdToken(true);
    if (firebaseIdToken == null || firebaseIdToken.trim().isEmpty) {
      throw AuthFlowException(
        'Firebase verification token nahi mila. Dobara try karo.',
      );
    }

    _loginInProgress = true;
    final appUser = await _repository.loginVerifiedCustomer(
      phone: _localPhoneDigitsFromE164(expectedPhone),
      agreement: agreementChecked.value,
      firebaseIdToken: firebaseIdToken,
      firebaseUid: user.uid,
      phoneE164: expectedPhone,
    );

    await _storage.write('isLoggedIn', true);
    await _storage.write('currentUser', appUser.toJson());
    if (Get.isRegistered<ProfileController>()) {
      await Get.find<ProfileController>().refreshForAuthenticatedSession();
    }

    resetOtpFlow();
    Get.offAllNamed(AppRoutes.dashboard);
  }

  bool _ensureFirebaseReady() {
    if (Firebase.apps.isNotEmpty) {
      return true;
    }
    final details = _firebaseSetupGuidance();
    Get.snackbar(
      'Firebase Not Ready',
      details,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 7),
    );
    return false;
  }

  Future<void> _clearFirebaseUser() async {
    try {
      if (_firebaseAuth.currentUser != null) {
        await _firebaseAuth.signOut();
      }
    } catch (error) {
      debugPrint('AuthController._clearFirebaseUser failed: $error');
    }
  }

  String _normalizeE164(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.length == phoneDigitLength) {
      return '$dialCode$digits';
    }
    if (value.startsWith('+')) {
      return '+$digits';
    }
    return '+$digits';
  }

  String _localPhoneDigitsFromE164(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= phoneDigitLength) return digits;
    return digits.substring(digits.length - phoneDigitLength);
  }

  String _firebaseErrorTitle(FirebaseAuthException error) {
    if (_isBrowserStateError(error)) {
      return 'Browser Verification Failed';
    }
    switch (error.code) {
      case 'invalid-verification-code':
        return 'Wrong OTP';
      case 'session-expired':
        return 'OTP Expired';
      case 'invalid-phone-number':
        return 'Invalid Number';
      case 'too-many-requests':
        return 'Too Many Attempts';
      case 'missing-client-identifier':
        return 'Firebase Setup Error';
      default:
        return 'Firebase Auth Error';
    }
  }

  String _firebaseErrorMessage(FirebaseAuthException error) {
    if (_isBrowserStateError(error)) {
      return _browserStateRecoveryMessage();
    }
    switch (error.code) {
      case 'invalid-phone-number':
        return 'The phone number is invalid.';
      case 'invalid-verification-code':
        return 'The OTP code is incorrect. Please try again.';
      case 'session-expired':
        return 'The OTP has expired. Please request a new OTP.';
      case 'too-many-requests':
        return 'Firebase ne is phone/app/IP ko temporarily throttle kar diya hai. Thori der wait karo, ya development me Firebase Console ka test phone number use karo.';
      case 'missing-client-identifier':
        return '${_firebaseSetupGuidance()} Fresh google-services.json replace karke app uninstall/reinstall karo.';
      default:
        return error.message ??
            'Firebase verification failed. Please try again.';
    }
  }

  void _logFirebaseAuthError(String source, FirebaseAuthException error) {
    debugPrint(
      'FirebaseAuth[$source]: code=${error.code}, message=${error.message}',
    );
  }

  bool _isBrowserStateError(FirebaseAuthException error) {
    final rawMessage = error.message?.toLowerCase() ?? '';
    return rawMessage.contains('missing initial state') ||
        rawMessage.contains('sessionstorage') ||
        rawMessage.contains('storage-partitioned browser environment');
  }

  String _browserStateRecoveryMessage() {
    return 'Browser reCAPTCHA state lose ho gayi. Android app me browser fallback use nahi hona chahiye; Firebase Android app ki SHA keys aur fresh google-services.json check karo.';
  }

  String _firebaseSetupGuidance() {
    if (kIsWeb) {
      return 'Ye project web Firebase phone auth ke liye configured nahi hai. Android app par test karo.';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final initError = FirebaseBootstrap.lastError;
        final base =
            'Android Firebase config check karo: package `com.sonickart`, SHA-1 `0E:5D:0E:19:33:75:2D:6D:1E:76:40:41:94:03:6E:6F:1E:14:30:62`, SHA-256 `30:D7:43:90:19:AD:2E:13:52:C6:29:1C:AC:7D:63:1D:B4:18:05:22:65:26:1B:7F:0A:43:7A:EC:EE:2F:30:E9` Firebase console me add hone chahiye.';
        if (initError != null) {
          return '$base Init error: $initError';
        }
        return base;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'Apple platforms ke liye `ios/Runner/GoogleService-Info.plist` abhi missing hai. Firebase console se plist download karke Runner target me add karo.';
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'Phone auth ko desktop par test mat karo. Android device/emulator use karo jahan Firebase auth configured hai.';
      case TargetPlatform.fuchsia:
        return 'Firebase is not configured for this platform.';
    }
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
