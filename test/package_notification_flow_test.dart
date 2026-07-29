import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sonic_cart/app/core/services/customer_socket_notification_service.dart';
import 'package:sonic_cart/app/core/services/local_notification_service.dart';
import 'package:sonic_cart/app/core/services/notification_service.dart';
import 'package:sonic_cart/app/core/services/package_notification_policy.dart';
import 'package:sonic_cart/app/data/models/package_order_model.dart';
import 'package:sonic_cart/app/modules/package/controllers/package_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageContainer = 'package_notification_flow_test';
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late GetStorage storage;
  late _DedupeLocalNotificationService localNotifications;
  late NotificationService notificationRecords;
  late _TestPackageController controller;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async {
          return '.dart_tool/test_storage/package_notification_flow';
        });
    await GetStorage.init(storageContainer);
  });

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    storage = GetStorage(storageContainer);
    await storage.erase();
    await _authenticate(storage);
    localNotifications = _DedupeLocalNotificationService();
    notificationRecords = NotificationService(storage);
    controller = _TestPackageController(storage);
    Get.put<LocalNotificationService>(localNotifications);
    Get.put<NotificationService>(notificationRecords);
    Get.put<PackageController>(controller);
  });

  tearDown(() async {
    Get.reset();
    await storage.erase();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test(
    'foreground Send Package event updates list selected state and notification',
    () async {
      final order = _packageOrder(
        id: 'PKG101',
        status: 'pending',
        packageOrderType: 'send',
      );
      controller.orders.assignAll([order]);
      controller.selectedOrder.value = order;

      final handled = await controller.handleRealtimePackagePayload({
        'packageOrderId': 'PKG101',
        'status': 'assigned',
      });
      await _waitUntil(() => localNotifications.shown.length == 1);

      expect(handled, isTrue);
      expect(controller.findOrderById('PKG101')?.status, 'assigned');
      expect(controller.selectedOrder.value?.status, 'assigned');
      expect(localNotifications.shown.single.title, 'Partner Assigned');
      expect(notificationRecords.notifications, hasLength(1));
      expect(notificationRecords.notifications.single.category, 'package');
    },
  );

  test(
    'foreground Receive Package event follows the same notification flow',
    () async {
      final order = _packageOrder(
        id: 'PKG102',
        status: 'pending',
        packageOrderType: 'receive',
      );
      controller.orders.assignAll([order]);
      controller.selectedOrder.value = order;

      await controller.handleRealtimePackagePayload({
        'package_id': 'PKG102',
        'status': 'accepted',
      });
      await _waitUntil(() => localNotifications.shown.length == 1);

      expect(controller.findOrderById('PKG102')?.status, 'accepted');
      expect(localNotifications.shown.single.title, 'Partner Assigned');
    },
  );

  test(
    'established suppressed package status updates state without displaying',
    () async {
      final order = _packageOrder(id: 'PKG103', status: 'picked_up');
      controller.orders.assignAll([order]);

      await controller.handleRealtimePackagePayload({
        'packageId': 'PKG103',
        'status': 'out_for_delivery',
      });
      await Future<void>.delayed(Duration.zero);

      expect(controller.findOrderById('PKG103')?.status, 'out_for_delivery');
      expect(localNotifications.shown, isEmpty);
      expect(notificationRecords.notifications, isEmpty);
    },
  );

  test('duplicate delivery of the same package status displays once', () async {
    controller.orders.assignAll([
      _packageOrder(id: 'PKG104', status: 'pending'),
    ]);

    await controller.handleRealtimePackagePayload({
      'packageOrderId': 'PKG104',
      'status': 'assigned',
    });
    await controller.handleRealtimePackagePayload({
      'packageOrderId': 'PKG104',
      'status': 'assigned',
    });
    await _waitUntil(() => localNotifications.shown.length == 1);

    expect(localNotifications.shown, hasLength(1));
    expect(notificationRecords.notifications, hasLength(1));
  });

  test(
    'different package identities receive independent notifications',
    () async {
      controller.orders.assignAll([
        _packageOrder(id: 'PKG105', status: 'pending'),
        _packageOrder(id: 'PKG106', status: 'pending'),
      ]);

      await controller.handleRealtimePackagePayload({
        'packageOrderId': 'PKG105',
        'status': 'assigned',
      });
      await controller.handleRealtimePackagePayload({
        'packageOrderId': 'PKG106',
        'status': 'assigned',
      });
      await _waitUntil(() => localNotifications.shown.length == 2);

      expect(localNotifications.shown, hasLength(2));
      expect(notificationRecords.notifications, hasLength(2));
    },
  );

  test('newer status applies and stale regression cannot replace it', () async {
    controller.orders.assignAll([
      _packageOrder(id: 'PKG107', status: 'assigned'),
    ]);

    await controller.handleRealtimePackagePayload({
      'packageOrderId': 'PKG107',
      'status': 'picked_up',
    });
    await _waitUntil(() => localNotifications.shown.length == 1);
    await controller.handleRealtimePackagePayload({
      'packageOrderId': 'PKG107',
      'status': 'pending',
    });

    expect(controller.findOrderById('PKG107')?.status, 'picked_up');
    expect(localNotifications.shown, hasLength(1));
    expect(localNotifications.shown.single.title, contains('Picked Up'));
  });

  test(
    'event for another package does not replace the open selected package',
    () async {
      final first = _packageOrder(id: 'PKG108', status: 'pending');
      final selected = _packageOrder(id: 'PKG109', status: 'assigned');
      controller.orders.assignAll([first, selected]);
      controller.selectedOrder.value = selected;

      await controller.handleRealtimePackagePayload({
        'packageOrderId': 'PKG108',
        'status': 'picked_up',
      });

      expect(controller.findOrderById('PKG108')?.status, 'picked_up');
      expect(controller.selectedOrder.value?.id, 'PKG109');
      expect(controller.selectedOrder.value?.status, 'assigned');
    },
  );

  test(
    'socket payload for selected package updates selected details immediately',
    () async {
      final selected = _packageOrder(id: 'PKG110', status: 'assigned');
      controller.orders.assignAll([selected]);
      controller.selectedOrder.value = selected;

      await controller.handleRealtimePackagePayload({
        'package_order_id': 'PKG110',
        'status': 'picked_up',
      });

      expect(controller.selectedOrder.value?.status, 'picked_up');
      expect(controller.orders.single.status, 'picked_up');
    },
  );

  test(
    'customer user-room socket updates package state and displays one notification',
    () async {
      controller.orders.assignAll([
        _packageOrder(id: 'PKG111', status: 'pending'),
      ]);
      final service = CustomerSocketNotificationService(
        storage: storage,
        isAppForeground: () => true,
      );

      final displayed = await service.handleStatusNotificationPayload({
        'type': 'package_status',
        'packageOrderId': 'PKG111',
        'status': 'assigned',
      });

      expect(displayed, isTrue);
      expect(controller.findOrderById('PKG111')?.status, 'assigned');
      expect(localNotifications.shown, hasLength(1));
      final payload = jsonDecode(localNotifications.shown.single.payload!);
      expect(payload['type'], 'package');
      expect(payload['packageOrderId'], 'PKG111');
    },
  );

  test(
    'background customer socket records package update without local display',
    () async {
      controller.orders.assignAll([
        _packageOrder(id: 'PKG111B', status: 'pending'),
      ]);
      final service = CustomerSocketNotificationService(
        storage: storage,
        isAppForeground: () => false,
      );

      final displayed = await service.handleStatusNotificationPayload({
        'type': 'package_status',
        'packageOrderId': 'PKG111B',
        'status': 'assigned',
      });

      expect(displayed, isTrue);
      expect(controller.findOrderById('PKG111B')?.status, 'assigned');
      expect(localNotifications.shown, isEmpty);
      expect(notificationRecords.notifications, hasLength(1));
    },
  );

  test(
    'suppressed customer socket status still updates package state',
    () async {
      controller.orders.assignAll([
        _packageOrder(id: 'PKG111A', status: 'picked_up'),
      ]);
      final service = CustomerSocketNotificationService(
        storage: storage,
        isAppForeground: () => true,
      );

      final displayed = await service.handleStatusNotificationPayload({
        'type': 'package_status',
        'packageOrderId': 'PKG111A',
        'status': 'out_for_delivery',
      });

      expect(displayed, isFalse);
      expect(controller.findOrderById('PKG111A')?.status, 'out_for_delivery');
      expect(localNotifications.shown, isEmpty);
      expect(notificationRecords.notifications, isEmpty);
    },
  );

  test(
    'explicit recipient mismatch is rejected before state or display',
    () async {
      controller.orders.assignAll([
        _packageOrder(id: 'PKG112', status: 'pending'),
      ]);
      final service = CustomerSocketNotificationService(
        storage: storage,
        isAppForeground: () => true,
      );

      final displayed = await service.handleStatusNotificationPayload({
        'type': 'package_status',
        'packageOrderId': 'PKG112',
        'status': 'assigned',
        'recipientUserId': 'another-user',
      });

      expect(displayed, isFalse);
      expect(controller.findOrderById('PKG112')?.status, 'pending');
      expect(localNotifications.shown, isEmpty);
    },
  );

  test(
    'package status notification carries an existing detail-route identity',
    () async {
      controller.orders.assignAll([
        _packageOrder(id: 'PKG113', status: 'pending'),
      ]);

      await controller.handleRealtimePackagePayload({
        'packageOrderId': 'PKG113',
        'status': 'assigned',
      });
      await _waitUntil(() => localNotifications.shown.length == 1);

      final payload =
          jsonDecode(localNotifications.shown.single.payload!)
              as Map<String, dynamic>;
      expect(payload, {
        'type': 'package',
        'packageOrderId': 'PKG113',
        'status': 'assigned',
      });
    },
  );

  group('package sender and receiver recipient policy', () {
    test('matches an explicit sender identity', () {
      expect(
        packageRecipientMatch(
          data: const {'senderUserId': 'user-current'},
          currentUserId: 'user-current',
          currentUserPhone: '',
        ),
        PackageRecipientMatch.matched,
      );
    });

    test('matches an explicit receiver phone', () {
      expect(
        packageRecipientMatch(
          data: const {'receiverPhone': '+92 300 0000000'},
          currentUserId: '',
          currentUserPhone: '03000000000',
        ),
        PackageRecipientMatch.matched,
      );
    });

    test(
      'missing recipient identity remains unspecified rather than guessed',
      () {
        expect(
          packageRecipientMatch(
            data: const {'packageOrderId': 'PKG114', 'status': 'assigned'},
            currentUserId: 'user-current',
            currentUserPhone: '03000000000',
          ),
          PackageRecipientMatch.unspecified,
        );
        expect(
          packageNotificationBelongsToKnownOrder(
            data: const {'packageOrderId': 'PKG114'},
            storedOrders: const [
              {'id': 'PKG999'},
            ],
          ),
          isFalse,
        );
      },
    );
  });

  group('background package display policy', () {
    test('notification payload is left to the operating system', () {
      final message = RemoteMessage(
        data: const {
          'type': 'package',
          'packageOrderId': 'PKG115',
          'status': 'assigned',
          'recipientUserId': 'user-current',
        },
        notification: const RemoteNotification(
          title: 'Partner Assigned',
          body: 'A partner was assigned.',
        ),
      );

      expect(
        LocalNotificationService.shouldDisplayRemoteMessageFromBackground(
          message,
          storage: storage,
        ),
        isFalse,
      );
    });

    test('system-owned payload marker is not displayed again locally', () {
      final message = RemoteMessage(
        data: const {
          'type': 'package',
          'packageOrderId': 'PKG115',
          'status': 'assigned',
          'recipientUserId': 'user-current',
          'notificationDisplayOwner': 'system',
          'fcmNotificationPayload': 'true',
        },
      );

      expect(
        LocalNotificationService.shouldDisplayRemoteMessageFromBackground(
          message,
          storage: storage,
        ),
        isFalse,
      );
    });

    test(
      'eligible data-only package payload can create one local notification',
      () {
        final message = RemoteMessage(
          data: const {
            'type': 'package',
            'packageOrderId': 'PKG116',
            'status': 'assigned',
            'recipientUserId': 'user-current',
          },
        );

        expect(
          LocalNotificationService.shouldDisplayRemoteMessageFromBackground(
            message,
            storage: storage,
          ),
          isTrue,
        );
      },
    );

    test(
      'eligible data-only order payload can create one local notification',
      () {
        final message = RemoteMessage(
          data: const {
            'type': 'order',
            'orderId': 'ORDR00717',
            'status': 'assigned',
            'recipientUserId': 'user-current',
          },
        );

        expect(
          LocalNotificationService.shouldDisplayRemoteMessageFromBackground(
            message,
            storage: storage,
          ),
          isTrue,
        );
      },
    );

    test('wrong order recipient is rejected in background', () {
      final message = RemoteMessage(
        data: const {
          'type': 'order',
          'orderId': 'ORDR00717',
          'status': 'assigned',
          'recipientUserId': 'another-user',
        },
      );

      expect(
        LocalNotificationService.shouldDisplayRemoteMessageFromBackground(
          message,
          storage: storage,
        ),
        isFalse,
      );
    });

    test(
      'unknown data-only package without recipient identity is rejected',
      () {
        final message = RemoteMessage(
          data: const {
            'type': 'package',
            'packageOrderId': 'PKG117',
            'status': 'assigned',
          },
        );

        expect(
          LocalNotificationService.shouldDisplayRemoteMessageFromBackground(
            message,
            storage: storage,
          ),
          isFalse,
        );
      },
    );

    test('known stored package permits neutral data-only payload', () async {
      await storage.write(PackageController.packageOrdersStorageKey, [
        _packageOrder(id: 'PKG118', status: 'pending').toJson(),
      ]);
      final message = RemoteMessage(
        data: const {
          'type': 'package',
          'packageOrderId': 'PKG118',
          'status': 'assigned',
        },
      );

      expect(
        LocalNotificationService.shouldDisplayRemoteMessageFromBackground(
          message,
          storage: storage,
        ),
        isTrue,
      );
    });

    test('data-only background dedupe is stable by status event', () async {
      final firstTime = DateTime.utc(2026, 1, 1, 12);

      expect(
        await LocalNotificationService.claimBackgroundDedupeKey(
          'package|pkg119|assigned',
          storage: storage,
          now: firstTime,
        ),
        isTrue,
      );
      expect(
        await LocalNotificationService.claimBackgroundDedupeKey(
          'package|pkg119|assigned',
          storage: storage,
          now: firstTime.add(const Duration(seconds: 30)),
        ),
        isFalse,
      );
      expect(
        await LocalNotificationService.claimBackgroundDedupeKey(
          'package|pkg119|picked_up',
          storage: storage,
          now: firstTime.add(const Duration(seconds: 30)),
        ),
        isTrue,
      );
      expect(
        await LocalNotificationService.claimBackgroundDedupeKey(
          'package|pkg119|assigned',
          storage: storage,
          now: firstTime.add(const Duration(minutes: 3)),
        ),
        isFalse,
      );
    });
  });

  test(
    'background handler and package listener ownership remain lifecycle-safe',
    () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      final customerSocketSource = File(
        'lib/app/core/services/customer_socket_notification_service.dart',
      ).readAsStringSync();
      final dashboardBindingSource = File(
        'lib/app/modules/dashboard/bindings/dashboard_binding.dart',
      ).readAsStringSync();
      final authSource = File(
        'lib/app/modules/auth/controllers/auth_controller.dart',
      ).readAsStringSync();
      final sessionSource = File(
        'lib/app/core/services/session_controller.dart',
      ).readAsStringSync();

      final backgroundHandler = mainSource.substring(
        mainSource.indexOf('Future<void> firebaseMessagingBackgroundHandler'),
        mainSource.indexOf('Future<void> main()'),
      );
      expect(backgroundHandler, isNot(contains('Get.find')));
      expect(
        backgroundHandler,
        contains('shouldDisplayRemoteMessageFromBackground'),
      );
      expect(
        backgroundHandler,
        contains('showRemoteMessageFromBackground(message)'),
      );
      expect(
        backgroundHandler,
        contains('recordRemoteMessageFromBackground(message)'),
      );
      expect(
        customerSocketSource,
        contains('if (_socket != null && _joinedUserId == userId) return;'),
      );
      expect(
        dashboardBindingSource,
        contains('if (!Get.isRegistered<CustomerSocketNotificationService>())'),
      );
      expect(
        dashboardBindingSource,
        contains(
          'Get.put(CustomerSocketNotificationService(), permanent: true)',
        ),
      );
      expect(authSource, contains('CustomerSocketNotificationService'));
      expect(authSource, contains('PackageSocketService'));
      expect(authSource, contains('.connectForCurrentUser()'));
      expect(sessionSource, contains('CustomerSocketNotificationService'));
      expect(sessionSource, contains('PackageSocketService'));
      expect(sessionSource, contains('.disconnect()'));
    },
  );
}

