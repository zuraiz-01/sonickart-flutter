import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../data/models/address_model.dart';
import '../data/models/order_model.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_service.dart';
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
  final couponCodeController = TextEditingController();
  final appliedCoupon = RxnString();
  final couponDiscount = 0.0.obs;
  final isPlacingOrder = false.obs;
  final orders = <OrderModel>[].obs;
  final latestOrder = Rxn<OrderModel>();
  final selectedOrder = Rxn<OrderModel>();

  bool get hasAddress => deliveryAddressController.text.trim().isNotEmpty;

  double checkoutTotal(double subtotal) =>
      (subtotal - couponDiscount.value).clamp(0, double.infinity).toDouble();

  @override
  void onInit() {
    super.onInit();
    debugPrint('OrderController.onInit: checkout flow initialized');
    loadOrders();
    preloadCheckoutContext();
  }

  void preloadCheckoutContext() {
    final profileController = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : null;
    final activeAddress = profileController?.addresses.firstWhereOrNull(
      (item) => item.isSelected,
    );
    final authController = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
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

  void applyCoupon(double subtotal) {
    final code = couponCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      appliedCoupon.value = null;
      couponDiscount.value = 0;
      return;
    }
    if (subtotal <= 0) return;
    if (code == 'SONIC10' || code == 'WELCOME10') {
      appliedCoupon.value = code;
      couponDiscount.value = (subtotal * 0.10).clamp(0, 150).toDouble();
      Get.snackbar(
        'Coupon Applied',
        '$code discount added.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    Get.snackbar(
      'Coupon Not Eligible',
      'This coupon is not available for this cart.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> loadOrders() async {
    final fromApi = await _tryFetchOrders();
    if (fromApi.isNotEmpty) {
      orders.assignAll(fromApi);
      latestOrder.value = fromApi.first;
      await _storage.write(
        _ordersStorageKey,
        fromApi.map((item) => item.toJson()).toList(),
      );
      debugPrint(
        'OrderController.loadOrders: fetched ${orders.length} orders from API',
      );
      return;
    }

    final rawOrders =
        _storage.read<List<dynamic>>(_ordersStorageKey) ?? <dynamic>[];
    final restored =
        rawOrders
            .map(
              (item) =>
                  OrderModel.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    orders.assignAll(restored);
    latestOrder.value = restored.isNotEmpty ? restored.first : null;
    debugPrint(
      'OrderController.loadOrders: restored ${orders.length} local orders',
    );
  }

  void openOrder(OrderModel order) {
    selectedOrder.value = order;
    debugPrint('OrderController.openOrder: order=${order.id}');
    Get.toNamed(
      AppRoutes.customerOrderDetails,
      arguments: {'orderId': order.id},
    );
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
    final authController = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    final profileController = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : null;

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
      final AddressModel? activeAddress = profileController?.addresses
          .firstWhereOrNull((item) => item.isSelected);
      final order = OrderModel(
        id: 'ORD${DateTime.now().millisecondsSinceEpoch}',
        items: cartController.items.toList(),
        customerName: authController?.currentUser?.name ?? 'SonicKart Customer',
        customerPhone: authController?.currentUser?.phone ?? '+91 0000000000',
        deliveryAddress:
            activeAddress?.address ?? deliveryAddressController.text.trim(),
        paymentMode: selectedPaymentMode.value,
        totalPrice: checkoutTotal(cartController.grandTotal),
        status: 'placed',
        createdAt: DateTime.now(),
      );
      final createdOrder = await _tryCreateOrder(order) ?? order;
      orders.insert(0, createdOrder);
      latestOrder.value = createdOrder;
      await _storage.write(
        _ordersStorageKey,
        orders.map((item) => item.toJson()).toList(),
      );
      debugPrint(
        'OrderController.placeOrder: order=${createdOrder.id} payment=${createdOrder.paymentMode} total=${createdOrder.totalPrice}',
      );
      await cartController.clearCart();
      appliedCoupon.value = null;
      couponDiscount.value = 0;
      couponCodeController.clear();
      Get.offNamed(
        AppRoutes.orderSuccess,
        arguments: {'orderId': createdOrder.id},
      );
    } finally {
      isPlacingOrder.value = false;
    }
  }

  int? etaFor(OrderModel order) {
    final status = order.status.toLowerCase();
    if (status == 'delivered' || status == 'cancelled') return 0;
    return 12 + (order.items.length * 2);
  }

  Future<void> cancelOrder(OrderModel order) async {
    final index = orders.indexWhere((item) => item.id == order.id);
    if (index < 0) return;
    try {
      if (Get.isRegistered<ApiService>()) {
        await Get.find<ApiService>().post(
          endpoint: '${ApiConstants.orderById(order.id)}/cancel-items',
          data: {'cancellationReason': 'Cancelled by customer'},
        );
      }
    } catch (error) {
      debugPrint('OrderController.cancelOrder: backend fallback after $error');
    }
    final cancelled = OrderModel(
      id: order.id,
      items: order.items,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      deliveryAddress: order.deliveryAddress,
      paymentMode: order.paymentMode,
      totalPrice: order.totalPrice,
      status: 'cancelled',
      createdAt: order.createdAt,
    );
    orders[index] = cancelled;
    latestOrder.value = orders.firstOrNull;
    await _storage.write(
      _ordersStorageKey,
      orders.map((item) => item.toJson()).toList(),
    );
    Get.snackbar(
      'Order Cancelled',
      'Your order has been cancelled successfully.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<OrderModel?> _tryCreateOrder(OrderModel draft) async {
    if (!Get.isRegistered<ApiService>()) return null;
    try {
      final firstProduct = draft.items.isNotEmpty
          ? draft.items.first.product
          : null;
      final payload = {
        'items': draft.items
            .map(
              (item) => {
                'id': item.product.id,
                '_id': item.product.id,
                'productId': item.product.id,
                'name': item.product.name,
                'price': item.product.numericPrice,
                'quantity': item.quantity,
                'count': item.quantity,
                'vendorId': item.product.vendorId.isEmpty
                    ? null
                    : item.product.vendorId,
                'vendor_id': item.product.vendorId.isEmpty
                    ? null
                    : item.product.vendorId,
                'branchId': item.product.branchId.isEmpty
                    ? null
                    : item.product.branchId,
                'branch_id': item.product.branchId.isEmpty
                    ? null
                    : item.product.branchId,
                'image': item.product.imageUrl,
              },
            )
            .toList(),
        'vendorId': firstProduct?.vendorId.isNotEmpty == true
            ? firstProduct!.vendorId
            : null,
        'vendor_id': firstProduct?.vendorId.isNotEmpty == true
            ? firstProduct!.vendorId
            : null,
        'branchId': firstProduct?.branchId.isNotEmpty == true
            ? firstProduct!.branchId
            : null,
        'branch_id': firstProduct?.branchId.isNotEmpty == true
            ? firstProduct!.branchId
            : null,
        'totalPrice': draft.totalPrice,
        'address': draft.deliveryAddress,
        'paymentMode': draft.paymentMode,
        'customerName': draft.customerName,
        'customerPhone': draft.customerPhone,
      };
      final response = await Get.find<ApiService>().post(
        endpoint: ApiConstants.orders,
        data: payload,
      );
      final raw = response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : response;
      final parsed = OrderModel.fromJson(raw);
      return parsed.id.isEmpty ? null : parsed;
    } catch (error) {
      debugPrint(
        'OrderController._tryCreateOrder: local fallback after $error',
      );
      return null;
    }
  }

  Future<List<OrderModel>> _tryFetchOrders() async {
    if (!Get.isRegistered<ApiService>()) return <OrderModel>[];
    try {
      final authController = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : null;
      final userId = authController?.currentUser?.id ?? '';
      final response = await Get.find<ApiService>().get(
        endpoint: ApiConstants.orders,
        query: {'customerId': userId},
      );
      final list =
          _extractList(response)
              .map(
                (item) =>
                    OrderModel.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .where((order) => order.id.isNotEmpty)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (error) {
      debugPrint(
        'OrderController._tryFetchOrders: local fallback after $error',
      );
      return <OrderModel>[];
    }
  }

  List _extractList(Map<String, dynamic> response) {
    final candidates = [
      response['data'],
      response['orders'],
      response['items'],
      response['result'],
      response['results'],
    ];
    for (final value in candidates) {
      if (value is List) return value;
      if (value is Map) {
        for (final nested in ['data', 'orders', 'items', 'result', 'results']) {
          final nestedValue = value[nested];
          if (nestedValue is List) return nestedValue;
        }
      }
    }
    return [];
  }

  @override
  void onClose() {
    deliveryAddressController.dispose();
    couponCodeController.dispose();
    super.onClose();
  }
}
