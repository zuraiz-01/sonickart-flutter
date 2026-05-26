import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../routes/app_routes.dart';
import '../constants/api_constants.dart';
import '../network/api_service.dart';
import 'firebase_bootstrap.dart';
import 'local_notification_service.dart';
import 'status_notification_copy.dart';

class PushNotificationService extends GetxService {
  PushNotificationService({GetStorage? storage})
    : _storage = storage ?? GetStorage();

  final GetStorage _storage;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<Map<String, dynamic>>? _localTapSub;
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

      _bindLocalNotificationTaps();
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
    final data = _notificationData(message.data);
    final isPackage = _isPackagePayload(data);
    final status = _status(data);
    final copy = status == null
        ? null
        : orderStatusNotificationCopy(
            status: status,
            orderNumber: _trackingNumber(data, package: isPackage),
            package: isPackage,
          );
    final title =
        message.notification?.title ??
        _firstText(data, [
          'title',
          'notificationTitle',
          'notification_title',
        ]) ??
        copy?.title;
    final body =
        message.notification?.body ??
        _firstText(data, [
          'body',
          'message',
          'notificationBody',
          'notification_body',
        ]) ??
        copy?.body;
    if (title == null && body == null) return;
    if (!Get.isRegistered<LocalNotificationService>()) return;

    Get.find<LocalNotificationService>().show(
      title: title ?? (isPackage ? 'Package update' : 'Order update'),
      body: body ?? 'You have a new ${isPackage ? 'package' : 'order'} update.',
      payload: _encodePayload(data, package: isPackage),
    );
  }

  void _handleTap(RemoteMessage message) {
    _handleNotificationData(_notificationData(message.data));
  }

  void _handleLocalTap(Map<String, dynamic> data) {
    _handleNotificationData(_notificationData(data));
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_routeWhenReady(data));
    });
  }

  Future<void> _routeWhenReady(Map<String, dynamic> data) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (Get.key.currentState == null) continue;
      if (Get.currentRoute == AppRoutes.splash) continue;
      _routeFromData(data);
      return;
    }

    _routeFromData(data);
  }

  void _routeFromData(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase();
    final isPackage = _isPackagePayload(data);
    final orderId = _trackingNumber(data, package: isPackage);

    if (isPackage || type == 'package') {
      Get.toNamed(
        AppRoutes.packageDetails,
        arguments: orderId.isEmpty ? null : {'orderId': orderId},
      );
      return;
    }

    if (type == 'order' || _status(data) != null || orderId.isNotEmpty) {
      Get.toNamed(
        AppRoutes.customerOrderDetails,
        arguments: orderId.isEmpty ? null : {'orderId': orderId},
      );
      return;
    }

    Get.toNamed(AppRoutes.notifications);
  }

  void _bindLocalNotificationTaps() {
    if (!Get.isRegistered<LocalNotificationService>()) return;
    final local = Get.find<LocalNotificationService>();
    _localTapSub?.cancel();
    _localTapSub = local.taps.listen(_handleLocalTap);
    final pending = local.takePendingLaunchData();
    if (pending != null) _handleLocalTap(pending);
  }

  Map<String, dynamic> _notificationData(Map<String, dynamic> data) {
    final merged = Map<String, dynamic>.from(data);
    for (final key in const [
      'data',
      'payload',
      'order',
      'package',
      'packageOrder',
    ]) {
      final child = _asMap(data[key]);
      if (child != null) merged.addAll(child);
    }
    return merged;
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? _firstText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _status(Map<String, dynamic> data) {
    return _firstText(data, const [
      'status',
      'deliveryStatus',
      'delivery_status',
      'orderStatus',
      'order_status',
      'packageStatus',
      'package_status',
    ]);
  }

  bool _isPackagePayload(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase();
    if (type?.contains('package') == true) return true;
    return const [
      'packageOrderId',
      'package_order_id',
      'packageId',
      'package_id',
      'packageStatus',
      'package_status',
    ].any((key) => data[key] != null);
  }

  String _trackingNumber(Map<String, dynamic> data, {required bool package}) {
    const packageKeys = [
      'packageOrderId',
      'package_order_id',
      'packageId',
      'package_id',
      'delivery_code',
    ];
    const orderKeys = [
      'orderNumber',
      'order_number',
      'orderId',
      'order_id',
      'id',
      '_id',
    ];
    return _firstText(
          data,
          package ? [...packageKeys, ...orderKeys] : orderKeys,
        ) ??
        '';
  }

  String _encodePayload(Map<String, dynamic> data, {required bool package}) {
    final payload = <String, String>{
      'type': package ? 'package' : 'order',
      for (final entry in data.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };
    return jsonEncode(payload);
  }

  @override
  void onClose() {
    _tokenRefreshSub?.cancel();
    _localTapSub?.cancel();
    super.onClose();
  }
}