Future<void> _authenticate(GetStorage storage) async {
  await storage.write('accessToken', 'session-token');
  await storage.write('isLoggedIn', true);
  await storage.write('currentUser', {
    'id': 'user-current',
    'phone': '03000000000',
  });
}

PackageOrderModel _packageOrder({
  required String id,
  required String status,
  String packageOrderType = 'send',
}) {
  return PackageOrderModel(
    id: id,
    customerName: 'Customer',
    customerPhone: '03000000000',
    packageType: 'Parcel',
    pickupAddress: 'Pickup',
    dropAddress: 'Drop',
    distanceKm: 5,
    deliveryCharge: 50,
    totalPrice: 50,
    status: status,
    createdAt: DateTime.utc(2026, 1, 1),
    packageOrderType: packageOrderType,
    raw: {
      'id': id,
      'packageOrderId': id,
      'status': status,
      'packageOrderType': packageOrderType,
      'createdAt': '2026-01-01T00:00:00.000Z',
    },
  );
}

Future<void> _waitUntil(bool Function() condition, {int attempts = 50}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition was not met after $attempts attempts.');
}

class _TestPackageController extends PackageController {
  _TestPackageController(super.storage);

  // Test double deliberately skips PackageController's network-loading onInit.
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _ShownNotification {
  const _ShownNotification({
    required this.title,
    required this.body,
    required this.payload,
    required this.dedupeKey,
  });

  final String title;
  final String body;
  final String? payload;
  final String? dedupeKey;
}

class _DedupeLocalNotificationService extends LocalNotificationService {
  final shown = <_ShownNotification>[];
  final _seen = <String>{};

  @override
  Future<void> show({
    required String title,
    required String body,
    String channelId = LocalNotificationService.defaultChannelId,
    String channelName = LocalNotificationService.defaultChannelName,
    String channelDescription =
        LocalNotificationService.defaultChannelDescription,
    String? payload,
    int? notificationId,
    String? dedupeKey,
    Duration dedupeWindow = const Duration(minutes: 2),
  }) async {
    final key = dedupeKey ?? '$channelId|$title|$body';
    if (!_seen.add(key)) return;
    shown.add(
      _ShownNotification(
        title: title,
        body: body,
        payload: payload,
        dedupeKey: dedupeKey,
      ),
    );
  }
}
