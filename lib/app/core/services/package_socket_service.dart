import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../modules/auth/controllers/auth_controller.dart';
import '../../modules/package/controllers/package_controller.dart';
import '../constants/api_constants.dart';

class PackageSocketService extends GetxService {
  io.Socket? _socket;
  String? _joinedOrderId;

  Future<PackageSocketService> init() async => this;

  void connectToOrder(PackageController controller, String orderId) {
    final normalizedId = _normalizeId(orderId);
    if (normalizedId.isEmpty) {
      disconnect();
      return;
    }

    if (_socket != null && _joinedOrderId == normalizedId) {
      return;
    }

    disconnect();
    _joinedOrderId = normalizedId;

    final user = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().currentUser
        : null;
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
        debugPrint('PackageSocketService: connected for package $normalizedId');
        for (final room in _roomsFor(orderId, normalizedId, user?.id)) {
          socket.emit('joinRoom', room);
        }
      })
      ..onConnectError((error) {
        debugPrint('PackageSocketService connect error: $error');
      })
      ..onError((error) {
        debugPrint('PackageSocketService socket error: $error');
      })
      ..onDisconnect((_) {
        debugPrint('PackageSocketService: disconnected');
      });

    for (final event in const [
      'liveTrackingUpdates',
      'packageOrderStatusUpdated',
      'packageOrderAssigned',
      'packageOrderUpdated',
      'orderConfirmed',
    ]) {
      socket.on(event, (payload) {
        unawaited(_handleUpdate(controller, normalizedId, payload));
      });
    }

    socket.connect();
  }

  Future<void> _handleUpdate(
    PackageController controller,
    String orderId,
    Object? payload,
  ) async {
    final map = _asMap(payload);
    if (map != null) {
      final handled = await controller.handleRealtimePackagePayload(
        map,
        fallbackOrderId: orderId,
      );
      if (handled) return;
    }
    await controller.refreshOrderDetails(orderId);
  }

  Iterable<String> _roomsFor(
    String originalOrderId,
    String normalizedOrderId,
    String? userId,
  ) sync* {
    final raw = originalOrderId.trim();
    if (raw.isNotEmpty) yield raw;
    yield normalizedOrderId;
    yield 'PKG$normalizedOrderId';
    yield 'package-$normalizedOrderId';
    if (userId != null && userId.trim().isNotEmpty) {
      yield 'user-${userId.trim()}';
    }
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  String _normalizeId(String value) {
    return value.trim().replaceFirst(RegExp(r'^PKG', caseSensitive: false), '');
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
    disconnect();
    super.onClose();
  }
}
