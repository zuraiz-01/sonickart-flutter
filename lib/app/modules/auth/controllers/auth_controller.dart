import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/services/firebase_bootstrap.dart';
import '../../../core/services/customer_socket_notification_service.dart';
import '../../../core/services/package_socket_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/service_area_gate_controller.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routes/app_routes.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../profile/controllers/profile_controller.dart';

class AuthController extends GetxController {
  AuthController(this._repository);

  // ============================================================
  // FIREBASE TEST / OTP CONFIG
  // ============================================================

  static const int otpResendSeconds = 60;
  static const int phoneDigitLength = 10;

  // Change this if your Firebase test number uses another country.
  // Pakistan = +92
  // India   = +91
  static const String dialCode = '+91';

  final AuthRepository _repository;
  final GetStorage _storage = GetStorage();

  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;

  // ============================================================
  // FORM
  // ============================================================

  final loginFormKey = GlobalKey<FormState>();

  final phoneController = TextEditingController();
  final otpController = TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  final isOtpSent = false.obs;
  final agreementChecked = false.obs;

  final isSendingOtp = false.obs;
  final isVerifyingOtp = false.obs;

  final resendTimer = 0.obs;

  final pendingPhone = ''.obs;

  final phoneInput = ''.obs;
  final otpInput = ''.obs;

  final otpSentAlertTick = 0.obs;
  final otpSentAlertTitle = ''.obs;
  final otpSentAlertMessage = ''.obs;

  Timer? _resendTimerTicker;
  Timer? _otpRequestWatchdog;

  String? _verificationId;
  int? _resendToken;

  bool _loginInProgress = false;

  // ============================================================
  // CURRENT USER
  // ============================================================

  UserModel? get currentUser {
    final rawUser = _storage.read('currentUser');

    if (rawUser is Map) {
      return UserModel.fromJson(Map<String, dynamic>.from(rawUser));
    }

    return null;
  }

  bool get isLoggedIn {
    return _storage.read('isLoggedIn') == true;
  }

  // ============================================================
  // PHONE
  // ============================================================

  String get enteredPhoneDigits {
    return phoneInput.value.replaceAll(RegExp(r'\D'), '');
  }

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

  String get fullPhone {
    return '$dialCode$normalizedPhone';
  }

  // ============================================================
  // BUTTON STATES
  // ============================================================

  bool get canSubmitPhone {
    return normalizedPhone.length == phoneDigitLength &&
        agreementChecked.value &&
        !isSendingOtp.value &&
        !isVerifyingOtp.value &&
        !_loginInProgress;
  }

  bool get canSubmitOtp {
    final otpDigits = otpInput.value.replaceAll(RegExp(r'\D'), '');

    return otpDigits.length == 6 &&
        agreementChecked.value &&
        !isSendingOtp.value &&
        !isVerifyingOtp.value &&
        !_loginInProgress;
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  String? validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return 'Phone number is required.';
    }

    final normalized =
        (digits.length == phoneDigitLength + 1 && digits.startsWith('0'))
        ? digits.substring(1)
        : digits;

    if (normalized.length != phoneDigitLength) {
      return 'Enter a valid 10-digit mobile number.';
    }

