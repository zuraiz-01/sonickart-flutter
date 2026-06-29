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
  final _recentDedupeKeys = <String, DateTime>{};

  bool _initialized = false;
  String? _pendingLaunchPayload;

  Stream<Map<String, dynamic>> get taps => _tapController.stream;

  @pragma('vm:entry-point')
  static Future<void> showRemoteMessageFromBackground(
    RemoteMessage message,
  ) async {
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
        message.notification?.title ??
        copy?.title;
    final body =
        _firstMessageText(data, const [
          'body',
          'message',
          'notificationBody',
          'notification_body',
        ]) ??
        message.notification?.body ??
        copy?.body;
    if (title == null && body == null) return;

    try {
      DartPluginRegistrant.ensureInitialized();
      final plugin = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      );
      await plugin.initialize(settings: initSettings);

      final android = plugin
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

      final dedupeKey = statusDedupeKey(
        package: isPackage,
        status: status,
        trackingNumber: orderNumber,
        title: title,
        body: body,
      );
      final notificationId =
          (dedupeKey == null
              ? (orderNumber.isNotEmpty
                    ? notificationIdForDedupeKey(orderNumber)
                    : null)
              : notificationIdForDedupeKey(dedupeKey)) ??
          DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await plugin.show(
        id: notificationId,
        title: title ?? 'SonicKart',
        body: body ?? 'You have a new update.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            defaultChannelId,
            defaultChannelName,
            channelDescription: defaultChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_stat_sonickart_notification',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: _encodePayload(data, package: isPackage),
      );
    } catch (error) {
      debugPrint(
        'LocalNotificationService.showRemoteMessageFromBackground failed: $error',
      );
    }
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
    String? dedupeKey,
    Duration dedupeWindow = const Duration(minutes: 2),
  }) async {
    final normalizedTitle = title.trim().isEmpty ? 'SonicKart' : title.trim();
    final normalizedBody = body.trim().isEmpty
        ? 'You have a new update.'
        : body.trim();
    final effectiveDedupeKey =
        dedupeKey ??
        [
          channelId,
          normalizedTitle,
          normalizedBody,
        ].map((value) => value.trim().toLowerCase()).join('|');
    if (_shouldSuppressDuplicate(effectiveDedupeKey, dedupeWindow)) return;

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
      icon: '@drawable/ic_stat_sonickart_notification',
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
            notificationIdForDedupeKey(effectiveDedupeKey) ??
            DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: normalizedTitle,
        body: normalizedBody,
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

  static String? statusDedupeKey({
    required bool package,
    String? status,
    String? trackingNumber,
    Iterable<String?> identifiers = const [],
    String? title,
    String? body,
  }) {
    final normalizedStatus =
        _canonicalStatus(status) ?? _statusFromText([title, body]);
    if (normalizedStatus == null || normalizedStatus.isEmpty) return null;

    final normalizedTracking = _canonicalTrackingId([
      trackingNumber,
      ...identifiers,
    ]);
    final inferredTracking =
        normalizedTracking ?? _trackingIdFromText([title, body]);
    if (inferredTracking == null || inferredTracking.isEmpty) return null;

    return '${package ? 'package' : 'order'}|$normalizedStatus|$inferredTracking';
  }

  static int? notificationIdForDedupeKey(String? key) {
    final normalized = key?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;

    var hash = 0;
    for (final codeUnit in normalized.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return 100000 + hash.remainder(900000);
  }

  bool _shouldSuppressDuplicate(String? key, Duration window) {
    final normalized = key?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty || window <= Duration.zero) {
      return false;
    }

    final now = DateTime.now();
    _recentDedupeKeys.removeWhere(
      (_, recordedAt) => now.difference(recordedAt) >= window,
    );
    final previous = _recentDedupeKeys[normalized];
    if (previous != null && now.difference(previous) < window) {
      return true;
    }
    _recentDedupeKeys[normalized] = now;
    return false;
  }

  static String? _canonicalStatus(String? value) {
    final raw = value?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return switch (normalized) {
      'placed' ||
      'pending' ||
      'assigned' ||
      'confirmed' ||
      'available' => 'placed',
      'accept' || 'accepted' => 'accepted',
      'pickup' || 'picked' || 'pickedup' || 'picked_up' => 'picked_up',
      'intransit' ||
      'in_transit' ||
      'on_the_way' ||
      'out_for_delivery' => 'in_transit',
      'delivered' || 'complete' || 'completed' => 'delivered',
      _ => normalized,
    };
  }

  static String? _statusFromText(Iterable<String?> values) {
    final text = values
        .whereType<String>()
        .join(' ')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    if (text.trim().isEmpty) return null;
    if (text.contains('accept')) {
      return 'accepted';
    }
    if (text.contains('placed') ||
        text.contains('assigned') ||
        text.contains('confirmed')) {
      return 'placed';
    }
    if (text.contains('picked up') || text.contains('pickup')) {
      return 'picked_up';
    }
    if (text.contains('in transit') ||
        text.contains('on the way') ||
        text.contains('out for delivery')) {
      return 'in_transit';
    }
    if (text.contains('delivered') || text.contains('completed')) {
      return 'delivered';
    }
    return null;
  }

  static String? _canonicalTrackingId(Iterable<String?> values) {
    for (final value in values) {
      final raw = value?.trim();
      if (raw == null || raw.isEmpty) continue;
      final alphaNumeric = raw.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        '',
      );
      if (alphaNumeric.isEmpty) continue;

      final digitMatches = RegExp(r'\d+').allMatches(alphaNumeric).toList();
      if (digitMatches.isNotEmpty) {
        final digits = digitMatches.last.group(0);
        if (digits != null && digits.length >= 3) {
          final trimmed = digits.replaceFirst(RegExp(r'^0+'), '');
          return trimmed.isEmpty ? '0' : trimmed;
        }
      }

      return alphaNumeric;
    }
    return null;
  }

  static String? _trackingIdFromText(Iterable<String?> values) {
    for (final value in values) {
      final raw = value?.trim();
      if (raw == null || raw.isEmpty) continue;
      final match = RegExp(r'#?[a-zA-Z]*\d{3,}').firstMatch(raw);
      final matched = match?.group(0);
      if (matched == null || matched.isEmpty) continue;
      final canonical = _canonicalTrackingId([matched]);
      if (canonical != null && canonical.isNotEmpty) return canonical;
    }
    return null;
  }

  @override
  void onClose() {
    _tapController.close();
    super.onClose();
  }
}
