import 'dart:async';

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
  final _productCache = <String, List<ProductModel>>{};
  final _productLoadFutures = <String, Future<List<ProductModel>>>{};
  String? _pendingCategoryId;
  String? _preferredVendorId;

  @override
  void onInit() {
    super.onInit();
    debugPrint('CategoriesController.onInit: starting category flow');
    _applyRouteArguments(Get.arguments);
    loadCategories();
  }

  void openFromRouteArguments(Object? arguments) {
    _applyRouteArguments(arguments);
    final categoryId = _pendingCategoryId;
    if (categoryId == null || categoryId.isEmpty) return;

    if (categories.isEmpty) {
      unawaited(loadCategories());
      return;
    }

    final target = categories.firstWhereOrNull(
      (category) => category.id == categoryId,
    );
    if (target == null) return;
    if (selectedCategory.value?.id == target.id) {
      unawaited(loadProducts(target.id));
      return;
    }
    unawaited(selectCategory(target));
  }

  Future<void> loadCategories() async {
    debugPrint('CategoriesController.loadCategories: loading categories');
    isCategoriesLoading.value = true;
    try {
      final result = await _repository.fetchCategories();
      categories.assignAll(result);

      final initialCategoryId = _pendingCategoryId;
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
      _prefetchRemainingCategories(target?.id);
    } finally {
      isCategoriesLoading.value = false;
    }
  }

  void _applyRouteArguments(Object? arguments) {
    if (arguments is! Map) return;

    final productId = arguments['productId']?.toString();
    targetProductId.value = productId == null || productId.isEmpty
        ? null
        : productId;

    final preferredVendorId = arguments['preferredVendorId']?.toString();
    if (preferredVendorId != _preferredVendorId) {
      _preferredVendorId = preferredVendorId;
      _productCache.clear();
      _productLoadFutures.clear();
    }

    final categoryId = arguments['categoryId']?.toString();
    if (categoryId != null && categoryId.isNotEmpty) {
      _pendingCategoryId = categoryId;
    }
  }

  Future<void> selectCategory(CategoryModel category) async {
    debugPrint(
      'CategoriesController.selectCategory: selected ${category.id} ${category.name}',
    );
    selectedCategory.value = category;
    await loadProducts(category.id);
  }

  Future<void> reloadSelectedCategory({bool force = false}) async {
    final category = selectedCategory.value;
    if (category == null) return;
    if (force) {
      _productCache.clear();
      _productLoadFutures.clear();
    }
    await loadProducts(category.id);
  }

  Future<void> loadProducts(String categoryId) async {
    debugPrint(
      'CategoriesController.loadProducts: loading products for $categoryId',
    );
    final cacheKey = _productCacheKey(categoryId);
    final cached = _productCache[cacheKey];
    if (cached != null) {
      products.assignAll(cached);
      return;
    }

    isProductsLoading.value = true;
    try {
      final result = await _loadProductsForCategory(categoryId);
      if (selectedCategory.value?.id != categoryId) return;
      products.assignAll(result);
    } finally {
      isProductsLoading.value = false;
    }
  }

  Future<List<ProductModel>> _loadProductsForCategory(String categoryId) {
    final cacheKey = _productCacheKey(categoryId);
    final cached = _productCache[cacheKey];
    if (cached != null) return Future.value(cached);

    final inFlight = _productLoadFutures[cacheKey];
    if (inFlight != null) return inFlight;

    final future = _repository
        .fetchProductsByCategory(
          categoryId,
          preferredVendorId: _preferredVendorId,
        )
        .then((result) {
          _productCache[cacheKey] = result;
          return result;
        });
    _productLoadFutures[cacheKey] = future;
    return future.whenComplete(() => _productLoadFutures.remove(cacheKey));
  }

  String _productCacheKey(String categoryId) =>
      '$categoryId|${_preferredVendorId ?? ''}';

  void _prefetchRemainingCategories(String? selectedId) {
    final ids = categories
        .map((category) => category.id)
        .where((id) => id.isNotEmpty && id != selectedId)
        .take(8)
        .toList(growable: false);
    if (ids.isEmpty) return;

    unawaited(() async {
      const batchSize = 2;
      for (var start = 0; start < ids.length; start += batchSize) {
        await Future.wait(
          ids
              .skip(start)
              .take(batchSize)
              .map(
                (id) => _loadProductsForCategory(
                  id,
                ).catchError((_) => const <ProductModel>[]),
              ),
        );
      }
    }());
  }
}
