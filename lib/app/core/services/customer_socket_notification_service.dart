import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../modules/auth/controllers/auth_controller.dart';
import '../../modules/order_controller.dart';
import '../../modules/package/controllers/package_controller.dart';
import '../constants/api_constants.dart';
import 'local_notification_service.dart';
import 'notification_service.dart';
import 'package_notification_policy.dart';
import 'status_notification_copy.dart';

class CustomerSocketNotificationService extends GetxService {
  CustomerSocketNotificationService({
    GetStorage? storage,
    bool Function()? isAppForeground,
  }) : _storage = storage ?? GetStorage(),
       _isAppForeground = isAppForeground;

  final GetStorage _storage;
  final bool Function()? _isAppForeground;
  io.Socket? _socket;
  String? _joinedUserId;

  Future<CustomerSocketNotificationService> init() async {
    connectForCurrentUser();
    return this;
  }

  void connectForCurrentUser() {
    final user = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().currentUser
        : null;
    final userId = user?.id.trim() ?? '';
    if (userId.isEmpty) {
      disconnect();
      return;
    }

    if (_socket != null && _joinedUserId == userId) return;

    disconnect();
    _joinedUserId = userId;
    final socket = io.io(
      ApiConstants.socketHost,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;

    socket
      ..onConnect((_) {
        debugPrint(
          'CustomerSocketNotificationService: connected for current user',
        );
        socket.emit('joinRoom', 'user-$userId');
        socket.emit('join_room', 'user-$userId');
      })
      ..onConnectError((error) {
        debugPrint('CustomerSocketNotificationService connect error: $error');
      })
      ..onError((error) {
        debugPrint('CustomerSocketNotificationService socket error: $error');
      })
      ..onReconnect((_) {
        debugPrint(
          'CustomerSocketNotificationService: reconnected for current user',
        );
        socket.emit('joinRoom', 'user-$userId');
        socket.emit('join_room', 'user-$userId');
      });

    for (final event in const [
      'liveTrackingUpdates',
      'order_status_update',
      'delivery_order_status_update',
      'packageOrderStatusUpdated',
      'packageOrderUpdated',
      'new_notification',
    ]) {
      socket.on(
        event,
        (payload) => unawaited(handleStatusNotificationPayload(payload)),
      );
    }

    socket.connect();
  }

  @visibleForTesting
  Future<bool> handleStatusNotificationPayload(Object? payload) async {
    final map = _notificationData(_asMap(payload));
    if (map == null) return false;
    final status = _firstText(map, [
      'status',
      'deliveryStatus',
      'delivery_status',
      'orderStatus',
      'order_status',
      'packageStatus',
      'package_status',
    ]);
    final type = _firstText(map, ['type', 'notificationType']);
    final isPackage =
        type?.toLowerCase().contains('package') == true ||
        _isPackagePayload(map);
    if (isPackage && !_packageRecipientAllowed(map)) return false;

    final trackingNumber = _trackingNumber(map, package: isPackage);
    final trackingIdentifiers = _trackingIdentifiers(map, package: isPackage);
    final previousDisplayStatus = _existingDisplayStatus(
      package: isPackage,
      trackingNumber: trackingNumber,
      identifiers: trackingIdentifiers,
    );
    final copy = status == null
        ? null
        : orderStatusNotificationCopy(
            status: status,
            orderNumber: trackingNumber,
            package: isPackage,
          );
    final title =
        copy?.title ??
        _firstText(map, ['title', 'notificationTitle']) ??
        (isPackage ? 'Package update' : 'Order update');
    final body =
        copy?.body ??
        _firstText(map, ['message', 'body', 'notificationBody']) ??
        'Your ${isPackage ? 'package' : 'order'} has a new update.';

    if (isPackage && Get.isRegistered<PackageController>()) {
      await Get.find<PackageController>().handleRealtimePackagePayload(
        map,
        fallbackOrderId: trackingNumber.isEmpty ? null : trackingNumber,
        notifyStatusChange: false,
      );
    }

    final displayStatus = notificationDisplayStatus(
      package: isPackage,
      status: status,
      text: [title, body],
    );
    if (displayStatus == null) {
      return false;
    }
    if (previousDisplayStatus != null &&
        previousDisplayStatus == displayStatus) {
      return false;
    }

    final dedupeKey = LocalNotificationService.statusDedupeKey(
      package: isPackage,
      status: status,
      trackingNumber: trackingNumber,
      identifiers: trackingIdentifiers,
      recipientId: _currentUserId,
      title: title,
      body: body,
    );

    if (Get.isRegistered<NotificationService>()) {
      await Get.find<NotificationService>().record(
        title: title,
        message: body,
        category: isPackage ? 'package' : 'order',
        dedupeKey: dedupeKey,
      );
    }
    if (_shouldShowSocketLocalNotification &&
        Get.isRegistered<LocalNotificationService>()) {
      await Get.find<LocalNotificationService>().show(
        title: title,
        body: body,
        payload: _encodeNavigationPayload(
          package: isPackage,
          trackingNumber: trackingNumber,
          status: status,
        ),
        notificationId: LocalNotificationService.notificationIdForDedupeKey(
          dedupeKey,
        ),
        dedupeKey: dedupeKey,
      );
    }
    return true;
  }

  String? _existingDisplayStatus({
    required bool package,
    required String trackingNumber,
    required List<String> identifiers,
  }) {
    if (package) {
      if (!Get.isRegistered<PackageController>()) return null;
      final controller = Get.find<PackageController>();
      for (final id in [trackingNumber, ...identifiers]) {
        final order = controller.findOrderById(id);
        if (order == null) continue;
        return notificationDisplayStatus(package: true, status: order.status);
      }
      return null;
    }

    if (!Get.isRegistered<OrderController>()) return null;
    final controller = Get.find<OrderController>();
    for (final id in [trackingNumber, ...identifiers]) {
      final order = controller.findOrderById(id);
      if (order == null) continue;
      return notificationDisplayStatus(package: false, status: order.status);
    }
    return null;
  }

  bool get _shouldShowSocketLocalNotification {
    final foregroundOverride = _isAppForeground;
    if (foregroundOverride != null) return foregroundOverride();

    final state = WidgetsBinding.instance.lifecycleState;
    return state == AppLifecycleState.resumed;
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
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  Map<String, dynamic>? _notificationData(Map<String, dynamic>? map) {
    if (map == null) return null;
    final merged = Map<String, dynamic>.from(map);
    for (final key in const [
      'data',
      'payload',
      'order',
      'package',
      'packageOrder',
    ]) {
      final child = _asMap(map[key]);
      if (child != null) merged.addAll(child);
    }
    return merged;
  }

  String? _firstText(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  bool _isPackagePayload(Map<String, dynamic>? map) {
    if (map == null) return false;
    return const [
      'packageOrderId',
      'package_order_id',
      'packageId',
      'package_id',
      'packageStatus',
      'package_status',
    ].any((key) => map[key] != null);
  }

  String _trackingNumber(Map<String, dynamic>? map, {required bool package}) {
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
          map,
          package ? [...packageKeys, ...orderKeys] : orderKeys,
        ) ??
        '';
  }

  List<String> _trackingIdentifiers(
    Map<String, dynamic>? map, {
    required bool package,
  }) {
    if (map == null) return const [];
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
    return (package ? [...packageKeys, ...orderKeys] : orderKeys)
        .map((key) => map[key]?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  bool _packageRecipientAllowed(Map<String, dynamic> data) {
    final currentUser = _currentUserData;
    if (currentUser == null) return false;
    return packageRecipientMatch(
          data: data,
          currentUserId: currentUser['id']?.toString() ?? '',
          currentUserPhone: currentUser['phone']?.toString() ?? '',
        ) !=
        PackageRecipientMatch.mismatched;
  }

  Map<String, dynamic>? get _currentUserData {
    if (_storage.read('isLoggedIn') != true ||
        (_storage.read<String>('accessToken')?.trim().isEmpty ?? true)) {
      return null;
    }
    final authUser = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().currentUser
        : null;
    if (authUser != null) {
      return {'id': authUser.id, 'phone': authUser.phone};
    }
    final rawUser = _storage.read('currentUser');
    return rawUser is Map ? Map<String, dynamic>.from(rawUser) : null;
  }

  String get _currentUserId {
    final currentUser = _currentUserData;
    if (currentUser == null) return '';
    return _firstText(currentUser, const [
          'id',
          '_id',
          'userId',
          'user_id',
          'phone',
          'phoneNumber',
          'mobile',
          'email',
        ]) ??
        '';
  }

  String _encodeNavigationPayload({
    required bool package,
    required String trackingNumber,
    required String? status,
  }) {
    return jsonEncode({
      'type': package ? 'package' : 'order',
      if (trackingNumber.isNotEmpty)
        (package ? 'packageOrderId' : 'orderId'): trackingNumber,
      if (status?.trim().isNotEmpty == true) 'status': status!.trim(),
    });
  }

  void disconnect() {
    final socket = _socket;
    if (socket != null) {
      socket
        ..clearListeners()
        ..disconnect()
        ..dispose();
    }
    _socket = null;
    _joinedUserId = null;
  }

  @override
  void onClose() {
    disconnect();
    super.onClose();
  }
}
