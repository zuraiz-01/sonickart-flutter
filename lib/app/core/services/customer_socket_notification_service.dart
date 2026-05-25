import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../modules/auth/controllers/auth_controller.dart';
import '../constants/api_constants.dart';
import 'local_notification_service.dart';

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
    final map = _asMap(payload);
    final status = _firstText(map, [
      'status',
      'deliveryStatus',
      'delivery_status',
      'package_status',
    ]);
    final type = _firstText(map, ['type']);
    final isPackage =
        type?.toLowerCase().contains('package') == true ||
        map?['package_id'] != null;
    final title =
        _firstText(map, ['title']) ??
        (isPackage ? 'Package update' : 'Order update');
    final body =
        _firstText(map, ['message', 'body']) ??
        (status == null
            ? 'Your ${isPackage ? 'package' : 'order'} has a new update.'
            : 'Your ${isPackage ? 'package' : 'order'} is ${_statusLabel(status)}.');

    Get.find<LocalNotificationService>().show(title: title, body: body);
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  String? _firstText(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String _statusLabel(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[-\s]+'),
      '_',
    );
    final compact = normalized.replaceAll('_', '');
    if (compact == 'picked' ||
        compact == 'pickup' ||
        compact == 'pickedup' ||
        compact == 'orderpickedup') {
      return 'Picked up';
    }
    if (compact == 'intransit' ||
        compact == 'transit' ||
        compact == 'orderintransit') {
      return 'In transit';
    }
    return normalized.replaceAll('_', ' ').capitalizeFirst ?? value;
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
