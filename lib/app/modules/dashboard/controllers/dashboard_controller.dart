import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/delivery_rating_dialog.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../routes/app_routes.dart';
import '../../order_controller.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../package/controllers/package_controller.dart';
import '../../profile/controllers/profile_controller.dart';

bool _dashboardTabNavigationQueued = false;
int? _queuedDashboardTabIndex;

void openDashboardTab(int index) {
  final targetIndex = _normalizeDashboardIndex(index);

  debugPrint(
    'openDashboardTab: target=$targetIndex currentRoute=${Get.currentRoute} registered=${Get.isRegistered<DashboardController>()}',
  );

  if (Get.isRegistered<DashboardController>()) {
    final controller = Get.find<DashboardController>();
    controller.setTabFromNavigation(targetIndex);

    if (Get.currentRoute == AppRoutes.dashboard) {
      return;
    }
  }

  _queuedDashboardTabIndex = targetIndex;
  if (_dashboardTabNavigationQueued) return;

  _dashboardTabNavigationQueued = true;

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final queuedTarget = _queuedDashboardTabIndex ?? targetIndex;
    _queuedDashboardTabIndex = null;
    try {
      await Get.offAllNamed(
        AppRoutes.dashboard,
        arguments: {'tabIndex': queuedTarget},
      );
      final latestQueuedTarget = _queuedDashboardTabIndex;
      if (latestQueuedTarget != null &&
          latestQueuedTarget != queuedTarget &&
          Get.isRegistered<DashboardController>()) {
        Get.find<DashboardController>().setTabFromNavigation(
          latestQueuedTarget,
        );
      }
    } catch (error) {
      debugPrint('openDashboardTab: navigation failed $error');
    } finally {
      _queuedDashboardTabIndex = null;
      _dashboardTabNavigationQueued = false;
    }
  });
}

int _normalizeDashboardIndex(int index) => index.clamp(0, 4);

class DashboardController extends GetxController {
  final currentIndex = 0.obs;
  final currentPromoIndex = 0.obs;
  final currentSearchHintIndex = 0.obs;
  final isCatalogLoading = false.obs;
  final isFeaturedLoading = false.obs;
  final featuredProducts = <ProductModel>[].obs;
  final categories = <CategoryModel>[].obs;

  static const _featuredLoadTimeout = Duration(seconds: 20);

  Timer? _searchHintTimer;
  Worker? _ratingWorker;
  int _catalogLoadRequestId = 0;

  bool _isChangingTab = false;

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
    final targetIndex = _normalizeDashboardIndex(index);
    final current = _normalizeDashboardIndex(currentIndex.value);

    debugPrint(
      'DashboardController.changeTab: current=$current target=$targetIndex',
    );

    if (current == targetIndex) {
      return;
    }

    if (_isChangingTab) return;

    _isChangingTab = true;

