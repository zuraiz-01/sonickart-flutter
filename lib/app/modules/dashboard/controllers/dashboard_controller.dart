import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/service_area_gate_controller.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/widgets/delivery_rating_dialog.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../routes/app_routes.dart';
import '../../order_controller.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../categories/controllers/categories_controller.dart';
import '../../package/controllers/package_controller.dart';
import '../../profile/controllers/profile_controller.dart';

void openDashboardTab(int index, {Object? arguments}) {
  final targetIndex = _normalizeDashboardIndex(index);

  if (targetIndex == 4 && !requireAuth()) return;

  debugPrint(
    'openDashboardTab: target=$targetIndex currentRoute=${Get.currentRoute} registered=${Get.isRegistered<DashboardController>()}',
  );

  if (Get.currentRoute == AppRoutes.dashboard) {
    _setDashboardTabIfReady(targetIndex, arguments: arguments);
    return;
  }

  // Update a live controller now; route arguments initialize a replacement.
  _setDashboardTabIfReady(targetIndex, arguments: arguments);
  try {
    final navigation = Get.offAllNamed<void>(
      AppRoutes.dashboard,
      arguments: {'tabIndex': targetIndex},
    );
    // This future completes when the dashboard route is later removed.
    if (navigation != null) {
      unawaited(
        navigation.then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('openDashboardTab: navigation failed $error');
            debugPrintStack(stackTrace: stackTrace);
          },
        ),
      );
    }
  } catch (error) {
    debugPrint('openDashboardTab: navigation failed $error');
  }
}

void _setDashboardTabIfReady(int targetIndex, {Object? arguments}) {
  if (!Get.isRegistered<DashboardController>() &&
      !Get.isPrepared<DashboardController>()) {
    return;
  }

  try {
    Get.find<DashboardController>().setTabFromNavigation(targetIndex);
    _applyDashboardTabArguments(targetIndex, arguments);
  } catch (error) {
    debugPrint('openDashboardTab: controller not ready $error');
  }
}

void _applyDashboardTabArguments(int targetIndex, Object? arguments) {
  if (targetIndex != 1 || arguments == null) return;
  if (!Get.isRegistered<CategoriesController>()) return;

  try {
    Get.find<CategoriesController>().openFromRouteArguments(arguments);
  } catch (error) {
    debugPrint('openDashboardTab: category arguments failed $error');
  }
}

int _normalizeDashboardIndex(int index) => index.clamp(0, 4);

class DashboardController extends GetxController with WidgetsBindingObserver {
  DashboardController({
    Duration initialCatalogContextTimeout =
        _defaultInitialCatalogContextTimeout,
    Duration settingsLoadTimeout = _defaultSettingsLoadTimeout,
    Duration resumeLocationRefreshInterval =
        _defaultResumeLocationRefreshInterval,
    DateTime Function()? clock,
  }) : _initialCatalogContextTimeout = initialCatalogContextTimeout,
       _settingsLoadTimeout = settingsLoadTimeout,
       _resumeLocationRefreshInterval = resumeLocationRefreshInterval,
       _clock = clock ?? DateTime.now;

  final currentIndex = 0.obs;
  final currentSearchHintIndex = 0.obs;
  final isCatalogLoading = false.obs;
  final isFeaturedLoading = false.obs;
  final featuredProducts = <ProductModel>[].obs;
  final categories = <CategoryModel>[].obs;

  static const _defaultInitialCatalogContextTimeout = Duration(seconds: 10);
  static const _defaultSettingsLoadTimeout = Duration(seconds: 8);
  static const _featuredLoadTimeout = Duration(seconds: 20);
  static const _defaultResumeLocationRefreshInterval = Duration(seconds: 5);

  final Duration _initialCatalogContextTimeout;
  final Duration _settingsLoadTimeout;
  final Duration _resumeLocationRefreshInterval;
  final DateTime Function() _clock;
  Timer? _searchHintTimer;
  Worker? _ratingWorker;
  Future<void>? _appOpenLocationRefresh;
  DateTime? _lastAppOpenLocationRefreshAt;
  bool _wasAwayFromForeground = false;
  int _catalogLoadRequestId = 0;

  final searchHints = const [
    'Search "sweets"',
    'Search "milk"',
    'Search for ata, dal, coke',
    'Search "chips"',
    'Search "pooja thali"',
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

    if (targetIndex == 4 && !requireAuth()) return;

    currentIndex.value = targetIndex;
    _runTabSideEffects(
      targetIndex,
      previousIndex: current,
      allowSameTabRefresh: false,
    );
  }

  void setTabFromNavigation(int index) {
    final targetIndex = _normalizeDashboardIndex(index);
    final current = _normalizeDashboardIndex(currentIndex.value);

    debugPrint(
      'DashboardController.setTabFromNavigation: requested tab $targetIndex',
    );

    if (targetIndex == 4 && !requireAuth()) return;

    currentIndex.value = targetIndex;
    _runTabSideEffects(
      targetIndex,
      previousIndex: current,
      allowSameTabRefresh: true,
    );
  }

  void refreshCurrentTab() {
    final index = _normalizeDashboardIndex(currentIndex.value);
    _runTabSideEffects(index, allowSameTabRefresh: true);
  }

