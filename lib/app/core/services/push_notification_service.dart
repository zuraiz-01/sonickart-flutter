import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../routes/app_routes.dart';
import '../constants/api_constants.dart';
import '../network/api_service.dart';
import 'firebase_bootstrap.dart';
import 'local_notification_service.dart';
import 'notification_service.dart';
import 'status_notification_copy.dart';

class PushNotificationService extends GetxService {
  PushNotificationService({GetStorage? storage})
    : _storage = storage ?? GetStorage();

  static const notificationsDisabledStorageKey = 'pushNotificationsDisabled';

  final GetStorage _storage;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<Map<String, dynamic>>? _localTapSub;
  bool _initialized = false;
  String? _lastRegisteredToken;
  final _recentRecords = <String, DateTime>{};

  Future<PushNotificationService> init() async {
    if (_initialized) return this;
    _initialized = true;

    try {
      await FirebaseBootstrap.initialize();

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint(
          'PushNotificationService: Notifications permission denied by user',
        );
      }

      await _setForegroundPresentationOptions();

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

      if (await areNotificationsEnabled()) {
        await registerCurrentToken();
      }
    } catch (error) {
      debugPrint('PushNotificationService.init skipped: $error');
    }
    return this;
  }

  Future<void> registerCurrentToken({String? token}) async {
    final accessToken = _storage.read<String>('accessToken');
    if (accessToken == null || accessToken.trim().isEmpty) return;
    if (!await areNotificationsEnabled()) return;

    try {
      final apnsToken = await _waitForApnsToken();
      final fcmToken = token ?? await FirebaseMessaging.instance.getToken();
      if (fcmToken == null || fcmToken.trim().isEmpty) return;
      if (_lastRegisteredToken == fcmToken) return;
      debugPrint(
        'PushNotificationService: FCM token fetched ${_describeToken(fcmToken)}',
      );

      final payload = <String, String>{
        'fcmToken': fcmToken,
        'fcm_token': fcmToken,
        'deviceToken': fcmToken,
        'device_token': fcmToken,
      };
      if (apnsToken != null) {
        payload['apnsToken'] = apnsToken;
        payload['apns_token'] = apnsToken;
      }

      await _api.patch(endpoint: ApiConstants.user, data: payload);
      _lastRegisteredToken = fcmToken;
      await _storage.write('fcmToken', fcmToken);
      debugPrint(
        'PushNotificationService: FCM token registered ${_describeToken(fcmToken)}',
      );
    } catch (error) {
      debugPrint('PushNotificationService.registerCurrentToken failed: $error');
    }
  }

  Future<bool> areNotificationsEnabled() async {
    if (_notificationsDisabledByUser) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return _isAllowed(settings.authorizationStatus);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return _isAllowed(settings.authorizationStatus);
    }
    return true;
  }

  Future<bool> enableNotifications() async {
    try {
      await FirebaseBootstrap.initialize();
      await _setForegroundPresentationOptions();
      await _storage.write(notificationsDisabledStorageKey, false);
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final allowed = _isAllowed(settings.authorizationStatus);
      if (!allowed) {
        await _storage.write(notificationsDisabledStorageKey, true);
        return false;
      }
      await registerCurrentToken();
      return true;
    } catch (error) {
      debugPrint('PushNotificationService.enableNotifications failed: $error');
      return false;
    }
  }

  Future<void> disableNotifications() async {
    await _storage.write(notificationsDisabledStorageKey, true);
    await clearTokenCache();
    final accessToken = _storage.read<String>('accessToken');
    if (accessToken == null || accessToken.trim().isEmpty) return;
    try {
      await _api.patch(
        endpoint: ApiConstants.user,
        data: const {
          'fcmToken': '',
          'fcm_token': '',
          'deviceToken': '',
          'device_token': '',
          'apnsToken': '',
          'apns_token': '',
        },
      );
    } catch (error) {
      debugPrint(
        'PushNotificationService.disableNotifications token clear failed: $error',
      );
    }
  }

  Future<void> clearTokenCache() async {
    _lastRegisteredToken = null;
    await _storage.remove('fcmToken');
  }

  bool get _notificationsDisabledByUser {
    return _storage.read<bool>(notificationsDisabledStorageKey) == true;
  }

  bool _isAllowed(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  Future<void> _setForegroundPresentationOptions() {
    return FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
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
    final isIosSystemNotification =
        defaultTargetPlatform == TargetPlatform.iOS &&
        message.notification != null;
    final status = _status(data);
    final trackingNumber = _trackingNumber(data, package: isPackage);
    final copy = status == null
        ? null
        : orderStatusNotificationCopy(
            status: status,
            orderNumber: trackingNumber,
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

    final dedupeKey = LocalNotificationService.statusDedupeKey(
      package: isPackage,
      status: status,
      trackingNumber: trackingNumber,
      title: title,
      body: body,
    );

    _recordInAppNotification(
      title: title ?? (isPackage ? 'Package update' : 'Order update'),
      body: body ?? 'You have a new ${isPackage ? 'package' : 'order'} update.',
      package: isPackage,
    );

    if (!isIosSystemNotification) {
      if (Get.isRegistered<LocalNotificationService>()) {
        Get.find<LocalNotificationService>().show(
          title: title ?? (isPackage ? 'Package update' : 'Order update'),
          body:
              body ??
              'You have a new ${isPackage ? 'package' : 'order'} update.',
          payload: _encodePayload(data, package: isPackage),
          notificationId: LocalNotificationService.notificationIdForDedupeKey(
            dedupeKey,
          ),
          dedupeKey: dedupeKey,
        );
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Get.isRegistered<LocalNotificationService>()) {
            Get.find<LocalNotificationService>().show(
              title: title ?? (isPackage ? 'Package update' : 'Order update'),
              body:
                  body ??
                  'You have a new ${isPackage ? 'package' : 'order'} update.',
              payload: _encodePayload(data, package: isPackage),
              notificationId:
                  LocalNotificationService.notificationIdForDedupeKey(
                    dedupeKey,
                  ),
              dedupeKey: dedupeKey,
            );
          }
        });
      }
    }
  }

  void _handleTap(RemoteMessage message) {
    _handleNotificationData(_notificationData(message.data));
  }

  void _handleLocalTap(Map<String, dynamic> data) {
    _handleNotificationData(_notificationData(data));
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final isPackage = _isPackagePayload(data);
    final title =
        _firstText(data, const [
          'title',
          'notificationTitle',
          'notification_title',
        ]) ??
        (isPackage ? 'Package update' : 'Order update');
    final body =
        _firstText(data, const [
          'body',
          'message',
          'notificationBody',
          'notification_body',
        ]) ??
        'You have a new ${isPackage ? 'package' : 'order'} update.';
    _recordInAppNotification(title: title, body: body, package: isPackage);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_routeWhenReady(data));
    });
  }

  Future<String?> _waitForApnsToken() async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return null;
    }

    for (var attempt = 0; attempt < 10; attempt += 1) {
      final token = await FirebaseMessaging.instance.getAPNSToken();
      if (token != null && token.trim().isNotEmpty) return token;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  void _recordInAppNotification({
    required String title,
    required String body,
    required bool package,
  }) {
    if (!Get.isRegistered<NotificationService>()) return;
    final now = DateTime.now();
    _recentRecords.removeWhere(
      (_, recordedAt) => now.difference(recordedAt).inMinutes >= 2,
    );
    final signature = '${package ? 'package' : 'order'}|$title|$body';
    if (_recentRecords.containsKey(signature)) return;
    _recentRecords[signature] = now;

    unawaited(
      Get.find<NotificationService>().record(
        title: title,
        message: body,
        category: package ? 'package' : 'order',
      ),
    );
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
