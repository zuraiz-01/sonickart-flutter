import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../data/models/package_order_model.dart';
import '../../../routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';

enum PackageViewMode { send, orders }

enum PackageStep { initial, pickup, drop, type, review }

class PackageController extends GetxController {
  PackageController(this._storage);

  static const _storageKey = 'package_orders';
  static const _packageTypes = ['Documents', 'Food', 'Parcel', 'Medicine'];
  static const _baseDeliveryCharge = 30.0;
  static const _chargePerKm = 8.0;

  final GetStorage _storage;

  final pickupController = TextEditingController();
  final dropController = TextEditingController();

  final viewMode = PackageViewMode.send.obs;
  final currentStep = PackageStep.initial.obs;
  final selectedPackageType = RxnString();
  final agreementChecked = false.obs;
  final orders = <PackageOrderModel>[].obs;
  final isSubmitting = false.obs;
  final isLoadingOrders = false.obs;
  final selectedOrder = Rxn<PackageOrderModel>();

  List<String> get packageTypes => _packageTypes;

  double get distanceKm => _estimateDistance(
        pickupController.text,
        dropController.text,
      );

  double get deliveryCharge => _baseDeliveryCharge + (distanceKm * _chargePerKm);

  double get totalPrice => deliveryCharge;

  bool get canMoveFromPickup => pickupController.text.trim().isNotEmpty;

  bool get canMoveFromDrop => dropController.text.trim().isNotEmpty;

  bool get canMoveFromType => selectedPackageType.value?.isNotEmpty == true;

  bool get canSubmitReview =>
      canMoveFromPickup &&
      canMoveFromDrop &&
      canMoveFromType &&
      agreementChecked.value;

  @override
  void onInit() {
    super.onInit();
    debugPrint('PackageController.onInit: package flow initialized');
    loadOrders();
  }

  void setViewMode(PackageViewMode mode) {
    debugPrint('PackageController.setViewMode: switching to $mode');
    viewMode.value = mode;
    if (mode == PackageViewMode.orders) {
      loadOrders();
    }
  }

  void startFlow(String flowType) {
    debugPrint('PackageController.startFlow: selected flow $flowType');
    resetDraft(keepOrders: true);
    currentStep.value = PackageStep.pickup;
  }

  void goBackStep() {
    debugPrint('PackageController.goBackStep: current step ${currentStep.value}');
    switch (currentStep.value) {
      case PackageStep.initial:
        return;
      case PackageStep.pickup:
        currentStep.value = PackageStep.initial;
      case PackageStep.drop:
        currentStep.value = PackageStep.pickup;
      case PackageStep.type:
        currentStep.value = PackageStep.drop;
      case PackageStep.review:
        currentStep.value = PackageStep.type;
    }
  }

