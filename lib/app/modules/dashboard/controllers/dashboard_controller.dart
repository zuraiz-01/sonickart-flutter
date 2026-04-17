import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/catalog_repository.dart';

class DashboardController extends GetxController {
  final currentIndex = 0.obs;
  final currentPromoIndex = 0.obs;
  final currentSearchHintIndex = 0.obs;
  final isCatalogLoading = false.obs;
  final featuredProducts = <ProductModel>[].obs;
  final categories = <CategoryModel>[].obs;

  Timer? _promoTimer;
  Timer? _searchHintTimer;

  final searchHints = const [
    'Search "sweets"',
    'Search "milk"',
    'Search for ata, dal, coke',
    'Search "chips"',
    'Search "pooja thali"',
  ];

  final promoCards = const [
    'assets/images/slider1.jpeg',
    'assets/images/slider2.jpeg',
  ];

  final activeOrder = const {
    'id': 'SK1024',
    'items': 3,
    'title': 'Your order is on the way',
    'subtitle': 'Tap to track the delivery live.',
  };

  void changeTab(int index) {
    debugPrint('DashboardController.changeTab: switching to index $index');
    currentIndex.value = index;
  }

  void setTabFromNavigation(int index) {
    debugPrint('DashboardController.setTabFromNavigation: requested tab $index');
    currentIndex.value = index;
  }

  void nextPromo() {
    if (promoCards.isEmpty) return;
    currentPromoIndex.value = (currentPromoIndex.value + 1) % promoCards.length;
  }

  Future<void> loadCatalog() async {
    if (isCatalogLoading.value) return;
    isCatalogLoading.value = true;
    try {
      final repo = Get.find<CatalogRepository>();
      final loadedCategories = await repo.fetchCategories();
      categories.assignAll(loadedCategories);

      final loadedProducts = <ProductModel>[];
      for (final category in loadedCategories.take(6)) {
        final products = await repo.fetchProductsByCategory(category.id);
        loadedProducts.addAll(products.take(3));
        if (loadedProducts.length >= 12) break;
      }
      featuredProducts.assignAll(loadedProducts.take(12));
    } catch (error) {
      debugPrint('DashboardController.loadCatalog: failed $error');
    } finally {
      isCatalogLoading.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    final requestedIndex = (Get.arguments?['tabIndex'] as num?)?.toInt();
    if (requestedIndex != null && requestedIndex >= 0 && requestedIndex <= 4) {
      setTabFromNavigation(requestedIndex);
    }
    loadCatalog();
    _promoTimer = Timer.periodic(const Duration(seconds: 4), (_) => nextPromo());
    _searchHintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      currentSearchHintIndex.value =
          (currentSearchHintIndex.value + 1) % searchHints.length;
    });
  }

  @override
  void onClose() {
    _promoTimer?.cancel();
    _searchHintTimer?.cancel();
    super.onClose();
  }
}
