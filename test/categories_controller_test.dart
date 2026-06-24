import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sonic_cart/app/core/constants/api_constants.dart';
import 'package:sonic_cart/app/core/network/api_service.dart';
import 'package:sonic_cart/app/data/models/address_model.dart';
import 'package:sonic_cart/app/data/models/category_model.dart';
import 'package:sonic_cart/app/data/models/product_model.dart';
import 'package:sonic_cart/app/data/models/product_subcategory_model.dart';
import 'package:sonic_cart/app/data/repositories/catalog_repository.dart';
import 'package:sonic_cart/app/modules/categories/controllers/categories_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageContainer = 'categories_controller_test';
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async {
          return '.dart_tool/test_storage/categories_controller';
        });
    await GetStorage.init(storageContainer);
  });

  tearDown(() async {
    await GetStorage(storageContainer).erase();
    Get.reset();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test('shows Other Products before real subcategory cards', () {
    final storage = GetStorage(storageContainer);
    final controller = CategoriesController(
      CatalogRepository(ApiService(storage: storage), storage: storage),
    );

    controller.selectedCategory.value = const CategoryModel(
      id: 'cat-1',
      name: 'Baby Care',
      emoji: '',
    );
    controller.subcategories.assignAll([
      const ProductSubcategoryModel(
        id: 'baby-food',
        categoryId: 'cat-1',
        name: 'Baby Food',
      ),
      const ProductSubcategoryModel(
        id: 'diapers',
        categoryId: 'cat-1',
        name: 'Diapers',
      ),
    ]);
    controller.categoryProducts.assignAll([
      const ProductModel(
        id: 'p-1',
        categoryId: 'cat-1',
        name: 'No Subcategory Product',
        description: '',
        unit: '1 pc',
        price: '10',
        mrp: '12',
        emoji: '',
      ),
      const ProductModel(
        id: 'p-2',
        categoryId: 'cat-1',
        name: 'Baby Food Product',
        description: '',
        unit: '1 pc',
        price: '20',
        mrp: '22',
        emoji: '',
        subcategoryId: 'baby-food',
        subcategoryName: 'Baby Food',
      ),
    ]);

    final options = controller.visibleSubcategoryOptions;

    expect(options, hasLength(3));
    expect(options.first.isMixed, isTrue);
    expect(options.first.name, 'Other Products');
    expect(options[1].name, 'Baby Food');
    expect(options[2].name, 'Diapers');
  });

  test('shows Other Products when category has only direct products', () {
    final storage = GetStorage(storageContainer);
    final controller = CategoriesController(
      CatalogRepository(ApiService(storage: storage), storage: storage),
    );

    controller.selectedCategory.value = const CategoryModel(
      id: 'cat-1',
      name: 'Snacks',
      emoji: '',
    );
    controller.categoryProducts.assignAll([
      const ProductModel(
        id: 'p-1',
        categoryId: 'cat-1',
        name: 'Direct Product',
        description: '',
        unit: '1 pc',
        price: '10',
        mrp: '12',
        emoji: '',
      ),
    ]);

    final options = controller.visibleSubcategoryOptions;

    expect(options, hasLength(1));
    expect(options.first.isMixed, isTrue);
    expect(options.first.name, 'Other Products');
  });

  test(
    'category product cache follows selected vendor scope changes',
    () async {
      final storage = GetStorage(storageContainer);
      await _writeSelectedScope(storage, 'vendor-a');
      final api = _CategoryFakeApiService(storage);
      final controller = CategoriesController(
        CatalogRepository(api, storage: storage),
      );
      controller.selectedCategory.value = const CategoryModel(
        id: 'cat-1',
        name: 'Grocery',
        emoji: '',
      );

      await controller.loadProducts('cat-1');

      expect(controller.categoryProducts.map((item) => item.vendorId), [
        'vendor-a',
      ]);

      await _writeSelectedScope(storage, 'vendor-b');
      await controller.loadProducts('cat-1');

      expect(controller.categoryProducts.map((item) => item.vendorId), [
        'vendor-b',
      ]);
      expect(api.productVendorIds, ['vendor-a', 'vendor-b']);
    },
  );

  test('initial product request waits until vendor scope is ready', () async {
    final storage = GetStorage(storageContainer);
    final api = _CategoryFakeApiService(storage);
    final scopeReady = Completer<void>();
    final controller = CategoriesController(
      CatalogRepository(api, storage: storage),
      initialCatalogContextReady: () => scopeReady.future,
    );
    final initialization = controller.initializeCatalog();

    await Future<void>.delayed(Duration.zero);

    expect(api.categoryRequestCount, 0);
    expect(api.productVendorIds, isEmpty);
    expect(controller.productsResolved.value, isFalse);

    await _writeSelectedScope(storage, 'vendor-first-open');
    scopeReady.complete();
    await initialization;

    expect(api.categoryRequestCount, 1);
    expect(api.productVendorIds, ['vendor-first-open']);
    expect(controller.categoryProducts, hasLength(1));
    expect(controller.categoryProducts.single.vendorId, 'vendor-first-open');
    expect(controller.productsResolved.value, isTrue);
  });
}

Future<void> _writeSelectedScope(GetStorage storage, String vendorId) async {
  await storage.write('selectedLocationServiceable', true);
  await storage.write('selectedVendorId', vendorId);
  await storage.write(
    'selectedAddress',
    AddressModel(
      id: 'addr-$vendorId',
      fullName: 'Customer',
      contactNumber: '',
      address: 'Address $vendorId',
      latitude: 24.8607,
      longitude: 67.0011,
      vendorId: vendorId,
      isSelected: true,
    ).toJson(),
  );
}

class _CategoryFakeApiService extends ApiService {
  _CategoryFakeApiService(GetStorage storage) : super(storage: storage);

  final productVendorIds = <String?>[];
  int categoryRequestCount = 0;

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
    if (endpoint == ApiConstants.productsByCategory('cat-1')) {
      final vendorId = query?['vendorId']?.toString();
      productVendorIds.add(vendorId);
      return {
        'products': [
          {
            'id': 'product-$vendorId',
            'categoryId': 'cat-1',
            'name': 'Scoped product $vendorId',
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
