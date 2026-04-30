import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../routes/app_routes.dart';
import '../../order_controller.dart';

void openDashboardTab(int index) {
  final targetIndex = index.clamp(0, 4);
  debugPrint(
    'openDashboardTab: target=$targetIndex currentRoute=${Get.currentRoute} registered=${Get.isRegistered<DashboardController>()}',
  );

  if (Get.isRegistered<DashboardController>()) {
    final controller = Get.find<DashboardController>();
    controller.setTabFromNavigation(targetIndex);

    if (Get.currentRoute == AppRoutes.dashboard) {
      return;
    }

    var foundDashboardRoute = false;
    Get.until((route) {
      final isDashboardRoute = route.settings.name == AppRoutes.dashboard;
      if (isDashboardRoute) {
        foundDashboardRoute = true;
      }
      return isDashboardRoute;
    });

    if (foundDashboardRoute) {
      return;
    }
  }

  Get.offNamed(AppRoutes.dashboard, arguments: {'tabIndex': targetIndex});
}

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

  void changeTab(int index) {
    debugPrint('DashboardController.changeTab: switching to index $index');
    currentIndex.value = index;
    if (index == 0) {
      unawaited(syncActiveProductOrder());
    }
  }

  void setTabFromNavigation(int index) {
    debugPrint(
      'DashboardController.setTabFromNavigation: requested tab $index',
    );
    currentIndex.value = index;
    if (index == 0) {
      unawaited(syncActiveProductOrder());
    }
  }

  void nextPromo() {
    if (promoCards.isEmpty) return;
    currentPromoIndex.value = (currentPromoIndex.value + 1) % promoCards.length;
  }

  Future<void> loadCatalog({bool force = false}) async {
    if (isCatalogLoading.value && !force) return;
    isCatalogLoading.value = true;
    try {
      final repo = Get.find<CatalogRepository>();
      await repo.loadDeliverySettings(force: force);
      final loadedCategories = await repo.fetchCategories();
      categories.assignAll(loadedCategories);
      featuredProducts.assignAll(
        await repo.fetchFeaturedProducts(loadedCategories),
      );
    } catch (error) {
      debugPrint('DashboardController.loadCatalog: failed $error');
    } finally {
      isCatalogLoading.value = false;
    }
  }

  Future<void> syncActiveProductOrder() async {
    if (!Get.isRegistered<OrderController>()) return;
    await Get.find<OrderController>().syncActiveProductOrder();
  }

  @override
  void onInit() {
    super.onInit();
    final requestedIndex = (Get.arguments?['tabIndex'] as num?)?.toInt();
    if (requestedIndex != null && requestedIndex >= 0 && requestedIndex <= 4) {
      setTabFromNavigation(requestedIndex);
    }
    loadCatalog();
    unawaited(syncActiveProductOrder());
    _promoTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => nextPromo(),
    );
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
