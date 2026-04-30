import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../modules/auth/controllers/auth_controller.dart';
import '../../modules/order_controller.dart';
import '../constants/api_constants.dart';

class OrderSocketService extends GetxService {
  io.Socket? _socket;
  Worker? _activeOrderWorker;
  String? _joinedOrderId;

  Future<OrderSocketService> init() async {
    if (Get.isRegistered<OrderController>()) {
      bindOrderController(Get.find<OrderController>());
    }
    return this;
  }

  void bindOrderController(OrderController controller) {
    _activeOrderWorker?.dispose();
    _activeOrderWorker = ever(controller.activeProductOrder, (_) {
      _syncConnection(controller);
    });
    _syncConnection(controller);
  }

  void _syncConnection(OrderController controller) {
    final user = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().currentUser
        : null;
    final activeOrder = controller.activeProductOrder.value;
    final orderId = activeOrder == null
        ? ''
        : controller.orderIdentifiers(activeOrder).firstOrNull ?? '';

    if (user == null || activeOrder == null || orderId.isEmpty) {
      disconnect();
      return;
    }

    if (_socket != null && _joinedOrderId == orderId) {
      return;
    }

    disconnect();
    _joinedOrderId = orderId;
    final socket = io.io(
      ApiConstants.mobileHost,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;

    socket
      ..onConnect((_) {
        debugPrint('OrderSocketService: connected for order $orderId');
        socket.emit('joinRoom', orderId);
        if (user.id.isNotEmpty) {
          socket.emit('joinRoom', 'user-${user.id}');
        }
      })
      ..onConnectError((error) {
        debugPrint('OrderSocketService connect error: $error');
      })
      ..onError((error) {
        debugPrint('OrderSocketService socket error: $error');
      })
      ..onDisconnect((_) {
        debugPrint('OrderSocketService: disconnected');
      })
      ..on('liveTrackingUpdates', (payload) {
        unawaited(_handleOrderUpdate(controller, orderId, payload));
      })
      ..on('orderConfirmed', (_) {
        unawaited(controller.refreshTrackingOrder(orderId));
      })
      ..on('orderCreated', (payload) {
        final map = _asMap(payload);
        if (map == null) return;
        final customerId = map['customerId'] ?? map['userId'];
        if (customerId != null && customerId.toString() == user.id) {
          unawaited(controller.handleRealtimeOrderPayload(map));
        }
      })
      ..connect();
  }

  Future<void> _handleOrderUpdate(
    OrderController controller,
    String orderId,
    Object? payload,
  ) async {
    final map = _asMap(payload);
    if (map != null) {
      await controller.handleRealtimeOrderPayload(map);
      return;
    }
    await controller.refreshTrackingOrder(orderId);
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
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
    _joinedOrderId = null;
  }

  @override
  void onClose() {
    _activeOrderWorker?.dispose();
    disconnect();
    super.onClose();
  }
}