  void _runTabSideEffects(
    int index, {
    int? previousIndex,
    required bool allowSameTabRefresh,
  }) {
    try {
      _prepareForTabChange(
        index,
        previousIndex: previousIndex,
        allowSameTabRefresh: allowSameTabRefresh,
      );
    } catch (error, stackTrace) {
      debugPrint('DashboardController.changeTab cleanup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      _afterTabSelected(index);
    } catch (error, stackTrace) {
      debugPrint('DashboardController.changeTab side effect failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _prepareForTabChange(
    int nextIndex, {
    int? previousIndex,
    required bool allowSameTabRefresh,
  }) {
    final current = _normalizeDashboardIndex(
      previousIndex ?? currentIndex.value,
    );
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

      final contextReady = force
          ? Future<void>.value()
          : _ensureInitialCatalogContextReady();
      final settingsReady = repo.loadDeliverySettings(force: force);

      final loadedCategories = await repo.fetchCategories();

      if (!_isCurrentCatalogLoad(requestId)) return;

      categories.assignAll(loadedCategories);
      isCatalogLoading.value = false;

      if (loadedCategories.isEmpty) {
        featuredProducts.clear();
        return;
      }

      await _waitForInitialCatalogContext(contextReady);
      if (!_isCurrentCatalogLoad(requestId)) return;

      await _waitForCatalogSettings(settingsReady);
      if (!_isCurrentCatalogLoad(requestId)) return;

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

      debugPrint(
        'DashboardController.loadCatalog: featuredProducts=${loadedFeatured.length}',
      );
      featuredProducts.assignAll(loadedFeatured);
    } catch (error) {
      if (_isCurrentCatalogLoad(requestId)) {
        debugPrint('DashboardController.loadCatalog: failed $error');
      }
    } finally {
      if (_isCurrentCatalogLoad(requestId)) {
        isCatalogLoading.value = false;
        isFeaturedLoading.value = false;
        debugPrint(
          'DashboardController.loadCatalog: complete requestId=$requestId '
          'categories=${categories.length} featured=${featuredProducts.length}',
        );
      }
    }
  }

  bool _isCurrentCatalogLoad(int requestId) {
    return requestId == _catalogLoadRequestId;
  }

  Future<void> _ensureInitialCatalogContextReady() async {
    final profileController = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : null;
    if (profileController?.hasBackendSession == true) {
      await profileController!.ensureCatalogContextReady();
      return;
    }
    if (!Get.isRegistered<ServiceAreaGateController>()) return;

    await Get.find<ServiceAreaGateController>().ensureChecked();
  }

  Future<void> _waitForInitialCatalogContext(Future<void> contextReady) async {
    try {
      await contextReady.timeout(_initialCatalogContextTimeout);
    } on TimeoutException {
      debugPrint(
        'DashboardController.loadCatalog: service-area context timed out; '
        'continuing with direct product-scope resolution.',
      );
      _retryCatalogWhenContextReady(contextReady);
    } catch (error, stackTrace) {
      debugPrint(
        'DashboardController.loadCatalog: service-area context failed $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _waitForCatalogSettings(
    Future<ProductCatalogSettings> settingsReady,
  ) async {
    try {
      await settingsReady.timeout(_settingsLoadTimeout);
    } on TimeoutException {
      debugPrint(
        'DashboardController.loadCatalog: catalog settings timed out; '
        'using current defaults.',
      );
    } catch (error, stackTrace) {
      debugPrint('DashboardController.loadCatalog: settings failed $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _retryCatalogWhenContextReady(Future<void> contextReady) {
    unawaited(
      contextReady
          .then((_) {
            if (isClosed || isFeaturedLoading.value) return;
            if (featuredProducts.isNotEmpty) return;
            unawaited(loadCatalog(force: true));
          })
          .catchError((Object error, StackTrace stackTrace) {
            debugPrint(
              'DashboardController.loadCatalog: late context retry failed $error',
            );
            debugPrintStack(stackTrace: stackTrace);
          }),
    );
  }

  Future<void> syncActiveProductOrder() async {
    if (!Get.isRegistered<OrderController>()) return;

    await Get.find<OrderController>().syncActiveProductOrder();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _wasAwayFromForeground = true;
      return;
    }
    if (!_wasAwayFromForeground) return;

    _wasAwayFromForeground = false;
    unawaited(_refreshLiveLocationAfterAppOpen());
  }

  Future<void> _refreshLiveLocationAfterAppOpen() {
    final active = _appOpenLocationRefresh;
    if (active != null) return active;
    if (isClosed || !Get.isRegistered<ServiceAreaGateController>()) {
      return Future<void>.value();
    }

    final serviceGateController = Get.find<ServiceAreaGateController>();
    if (!serviceGateController.shouldRefreshLiveLocationOnAppOpen) {
      return Future<void>.value();
    }

    final now = _clock();
    final lastRefreshAt = _lastAppOpenLocationRefreshAt;
    if (lastRefreshAt != null &&
        now.difference(lastRefreshAt) < _resumeLocationRefreshInterval) {
      return Future<void>.value();
    }
    _lastAppOpenLocationRefreshAt = now;

    final refresh = _runLiveLocationAfterAppOpen(serviceGateController);
    _appOpenLocationRefresh = refresh;
    refresh.whenComplete(() {
      if (identical(_appOpenLocationRefresh, refresh)) {
        _appOpenLocationRefresh = null;
      }
    });
    return refresh;
  }

  Future<void> _runLiveLocationAfterAppOpen(
    ServiceAreaGateController serviceGateController,
  ) async {
    await serviceGateController.checkCurrentLocation(force: true);
    if (isClosed || serviceGateController.isBlocked) return;

    await loadCatalog(force: true);
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

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
    WidgetsBinding.instance.removeObserver(this);
    _searchHintTimer?.cancel();
    _ratingWorker?.dispose();

    super.onClose();
  }
}
