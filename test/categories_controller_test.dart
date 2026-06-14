import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sonic_cart/app/core/network/api_service.dart';
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
}
