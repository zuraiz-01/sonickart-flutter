import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/catalog_repository.dart';

class CategoriesController extends GetxController {
  CategoriesController(this._repository);

  final CatalogRepository _repository;

  final categories = <CategoryModel>[].obs;
  final products = <ProductModel>[].obs;
  final selectedCategory = Rxn<CategoryModel>();
  final isCategoriesLoading = false.obs;
  final isProductsLoading = false.obs;
  final targetProductId = RxnString();
  String? _preferredVendorId;

  @override
  void onInit() {
    super.onInit();
    debugPrint('CategoriesController.onInit: starting category flow');
    targetProductId.value = Get.arguments?['productId']?.toString();
    _preferredVendorId = Get.arguments?['preferredVendorId']?.toString();
    loadCategories();
  }

  Future<void> loadCategories() async {
    debugPrint('CategoriesController.loadCategories: loading categories');
    isCategoriesLoading.value = true;
    try {
      final result = await _repository.fetchCategories();
      categories.assignAll(result);

      final initialCategoryId = Get.arguments?['categoryId']?.toString();
      CategoryModel? target;
      if (initialCategoryId != null && initialCategoryId.isNotEmpty) {
        for (final category in result) {
          if (category.id == initialCategoryId) {
            target = category;
            break;
          }
        }
      }
      target ??= result.isNotEmpty ? result.first : null;
      if (target != null) {
        await selectCategory(target);
      }
    } finally {
      isCategoriesLoading.value = false;
    }
  }

  Future<void> selectCategory(CategoryModel category) async {
    debugPrint(
      'CategoriesController.selectCategory: selected ${category.id} ${category.name}',
    );
    selectedCategory.value = category;
    await loadProducts(category.id);
  }

  Future<void> reloadSelectedCategory() async {
    final category = selectedCategory.value;
    if (category == null) return;
    await loadProducts(category.id);
  }

  Future<void> loadProducts(String categoryId) async {
    debugPrint(
      'CategoriesController.loadProducts: loading products for $categoryId',
    );
    isProductsLoading.value = true;
    try {
      final result = await _repository.fetchProductsByCategory(
        categoryId,
        preferredVendorId: _preferredVendorId,
      );
      products.assignAll(result);
    } finally {
      isProductsLoading.value = false;
    }
  }
}
