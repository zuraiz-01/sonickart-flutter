import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import 'status_notification_copy.dart';

class LocalNotificationService extends GetxService {
  static const defaultChannelId = 'sonickart_order_updates';
  static const defaultChannelName = 'Order updates';
  static const defaultChannelDescription =
      'Order and package status notifications';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final _tapController = StreamController<Map<String, dynamic>>.broadcast();

  bool _initialized = false;
  String? _pendingLaunchPayload;

  Stream<Map<String, dynamic>> get taps => _tapController.stream;

  @pragma('vm:entry-point')
  static Future<void> showRemoteMessageFromBackground(
    RemoteMessage message,
  ) async {
    if (message.notification != null) return;

    final data = _notificationData(message.data);
    final isPackage = _isPackagePayload(data);
    final status = _status(data);
    final orderNumber = _trackingNumber(data, package: isPackage);
    final copy = status == null
        ? null
        : orderStatusNotificationCopy(
            status: status,
            orderNumber: orderNumber,
            package: isPackage,
          );
    final title =
        _firstMessageText(data, const [
          'title',
          'notificationTitle',
          'notification_title',
        ]) ??
        copy?.title;
    final body =
        _firstMessageText(data, const [
          'body',
          'message',
          'notificationBody',
          'notification_body',
        ]) ??
        copy?.body;
    if (title == null && body == null) return;

    DartPluginRegistrant.ensureInitialized();
    final service = LocalNotificationService();
    await service.init();
    final notificationId = orderNumber.isNotEmpty
        ? orderNumber.hashCode.abs().remainder(100000)
        : DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await service.show(
      title: title ?? 'SonicKart',
      body: body ?? 'You have a new update.',
      payload: _encodePayload(data, package: isPackage),
      notificationId: notificationId,
    );
  }

  Future<LocalNotificationService> init() async {
    if (_initialized) return this;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _handleTap,
      );
      await _createAndroidChannel();
      await _requestAndroidPermission();
      _initialized = true;
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      final payload = launchDetails?.notificationResponse?.payload;
      if (launchDetails?.didNotificationLaunchApp == true &&
          payload != null &&
          payload.isNotEmpty) {
        _pendingLaunchPayload = payload;
      }
    } catch (error) {
      debugPrint('LocalNotificationService.init failed: $error');
    }

    return this;
  }

  Map<String, dynamic>? takePendingLaunchData() {
    final payload = _pendingLaunchPayload;
    _pendingLaunchPayload = null;
    return _payloadMap(payload);
  }

  Future<void> show({
    required String title,
    required String body,
    String channelId = defaultChannelId,
    String channelName = defaultChannelName,
    String channelDescription = defaultChannelDescription,
    String? payload,
    int? notificationId,
  }) async {
    if (!_initialized) {
      await init();
    }

    const importance = Importance.high;
    const priority = Priority.high;
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    try {
      await _plugin.show(
        id:
            notificationId ??
            DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title.trim().isEmpty ? 'SonicKart' : title.trim(),
        body: body.trim().isEmpty ? 'You have a new update.' : body.trim(),
        notificationDetails: details,
        payload: payload,
      );
    } catch (error) {
      debugPrint('LocalNotificationService.show failed: $error');
    }
  }

  Future<void> _createAndroidChannel() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        defaultChannelId,
        defaultChannelName,
        description: defaultChannelDescription,
        importance: Importance.high,
      ),
    );
  }

  Future<void> _requestAndroidPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
  }

  void _handleTap(NotificationResponse response) {
    final payload = _payloadMap(response.payload);
    if (payload == null) return;
    _tapController.add(payload);
  }

  static String? _firstMessageText(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static Map<String, dynamic> _notificationData(Map<String, dynamic> data) {
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

  static Map<String, dynamic>? _asMap(Object? value) {
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

  static String? _status(Map<String, dynamic> data) {
    return _firstMessageText(data, const [
      'status',
      'deliveryStatus',
      'delivery_status',
      'orderStatus',
      'order_status',
      'packageStatus',
      'package_status',
    ]);
  }

  static bool _isPackagePayload(Map<String, dynamic> data) {
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

  static String _trackingNumber(
    Map<String, dynamic> data, {
    required bool package,
  }) {
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
    return _firstMessageText(
          data,
          package ? [...packageKeys, ...orderKeys] : orderKeys,
        ) ??
        '';
  }

  static String _encodePayload(
    Map<String, dynamic> data, {
    required bool package,
  }) {
    final payload = <String, String>{
      'type': package ? 'package' : 'order',
      for (final entry in data.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };
    return jsonEncode(payload);
  }

  static Map<String, dynamic>? _payloadMap(String? payload) {
    final raw = payload?.trim();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return {'type': raw};
    }
    return null;
  }

  @override
  void onClose() {
    _tapController.close();
    super.onClose();
  }
}
