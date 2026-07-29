import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../modules/auth/controllers/auth_controller.dart';
import '../../modules/order_controller.dart';
import '../../modules/package/controllers/package_controller.dart';
import 'session_controller.dart';

typedef StatusReconciliationCallback = Future<void> Function();

class AppResumeReconciliationService extends GetxService
    with WidgetsBindingObserver {
  AppResumeReconciliationService(
    this._storage, {
    this.minimumInterval = const Duration(seconds: 5),
    DateTime Function()? clock,
    StatusReconciliationCallback? orderReconciliation,
    StatusReconciliationCallback? packageReconciliation,
  }) : _clock = clock ?? DateTime.now,
       _orderReconciliation = orderReconciliation,
       _packageReconciliation = packageReconciliation;

  final GetStorage _storage;
  final Duration minimumInterval;
  final DateTime Function() _clock;
  final StatusReconciliationCallback? _orderReconciliation;
  final StatusReconciliationCallback? _packageReconciliation;

  Future<void>? _activeReconciliation;
  DateTime? _lastReconciliationStartedAt;
  bool _wasAwayFromForeground = false;
  bool _isObserving = false;  

  void start() {
    if (_isObserving) return;
    _isObserving = true;
    _wasAwayFromForeground =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _wasAwayFromForeground = true;
      return;
    }
    if (!_wasAwayFromForeground) return;

    _wasAwayFromForeground = false;
    unawaited(reconcileStatuses());
  }

  Future<void> reconcileStatuses() {
    final active = _activeReconciliation;
    if (active != null) return active;
    if (!_hasAuthenticatedSession) return Future<void>.value();

    final now = _clock();
    final lastStartedAt = _lastReconciliationStartedAt;
    if (lastStartedAt != null &&
        now.difference(lastStartedAt) < minimumInterval) {
      return Future<void>.value();
    }

    _lastReconciliationStartedAt = now;
    final reconciliation = _runReconciliation();
    _activeReconciliation = reconciliation;
    return reconciliation;
  }

  bool get _hasAuthenticatedSession {
    final accessToken = _storage.read<String>('accessToken')?.trim() ?? '';
    if (accessToken.isEmpty || _storage.read('isLoggedIn') != true) {
      return false;
    }

    if (Get.isRegistered<SessionController>() &&
        Get.find<SessionController>().isSessionExpiredVisible.value) {
      return false;
    }

    if (Get.isRegistered<AuthController>()) {
      final authController = Get.find<AuthController>();
      return authController.isLoggedIn &&
          (authController.currentUser?.id.trim().isNotEmpty ?? false);
    }

    final rawUser = _storage.read('currentUser');
    if (rawUser is! Map) return false;
    final userId = rawUser['id'] ?? rawUser['_id'] ?? rawUser['userId'];
    return userId?.toString().trim().isNotEmpty == true;
  }

  Future<void> _runReconciliation() async {
    try {
      await Future.wait([
        _runSafely('orders', _resolveOrderReconciliation()),
        _runSafely('packages', _resolvePackageReconciliation()),
      ]);
    } finally {
      _activeReconciliation = null;
    }
  }

  StatusReconciliationCallback? _resolveOrderReconciliation() {
    final override = _orderReconciliation;
    if (override != null) return override;
    if (!Get.isRegistered<OrderController>()) return null;
    return Get.find<OrderController>().syncActiveProductOrder;
  }

  StatusReconciliationCallback? _resolvePackageReconciliation() {
    final override = _packageReconciliation;
    if (override != null) return override;
    if (!Get.isRegistered<PackageController>()) return null;
    return Get.find<PackageController>().syncOrdersFromBackend;
  }

  Future<void> _runSafely(
    String label,
    StatusReconciliationCallback? reconciliation,
  ) async {
    if (reconciliation == null) return;
    try {
      await reconciliation();
    } catch (error, stackTrace) {
      debugPrint('App resume $label reconciliation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void onClose() {
    if (_isObserving) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserving = false;
    }
    super.onClose();
  }
}
