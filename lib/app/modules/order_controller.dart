import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../data/models/address_model.dart';
import '../data/models/order_model.dart';
import '../routes/app_routes.dart';
import 'auth/controllers/auth_controller.dart';
import 'cart/controllers/cart_controller.dart';
import 'profile/controllers/profile_controller.dart';

class OrderController extends GetxController {
  OrderController(this._storage);

  static const _ordersStorageKey = 'customer_orders';

  final GetStorage _storage;

  final deliveryAddressController = TextEditingController();
  final selectedPaymentMode = 'COD'.obs;
  final isPlacingOrder = false.obs;
  final orders = <OrderModel>[].obs;
  final latestOrder = Rxn<OrderModel>();
  final selectedOrder = Rxn<OrderModel>();

  bool get hasAddress => deliveryAddressController.text.trim().isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    debugPrint('OrderController.onInit: checkout flow initialized');
    loadOrders();
    preloadCheckoutContext();
  }

  void preloadCheckoutContext() {
    final profileController =
        Get.isRegistered<ProfileController>() ? Get.find<ProfileController>() : null;
    final activeAddress = profileController?.addresses.firstWhereOrNull(
      (item) => item.isSelected,
    );
    final authController =
        Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    final fallbackAddress = authController?.currentUser?.phone != null
        ? 'Deliver to ${authController!.currentUser!.phone}'
        : '';
    deliveryAddressController.text =
        activeAddress?.address ?? deliveryAddressController.text.trim();
    if (deliveryAddressController.text.trim().isEmpty) {
      deliveryAddressController.text = fallbackAddress;
    }
    debugPrint(
      'OrderController.preloadCheckoutContext: deliveryAddress="${deliveryAddressController.text.trim()}"',
    );
  }

  void selectPaymentMode(String mode) {
    debugPrint('OrderController.selectPaymentMode: mode=$mode');
    selectedPaymentMode.value = mode;
  }

  Future<void> loadOrders() async {
    final rawOrders =
        _storage.read<List<dynamic>>(_ordersStorageKey) ?? <dynamic>[];
    final restored = rawOrders
        .map(
          (item) => OrderModel.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    orders.assignAll(restored);
    latestOrder.value = restored.isNotEmpty ? restored.first : null;
    debugPrint('OrderController.loadOrders: restored ${orders.length} orders');
  }

  void openOrder(OrderModel order) {
    selectedOrder.value = order;
    debugPrint('OrderController.openOrder: order=${order.id}');
    Get.toNamed(AppRoutes.customerOrderDetails, arguments: {'orderId': order.id});
  }

  OrderModel? findOrderById(String orderId) {
    for (final order in orders) {
      if (order.id == orderId) {
        return order;
      }
    }
    return null;
  }

  Future<void> placeOrder() async {
    final cartController = Get.find<CartController>();
    final authController =
        Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    final profileController =
        Get.isRegistered<ProfileController>() ? Get.find<ProfileController>() : null;

    if (cartController.items.isEmpty) {
      Get.snackbar(
        'Cart Empty',
        'Add items before checkout.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!hasAddress) {
      Get.snackbar(
        'Address Required',
        'Please add delivery address to continue.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (isPlacingOrder.value) {
      return;
    }

    isPlacingOrder.value = true;
    try {
      final AddressModel? activeAddress = profileController?.addresses.firstWhereOrNull(
        (item) => item.isSelected,
      );
      final order = OrderModel(
        id: 'ORD${DateTime.now().millisecondsSinceEpoch}',
        items: cartController.items.toList(),
        customerName: authController?.currentUser?.name ?? 'SonicKart Customer',
        customerPhone: authController?.currentUser?.phone ?? '+91 0000000000',
        deliveryAddress:
            activeAddress?.address ?? deliveryAddressController.text.trim(),
        paymentMode: selectedPaymentMode.value,
        totalPrice: cartController.grandTotal,
        status: 'placed',
        createdAt: DateTime.now(),
      );
      orders.insert(0, order);
      latestOrder.value = order;
      await _storage.write(
        _ordersStorageKey,
        orders.map((item) => item.toJson()).toList(),
      );
      debugPrint(
        'OrderController.placeOrder: order=${order.id} payment=${order.paymentMode} total=${order.totalPrice}',
      );
      await cartController.clearCart();
      Get.offNamed(AppRoutes.orderSuccess, arguments: {'orderId': order.id});
    } finally {
      isPlacingOrder.value = false;
    }
  }

  @override
  void onClose() {
    deliveryAddressController.dispose();
    super.onClose();
  }
}
