import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package_notification_policy.dart';
import 'notification_service.dart';
import 'status_notification_copy.dart';

class LocalNotificationService extends GetxService {
  static const defaultChannelId = 'sonickart_order_updates';
  static const defaultChannelName = 'Order updates';
  static const defaultChannelDescription =
      'Order and package status notifications';
  static const backgroundDedupeStorageKey =
      '_background_notification_dedupe_keys';
  static const statusEventDedupeWindow = Duration(days: 14);
  static const _maxBackgroundDedupeEntries = 250;

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
    if (!shouldDisplayRemoteMessageFromBackground(message)) return;

    final data = _notificationData(message.data);
    final isPackage = _isPackagePayload(data);
    final status = _status(data);
    final orderNumber = _trackingNumber(data, package: isPackage);
    final recipientId = _recipientId(data);
    final copy = status == null
        ? null
        : orderStatusNotificationCopy(
            status: status,
            orderNumber: orderNumber,
            package: isPackage,
          );
    final title =
        copy?.title ??
        _firstMessageText(data, const [
          'title',
          'notificationTitle',
          'notification_title',
        ]) ??
        message.notification?.title;
    final body =
        copy?.body ??
        _firstMessageText(data, const [
          'body',
          'message',
          'notificationBody',
          'notification_body',
        ]) ??
        message.notification?.body;
    if (shouldSuppressOrderStatusNotification(
      package: isPackage,
      status: status,
      text: [title, body],
    )) {
      return;
    }
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
        recipientId: recipientId,
        title: title,
        body: body,
      );
      if (dedupeKey != null && !await claimBackgroundDedupeKey(dedupeKey)) {
        return;
      }
      await NotificationService.recordStored(
        storage: GetStorage(),
        title: title ?? 'SonicKart',
        message: body ?? 'You have a new update.',
        category: isPackage ? 'package' : 'order',
        dedupeKey: dedupeKey,
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

  @pragma('vm:entry-point')
  static Future<void> recordRemoteMessageFromBackground(
    RemoteMessage message,
  ) async {
    final data = _notificationData(message.data);
    final isPackage = _isPackagePayload(data);
    if (!_recipientAllowed(data, package: isPackage)) return;

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
        copy?.title ??
        _firstMessageText(data, const [
          'title',
          'notificationTitle',
          'notification_title',
        ]) ??
        message.notification?.title;
    final body =
        copy?.body ??
        _firstMessageText(data, const [
          'body',
          'message',
          'notificationBody',
          'notification_body',
        ]) ??
        message.notification?.body;
    if (shouldSuppressOrderStatusNotification(
      package: isPackage,
      status: status,
      text: [title, body],
    )) {
      return;
    }
    if (title == null && body == null) return;

    final dedupeKey = statusDedupeKey(
      package: isPackage,
      status: status,
      trackingNumber: trackingNumber,
      recipientId: _recipientId(data),
      title: title,
      body: body,
    );
    await NotificationService.recordStored(
      storage: GetStorage(),
      title: title ?? 'SonicKart',
      message: body ?? 'You have a new update.',
      category: isPackage ? 'package' : 'order',
      dedupeKey: dedupeKey,
    );
  }

  static bool shouldDisplayRemoteMessageFromBackground(
    RemoteMessage message, {
    GetStorage? storage,
  }) {
    if (message.notification != null) return false;
    final data = _notificationData(message.data);
    if (_systemNotificationOwnsDisplay(data)) return false;
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
        copy?.title ??
        _firstMessageText(data, const [
          'title',
          'notificationTitle',
          'notification_title',
        ]);
    final body =
        copy?.body ??
        _firstMessageText(data, const [
          'body',
          'message',
          'notificationBody',
          'notification_body',
        ]);
    if (shouldSuppressOrderStatusNotification(
      package: isPackage,
      status: status,
      text: [title, body],
    )) {
      return false;
    }
    if (title == null && body == null) return false;
    return _recipientAllowed(data, package: isPackage, storage: storage);
  }

  @visibleForTesting
  static Future<bool> claimBackgroundDedupeKey(
    String dedupeKey, {
    GetStorage? storage,
    DateTime? now,
    Duration dedupeWindow = statusEventDedupeWindow,
  }) async {
    final normalizedKey = dedupeKey.trim().toLowerCase();
    if (normalizedKey.isEmpty) return true;

    final box = storage ?? GetStorage();
    final currentTime = (now ?? DateTime.now()).toUtc();
    final cutoff = currentTime.subtract(dedupeWindow).millisecondsSinceEpoch;
    final recent = <String, int>{};
    final stored = box.read(backgroundDedupeStorageKey);
    if (stored is Map) {
      for (final entry in stored.entries) {
        final timestamp = int.tryParse(entry.value.toString());
        if (timestamp != null && timestamp >= cutoff) {
          recent[entry.key.toString()] = timestamp;
        }
      }
    }

    if (recent.containsKey(normalizedKey)) return false;
    recent[normalizedKey] = currentTime.millisecondsSinceEpoch;

    final boundedEntries = recent.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    await box.write(
      backgroundDedupeStorageKey,
      Map<String, int>.fromEntries(
        boundedEntries.take(_maxBackgroundDedupeEntries),
      ),
    );
    return true;
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
    final persistedDedupeWindow = _isStatusDedupeKey(effectiveDedupeKey)
        ? statusEventDedupeWindow
        : dedupeWindow;
    if (dedupeKey != null &&
        !await claimBackgroundDedupeKey(
          effectiveDedupeKey,
          dedupeWindow: persistedDedupeWindow,
        )) {
      return;
    }

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

  static bool _systemNotificationOwnsDisplay(Map<String, dynamic> data) {
    final owner = _firstMessageText(data, const [
      'notificationDisplayOwner',
      'displayOwner',
      'visualDisplayOwner',
      'display_owner',
      'visual_display_owner',
    ])?.toLowerCase();
    if (const {'system', 'fcm', 'firebase', 'remote', 'os'}.contains(owner)) {
      return true;
    }

    return _boolFlag(data, const [
      'systemNotification',
      'system_notification',
      'fcmNotificationPayload',
      'fcm_notification_payload',
      'hasNotificationPayload',
      'has_notification_payload',
      'notificationPayload',
      'notification_payload',
    ]);
  }

  static bool _boolFlag(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is bool) return value;
      final text = value?.toString().trim().toLowerCase();
      if (text == null || text.isEmpty) continue;
      if (const {'true', '1', 'yes', 'y'}.contains(text)) return true;
    }
    return false;
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
    final status = _status(data);
    final trackingNumber = _trackingNumber(data, package: package);
    final recipientId = _recipientId(data);
    final payload = <String, String>{
      'type': package ? 'package' : 'order',
      if (trackingNumber.isNotEmpty)
        (package ? 'packageOrderId' : 'orderId'): trackingNumber,
      if (status?.trim().isNotEmpty == true) 'status': status!.trim(),
      if (recipientId.isNotEmpty) 'recipientUserId': recipientId,
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
    String? recipientId,
    Iterable<String?> recipientIdentifiers = const [],
    String? title,
    String? body,
  }) {
    final normalizedStatus =
        _canonicalStatus(status, package: package) ??
        _statusFromText([title, body], package: package);
    if (normalizedStatus == null || normalizedStatus.isEmpty) return null;

    final normalizedTracking = _canonicalTrackingId([
      trackingNumber,
      ...identifiers,
    ]);
    final inferredTracking =
        normalizedTracking ?? _trackingIdFromText([title, body]);
    if (inferredTracking == null || inferredTracking.isEmpty) return null;

    final normalizedRecipient = _canonicalRecipientId([
      recipientId,
      ...recipientIdentifiers,
    ]);
    return [
      package ? 'package' : 'order',
      normalizedStatus,
      inferredTracking,
      if (normalizedRecipient != null && normalizedRecipient.isNotEmpty)
        normalizedRecipient,
    ].join('|');
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

  static String? _canonicalStatus(String? value, {required bool package}) {
    final raw = value?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final compact = normalized.replaceAll('_', '');
    return switch (normalized) {
      'placed' || 'pending' || 'booked' => package ? 'booked' : 'placed',
      'assigned' ||
      'confirmed' ||
      'accept' ||
      'accepted' ||
      'on_the_way_to_pickup' ||
      'partner_assigned' ||
      'delivery_assigned' ||
      'delivery_partner_assigned' ||
      'assigned_to_partner' ||
      'rider_assigned' ||
      'driver_assigned' => 'assigned',
      'pickup' || 'picked' || 'pickedup' || 'picked_up' => 'picked_up',
      'intransit' ||
      'in_transit' ||
      'on_the_way' ||
      'on_the_way_to_delivery' ||
      'out_for_delivery' => 'picked_up',
      'delivered' || 'complete' || 'completed' => 'delivered',
      _
          when compact == 'orderplaced' ||
              compact == 'packagebooked' ||
              compact == 'packageplaced' ||
              compact == 'waitingpickup' ||
              compact == 'waitingforpickup' ||
              compact == 'orderwaitingforpickup' ||
              compact == 'packagewaitingforpickup' =>
        package ? 'booked' : 'placed',
      _
          when compact == 'orderaccepted' ||
              compact == 'packageaccepted' ||
              compact == 'orderassigned' ||
              compact == 'packageassigned' ||
              compact == 'partnerassigned' ||
              compact == 'deliveryassigned' ||
              compact == 'deliverypartnerassigned' ||
              compact == 'assignedtopartner' ||
              compact == 'onthewaytopickup' ||
              compact == 'orderonthewaytopickup' ||
              compact == 'packageonthewaytopickup' ||
              compact == 'riderassigned' ||
              compact == 'driverassigned' =>
        'assigned',
      _
          when compact == 'orderpickedup' ||
              compact == 'packagepickedup' ||
              compact == 'orderpickup' ||
              compact == 'packagepickup' ||
              compact == 'orderintransit' ||
              compact == 'packageintransit' ||
              compact == 'orderontheway' ||
              compact == 'packageontheway' ||
              compact == 'onthewaytodelivery' ||
              compact == 'orderonthewaytodelivery' ||
              compact == 'packageonthewaytodelivery' ||
              compact == 'orderoutfordelivery' ||
              compact == 'packageoutfordelivery' ||
              compact == 'arriving' ||
              compact == 'orderarriving' ||
              compact == 'packagearriving' =>
        'picked_up',
      _
          when compact == 'orderdelivered' ||
              compact == 'packagedelivered' ||
              compact == 'ordercompleted' ||
              compact == 'packagecompleted' =>
        'delivered',
      _ => normalized,
    };
  }

  static String? _statusFromText(
    Iterable<String?> values, {
    required bool package,
  }) {
    final text = values
        .whereType<String>()
        .join(' ')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    if (text.trim().isEmpty) return null;
    if (text.contains('delivered') || text.contains('completed')) {
      return 'delivered';
    }
    if (text.contains('accept') ||
        text.contains('confirmed') ||
        text.contains('assigned')) {
      return 'assigned';
    }
    if (text.contains('placed') ||
        text.contains('pending') ||
        text.contains('booked')) {
      return package ? 'booked' : 'placed';
    }
    if (text.contains('picked up') || text.contains('pickup')) {
      return 'picked_up';
    }
    if (text.contains('in transit') ||
        text.contains('on the way') ||
        text.contains('out for delivery')) {
      return 'picked_up';
    }
    return null;
  }

  static String? _canonicalTrackingId(Iterable<String?> values) {
    String? fallback;
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

      fallback ??= alphaNumeric;
    }
    return fallback;
  }

  bool _isStatusDedupeKey(String key) {
    final normalized = key.trim().toLowerCase();
    return normalized.startsWith('order|') || normalized.startsWith('package|');
  }

  static String _recipientId(Map<String, dynamic> data) {
    return _firstMessageText(data, const [
          'recipientUserId',
          'recipient_user_id',
          'recipientId',
          'recipient_id',
          'targetUserId',
          'target_user_id',
          'customerId',
          'customer_id',
          'userId',
          'user_id',
        ]) ??
        '';
  }

  static bool _recipientAllowed(
    Map<String, dynamic> data, {
    required bool package,
    GetStorage? storage,
  }) {
    final box = storage ?? GetStorage();
    if (box.read('isLoggedIn') != true ||
        (box.read<String>('accessToken')?.trim().isEmpty ?? true)) {
      return false;
    }
    final rawUser = box.read('currentUser');
    if (rawUser is! Map) return false;
    final user = Map<String, dynamic>.from(rawUser);
    final match = packageRecipientMatch(
      data: data,
      currentUserId:
          (user['id'] ?? user['_id'] ?? user['userId'])?.toString() ?? '',
      currentUserPhone:
          (user['phone'] ?? user['phoneNumber'] ?? user['mobile'])
              ?.toString() ??
          '',
    );
    if (match == PackageRecipientMatch.matched) return true;
    if (match == PackageRecipientMatch.mismatched) return false;
    if (!package) return true;

    final storedOrders =
        box.read<List<dynamic>>(storedPackageOrdersKey) ?? const <dynamic>[];
    return packageNotificationBelongsToKnownOrder(
      data: data,
      storedOrders: storedOrders,
    );
  }

  static String? _canonicalRecipientId(Iterable<String?> values) {
    for (final value in values) {
      final raw = value?.trim().toLowerCase();
      if (raw == null || raw.isEmpty) continue;
      final normalized = raw.replaceAll(RegExp(r'[^a-z0-9@._+-]+'), '');
      if (normalized.isNotEmpty) return normalized;
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
