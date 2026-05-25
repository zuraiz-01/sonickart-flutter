import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

class LocalNotificationService extends GetxService {
  static const defaultChannelId = 'sonickart_order_updates';
  static const defaultChannelName = 'Order updates';
  static const defaultChannelDescription =
      'Order and package status notifications';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<LocalNotificationService> init() async {
    if (_initialized) return this;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    try {
      await _plugin.initialize(settings: settings);
      await _createAndroidChannel();
      await _requestAndroidPermission();
      _initialized = true;
    } catch (error) {
      debugPrint('LocalNotificationService.init failed: $error');
    }

    return this;
  }

  Future<void> show({
    required String title,
    required String body,
    String channelId = defaultChannelId,
    String channelName = defaultChannelName,
    String channelDescription = defaultChannelDescription,
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
    final details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title.trim().isEmpty ? 'SonicKart' : title.trim(),
        body: body.trim().isEmpty ? 'You have a new update.' : body.trim(),
        notificationDetails: details,
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
}
