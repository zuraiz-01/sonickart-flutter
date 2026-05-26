import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../modules/auth/controllers/auth_controller.dart';
import '../constants/api_constants.dart';
import 'local_notification_service.dart';
import 'status_notification_copy.dart';

class CustomerSocketNotificationService extends GetxService {
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
        debugPrint('CustomerSocketNotificationService: connected for $userId');
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
          'CustomerSocketNotificationService: reconnected for $userId',
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
      socket.on(event, (payload) => _showStatusNotification(payload));
    }

    socket.connect();
  }

  void _showStatusNotification(Object? payload) {
    if (!Get.isRegistered<LocalNotificationService>()) return;
    final map = _notificationData(_asMap(payload));
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
    final copy = status == null
        ? null
        : orderStatusNotificationCopy(
            status: status,
            orderNumber: _trackingNumber(map, package: isPackage),
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

    Get.find<LocalNotificationService>().show(title: title, body: body);
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
