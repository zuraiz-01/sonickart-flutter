import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sonic_cart/app/core/constants/api_constants.dart';
import 'package:sonic_cart/app/core/network/api_service.dart';
import 'package:sonic_cart/app/core/services/app_session_scope.dart';
import 'package:sonic_cart/app/data/models/address_model.dart';
import 'package:sonic_cart/app/data/models/category_model.dart';
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
    await GetStorage.init();
    await GetStorage.init(storageContainer);
  });

  tearDown(() async {
    await GetStorage().erase();
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

  test('live location product scope uses stored vendor id', () async {
    final storage = GetStorage(storageContainer);
    await storage.write('selectedLocationServiceable', true);
    await storage.write('selectedVendorId', 'vendor-live-stored');
    await storage.write(
      'selectedAddress',
      const AddressModel(
        id: 'live-location',
        fullName: 'Customer',
        contactNumber: '',
        address: 'Fresh live location',
        latitude: 24.95,
        longitude: 67.05,
        vendorId: 'vendor-live-stored',
        isSelected: true,
      ).toJson(),
    );
    final api = _FakeApiService(storage);
    final repository = CatalogRepository(api, storage: storage);

    final products = await repository.fetchProductsByCategory('cat-1');

    expect(products.map((item) => item.vendorId), ['vendor-live-stored']);
    expect(api.resolveVendorCalls, 0);
    expect(api.productVendorIds, ['vendor-live-stored']);
  });

  test('category products ignore records from another category', () async {
    final storage = GetStorage(storageContainer);
    await storage.write('selectedLocationServiceable', true);
    await storage.write('selectedVendorId', 'vendor-1');
    await storage.write(
      'selectedAddress',
      const AddressModel(
        id: 'addr-1',
        fullName: 'Ali',
        contactNumber: '03000000000',
        address: 'Saved selected address',
        latitude: 24.95,
        longitude: 67.05,
        vendorId: 'vendor-1',
        isSelected: true,
      ).toJson(),
    );
    final api = _FakeApiService(storage)..includeMismatchedCategory = true;
    final repository = CatalogRepository(api, storage: storage);

    final products = await repository.fetchProductsByCategory('cat-1');

    expect(products.map((item) => item.id), ['product-1']);
  });

  test(
    'featured products stay inside selected vendor and address radius scope',
    () async {
      final storage = GetStorage(storageContainer);
      await storage.write('selectedLocationServiceable', true);
      await storage.write('selectedVendorId', 'vendor-1');
      await storage.write(
        'selectedAddress',
        const AddressModel(
          id: 'addr-1',
          fullName: 'Ali',
          contactNumber: '03000000000',
          address: 'Saved selected address',
          latitude: 24.95,
          longitude: 67.05,
          vendorId: 'vendor-1',
          isSelected: true,
        ).toJson(),
      );
      final api = _FakeApiService(storage)..includeOtherVendorProducts = true;
      final repository = CatalogRepository(api, storage: storage);

      final products = await repository.fetchFeaturedProducts(const [
        _TestCategoryModel(id: 'cat-1', name: 'Grocery'),
        _TestCategoryModel(id: 'cat-2', name: 'Snacks'),
      ]);

      expect(products, hasLength(2));
      expect(products.map((item) => item.vendorId).toSet(), {'vendor-1'});
      expect(products.map((item) => item.id).toSet(), {
        'cat-1-vendor-1',
        'cat-2-vendor-1',
      });
      expect(api.resolveVendorCalls, 0);
      expect(api.productQueries, hasLength(2));
      for (final query in api.productQueries) {
        expect(query['vendorId'], 'vendor-1');
        expect(query['latitude'], 24.95);
        expect(query['longitude'], 67.05);
        expect(query['radiusKm'], 50.0);
      }
    },
  );
}

class _FakeApiService extends ApiService {
  _FakeApiService(GetStorage storage) : super(storage: storage);

  int resolveVendorCalls = 0;
  bool includeMismatchedCategory = false;
  bool includeOtherVendorProducts = false;
  final productVendorIds = <String?>[];
  final productQueries = <Map<String, dynamic>>[];

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
    if (endpoint == ApiConstants.productsByCategory('cat-1') ||
        endpoint == ApiConstants.productsByCategory('cat-2')) {
      final categoryId = endpoint.endsWith('/cat-2') ? 'cat-2' : 'cat-1';
      final vendorId = query?['vendorId']?.toString();
      productVendorIds.add(query?['vendorId']?.toString());
      productQueries.add(Map<String, dynamic>.from(query ?? const {}));
      return {
        'products': [
          {
            'id': includeOtherVendorProducts
                ? '$categoryId-$vendorId'
                : 'product-1',
            'categoryId': categoryId,
            'name': 'Scoped product',
            'description': '',
            'unit': '1 pc',
            'price': '10',
            'mrp': '12',
            'vendorId': vendorId,
          },
          if (includeMismatchedCategory)
            {
              'id': 'product-other-category',
              'categoryId': 'cat-2',
              'name': 'Wrong category product',
              'description': '',
              'unit': '1 pc',
              'price': '10',
              'mrp': '12',
              'vendorId': query?['vendorId'],
            },
          if (includeOtherVendorProducts)
            {
              'id': '$categoryId-other-vendor',
              'categoryId': categoryId,
              'name': 'Other vendor product',
              'description': '',
              'unit': '1 pc',
              'price': '10',
              'mrp': '12',
              'vendorId': 'vendor-other',
            },
        ],
      };
    }
    return const {};
  }
}

class _TestCategoryModel extends CategoryModel {
  const _TestCategoryModel({required super.id, required super.name})
    : super(emoji: '');
}
