import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sonic_cart/app/core/constants/api_constants.dart';
import 'package:sonic_cart/app/core/network/api_service.dart';
import 'package:sonic_cart/app/core/services/app_resume_reconciliation_service.dart';
import 'package:sonic_cart/app/core/services/service_area_gate_controller.dart';
import 'package:sonic_cart/app/core/services/service_area_gate_service.dart';
import 'package:sonic_cart/app/core/services/session_controller.dart';
import 'package:sonic_cart/app/data/models/order_model.dart';
import 'package:sonic_cart/app/data/models/package_order_model.dart';
import 'package:sonic_cart/app/data/repositories/auth_repository.dart';
import 'package:sonic_cart/app/modules/auth/controllers/auth_controller.dart';
import 'package:sonic_cart/app/modules/dashboard/controllers/dashboard_controller.dart';
import 'package:sonic_cart/app/modules/order_controller.dart';
import 'package:sonic_cart/app/modules/package/controllers/package_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async {
          return '.dart_tool/test_storage/app_resume_reconciliation';
        });
    await GetStorage.init();
  });

  tearDown(() async {
    await GetStorage().erase();
    Get.reset();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test(
    'background-to-resumed transition reconciles orders and packages',
    () async {
      final storage = GetStorage();
      await _authenticate(storage);
      var orderCalls = 0;
      var packageCalls = 0;
      final service = AppResumeReconciliationService(
        storage,
        minimumInterval: Duration.zero,
        orderReconciliation: () async => orderCalls += 1,
        packageReconciliation: () async => packageCalls += 1,
      );

      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _pumpUntil(() => orderCalls == 1 && packageCalls == 1);

      expect(orderCalls, 1);
      expect(packageCalls, 1);
    },
  );

  test(
    'repeated resumed callbacks share one in-flight reconciliation',
    () async {
      final storage = GetStorage();
      await _authenticate(storage);
      final orderRefresh = Completer<void>();
      var orderCalls = 0;
      var packageCalls = 0;
      final service = AppResumeReconciliationService(
        storage,
        minimumInterval: Duration.zero,
        orderReconciliation: () {
          orderCalls += 1;
          return orderRefresh.future;
        },
        packageReconciliation: () async => packageCalls += 1,
      );

      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _pumpUntil(() => orderCalls == 1);

      service.didChangeAppLifecycleState(AppLifecycleState.inactive);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(orderCalls, 1);
      expect(packageCalls, 1);

      orderRefresh.complete();
      await _pumpUntil(() => orderRefresh.isCompleted);
    },
  );

  test(
    'quick inactive-resumed churn respects reconciliation cooldown',
    () async {
      final storage = GetStorage();
      await _authenticate(storage);
      final now = DateTime.utc(2026, 1, 1, 12);
      var calls = 0;
      final service = AppResumeReconciliationService(
        storage,
        clock: () => now,
        orderReconciliation: () async => calls += 1,
        packageReconciliation: () async {},
      );

      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _pumpUntil(() => calls == 1);

      service.didChangeAppLifecycleState(AppLifecycleState.inactive);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
    },
  );

  test(
    'unauthenticated or expired session skips protected refreshes',
    () async {
      final storage = GetStorage();
      var calls = 0;
      final service = AppResumeReconciliationService(
        storage,
        minimumInterval: Duration.zero,
        orderReconciliation: () async => calls += 1,
        packageReconciliation: () async => calls += 1,
      );

      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);

      await _authenticate(storage);
      final session = Get.put(SessionController(storage));
      session.isSessionExpiredVisible.value = true;
      service.didChangeAppLifecycleState(AppLifecycleState.inactive);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(calls, 0);
    },
  );

  test(
    'authenticated resume is safe before domain controllers exist',
    () async {
      final storage = GetStorage();
      await _authenticate(storage);
      final service = AppResumeReconciliationService(
        storage,
        minimumInterval: Duration.zero,
      );

      await expectLater(service.reconcileStatuses(), completes);

      expect(Get.isRegistered<OrderController>(), isFalse);
      expect(Get.isRegistered<PackageController>(), isFalse);
    },
  );

  test(
    'successful order reconciliation updates list and selected status',
    () async {
      final storage = GetStorage();
      await _authenticate(storage);
      final api = _StatusApiService(storage);
      Get.put<ApiService>(api);
      Get.put<AuthController>(
        AuthController(AuthRepository(api, storage: storage)),
      );
      final controller = OrderController(storage);
      addTearDown(controller.onClose);
      final cached = _order(status: 'accepted');
      controller.orders.assignAll([cached]);
      controller.latestOrder.value = cached;
      controller.activeProductOrder.value = cached;
      controller.selectedOrder.value = cached;

      await controller.syncActiveProductOrder();

      expect(controller.findOrderById('ORD1')?.status, 'delivered');
      expect(controller.selectedOrder.value?.status, 'delivered');
      expect(controller.activeProductOrder.value, isNull);
      expect(controller.orders, hasLength(1));
      expect(api.orderListRequests, 1);
    },
  );

  test(
    'successful package reconciliation updates list and selected status',
    () async {
      final storage = GetStorage();
      final api = _StatusApiService(storage);
      Get.put<ApiService>(api);
      final controller = PackageController(storage);
      addTearDown(controller.onClose);
      final cached = _packageOrder(status: 'pending');
      controller.orders.assignAll([cached]);
      controller.selectedOrder.value = cached;

      await controller.syncOrdersFromBackend();

      expect(controller.findOrderById('PKG1')?.status, 'accepted');
      expect(controller.selectedOrder.value?.status, 'accepted');
      expect(controller.orders, hasLength(1));
      expect(api.packageListRequests, 1);
    },
  );

  test('failed package reconciliation preserves valid cached state', () async {
    final storage = GetStorage();
    final api = _StatusApiService(storage)..failPackageRequests = true;
    Get.put<ApiService>(api);
    final controller = PackageController(storage);
    addTearDown(controller.onClose);
    final cached = _packageOrder(status: 'picked_up');
    controller.orders.assignAll([cached]);
    controller.selectedOrder.value = cached;

    await controller.syncOrdersFromBackend();

    expect(controller.orders, hasLength(1));
    expect(controller.findOrderById('PKG1')?.status, 'picked_up');
    expect(controller.selectedOrder.value?.status, 'picked_up');
  });

  test('foreground package socket payload path still updates status', () async {
    final controller = PackageController(GetStorage());
    addTearDown(controller.onClose);
    controller.orders.assignAll([_packageOrder(status: 'pending')]);

    final handled = await controller.handleRealtimePackagePayload({
      'id': 'PKG1',
      'status': 'picked_up',
    });

    expect(handled, isTrue);
    expect(controller.findOrderById('PKG1')?.status, 'picked_up');
  });

  testWidgets(
    'resume reconciliation preserves route, dashboard tab, and service-area state',
    (tester) async {
      final storage = GetStorage();
      await _authenticate(storage);
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/order-details',
          getPages: [
            GetPage(
              name: '/order-details',
              page: () => const Scaffold(body: Text('order-details')),
            ),
          ],
        ),
      );
      final dashboard = DashboardController()..currentIndex.value = 3;
      addTearDown(dashboard.onClose);
      final gateService = _CountingServiceAreaGateService(storage);
      Get.put(ServiceAreaGateController(serviceAreaGateService: gateService));
      await _pumpUntil(() => gateService.evaluateCalls == 1);
      var reconciliationCalls = 0;
      final service = AppResumeReconciliationService(
        storage,
        minimumInterval: Duration.zero,
        orderReconciliation: () async => reconciliationCalls += 1,
        packageReconciliation: () async => reconciliationCalls += 1,
      );

      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _pumpUntil(() => reconciliationCalls == 2);

      expect(Get.currentRoute, '/order-details');
      expect(dashboard.currentIndex.value, 3);
      expect(gateService.evaluateCalls, 1);
    },
  );
}