    try {
      _prepareForTabChange(targetIndex, allowSameTabRefresh: false);
      currentIndex.value = targetIndex;
      _afterTabSelected(targetIndex);
    } finally {
      _isChangingTab = false;
    }
  }

  void setTabFromNavigation(int index) {
    final targetIndex = _normalizeDashboardIndex(index);

    debugPrint(
      'DashboardController.setTabFromNavigation: requested tab $targetIndex',
    );

    _prepareForTabChange(targetIndex, allowSameTabRefresh: true);
    currentIndex.value = targetIndex;
    _afterTabSelected(targetIndex);
  }

  void refreshCurrentTab() {
    final index = _normalizeDashboardIndex(currentIndex.value);
    _prepareForTabChange(index, allowSameTabRefresh: true);
    _afterTabSelected(index);
  }

  void _prepareForTabChange(
    int nextIndex, {
    required bool allowSameTabRefresh,
  }) {
    final current = _normalizeDashboardIndex(currentIndex.value);
    final isSameTab = current == nextIndex;

    if (isSameTab && !allowSameTabRefresh) return;

    if (Get.isRegistered<ProfileController>()) {
      Get.find<ProfileController>().clearTransientOverlays();
    }

    if (Get.isRegistered<PackageController>()) {
      Get.find<PackageController>().closeTransientOverlays();
    }
  }

  void _afterTabSelected(int index) {
    if (index == 0) {
      unawaited(syncActiveProductOrder());
    }

    if (index == 2 && Get.isRegistered<CartController>()) {
      unawaited(Get.find<CartController>().syncCartFromStorage());
    }

    if (index == 3 && Get.isRegistered<PackageController>()) {
      unawaited(Get.find<PackageController>().loadOrders());
    }

    if (index == 4 && Get.isRegistered<ProfileController>()) {
      unawaited(Get.find<ProfileController>().loadProfileSummary());
    }
  }

  void nextPromo() {
    if (promoCards.isEmpty) return;

    currentPromoIndex.value = (currentPromoIndex.value + 1) % promoCards.length;
  }

  Future<void> loadCatalog({bool force = false}) async {
    if ((isCatalogLoading.value || isFeaturedLoading.value) && !force) return;

    final requestId = ++_catalogLoadRequestId;

    isCatalogLoading.value = true;
    isFeaturedLoading.value = true;

    try {
      final repo = Get.find<CatalogRepository>();

      if (force) {
        repo.invalidateProductScope();
        featuredProducts.clear();
      }

      await repo.loadDeliverySettings(force: force);

      if (!_isCurrentCatalogLoad(requestId)) return;

      final loadedCategories = await repo.fetchCategories();

      if (!_isCurrentCatalogLoad(requestId)) return;

      categories.assignAll(loadedCategories);
      isCatalogLoading.value = false;

      if (loadedCategories.isEmpty) {
        featuredProducts.clear();
        return;
      }

      final loadedFeatured = await repo
          .fetchFeaturedProducts(loadedCategories)
          .timeout(
            _featuredLoadTimeout,
            onTimeout: () {
              debugPrint('DashboardController.loadCatalog: featured timeout');
              return const <ProductModel>[];
            },
          );

      if (!_isCurrentCatalogLoad(requestId)) return;

      featuredProducts.assignAll(loadedFeatured);
    } catch (error) {
      if (_isCurrentCatalogLoad(requestId)) {
        debugPrint('DashboardController.loadCatalog: failed $error');
      }
    } finally {
      if (_isCurrentCatalogLoad(requestId)) {
        isCatalogLoading.value = false;
        isFeaturedLoading.value = false;
      }
    }
  }

  bool _isCurrentCatalogLoad(int requestId) {
    return requestId == _catalogLoadRequestId;
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
      currentIndex.value = requestedIndex;
      _afterTabSelected(requestedIndex);
    }

    unawaited(loadCatalog());
    unawaited(syncActiveProductOrder());

    _searchHintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (searchHints.isEmpty) return;

      currentSearchHintIndex.value =
          (currentSearchHintIndex.value + 1) % searchHints.length;
    });

    if (Get.isRegistered<OrderController>()) {
      _ratingWorker = ever(Get.find<OrderController>().needsRatingForOrder, (
        order,
      ) {
        if (order == null) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Get.overlayContext == null && Get.context == null) return;
          final orderController = Get.find<OrderController>();
          if (!orderController.beginDeliveryRatingPrompt(order)) return;

          Get.dialog(
            DeliveryRatingDialog(
              orderId: order.id,
              deliveryPartnerName: orderController.deliveryPartnerNameFor(
                order,
              ),
              onSubmitRating:
                  ({required orderId, required rating, required feedback}) =>
                      orderController.submitDeliveryRating(
                        orderId: orderId,
                        rating: rating,
                        feedback: feedback,
                      ),
              onRatingFlowComplete: orderController.endDeliveryRatingPrompt,
            ),
            barrierColor: Colors.black.withValues(alpha: 0.5),
          );
        });
      });
    }
  }

  @override
  void onClose() {
    _searchHintTimer?.cancel();
    _ratingWorker?.dispose();

    super.onClose();
  }
}