  void continueFromPickup() {
    debugPrint(
      'PackageController.continueFromPickup: pickup="${pickupController.text.trim()}"',
    );
    if (!canMoveFromPickup) {
      Get.snackbar(
        'Pickup Required',
        'Please enter pickup address first.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    currentStep.value = PackageStep.drop;
  }

  void continueFromDrop() {
    debugPrint(
      'PackageController.continueFromDrop: drop="${dropController.text.trim()}"',
    );
    if (!canMoveFromDrop) {
      Get.snackbar(
        'Drop Required',
        'Please enter drop address first.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    currentStep.value = PackageStep.type;
  }

  void selectPackageType(String value) {
    debugPrint('PackageController.selectPackageType: selected $value');
    selectedPackageType.value = value;
  }

  void continueFromType() {
    debugPrint(
      'PackageController.continueFromType: selected type ${selectedPackageType.value}',
    );
    if (!canMoveFromType) {
      Get.snackbar(
        'Package Type Required',
        'Please select a package type.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    currentStep.value = PackageStep.review;
  }

  void toggleAgreement() {
    agreementChecked.toggle();
    debugPrint(
      'PackageController.toggleAgreement: agreement=${agreementChecked.value}',
    );
  }

  Future<void> submitOrder() async {
    debugPrint('PackageController.submitOrder: submit requested');
    if (!canSubmitReview) {
      Get.snackbar(
        'Review Incomplete',
        'Pickup, drop, package type aur agreement complete karo.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (isSubmitting.value) {
      debugPrint('PackageController.submitOrder: already submitting');
      return;
    }

    isSubmitting.value = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final authController =
          Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
      final user = authController?.currentUser;
      final order = PackageOrderModel(
        id: 'PKG${DateTime.now().millisecondsSinceEpoch}',
        customerName: user?.name ?? 'SonicKart Customer',
        customerPhone: user?.phone ?? '+91 0000000000',
        packageType: selectedPackageType.value ?? 'Package',
        pickupAddress: pickupController.text.trim(),
        dropAddress: dropController.text.trim(),
        distanceKm: distanceKm,
        deliveryCharge: deliveryCharge,
        totalPrice: totalPrice,
        status: 'pending',
        createdAt: DateTime.now(),
      );
      orders.insert(0, order);
      selectedOrder.value = order;
      await _persistOrders();
      debugPrint(
        'PackageController.submitOrder: order created ${order.id} total=${order.totalPrice}',
      );
      resetDraft(keepOrders: true);
      viewMode.value = PackageViewMode.orders;
      Get.toNamed(AppRoutes.packageDetails, arguments: {'orderId': order.id});
    } finally {
      isSubmitting.value = false;
    }
  }

  void openOrder(PackageOrderModel order) {
    debugPrint('PackageController.openOrder: opening order ${order.id}');
    selectedOrder.value = order;
    Get.toNamed(AppRoutes.packageDetails, arguments: {'orderId': order.id});
  }

  PackageOrderModel? findOrderById(String orderId) {
    for (final order in orders) {
      if (order.id == orderId) {
        return order;
      }
    }
    return null;
  }

  Future<void> loadOrders() async {
    debugPrint('PackageController.loadOrders: loading package orders');
    isLoadingOrders.value = true;
    try {
      final rawOrders =
          _storage.read<List<dynamic>>(_storageKey) ?? <dynamic>[];
      final restoredOrders = rawOrders
          .map(
            (item) => PackageOrderModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      orders.assignAll(restoredOrders);
      debugPrint(
        'PackageController.loadOrders: restored ${orders.length} package orders',
      );
    } finally {
      isLoadingOrders.value = false;
    }
  }

  void useAutoDetectedPickup() {
    pickupController.text = 'House 14, Block C, Gulshan-e-Iqbal';
    debugPrint(
      'PackageController.useAutoDetectedPickup: pickup set to ${pickupController.text}',
    );
  }

  void useSuggestedDrop() {
    dropController.text = 'Sonic Point, Shahrah-e-Faisal';
    debugPrint(
      'PackageController.useSuggestedDrop: drop set to ${dropController.text}',
    );
  }

  void resetDraft({bool keepOrders = false}) {
    debugPrint('PackageController.resetDraft: clearing draft state');
    pickupController.clear();
    dropController.clear();
    selectedPackageType.value = null;
    agreementChecked.value = false;
    currentStep.value = PackageStep.initial;
    if (!keepOrders) {
      orders.clear();
    }
  }

  Future<void> _persistOrders() async {
    final payload = orders.map((order) => order.toJson()).toList();
    await _storage.write(_storageKey, payload);
    debugPrint(
      'PackageController._persistOrders: persisted ${orders.length} package orders',
    );
  }

  double _estimateDistance(String pickup, String drop) {
    final pickupLength = pickup.trim().length;
    final dropLength = drop.trim().length;
    if (pickupLength == 0 || dropLength == 0) {
      return 0;
    }
    final seed = pickupLength + dropLength;
    final distance = 2 + (seed % 9) + ((pickupLength % 3) * 0.5);
    return double.parse(distance.toStringAsFixed(1));
  }

  @override
  void onClose() {
    pickupController.dispose();
    dropController.dispose();
    super.onClose();
  }
}