Future<void> _authenticate(GetStorage storage) async {
  await storage.write('accessToken', 'valid-access-token');
  await storage.write('isLoggedIn', true);
  await storage.write('currentUser', {
    'id': 'customer-1',
    'name': 'Customer',
    'email': 'customer@example.com',
    'phone': '03000000000',
  });
}

Future<void> _pumpUntil(bool Function() condition, {int attempts = 30}) async {
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
}

OrderModel _order({required String status}) {
  return OrderModel(
    id: 'ORD1',
    items: const [],
    customerName: 'Customer',
    customerPhone: '03000000000',
    deliveryAddress: 'Customer drop address',
    paymentMode: 'COD',
    totalPrice: 500,
    status: status,
    createdAt: DateTime.utc(2026, 1, 1),
    raw: {
      'id': 'ORD1',
      'orderId': 'ORD1',
      'status': status,
      'deliveryStatus': status,
      'deliveryAddress': 'Customer drop address',
      'totalPrice': 500,
      'createdAt': '2026-01-01T00:00:00.000Z',
    },
  );
}

PackageOrderModel _packageOrder({required String status}) {
  return PackageOrderModel(
    id: 'PKG1',
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
      'id': 'PKG1',
      'status': status,
      'createdAt': '2026-01-01T00:00:00.000Z',
    },
  );
}

class _StatusApiService extends ApiService {
  _StatusApiService(GetStorage storage) : super(storage: storage);

  bool failPackageRequests = false;
  int orderListRequests = 0;
  int packageListRequests = 0;

  Map<String, dynamic> get _remoteOrder => {
    'id': 'ORD1',
    'orderId': 'ORD1',
    'status': 'delivered',
    'deliveryStatus': 'delivered',
    'customerName': 'Customer',
    'customerPhone': '03000000000',
    'deliveryAddress': 'Customer drop address',
    'paymentMode': 'COD',
    'totalPrice': 500,
    'createdAt': '2026-01-01T00:00:00.000Z',
  };

  Map<String, dynamic> get _remotePackage => {
    'id': 'PKG1',
    'status': 'accepted',
    'customerName': 'Customer',
    'customerPhone': '03000000000',
    'packageType': 'Parcel',
    'pickupAddress': 'Pickup',
    'dropAddress': 'Drop',
    'distanceKm': 5,
    'deliveryCharge': 50,
    'totalPrice': 50,
    'createdAt': '2026-01-01T00:00:00.000Z',
  };

  @override
  Future<Map<String, dynamic>> get({
    required String endpoint,
    Map<String, dynamic>? query,
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    if (endpoint == ApiConstants.orders) {
      orderListRequests += 1;
      return {
        'data': [_remoteOrder, _remoteOrder],
      };
    }
    if (endpoint == ApiConstants.orderById('ORD1')) {
      return _remoteOrder;
    }
    if (endpoint == ApiConstants.packageOrder) {
      packageListRequests += 1;
      if (failPackageRequests) {
        throw StateError('package API unavailable');
      }
      return {
        'data': [_remotePackage, _remotePackage],
      };
    }
    return const {};
  }
}

class _CountingServiceAreaGateService extends ServiceAreaGateService {
  _CountingServiceAreaGateService(GetStorage storage)
    : super(apiService: ApiService(storage: storage));

  int evaluateCalls = 0;

  @override
  Future<ServiceAreaGateResult> evaluate() async {
    evaluateCalls += 1;
    return ServiceAreaGateResult.allowed(
      locationLabel: 'Existing service area',
      latitude: 24.8607,
      longitude: 67.0011,
    );
  }
}
