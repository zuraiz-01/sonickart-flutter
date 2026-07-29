import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sonic_cart/app/core/services/customer_socket_notification_service.dart';
import 'package:sonic_cart/app/core/services/local_notification_service.dart';
import 'package:sonic_cart/app/core/services/push_notification_service.dart';
import 'package:sonic_cart/app/data/models/package_order_model.dart';
import 'package:sonic_cart/app/modules/package/controllers/package_controller.dart';
import 'package:sonic_cart/app/routes/app_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageContainer = 'push_notification_service_test';
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late GetStorage storage;
  late _FakePushMessagingClient messaging;
  late _FakeLocalTapSource localTaps;
  late List<Map<String, String>> registrations;
  PushNotificationService? service;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async {
          return '.dart_tool/test_storage/push_notification_service';
        });
    await GetStorage.init(storageContainer);
  });

  setUp(() async {
    Get.reset();
    storage = GetStorage(storageContainer);
    await storage.erase();
    messaging = _FakePushMessagingClient();
    localTaps = _FakeLocalTapSource();
    registrations = <Map<String, String>>[];
    service = _buildService(
      storage: storage,
      messaging: messaging,
      localTaps: localTaps,
      registrations: registrations,
    );
  });

  tearDown(() async {
    service?.onClose();
    await Future<void>.delayed(Duration.zero);
    await messaging.dispose();
    await localTaps.dispose();
    debugDefaultTargetPlatformOverride = null;
    Get.reset();
    await storage.erase();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test('successful initialization marks listener setup complete', () async {
    await service!.init();

    expect(service!.listenersInitialized, isTrue);
    expect(messaging.initializeCalls, 1);
    expect(messaging.permissionCalls, 1);
    expect(messaging.presentationCalls, 1);
    expect(messaging.messageStreamReads, 1);
    expect(messaging.openedStreamReads, 1);
    expect(messaging.tokenRefreshStreamReads, 1);
    expect(localTaps.streamReads, 1);
  });

  test('failed partial initialization does not stay initialized', () async {
    messaging.initialMessageFailuresRemaining = 1;

    await service!.init();

    expect(service!.listenersInitialized, isFalse);
    expect(messaging.messages.hasListener, isFalse);
    expect(messaging.openedMessages.hasListener, isFalse);
    expect(messaging.tokenRefreshes.hasListener, isFalse);
    expect(localTaps.controller.hasListener, isFalse);
  });

  test('a later initialization call succeeds after a failure', () async {
    messaging.permissionFailuresRemaining = 1;

    await service!.init();
    expect(service!.listenersInitialized, isFalse);

    await service!.init();

    expect(service!.listenersInitialized, isTrue);
    expect(messaging.initializeCalls, 2);
    expect(messaging.permissionCalls, 2);
  });

  test('concurrent initialization calls share one operation', () async {
    final initializeGate = Completer<void>();
    messaging.initializeGate = initializeGate;

    final first = service!.init();
    final second = service!.init();

    expect(identical(first, second), isTrue);
    expect(messaging.initializeCalls, 1);

    initializeGate.complete();
    await Future.wait([first, second]);

    expect(service!.listenersInitialized, isTrue);
    expect(messaging.messageStreamReads, 1);
  });

  test(
    'repeated successful initialization does not duplicate listeners',
    () async {
      await service!.init();
      await service!.init();
      await service!.init();

      expect(messaging.messageStreamReads, 1);
      expect(messaging.openedStreamReads, 1);
      expect(messaging.tokenRefreshStreamReads, 1);
      expect(localTaps.streamReads, 1);
      expect(messaging.messages.hasListener, isTrue);
      expect(messaging.openedMessages.hasListener, isTrue);
      expect(messaging.tokenRefreshes.hasListener, isTrue);
      expect(localTaps.controller.hasListener, isTrue);
    },
  );

  test('temporary APNs-token absence does not block listener setup', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _authenticate(storage, userId: 'user-1', accessToken: 'session-1');
      messaging.fcmToken = 'fcm-ios';
      messaging.apnsToken = null;
      final stopwatch = Stopwatch()..start();

      await service!.init();
      await _waitUntil(() => registrations.length == 1);
      stopwatch.stop();

      expect(service!.listenersInitialized, isTrue);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
      expect(registrations.single['fcmToken'], 'fcm-ios');
      expect(registrations.single, isNot(contains('apnsToken')));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('authenticated session registers and caches available tokens', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _authenticate(storage, userId: 'user-1', accessToken: 'session-1');
      messaging.fcmToken = 'fcm-1';
      messaging.apnsToken = 'apns-1';

      await service!.registerCurrentToken();

      expect(registrations, hasLength(1));
      expect(registrations.single, {
        'fcmToken': 'fcm-1',
        'fcm_token': 'fcm-1',
        'deviceToken': 'fcm-1',
        'device_token': 'fcm-1',
        'apnsToken': 'apns-1',
        'apns_token': 'apns-1',
      });
      expect(storage.read<String>('fcmToken'), 'fcm-1');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('guest session does not call the protected token endpoint', () async {
    messaging.fcmToken = 'guest-token';

    await service!.registerCurrentToken();

    expect(registrations, isEmpty);
    expect(messaging.getTokenCalls, 0);
  });

  test('expired session does not call the protected token endpoint', () async {
    await storage.write('accessToken', 'expired-session');
    await storage.write('isLoggedIn', false);
    await storage.write('currentUser', {'id': 'user-1'});
    messaging.fcmToken = 'expired-token';

    await service!.registerCurrentToken();

    expect(registrations, isEmpty);
    expect(messaging.getTokenCalls, 0);
  });

  test('backend registration failure leaves listeners active', () async {
    await _authenticate(storage, userId: 'user-1', accessToken: 'session-1');
    messaging.fcmToken = 'fcm-failure';
    var backendCalls = 0;
    service = PushNotificationService(
      storage: storage,
      messaging: messaging,
      localTapSource: localTaps,
      tokenRegistrar: (_) async {
        backendCalls += 1;
        throw StateError('offline');
      },
    );

    await service!.init();
    await _waitUntil(() => backendCalls == 1);

    expect(service!.listenersInitialized, isTrue);
    expect(messaging.messages.hasListener, isTrue);
    expect(messaging.openedMessages.hasListener, isTrue);
    expect(storage.read<String>('fcmToken'), isNull);
  });

  test('FCM token refresh registers the new token once', () async {
    await _authenticate(storage, userId: 'user-1', accessToken: 'session-1');
    messaging.fcmToken = null;
    await service!.init();

    messaging.tokenRefreshes.add('refreshed-fcm');
    await _waitUntil(() => registrations.length == 1);

    expect(registrations.single['fcmToken'], 'refreshed-fcm');
    expect(storage.read<String>('fcmToken'), 'refreshed-fcm');
  });

  test(
    'identical token refresh events do not duplicate backend calls',
    () async {
      await _authenticate(storage, userId: 'user-1', accessToken: 'session-1');
      messaging.fcmToken = null;
      await service!.init();

      messaging.tokenRefreshes
        ..add('same-refreshed-fcm')
        ..add('same-refreshed-fcm')
        ..add('same-refreshed-fcm');
      await _waitUntil(() => registrations.length == 1);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(registrations, hasLength(1));
    },
  );

  test('persisted same-session token registration is idempotent', () async {
    await _authenticate(storage, userId: 'user-1', accessToken: 'session-1');
    messaging.fcmToken = 'fcm-1';
    await service!.registerCurrentToken();
    service!.onClose();

    service = _buildService(
      storage: storage,
      messaging: messaging,
      localTaps: localTaps,
      registrations: registrations,
    );
    await service!.registerCurrentToken();

    expect(registrations, hasLength(1));
  });

  test(
    'a new authenticated user cannot inherit the old user token cache',
    () async {
      messaging.fcmToken = 'shared-device-fcm';
      await _authenticate(storage, userId: 'user-1', accessToken: 'session-1');
      await service!.registerCurrentToken();

      await _authenticate(storage, userId: 'user-2', accessToken: 'session-2');
      await service!.registerCurrentToken();

      expect(registrations, hasLength(2));
    },
  );

  test(
    'same-token registration is queued across an in-flight user change',
    () async {
      final firstRegistrationGate = Completer<void>();
      var backendCalls = 0;
      service = PushNotificationService(
        storage: storage,
        messaging: messaging,
        localTapSource: localTaps,
        tokenRegistrar: (_) async {
          backendCalls += 1;
          if (backendCalls == 1) await firstRegistrationGate.future;
        },
      );
      await _authenticate(storage, userId: 'user-1', accessToken: 'session-1');

      final first = service!.registerCurrentToken(token: 'shared-fcm');
      await _waitUntil(() => backendCalls == 1);
      await _authenticate(storage, userId: 'user-2', accessToken: 'session-2');
      final second = service!.registerCurrentToken(token: 'shared-fcm');
      firstRegistrationGate.complete();
      await Future.wait([first, second]);

      expect(backendCalls, 2);
      expect(storage.read<String>('fcmToken'), 'shared-fcm');
    },
  );

  test(
    'later APNs availability re-registers the same FCM token once',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await _authenticate(
          storage,
          userId: 'user-1',
          accessToken: 'session-1',
        );
        messaging.fcmToken = 'fcm-ios';
        messaging.apnsToken = null;
        await service!.registerCurrentToken();

        messaging.apnsToken = 'apns-later';
        await service!.registerCurrentToken();
        await service!.registerCurrentToken();

        expect(registrations, hasLength(2));
        expect(registrations.first, isNot(contains('apnsToken')));
        expect(registrations.last['apnsToken'], 'apns-later');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  test(
    'foreground messages keep using the existing local display flow',
    () async {
      final local = _RecordingLocalNotificationService();
      Get.put<LocalNotificationService>(local);
      await service!.init();

      messaging.messages.add(
        const RemoteMessage(
          messageId: 'foreground-1',
          data: {'type': 'order', 'status': 'accepted', 'orderId': '101'},
          notification: RemoteNotification(title: 'Update', body: 'Body'),
        ),
      );
      await _waitUntil(() => local.shown.length == 1);

      expect(local.shown.single.$1, isNotEmpty);
      expect(local.shown.single.$2, isNotEmpty);
    },
  );

  test(
    'foreground package FCM updates package state and displays once',
    () async {
      await _authenticate(storage, userId: 'user-1', accessToken: 'session-1');
      final local = _RecordingLocalNotificationService();
      final packageController = _TestPushPackageController(storage);
      packageController.orders.assignAll([
        _pushPackageOrder(id: 'PKG202', status: 'pending'),
      ]);
      Get.put<LocalNotificationService>(local);
      Get.put<PackageController>(packageController);
      await service!.init();

      messaging.messages.add(
        const RemoteMessage(
          messageId: 'foreground-package-1',
          data: {
            'type': 'package',
            'packageOrderId': 'PKG202',
            'status': 'assigned',
            'recipientUserId': 'user-1',
          },
        ),
      );
      await _waitUntil(
        () =>
            local.shown.length == 1 &&
            packageController.findOrderById('PKG202')?.status == 'assigned',
      );

      expect(local.shown, hasLength(1));
      expect(packageController.findOrderById('PKG202')?.status, 'assigned');
    },
  );

  test(
    'foreground order status messages use exact copy and alias dedupe',
    () async {
      final local = _RecordingLocalNotificationService();
      Get.put<LocalNotificationService>(local);
      await service!.init();

      for (final entry in const [
        (
          status: 'placed',
          orderId: 'ORDR00710',
          title: 'Order Placed',
          body: 'Your Order Has Been Placed.',
        ),
        (
          status: 'accepted',
          orderId: 'ORDR00711',
          title: 'Partner Assigned',
          body: 'A Delivery Partner Has Been Assigned.',
        ),
        (
          status: 'picked_up',
          orderId: 'ORDR00712',
          title: 'Order Picked Up',
          body: 'Your Order Has Been Picked Up.',
        ),
        (
          status: 'delivered',
          orderId: 'ORDR00713',
          title: 'Order Delivered',
          body: 'Your Order Has Been Delivered.',
        ),
      ]) {
        messaging.messages.add(
          RemoteMessage(
            data: {
              'type': 'order',
              'status': entry.status,
              'orderId': entry.orderId,
            },
          ),
        );
      }
      await _waitUntil(() => local.shown.length == 4);

      expect(local.shown, [
        ('Order Placed', 'Your Order Has Been Placed.'),
        ('Partner Assigned', 'A Delivery Partner Has Been Assigned.'),
        ('Order Picked Up', 'Your Order Has Been Picked Up.'),
        ('Order Delivered', 'Your Order Has Been Delivered.'),
      ]);

      messaging.messages.add(
        const RemoteMessage(
          data: {
            'type': 'order',
            'status': 'on_the_way',
            'orderId': 'ORDR00712',
          },
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(local.shown, hasLength(4));
    },
  );

  test(
    'foreground package status messages use exact copy and alias dedupe',
    () async {
      await _authenticate(storage, userId: 'user-1', accessToken: 'session-1');
      final local = _RecordingLocalNotificationService();
      Get.put<LocalNotificationService>(local);
      await service!.init();

      for (final entry in const [
        (
          status: 'placed',
          packageOrderId: 'PKG00210',
          title: 'Package Booked',
          body: 'Your Package Has Been Booked.',
        ),
        (
          status: 'accepted',
          packageOrderId: 'PKG00211',
          title: 'Partner Assigned',
          body: 'A Delivery Partner Has Been Assigned.',
        ),
        (
          status: 'picked_up',
          packageOrderId: 'PKG00212',
          title: 'Package Picked Up',
          body: 'Your Package Has Been Picked Up.',
        ),
        (
          status: 'delivered',
          packageOrderId: 'PKG00213',
          title: 'Package Delivered',
          body: 'Your Package Has Been Delivered.',
        ),
      ]) {
        messaging.messages.add(
          RemoteMessage(
            data: {
              'type': 'package',
              'status': entry.status,
              'packageOrderId': entry.packageOrderId,
              'recipientUserId': 'user-1',
            },
          ),
        );
      }
      await _waitUntil(() => local.shown.length == 4);

      expect(local.shown, [
        ('Package Booked', 'Your Package Has Been Booked.'),
        ('Partner Assigned', 'A Delivery Partner Has Been Assigned.'),
        ('Package Picked Up', 'Your Package Has Been Picked Up.'),
        ('Package Delivered', 'Your Package Has Been Delivered.'),
      ]);

      messaging.messages.add(
        const RemoteMessage(
          data: {
            'type': 'package',
            'status': 'out_for_delivery',
            'packageOrderId': 'PKG00212',
            'recipientUserId': 'user-1',
          },
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(local.shown, hasLength(4));
    },
  );

  test('foreground FCM plus customer socket overlap displays once', () async {
    await _authenticate(storage, userId: 'user-1', accessToken: 'session-1');
    final local = _RecordingLocalNotificationService();
    final packageController = _TestPushPackageController(storage);
    packageController.orders.assignAll([
      _pushPackageOrder(id: 'PKG203', status: 'pending'),
    ]);
    Get.put<LocalNotificationService>(local);
    Get.put<PackageController>(packageController);
    await service!.init();
    final customerSocket = CustomerSocketNotificationService(
      storage: storage,
      isAppForeground: () => true,
    );

    messaging.messages.add(
      const RemoteMessage(
        messageId: 'foreground-package-overlap',
        data: {
          'type': 'package',
          'packageOrderId': 'PKG203',
          'status': 'assigned',
          'recipientUserId': 'user-1',
        },
      ),
    );
    await customerSocket.handleStatusNotificationPayload({
      'type': 'package',
      'packageOrderId': 'PKG203',
      'status': 'assigned',
      'recipientUserId': 'user-1',
    });
    await _waitUntil(
      () => packageController.findOrderById('PKG203')?.status == 'assigned',
    );

    expect(local.shown, hasLength(1));
  });

  test('foreground package FCM rejects explicit recipient mismatch', () async {
    await _authenticate(storage, userId: 'user-1', accessToken: 'session-1');
    final local = _RecordingLocalNotificationService();
    final packageController = _TestPushPackageController(storage);
    packageController.orders.assignAll([
      _pushPackageOrder(id: 'PKG204', status: 'pending'),
    ]);
    Get.put<LocalNotificationService>(local);
    Get.put<PackageController>(packageController);
    await service!.init();

    messaging.messages.add(
      const RemoteMessage(
        messageId: 'foreground-package-mismatch',
        data: {
          'type': 'package',
          'packageOrderId': 'PKG204',
          'status': 'assigned',
          'recipientUserId': 'another-user',
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(local.shown, isEmpty);
    expect(packageController.findOrderById('PKG204')?.status, 'pending');
  });

  test(
    'unknown package FCM without recipient identity is not guessed',
    () async {
      await _authenticate(storage, userId: 'user-1', accessToken: 'session-1');
      final local = _RecordingLocalNotificationService();
      Get.put<LocalNotificationService>(local);
      await service!.init();

      messaging.messages.add(
        const RemoteMessage(
          messageId: 'foreground-package-unknown',
          data: {
            'type': 'package',
            'packageOrderId': 'PKG205',
            'status': 'assigned',
          },
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(local.shown, isEmpty);
    },
  );

  testWidgets('notification taps keep using the existing order route', (
    tester,
  ) async {
    await tester.pumpWidget(_notificationTestApp());
    await service!.init();

    messaging.openedMessages.add(
      const RemoteMessage(
        messageId: 'tap-1',
        data: {'type': 'order', 'status': 'accepted', 'orderId': '101'},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.liveTracking);
    expect(find.text('live-tracking'), findsOneWidget);
  });

  testWidgets('initial message keeps using the existing terminated tap flow', (
    tester,
  ) async {
    await _authenticate(storage, userId: 'user-1', accessToken: 'session-1');
    messaging.initialMessage = const RemoteMessage(
      messageId: 'terminated-1',
      data: {
        'type': 'package',
        'packageId': '202',
        'recipientUserId': 'user-1',
      },
    );
    await tester.pumpWidget(_notificationTestApp());

    await service!.init();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.packageDetails);
    expect(find.text('package-details'), findsOneWidget);
  });

  testWidgets(
    'validated local package tap keeps its package detail destination',
    (tester) async {
      await _authenticate(storage, userId: 'user-1', accessToken: 'session-1');
      await tester.pumpWidget(_notificationTestApp());
      await service!.init();

      localTaps.controller.add({
        'type': 'package',
        'packageOrderId': 'PKG206',
        'status': 'assigned',
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.packageDetails);
      expect(find.text('package-details'), findsOneWidget);
    },
  );

  test('background handler remains top-level and registered once', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(
      source,
      contains(
        "@pragma('vm:entry-point')\n"
        'Future<void> firebaseMessagingBackgroundHandler(',
      ),
    );
    expect(
      RegExp(
        r'FirebaseMessaging\.onBackgroundMessage\('
        r'firebaseMessagingBackgroundHandler\)',
      ).allMatches(source),
      hasLength(1),
    );
  });
}

PushNotificationService _buildService({
  required GetStorage storage,
  required _FakePushMessagingClient messaging,
  required _FakeLocalTapSource localTaps,
  required List<Map<String, String>> registrations,
}) {
  return PushNotificationService(
    storage: storage,
    messaging: messaging,
    localTapSource: localTaps,
    tokenRegistrar: (payload) async {
      registrations.add(Map<String, String>.from(payload));
    },
  );
}

Future<void> _authenticate(
  GetStorage storage, {
  required String userId,
  required String accessToken,
}) async {
  await storage.write('accessToken', accessToken);
  await storage.write('isLoggedIn', true);
  await storage.write('currentUser', {'id': userId, 'phone': '+15550000000'});
}

Future<void> _waitUntil(bool Function() condition, {int attempts = 50}) async {
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition was not met after $attempts attempts.');
}

Widget _notificationTestApp() {
  return GetMaterialApp(
    initialRoute: AppRoutes.notifications,
    getPages: [
      GetPage(
        name: AppRoutes.customerOrderDetails,
        page: () => const Scaffold(body: Text('order-details')),
      ),
      GetPage(
        name: AppRoutes.liveTracking,
        page: () => const Scaffold(body: Text('live-tracking')),
      ),
      GetPage(
        name: AppRoutes.packageDetails,
        page: () => const Scaffold(body: Text('package-details')),
      ),
      GetPage(
        name: AppRoutes.notifications,
        page: () => const Scaffold(body: Text('notifications')),
      ),
    ],
  );
}

class _FakePushMessagingClient implements PushMessagingClient {
  final messages = StreamController<RemoteMessage>.broadcast();
  final openedMessages = StreamController<RemoteMessage>.broadcast();
  final tokenRefreshes = StreamController<String>.broadcast();

  Completer<void>? initializeGate;
  AuthorizationStatus authorizationStatus = AuthorizationStatus.authorized;
  RemoteMessage? initialMessage;
  String? fcmToken;
  String? apnsToken;
  int initializeCalls = 0;
  int permissionCalls = 0;
  int presentationCalls = 0;
  int authorizationStatusCalls = 0;
  int messageStreamReads = 0;
  int openedStreamReads = 0;
  int tokenRefreshStreamReads = 0;
  int initialMessageCalls = 0;
  int getTokenCalls = 0;
  int getApnsTokenCalls = 0;
  int permissionFailuresRemaining = 0;
  int initialMessageFailuresRemaining = 0;

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
    final gate = initializeGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<AuthorizationStatus> requestPermission() async {
    permissionCalls += 1;
    if (permissionFailuresRemaining > 0) {
      permissionFailuresRemaining -= 1;
      throw StateError('permission unavailable');
    }
    return authorizationStatus;
  }

  @override
  Future<AuthorizationStatus> getAuthorizationStatus() async {
    authorizationStatusCalls += 1;
    return authorizationStatus;
  }

  @override
  Future<void> setForegroundPresentationOptions() async {
    presentationCalls += 1;
  }

  @override
  Stream<RemoteMessage> get onMessage {
    messageStreamReads += 1;
    return messages.stream;
  }

  @override
  Stream<RemoteMessage> get onMessageOpenedApp {
    openedStreamReads += 1;
    return openedMessages.stream;
  }

  @override
  Stream<String> get onTokenRefresh {
    tokenRefreshStreamReads += 1;
    return tokenRefreshes.stream;
  }

  @override
  Future<RemoteMessage?> getInitialMessage() async {
    initialMessageCalls += 1;
    if (initialMessageFailuresRemaining > 0) {
      initialMessageFailuresRemaining -= 1;
      throw StateError('initial message unavailable');
    }
    return initialMessage;
  }

  @override
  Future<String?> getToken() async {
    getTokenCalls += 1;
    return fcmToken;
  }

  @override
  Future<String?> getApnsToken() async {
    getApnsTokenCalls += 1;
    return apnsToken;
  }

  Future<void> dispose() async {
    await messages.close();
    await openedMessages.close();
    await tokenRefreshes.close();
  }
}

class _FakeLocalTapSource implements PushLocalTapSource {
  final controller = StreamController<Map<String, dynamic>>.broadcast();
  Map<String, dynamic>? pending;
  int streamReads = 0;

  @override
  Stream<Map<String, dynamic>> get taps {
    streamReads += 1;
    return controller.stream;
  }

  @override
  Map<String, dynamic>? takePendingLaunchData() {
    final value = pending;
    pending = null;
    return value;
  }

  Future<void> dispose() => controller.close();
}

class _RecordingLocalNotificationService extends LocalNotificationService {
  final shown = <(String, String)>[];
  final _dedupeKeys = <String>{};

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
    if (!_dedupeKeys.add(key)) return;
    shown.add((title, body));
  }
}

class _TestPushPackageController extends PackageController {
  _TestPushPackageController(super.storage);

  // Test double deliberately skips PackageController's network-loading onInit.
  @override
  // ignore: must_call_super
  void onInit() {}
}

PackageOrderModel _pushPackageOrder({
  required String id,
  required String status,
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
    raw: {
      'id': id,
      'packageOrderId': id,
      'status': status,
      'createdAt': '2026-01-01T00:00:00.000Z',
    },
  );
}
