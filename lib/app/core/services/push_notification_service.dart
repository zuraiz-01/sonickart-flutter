import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../routes/app_routes.dart';
import '../constants/api_constants.dart';
import '../network/api_service.dart';
import 'firebase_bootstrap.dart';
import 'local_notification_service.dart';

class PushNotificationService extends GetxService {
  PushNotificationService({GetStorage? storage})
    : _storage = storage ?? GetStorage();

  final GetStorage _storage;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;
  String? _lastRegisteredToken;

  Future<PushNotificationService> init() async {
    if (_initialized) return this;
    _initialized = true;

    try {
      await FirebaseBootstrap.initialize();
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => unawaited(registerCurrentToken(token: token)),
      );

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleTap(initialMessage);
      }

      await registerCurrentToken();
    } catch (error) {
      debugPrint('PushNotificationService.init skipped: $error');
    }
    return this;
  }

  Future<void> registerCurrentToken({String? token}) async {
    final accessToken = _storage.read<String>('accessToken');
    if (accessToken == null || accessToken.trim().isEmpty) return;

    try {
      final fcmToken = token ?? await FirebaseMessaging.instance.getToken();
      if (fcmToken == null || fcmToken.trim().isEmpty) return;
      if (_lastRegisteredToken == fcmToken) return;
      debugPrint(
        'PushNotificationService: FCM token fetched ${_describeToken(fcmToken)}',
      );

      await _api.patch(
        endpoint: ApiConstants.user,
        data: {
          'fcmToken': fcmToken,
          'fcm_token': fcmToken,
          'deviceToken': fcmToken,
          'device_token': fcmToken,
        },
      );
      _lastRegisteredToken = fcmToken;
      await _storage.write('fcmToken', fcmToken);
      debugPrint(
        'PushNotificationService: FCM token registered ${_describeToken(fcmToken)}',
      );
    } catch (error) {
      debugPrint('PushNotificationService.registerCurrentToken failed: $error');
    }
  }

  Future<void> clearTokenCache() async {
    _lastRegisteredToken = null;
    await _storage.remove('fcmToken');
  }

  ApiService get _api {
    if (Get.isRegistered<ApiService>()) return Get.find<ApiService>();
    return ApiService(storage: _storage);
  }

  String _describeToken(String token) {
    final trimmed = token.trim();
    if (trimmed.length <= 12) return 'length=${trimmed.length}';
    return 'length=${trimmed.length} prefix=${trimmed.substring(0, 6)}...suffix=${trimmed.substring(trimmed.length - 6)}';
  }

  void _showForegroundNotification(RemoteMessage message) {
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    if (title == null || body == null) return;
    if (!Get.isRegistered<LocalNotificationService>()) return;

    Get.find<LocalNotificationService>().show(title: title, body: body);
  }

  void _handleTap(RemoteMessage message) {
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      _routeFromMessage(message);
    });
  }

  void _routeFromMessage(RemoteMessage message) {
    final type = message.data['type']?.toString().toLowerCase();
    final orderId = message.data['orderId']?.toString();

    if (type == 'package') {
      Get.toNamed(
        AppRoutes.packageDetails,
        arguments: orderId == null || orderId.isEmpty
            ? null
            : {'orderId': orderId},
      );
      return;
    }

    if (type == 'order') {
      Get.toNamed(
        AppRoutes.customerOrderDetails,
        arguments: orderId == null || orderId.isEmpty
            ? null
            : {'orderId': orderId},
      );
      return;
    }

    Get.toNamed(AppRoutes.notifications);
  }

  @override
  void onClose() {
    _tokenRefreshSub?.cancel();
    super.onClose();
  }
}
