import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  AuthRepository(this._apiService, {GetStorage? storage})
    : _storage = storage ?? GetStorage();

  final ApiService _apiService;
  final GetStorage _storage;

  Future<UserModel> loginVerifiedCustomer({
    required String phone,
    required bool agreement,
    required String firebaseIdToken,
    required String firebaseUid,
    required String phoneE164,
  }) async {
    debugPrint('AuthRepository.loginVerifiedCustomer: phone=$phone');
    try {
      final response = await _postCustomerLogin(
        data: {'phone': phone, 'agreement': agreement},
      );
      return _persistCustomerSession(response);
    } on ApiException catch (error) {
      if (!_shouldRetryWithFirebaseProof(error)) {
        throw AuthFlowException(
          error.message.isNotEmpty
              ? error.message
              : 'Login session start nahi ho saki. Dobara try karo.',
        );
      }

      try {
        final response = await _postCustomerLogin(
          data: {
            'phone': phoneE164,
            'agreement': agreement,
            'firebaseIdToken': firebaseIdToken,
            'firebaseUid': firebaseUid,
          },
          headers: {
            'Authorization': 'Bearer $firebaseIdToken',
            'x-firebase-token': firebaseIdToken,
          },
        );
        return _persistCustomerSession(response);
      } on ApiException catch (fallbackError) {
        throw AuthFlowException(
          fallbackError.message.isNotEmpty
              ? fallbackError.message
              : 'Login session start nahi ho saki. Dobara try karo.',
        );
      }
    } on AuthFlowException {
      rethrow;
    } catch (error) {
      debugPrint('AuthRepository.loginVerifiedCustomer failed: $error');
      throw AuthFlowException(
        'Backend se login complete nahi ho saka. Dobara try karo.',
      );
    }
  }

  Future<void> logout() async {
    await _storage.remove('accessToken');
    await _storage.remove('refreshToken');
  }

  Future<Map<String, dynamic>> _postCustomerLogin({
    required Map<String, dynamic> data,
    Map<String, String>? headers,
  }) {
    return _apiService.post(
      endpoint: ApiConstants.customerLogin,
      data: data,
      authenticated: false,
      headers: headers,
    );
  }

  Future<UserModel> _persistCustomerSession(
    Map<String, dynamic> response,
  ) async {
    final token = _findString(response, const [
      'accessToken',
      'token',
      'access_token',
    ]);
    final refresh = _findString(response, const [
      'refreshToken',
      'refresh_token',
    ]);
    if (token == null || token.trim().isEmpty) {
      throw AuthFlowException(
        'Login session start nahi ho saki. Dobara try karo.',
      );
    }
    await _storage.write('accessToken', token);
    if (refresh != null && refresh.trim().isNotEmpty) {
      await _storage.write('refreshToken', refresh);
    }
    final userJson =
        _findMap(response, const ['customer', 'user']) ??
        _findMap(response, const ['data']) ??
        response;
    final user = UserModel.fromJson(userJson);
    if (user.phone.isEmpty && user.id.isEmpty) {
      throw AuthFlowException(
        'User profile load nahi ho saka. Dobara try karo.',
      );
    }
    return user;
  }

  bool _shouldRetryWithFirebaseProof(ApiException error) {
    final message = error.message.toLowerCase();
    if (error.statusCode == 400 ||
        error.statusCode == 401 ||
        error.statusCode == 403) {
      return true;
    }
    return message.contains('invalid otp') ||
        message.contains('otp') ||
        message.contains('verification') ||
        message.contains('phone auth');
  }

  String? _findString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().isNotEmpty) return value.toString();
    }
    for (final value in map.values) {
      if (value is Map) {
        final nested = _findString(Map<String, dynamic>.from(value), keys);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  Map<String, dynamic>? _findMap(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    for (final value in map.values) {
      if (value is Map) {
        final nested = _findMap(Map<String, dynamic>.from(value), keys);
        if (nested != null) return nested;
      }
    }
    return null;
  }
}

class AuthFlowException implements Exception {
  AuthFlowException(this.message);

  final String message;

  @override
  String toString() => 'AuthFlowException: $message';
}
