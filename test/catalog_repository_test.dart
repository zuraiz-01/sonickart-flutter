import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sonic_cart/app/core/constants/api_constants.dart';
import 'package:sonic_cart/app/core/network/api_service.dart';
import 'package:sonic_cart/app/core/services/app_session_scope.dart';
import 'package:sonic_cart/app/data/models/address_model.dart';
import 'package:sonic_cart/app/data/repositories/catalog_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageContainer = 'catalog_repository_test';
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async {
          return '.dart_tool/test_storage/catalog_repository';
        });
    await GetStorage.init(storageContainer);
  });

  tearDown(() async {
    await GetStorage(storageContainer).erase();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test('service location product scope uses stored vendor id', () async {
    final storage = GetStorage(storageContainer);
    await storage.write('selectedLocationServiceable', true);
    await storage.write(
      AppSessionScope.selectedServiceLocationSessionKey,
      AppSessionScope.id,
    );
    await storage.write('selectedVendorId', 'vendor-1');
    await storage.write(
      'selectedAddress',
      const AddressModel(
        id: 'service-location',
        fullName: 'Customer',
        contactNumber: '',
        address: 'Guest selected serviceable address',
        latitude: 24.8607,
        longitude: 67.0011,
        vendorId: 'vendor-1',
        isSelected: true,
      ).toJson(),
    );
    final api = _FakeApiService(storage);
    final repository = CatalogRepository(api, storage: storage);

    final products = await repository.fetchProductsByCategory('cat-1');

    expect(products.map((item) => item.vendorId), ['vendor-1']);
    expect(api.resolveVendorCalls, 0);
    expect(api.productVendorIds, ['vendor-1']);
  });

  test(
    'stale service location product scope is ignored after app restart',
    () async {
      final storage = GetStorage(storageContainer);
      await storage.write('selectedLocationServiceable', true);
      await storage.write(
        AppSessionScope.selectedServiceLocationSessionKey,
        'old-app-run',
      );
      await storage.write('selectedVendorId', 'vendor-1');
      await storage.write(
        'selectedAddress',
        const AddressModel(
          id: 'service-location',
          fullName: 'Customer',
          contactNumber: '',
          address: 'Old app run serviceable address',
          latitude: 24.8607,
          longitude: 67.0011,
          vendorId: 'vendor-1',
          isSelected: true,
        ).toJson(),
      );
      final api = _FakeApiService(storage);
      final repository = CatalogRepository(api, storage: storage);

      final products = await repository.fetchProductsByCategory('cat-1');

      expect(products, isEmpty);
      expect(api.resolveVendorCalls, 0);
      expect(api.productVendorIds, isEmpty);
    },
  );

  test('saved selected address product scope uses stored vendor id', () async {
    final storage = GetStorage(storageContainer);
    await storage.write('selectedLocationServiceable', true);
    await storage.write('selectedVendorId', 'vendor-saved');
    await storage.write(
      'selectedAddress',
      const AddressModel(
        id: 'addr-1',
        fullName: 'Ali',
        contactNumber: '03000000000',
        address: 'Saved selected address',
        latitude: 24.95,
        longitude: 67.05,
        vendorId: 'vendor-saved',
        isSelected: true,
      ).toJson(),
    );
    final api = _FakeApiService(storage);
    final repository = CatalogRepository(api, storage: storage);

    final products = await repository.fetchProductsByCategory('cat-1');

    expect(products.map((item) => item.vendorId), ['vendor-saved']);
    expect(api.resolveVendorCalls, 0);
    expect(api.productVendorIds, ['vendor-saved']);
  });
}

class _FakeApiService extends ApiService {
  _FakeApiService(GetStorage storage) : super(storage: storage);

  int resolveVendorCalls = 0;
  final productVendorIds = <String?>[];

  @override
  Future<Map<String, dynamic>> get({
    required String endpoint,
    Map<String, dynamic>? query,
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    if (endpoint == ApiConstants.resolveVendor) {
      resolveVendorCalls += 1;
      return {
        'vendorIds': ['vendor-live'],
      };
    }
    if (endpoint == ApiConstants.productsByCategory('cat-1')) {
      productVendorIds.add(query?['vendorId']?.toString());
      return {
        'products': [
          {
            'id': 'product-1',
            'categoryId': 'cat-1',
            'name': 'Scoped product',
            'description': '',
            'unit': '1 pc',
            'price': '10',
            'mrp': '12',
            'vendorId': query?['vendorId'],
          },
        ],
      };
    }
    return const {};
  }
}
