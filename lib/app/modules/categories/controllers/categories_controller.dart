import 'dart:async';

import 'package:flutter/widgets.dart';
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
  final productsResolved = false.obs;
  final targetProductId = RxnString();

  final categoryListScrollController = ScrollController();
  final productGridScrollController = ScrollController();

  static const categoryListItemExtent = 124.0;
  static const _productLoadTimeout = Duration(seconds: 24);

  final _productCache = <String, List<ProductModel>>{};
  final _productLoadFutures = <String, Future<List<ProductModel>>>{};

  Future<void>? _categoriesLoadFuture;

  int _productsRequestId = 0;
  String? _pendingCategoryId;
  String? _preferredVendorId;

  int _productCacheGeneration = 0;
  String? _lastResolvedProductCacheKey;
  String? _currentlyLoadingProductCacheKey;

  @override
  void onInit() {
    super.onInit();

    debugPrint('CategoriesController.onInit: starting category flow');

    _applyRouteArguments(Get.arguments);
    unawaited(loadCategories());
  }

  void openFromRouteArguments(Object? arguments) {
    if (arguments is! Map) return;
    if (!_hasCategoryRouteArguments(arguments)) return;

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
      _scrollToSelectedCategory();

      final cacheKey = _productCacheKey(target.id);

      if (_lastResolvedProductCacheKey == cacheKey && productsResolved.value) {
        _scrollToTargetProduct();
        return;
      }

      if (_currentlyLoadingProductCacheKey == cacheKey &&
          isProductsLoading.value) {
        return;
      }

      unawaited(loadProducts(target.id));
      return;
    }

    unawaited(selectCategory(target));
  }

  Future<void> loadCategories() {
    final existingFuture = _categoriesLoadFuture;
    if (existingFuture != null) return existingFuture;

    _categoriesLoadFuture = _loadCategoriesInternal();

    return _categoriesLoadFuture!.whenComplete(() {
      _categoriesLoadFuture = null;
    });
  }

  Future<void> _loadCategoriesInternal() async {
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
        isCategoriesLoading.value = false;
        await selectCategory(target);
      }
    } catch (error) {
      debugPrint('CategoriesController.loadCategories: failed $error');
    } finally {
      isCategoriesLoading.value = false;
    }
  }

  bool _hasCategoryRouteArguments(Map arguments) {
    final categoryId = arguments['categoryId']?.toString();
    return categoryId != null && categoryId.isNotEmpty;
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
      _productCacheGeneration++;

      _lastResolvedProductCacheKey = null;
      _currentlyLoadingProductCacheKey = null;
      _productsRequestId++;
      isProductsLoading.value = false;
      productsResolved.value = false;
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

    final cacheKey = _productCacheKey(category.id);
    final isSameCategory = selectedCategory.value?.id == category.id;

    selectedCategory.value = category;
    _scrollToSelectedCategory();

    if (isSameCategory &&
        _lastResolvedProductCacheKey == cacheKey &&
        productsResolved.value) {
      _scrollToTargetProduct();
      return;
    }

    if (_currentlyLoadingProductCacheKey == cacheKey &&
        isProductsLoading.value) {
      return;
    }

    await loadProducts(category.id);
  }

  bool shouldIgnoreCategoryTap(CategoryModel category) {
    if (selectedCategory.value?.id == category.id) return true;

    final cacheKey = _productCacheKey(category.id);
    return _currentlyLoadingProductCacheKey == cacheKey &&
        isProductsLoading.value;
  }

  Future<void> reloadSelectedCategory({bool force = false}) async {
    final category = selectedCategory.value;
    if (category == null) return;

    if (force) {
      _productCache.clear();
      _productLoadFutures.clear();
      _productCacheGeneration++;
      _lastResolvedProductCacheKey = null;
      _currentlyLoadingProductCacheKey = null;
      productsResolved.value = false;
    }

    await loadProducts(category.id, force: force);
  }

  Future<void> loadProducts(String categoryId, {bool force = false}) async {
    final cacheKey = _productCacheKey(categoryId);

    debugPrint(
      'CategoriesController.loadProducts: loading products for $categoryId',
    );

    if (!force &&
        _lastResolvedProductCacheKey == cacheKey &&
        productsResolved.value) {
      _scrollToTargetProduct();
      return;
    }

    if (!force &&
        _currentlyLoadingProductCacheKey == cacheKey &&
        isProductsLoading.value) {
      return;
    }

    final cached = force ? null : _productCache[cacheKey];

    if (cached != null) {
      products.assignAll(cached);
      productsResolved.value = true;
      isProductsLoading.value = false;
      _lastResolvedProductCacheKey = cacheKey;
      _currentlyLoadingProductCacheKey = null;
      _scrollToTargetProduct();
      return;
    }

    final requestId = ++_productsRequestId;

    productsResolved.value = false;
    isProductsLoading.value = true;
    _currentlyLoadingProductCacheKey = cacheKey;

    try {
      final result = await _loadProductsForCategory(categoryId, force: force)
          .timeout(
            _productLoadTimeout,
            onTimeout: () {
              debugPrint(
                'CategoriesController.loadProducts: timed out for $categoryId',
              );
              return const <ProductModel>[];
            },
          );

      if (!_isCurrentProductRequest(requestId, categoryId)) return;

      products.assignAll(result);
      productsResolved.value = true;
      _lastResolvedProductCacheKey = cacheKey;
      _scrollToTargetProduct();
    } catch (error) {
      debugPrint('CategoriesController.loadProducts: failed $error');

      if (_isCurrentProductRequest(requestId, categoryId)) {
        products.clear();
        productsResolved.value = true;
        _lastResolvedProductCacheKey = cacheKey;
      }
    } finally {
      if (_isCurrentProductRequest(requestId, categoryId)) {
        isProductsLoading.value = false;

        if (_currentlyLoadingProductCacheKey == cacheKey) {
          _currentlyLoadingProductCacheKey = null;
        }
      }
    }
  }

  Future<List<ProductModel>> _loadProductsForCategory(
    String categoryId, {
    bool force = false,
  }) {
    final cacheKey = _productCacheKey(categoryId);

    if (force) {
      _productCache.remove(cacheKey);
      _productLoadFutures.remove(cacheKey);
      _productCacheGeneration++;
    }

    final cached = _productCache[cacheKey];
    if (!force && cached != null) return Future.value(cached);

    final inFlight = _productLoadFutures[cacheKey];
    if (!force && inFlight != null) return inFlight;

    final generation = _productCacheGeneration;
    final future = _repository
        .fetchProductsByCategory(
          categoryId,
          preferredVendorId: _preferredVendorId,
        )
        .then((result) {
          if (generation == _productCacheGeneration) {
            _productCache[cacheKey] = result;
          }
          return result;
        });

    _productLoadFutures[cacheKey] = future;

    return future.whenComplete(() {
      if (identical(_productLoadFutures[cacheKey], future)) {
        _productLoadFutures.remove(cacheKey);
      }
    });
  }

  String _productCacheKey(String categoryId) {
    return '$categoryId|${_preferredVendorId ?? ''}';
  }

  bool _isCurrentProductRequest(int requestId, String categoryId) {
    return requestId == _productsRequestId &&
        selectedCategory.value?.id == categoryId;
  }

  void _scrollToSelectedCategory() {
    final selected = selectedCategory.value;
    if (selected == null || categories.isEmpty) return;

    final categoryIndex = categories.indexWhere(
      (category) => category.id == selected.id,
    );

    if (categoryIndex < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!categoryListScrollController.hasClients) return;

      final position = categoryListScrollController.position;

      final centeredOffset =
          categoryIndex * categoryListItemExtent -
          ((position.viewportDimension - categoryListItemExtent) / 2);

      final targetOffset = centeredOffset
          .clamp(0.0, position.maxScrollExtent)
          .toDouble();

      if ((position.pixels - targetOffset).abs() < 2) return;

      categoryListScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _scrollToTargetProduct() {
    final productId = targetProductId.value;

    if (productId == null || productId.isEmpty || products.isEmpty) return;

    final productIndex = products.indexWhere(
      (product) => product.id == productId,
    );

    if (productIndex < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!productGridScrollController.hasClients) return;

      const columns = 2;
      const horizontalPadding = 16.0;
      const crossAxisSpacing = 8.0;
      const mainAxisSpacing = 10.0;
      const topPadding = 8.0;
      const childAspectRatio = 0.50;

      final gridWidth = Get.width * 0.70;

      final tileWidth =
          (gridWidth - horizontalPadding - crossAxisSpacing) / columns;

      final tileHeight = tileWidth / childAspectRatio;

      final rowIndex = productIndex ~/ columns;

      final rawOffset = topPadding + rowIndex * (tileHeight + mainAxisSpacing);

      final maxOffset = productGridScrollController.position.maxScrollExtent;

      final targetOffset = rawOffset.clamp(0.0, maxOffset).toDouble();

      productGridScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );

      targetProductId.value = null;
    });
  }

  @override
  void onClose() {
    categoryListScrollController.dispose();
    productGridScrollController.dispose();

    super.onClose();
  }
}
