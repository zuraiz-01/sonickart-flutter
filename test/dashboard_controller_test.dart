import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sonic_cart/app/core/constants/api_constants.dart';
import 'package:sonic_cart/app/core/network/api_service.dart';
import 'package:sonic_cart/app/core/services/service_area_gate_controller.dart';
import 'package:sonic_cart/app/core/services/service_area_gate_service.dart';
import 'package:sonic_cart/app/data/repositories/catalog_repository.dart';
import 'package:sonic_cart/app/modules/dashboard/controllers/dashboard_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async {
          return '.dart_tool/test_storage/dashboard_controller';
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

  test('bottom tab indexes map categories before cart', () {
    final controller = DashboardController();

    controller.changeTab(1);
    expect(controller.currentIndex.value, 1);

    controller.changeTab(2);
    expect(controller.currentIndex.value, 2);

    controller.changeTab(1);
    expect(controller.currentIndex.value, 1);
  });

  test(
    'home categories load before first service area check finishes',
    () async {
      final storage = GetStorage();
      final api = _DashboardFakeApiService(storage);
      Get.put<ApiService>(api);
      Get.put<CatalogRepository>(
        CatalogRepository(api, storage: storage),
        permanent: true,
      );
      final serviceArea = _BlockingServiceAreaGateService(storage);
      final gate = Get.put(
        ServiceAreaGateController(serviceAreaGateService: serviceArea),
        permanent: true,
      );
      addTearDown(gate.onClose);

      final controller = DashboardController();
      addTearDown(controller.onClose);
      final load = controller.loadCatalog();

      await _pumpUntil(() => api.categoryRequestCount == 1);

      expect(controller.categories, hasLength(1));
      expect(api.productVendorIds, isEmpty);
      expect(controller.isFeaturedLoading.value, isTrue);

      serviceArea.completeAllowed();
      await load;

      expect(api.resolveVendorCalls, 1);
      expect(api.productVendorIds, ['vendor-live']);
      expect(controller.featuredProducts, hasLength(1));
      expect(controller.isFeaturedLoading.value, isFalse);
    },
  );

  test('featured loader stops if first service area check hangs', () async {
    final storage = GetStorage();
    final api = _DashboardFakeApiService(storage);
    Get.put<ApiService>(api);
    Get.put<CatalogRepository>(
      CatalogRepository(api, storage: storage),
      permanent: true,
    );
    final gate = Get.put(
      ServiceAreaGateController(
        serviceAreaGateService: _NeverCompletesServiceAreaGateService(storage),
      ),
      permanent: true,
    );
    addTearDown(gate.onClose);

    final controller = DashboardController(
      initialCatalogContextTimeout: const Duration(milliseconds: 1),
      settingsLoadTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(controller.onClose);

    await controller.loadCatalog();

    expect(controller.categories, hasLength(1));
    expect(controller.isCatalogLoading.value, isFalse);
    expect(controller.isFeaturedLoading.value, isFalse);
  });
}

Future<void> _pumpUntil(bool Function() condition, {int attempts = 20}) async {
  for (var i = 0; i < attempts; i += 1) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
}

class _BlockingServiceAreaGateService extends ServiceAreaGateService {
  _BlockingServiceAreaGateService(GetStorage storage)
    : super(apiService: ApiService(storage: storage));

  final _completer = Completer<ServiceAreaGateResult>();

  @override
  Future<ServiceAreaGateResult> evaluate() => _completer.future;

  void completeAllowed() {
    if (_completer.isCompleted) return;
    _completer.complete(
      ServiceAreaGateResult.allowed(
        locationLabel: 'Fresh install serviceable location',
        latitude: 24.8607,
        longitude: 67.0011,
      ),
    );
  }
}

class _NeverCompletesServiceAreaGateService extends ServiceAreaGateService {
  _NeverCompletesServiceAreaGateService(GetStorage storage)
    : super(apiService: ApiService(storage: storage));

  @override
  Future<ServiceAreaGateResult> evaluate() =>
      Completer<ServiceAreaGateResult>().future;
}

class _DashboardFakeApiService extends ApiService {
  _DashboardFakeApiService(GetStorage storage) : super(storage: storage);

  int categoryRequestCount = 0;
  int resolveVendorCalls = 0;
  final productVendorIds = <String?>[];

  @override
  Future<Map<String, dynamic>> get({
    required String endpoint,
    Map<String, dynamic>? query,
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    if (endpoint == ApiConstants.categories) {
      categoryRequestCount += 1;
      return {
        'categories': [
          {'id': 'cat-1', 'name': 'Grocery'},
        ],
      };
    }
    if (endpoint == ApiConstants.resolveVendor) {
      resolveVendorCalls += 1;
      return {
        'vendorIds': ['vendor-live'],
      };
    }
    if (endpoint == ApiConstants.productsByCategory('cat-1')) {
      final vendorId = query?['vendorId']?.toString();
      productVendorIds.add(vendorId);
      return {
        'products': [
          {
            'id': 'product-$vendorId',
            'categoryId': 'cat-1',
            'name': 'Scoped product',
            'description': '',
            'unit': '1 pc',
            'price': '10',
            'mrp': '12',
            'vendorId': vendorId,
          },
        ],
      };
    }
    return const {};
  }
}