    return null;
  }

  String? validateOtp(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');

    if (digits.length != 6) {
      return 'Enter a valid 6-digit OTP.';
    }

    return null;
  }

  // ============================================================
  // AGREEMENT
  // ============================================================

  void toggleAgreement() {
    agreementChecked.toggle();
  }

  // ============================================================
  // RESET
  // ============================================================

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
    _otpRequestWatchdog?.cancel();
  }

  // ============================================================
  // SEND OTP
  // ============================================================

  Future<void> sendOtp() async {
    if (!agreementChecked.value) {
      AppSnackBar.show(
        'Agreement Required',
        'Please agree to Terms & Conditions and Privacy Policy to continue.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!(loginFormKey.currentState?.validate() ?? false)) {
      AppSnackBar.show(
        'Invalid Number',
        'Enter a valid 10-digit mobile number.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (isSendingOtp.value || isVerifyingOtp.value) {
      return;
    }

    if (!_ensureFirebaseReady()) {
      return;
    }

    await _requestFirebaseOtp(phone: fullPhone, forceResend: false);
  }

  // ============================================================
  // RESEND OTP
  // ============================================================

  Future<void> resendOtp() async {
    if (resendTimer.value > 0 || isSendingOtp.value || isVerifyingOtp.value) {
      return;
    }

    if (!_ensureFirebaseReady()) {
      return;
    }

    final phone = pendingPhone.value.isNotEmpty
        ? pendingPhone.value
        : fullPhone;

    if (phone.isEmpty) {
      return;
    }

    await _requestFirebaseOtp(phone: phone, forceResend: true);
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<void> verifyOtp() async {
    if (!agreementChecked.value) {
      AppSnackBar.show(
        'Agreement Required',
        'Please agree to Terms & Conditions and Privacy Policy to continue.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final otpError = validateOtp(otpController.text);

    if (otpError != null) {
      AppSnackBar.show(
        'Invalid OTP',
        'Please enter a valid 6 digit OTP.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (isVerifyingOtp.value || isSendingOtp.value) {
      return;
    }

    if (!_ensureFirebaseReady()) {
      return;
    }

    final phoneForVerification = pendingPhone.value.isNotEmpty
        ? pendingPhone.value
        : fullPhone;

    final phoneDigits = phoneForVerification.replaceAll(RegExp(r'\D'), '');

    if (phoneDigits.length < phoneDigitLength) {
      AppSnackBar.show(
        'Invalid Number',
        'Mobile number is incomplete. Enter the number again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (_verificationId == null || _verificationId!.trim().isEmpty) {
      AppSnackBar.show(
        'OTP Session Expired',
        'Please request a new OTP.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isVerifyingOtp.value = true;

    try {
      final smsCode = otpController.text.replaceAll(RegExp(r'\D'), '');

      debugPrint('AuthController: verifying OTP for $phoneForVerification');

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      final result = await _firebaseAuth.signInWithCredential(credential);

      final user = result.user ?? _firebaseAuth.currentUser;

      if (user == null) {
        throw AuthFlowException(
          'Verification succeeded, but Firebase user session was not found.',
        );
      }

      await _completeBackendLogin(user);
    } on FirebaseAuthException catch (error) {
      _logFirebaseAuthError('verifyOtp', error);

      if (error.code == 'session-expired') {
        resetOtpFlow();
      }

      if (error.code == 'invalid-verification-code') {
        otpController.clear();
      }

      AppSnackBar.show(
        _firebaseErrorTitle(error),
        _firebaseErrorMessage(error),
        snackPosition: SnackPosition.BOTTOM,
      );
    } on AuthFlowException catch (error) {
      await _clearFirebaseUser();

      resetOtpFlow();

      AppSnackBar.show(
        'Login Failed',
        error.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      debugPrint('AuthController.verifyOtp unexpected error: $error');

      AppSnackBar.show(
        'Login Failed',
        'Something went wrong while verifying the OTP.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isVerifyingOtp.value = false;
    }
  }

  // ============================================================
  // CHANGE NUMBER
  // ============================================================

  void changeNumber() {
    unawaited(_clearFirebaseUser());

    resetOtpFlow();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    if (Get.isRegistered<CustomerSocketNotificationService>()) {
      Get.find<CustomerSocketNotificationService>().disconnect();
    }

    if (Get.isRegistered<PackageSocketService>()) {
      Get.find<PackageSocketService>().disconnect();
    }

    if (Get.isRegistered<CartController>()) {
      await Get.find<CartController>().detachFromCurrentSession();
    }

    if (Get.isRegistered<ProfileController>()) {
      Get.find<ProfileController>().clearSessionState();
    }

    if (Get.isRegistered<PushNotificationService>()) {
      await Get.find<PushNotificationService>().clearTokenCache();
    }

    await _clearFirebaseUser();

    await _storage.erase();

    clearForms();

    Get.offAllNamed(AppRoutes.login);
  }

  // ============================================================
  // CLEAR FORMS
  // ============================================================

  void clearForms() {
    phoneController.clear();
    otpController.clear();

    agreementChecked.value = false;

    resetOtpFlow();
  }

  // ============================================================
  // INIT
  // ============================================================

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

  // ============================================================
  // FIREBASE OTP REQUEST
  // ============================================================

  Future<void> _requestFirebaseOtp({
    required String phone,
    required bool forceResend,
  }) async {
    try {
      if (!forceResend) {
        await _clearFirebaseUser();

        // Do not reset the entire form here.
        isOtpSent.value = false;
        _verificationId = null;
        _resendToken = null;
      }

      pendingPhone.value = phone;

      isSendingOtp.value = true;

      _startOtpRequestWatchdog();

      debugPrint('FirebaseAuth: requesting OTP for $phone');

      await _startPhoneNumberVerification(
        phone: phone,
        forceResend: forceResend,
      );
    } on FirebaseAuthException catch (error) {
      _logFirebaseAuthError('_requestFirebaseOtp', error);

      isSendingOtp.value = false;

      _otpRequestWatchdog?.cancel();

      AppSnackBar.show(
        _firebaseErrorTitle(error),
        _firebaseErrorMessage(error),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      debugPrint('FirebaseAuth OTP request error: $error');

      isSendingOtp.value = false;

      _otpRequestWatchdog?.cancel();

      AppSnackBar.show(
        'OTP Failed',
        'Firebase OTP could not be started. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ============================================================
  // VERIFY PHONE NUMBER
  // ============================================================

  Future<void> _startPhoneNumberVerification({
    required String phone,
    required bool forceResend,
  }) {
    return _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phone,

      timeout: const Duration(seconds: otpResendSeconds),

      forceResendingToken: forceResend ? _resendToken : null,

      // ========================================================
      // AUTOMATIC VERIFICATION
      // ========================================================
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          debugPrint('FirebaseAuth: verificationCompleted');

          _otpRequestWatchdog?.cancel();

          isSendingOtp.value = false;
          isVerifyingOtp.value = true;

          final result = await _firebaseAuth.signInWithCredential(credential);

          final user = result.user ?? _firebaseAuth.currentUser;

          if (user != null && agreementChecked.value) {
            await _completeBackendLogin(user);
          }
        } on FirebaseAuthException catch (error) {
          _logFirebaseAuthError('verificationCompleted', error);

          AppSnackBar.show(
            _firebaseErrorTitle(error),
            _firebaseErrorMessage(error),
            snackPosition: SnackPosition.BOTTOM,
          );
        } on AuthFlowException catch (error) {
          await _clearFirebaseUser();

          resetOtpFlow();

          AppSnackBar.show(
            'Login Failed',
            error.message,
            snackPosition: SnackPosition.BOTTOM,
          );
        } finally {
          isVerifyingOtp.value = false;
        }
      },

      // ========================================================
      // VERIFICATION FAILED
      // ========================================================
      verificationFailed: (FirebaseAuthException error) {
        _logFirebaseAuthError('verificationFailed', error);

        unawaited(_handleVerificationFailure(error: error));
      },

      // ========================================================
      // CODE SENT
      // ========================================================
      codeSent: (String verificationId, int? forceResendingToken) {
        debugPrint('FirebaseAuth: codeSent');

        _verificationId = verificationId;

        _resendToken = forceResendingToken;

        _otpRequestWatchdog?.cancel();

        pendingPhone.value = phone;

        isOtpSent.value = true;

        otpController.clear();

        isSendingOtp.value = false;

        _startResendTimer();

        otpSentAlertTitle.value = forceResend ? 'OTP Resent' : 'OTP Sent';

        otpSentAlertMessage.value =
            'A verification code has been sent to $phone.';

        otpSentAlertTick.value++;

        AppSnackBar.show(
          forceResend ? 'OTP Resent' : 'OTP Sent',
          'Enter the OTP configured for this Firebase test number.',
          snackPosition: SnackPosition.BOTTOM,
        );
      },

      // ========================================================
      // TIMEOUT
      // ========================================================
      codeAutoRetrievalTimeout: (String verificationId) {
        debugPrint('FirebaseAuth: codeAutoRetrievalTimeout');

        _verificationId = verificationId;

        _otpRequestWatchdog?.cancel();

        isSendingOtp.value = false;
      },
    );
  }

  // ============================================================
  // VERIFICATION FAILURE
  // ============================================================

  Future<void> _handleVerificationFailure({
    required FirebaseAuthException error,
  }) async {
    isSendingOtp.value = false;
    isVerifyingOtp.value = false;

    _otpRequestWatchdog?.cancel();

    AppSnackBar.show(
      _firebaseErrorTitle(error),
      _firebaseErrorMessage(error),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 7),
    );
  }

  // ============================================================
  // BACKEND LOGIN
  // ============================================================

  Future<void> _completeBackendLogin(User user) async {
    if (_loginInProgress) {
      return;
    }

    final verifiedPhone = _normalizeE164(user.phoneNumber ?? '');

    final expectedPhone = _normalizeE164(
      pendingPhone.value.isNotEmpty ? pendingPhone.value : fullPhone,
    );

    debugPrint('AuthController._completeBackendLogin:');

    debugPrint('verifiedPhone=$verifiedPhone');

    debugPrint('expectedPhone=$expectedPhone');

    if (verifiedPhone.isEmpty || verifiedPhone != expectedPhone) {
      throw AuthFlowException(
        'Verified phone does not match the entered number.',
      );
    }

    final firebaseIdToken = await user.getIdToken(true);

    if (firebaseIdToken == null || firebaseIdToken.trim().isEmpty) {
      throw AuthFlowException(
        'Firebase verification token was not received. Please try again.',
      );
    }

    _loginInProgress = true;

    try {
      final appUser = await _repository.loginVerifiedCustomer(
        phone: _localPhoneDigitsFromE164(expectedPhone),
        agreement: agreementChecked.value,
        firebaseIdToken: firebaseIdToken,
        firebaseUid: user.uid,
        phoneE164: expectedPhone,
      );

      await _storage.write('isLoggedIn', true);

      await _storage.write('currentUser', appUser.toJson());

      // ========================================================
      // CART
      // ========================================================

      if (Get.isRegistered<CartController>()) {
        await Get.find<CartController>().rebindToCurrentSession();
      }

      // ========================================================
      // SOCKET
      // ========================================================

      if (Get.isRegistered<CustomerSocketNotificationService>()) {
        Get.find<CustomerSocketNotificationService>().connectForCurrentUser();
      }

      // ========================================================
      // PUSH
      // ========================================================

      if (Get.isRegistered<PushNotificationService>()) {
        await Get.find<PushNotificationService>().registerCurrentToken();
      }

      // ========================================================
      // PROFILE
      // ========================================================

      if (Get.isRegistered<ProfileController>()) {
        await Get.find<ProfileController>().refreshForAuthenticatedSession();
      }

      resetOtpFlow();

      Get.offAllNamed(AppRoutes.dashboard);

      _scheduleAuthenticatedServiceAreaRecheck();
    } catch (error) {
      _loginInProgress = false;
      rethrow;
    }
  }

  // ============================================================
  // SERVICE AREA
  // ============================================================

  void _scheduleAuthenticatedServiceAreaRecheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<ServiceAreaGateController>()) {
        return;
      }

      final controller = Get.find<ServiceAreaGateController>();

      if (controller.preserveSelectedServiceableLocation()) {
        return;
      }

      unawaited(controller.ensureChecked(force: true));
    });
  }

  // ============================================================
  // FIREBASE READY
  // ============================================================

  bool _ensureFirebaseReady() {
    if (Firebase.apps.isNotEmpty) {
      return true;
    }

    AppSnackBar.show(
      'Firebase Not Ready',
      'Firebase.initializeApp() must complete before phone authentication.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 7),
    );

    return false;
  }

  // ============================================================
  // CLEAR FIREBASE USER
  // ============================================================

  Future<void> _clearFirebaseUser() async {
    try {
      if (_firebaseAuth.currentUser != null) {
        await _firebaseAuth.signOut();
      }
    } catch (error) {
      debugPrint('AuthController._clearFirebaseUser failed: $error');
    }
  }

  // ============================================================
  // PHONE NORMALIZATION
  // ============================================================

  String _normalizeE164(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return '';
    }

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

    if (digits.length <= phoneDigitLength) {
      return digits;
    }

    return digits.substring(digits.length - phoneDigitLength);
  }

  // ============================================================
  // FIREBASE ERROR TITLE
  // ============================================================

  String _firebaseErrorTitle(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-verification-code':
        return 'Wrong OTP';

      case 'session-expired':
        return 'OTP Expired';

      case 'invalid-phone-number':
        return 'Invalid Number';

      case 'too-many-requests':
        return 'Too Many Attempts';

      case 'quota-exceeded':
        return 'SMS Quota Exceeded';

      case 'captcha-check-failed':
        return 'Verification Failed';

      case 'app-not-authorized':
        return 'Firebase App Not Authorized';

      case 'operation-not-allowed':
        return 'Phone Auth Disabled';

      case 'network-request-failed':
        return 'Network Error';

      default:
        return 'Firebase Auth Error';
    }
  }

  // ============================================================
  // FIREBASE ERROR MESSAGE
  // ============================================================

  String _firebaseErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'The phone number is invalid. Check the country code and number.';

      case 'invalid-verification-code':
        return 'The OTP code is incorrect. For a Firebase test number, enter the fixed OTP configured in Firebase Console.';

      case 'session-expired':
        return 'The OTP session has expired. Request a new OTP.';

      case 'too-many-requests':
        return 'Too many authentication attempts. Use a Firebase test phone number while developing and try again later.';

      case 'quota-exceeded':
        return 'Firebase SMS quota has been exceeded. Use a Firebase test phone number for simulator testing.';

      case 'captcha-check-failed':
        return 'Firebase app verification failed. Check the iOS Firebase configuration and GoogleService-Info.plist.';

      case 'app-not-authorized':
        return 'This iOS app is not authorized in Firebase. Check the iOS bundle ID and GoogleService-Info.plist.';

      case 'operation-not-allowed':
        return 'Phone authentication is not enabled in Firebase Authentication.';

      case 'network-request-failed':
        return 'Check your internet connection and try again.';

      default:
        return error.message ??
            'Firebase verification failed. Please try again.';
    }
  }

  // ============================================================
  // LOG ERROR
  // ============================================================

  void _logFirebaseAuthError(String source, FirebaseAuthException error) {
    debugPrint(
      'FirebaseAuth[$source]: '
      'code=${error.code}, '
      'message=${error.message}',
    );
  }

  // ============================================================
  // RESEND TIMER
  // ============================================================

  void _startResendTimer() {
    _resendTimerTicker?.cancel();

    resendTimer.value = otpResendSeconds;

    _resendTimerTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendTimer.value <= 1) {
        resendTimer.value = 0;
        timer.cancel();
        return;
      }

      resendTimer.value--;
    });
  }

  // ============================================================
  // OTP WATCHDOG
  // ============================================================

  void _startOtpRequestWatchdog() {
    _otpRequestWatchdog?.cancel();

    _otpRequestWatchdog = Timer(const Duration(seconds: 30), () {
      if (!isSendingOtp.value || isOtpSent.value) {
        return;
      }

      isSendingOtp.value = false;

      AppSnackBar.show(
        'OTP Not Sent',
        'Firebase did not complete phone verification. Check your Firebase iOS configuration and test phone number.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 8),
      );
    });
  }

  // ============================================================
  // CLOSE
  // ============================================================

  @override
  void onClose() {
    _resendTimerTicker?.cancel();

    _otpRequestWatchdog?.cancel();

    phoneController.dispose();

    otpController.dispose();

    super.onClose();
  }
}

// ================================================================
// AUTH FLOW EXCEPTION
// ================================================================

class AuthFlowException implements Exception {
  final String message;

  AuthFlowException(this.message);

  @override
  String toString() {
    return message;
  }
}
