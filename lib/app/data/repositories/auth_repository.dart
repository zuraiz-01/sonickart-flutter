import 'package:flutter/foundation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  AuthRepository(this._apiService);

  final ApiService _apiService;

  Future<void> sendOtp({required String phone}) async {
    debugPrint('=================================');
    debugPrint('AuthRepository.sendOtp: request started');
    debugPrint('URL -> ${ApiConstants.login}');
    debugPrint('Payload -> {phone: $phone}');
    await _apiService.post(
      endpoint: ApiConstants.login,
      data: {
        'phone': phone,
      },
    );
    debugPrint('AuthRepository.sendOtp: response received');
  }

  UserModel buildPendingUser({required String phone}) {
    final localPhone = phone.replaceFirst('+91', '');
    return UserModel(
      id: 'usr-$localPhone',
      name: 'SonicKart Customer',
      email: 'customer$localPhone@sonickart.app',
      phone: phone,
    );
  }

  Future<UserModel?> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    debugPrint('=================================');
    debugPrint('AuthRepository.verifyOtp: request started');
    debugPrint('URL -> ${ApiConstants.verifyOtp}');
    debugPrint('Payload -> {phone: $phone, otp: $otp}');
    await _apiService.post(
      endpoint: ApiConstants.verifyOtp,
      data: {
        'phone': phone,
        'otp': otp,
      },
    );

    debugPrint('AuthRepository.verifyOtp: response received');
    debugPrint('AuthRepository.verifyOtp: OTP match result = ${otp == '123456'}');

    if (otp != '123456') {
      return null;
    }

    return buildPendingUser(phone: phone);
  }
}
