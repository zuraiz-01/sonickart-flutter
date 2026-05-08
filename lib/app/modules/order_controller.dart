import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../firebase_options.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_service.dart';
import '../core/services/location_lookup_service.dart';
import '../core/services/notification_service.dart';
import '../core/widgets/app_snackbar.dart';
import '../data/models/address_model.dart';
import '../data/models/cart_item_model.dart';
import '../data/models/order_model.dart';
import '../data/models/product_model.dart';
import '../data/repositories/catalog_repository.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'auth/controllers/auth_controller.dart';
import 'cart/controllers/cart_controller.dart';
import 'profile/controllers/profile_controller.dart';

class OrderController extends GetxController {
  OrderController(this._storage);

  static const _ordersStorageKey = 'customer_orders';
  static const _selectedAddressStorageKey = 'selectedAddress';
  static const _selectedVendorIdStorageKey = 'selectedVendorId';
  static const _defaultProductRadiusKm = 5.0;
  static const _defaultFreeDeliveryThreshold = 200.0;
  static const _defaultProductDeliveryCharge = 30.0;

  final GetStorage _storage;
  final LocationLookupService _locationLookupService = LocationLookupService();

  final deliveryAddressController = TextEditingController();
  final selectedPaymentMode = 'COD'.obs;
  final couponCodeController = TextEditingController();
  final isPlacingOrder = false.obs;
  final isLoadingCoupons = false.obs;
  final isApplyingCoupon = false.obs;
  final couponFeedback = RxnString();
  final selectedCoupon = Rxn<CheckoutCoupon>();
  final availableCoupons = <CheckoutCoupon>[].obs;
  final productRadiusKm = _defaultProductRadiusKm.obs;
  final freeDeliveryThreshold = _defaultFreeDeliveryThreshold.obs;
  final productDeliveryCharge = _defaultProductDeliveryCharge.obs;
  final orders = <OrderModel>[].obs;
  final latestOrder = Rxn<OrderModel>();
  final selectedOrder = Rxn<OrderModel>();
  final selectedCheckoutAddress = Rxn<AddressModel>();
  final activeProductOrder = Rxn<OrderModel>();
  final isSyncingActiveOrder = false.obs;
  final isHandlingUnavailableCart = false.obs;
  final isValidatingCartAvailability = false.obs;
  final selectingCheckoutAddressId = RxnString();

  bool _hasManualCheckoutAddress = false;

  bool get hasAddress => _deliveryAddressPreview.trim().isNotEmpty;

  String get deliveryRecipient {
    final auth = _authController;
    final selected = selectedCheckoutAddress.value;
    if (selected?.fullName.trim().isNotEmpty == true) {
      return selected!.fullName.trim();
    }
    if (auth?.currentUser?.name.trim().isNotEmpty == true) {
      return auth!.currentUser!.name.trim();
    }
    if (selected?.contactNumber.trim().isNotEmpty == true) {
      return selected!.contactNumber.trim();
    }
    return 'Select delivery address';
  }

  String get deliveryAddressPreview {
    final value = _deliveryAddressPreview;
    return value.isEmpty ? 'Add your delivery address to continue' : value;
  }

  String get _deliveryAddressPreview {
    return selectedCheckoutAddress.value?.address.trim().isNotEmpty == true
        ? selectedCheckoutAddress.value!.address.trim()
        : deliveryAddressController.text.trim();
  }

  double freeDeliveryAmountLeft(List<CartItemModel> items) {
    final totals = calculateCheckoutTotals(items);
    final remaining = freeDeliveryThreshold.value - totals.totalBeforeDiscount;
    return remaining > 0 ? _roundCurrency(remaining) : 0;
  }

  CheckoutTotals calculateCheckoutTotals(List<CartItemModel> items) {
    final itemsTotal = _roundCurrency(
      items.fold<double>(0, (sum, item) => sum + item.totalPrice),
    );
    final hasValidItems = items.any((item) => item.quantity > 0);
    final deliveryCharge =
        itemsTotal > 0 && itemsTotal < freeDeliveryThreshold.value
        ? productDeliveryCharge.value
        : 0.0;
    final coupon = selectedCoupon.value;
    final couponDiscount = coupon == null
        ? 0.0
        : _calculateCouponDiscount(coupon, items, itemsTotal);
    final appliedCoupon = couponDiscount > 0 ? coupon : null;
    return CheckoutTotals(
      itemsTotal: itemsTotal,
      gstAmount: 0,
      totalBeforeDiscount: itemsTotal,
      deliveryCharge: _roundCurrency(deliveryCharge),
      couponDiscount: _roundCurrency(couponDiscount),
      grandTotal: _roundCurrency(itemsTotal + deliveryCharge - couponDiscount),
      hasValidItems: hasValidItems,
      appliedCoupon: appliedCoupon,
    );
  }

  @override
  void onInit() {
    super.onInit();
    debugPrint('OrderController.onInit: checkout flow initialized');
    loadOrders();
    preloadCheckoutContext();
    loadDeliverySettings();
  }

  Future<void> loadDeliverySettings({bool force = false}) async {
    try {
      final response = await _firestoreGet(
        'adminSettings/deliveryRadius',
        isDocument: true,
      );
      final fields = _decodeFirestoreFields(response['fields']);
      productRadiusKm.value = max(
        1,
        _readNumber(fields, const [
          'productVisibilityRadiusKm',
          'productRadiusKm',
          'product_radius_km',
          'products.radiusKm',
          'products.visibilityRadiusKm',
          'products.productVisibilityRadiusKm',
        ], _defaultProductRadiusKm),
      );
      freeDeliveryThreshold.value = max(
        0,
        _readNumber(fields, const [
          'freeDeliveryThreshold',
          'free_delivery_threshold',
          'products.freeDeliveryThreshold',
          'products.freeDeliveryAmount',
        ], _defaultFreeDeliveryThreshold),
      );
      productDeliveryCharge.value = max(
        0,
        _readNumber(fields, const [
          'deliveryCharge',
          'productDeliveryCharge',
          'products.deliveryCharge',
          'products.deliveryFee',
        ], _defaultProductDeliveryCharge),
      );
    } catch (_) {
      // Defaults match the React Native fallback when Firestore settings are
      // unavailable for the current Firebase auth context.
    }
  }

  Future<void> preloadCheckoutContext() async {
    final profileController = _profileController;
    if (profileController != null && profileController.addresses.isEmpty) {
      await profileController.loadAddresses();
    }

    final currentSelection = selectedCheckoutAddress.value;
    if (_hasManualCheckoutAddress &&
        currentSelection?.address.trim().isNotEmpty == true) {
      deliveryAddressController.text = currentSelection!.address.trim();
      return;
    }

    final activeAddress =
        profileController?.activeAddress ??
        profileController?.addresses.firstWhereOrNull(
          (item) => item.isSelected,
        ) ??
        profileController?.addresses.firstOrNull;
    if (activeAddress != null) {
      _hasManualCheckoutAddress = false;
      selectedCheckoutAddress.value = activeAddress;
      deliveryAddressController.text = activeAddress.address;
      return;
    }

    _hasManualCheckoutAddress = false;
    if (deliveryAddressController.text.trim().startsWith('Deliver to ')) {
      deliveryAddressController.clear();
    }
  }

  void selectPaymentMode(String mode) {
    selectedPaymentMode.value = mode;
  }

  Future<void> openCouponSheet() async {
    couponFeedback.value = null;
    await loadCouponsForCart();
  }

  Future<void> loadCouponsForCart() async {
    final cart = _cartController;
    final totals = calculateCheckoutTotals(cart.items);
    if (totals.itemsTotal <= 0) {
      availableCoupons.clear();
      return;
    }

    isLoadingCoupons.value = true;
    try {
      final documents = await _fetchCouponDocuments();
      final coupons =
          documents
              .whereType<Map>()
              .map(_parseCouponDocument)
              .whereType<CheckoutCoupon>()
              .toList()
            ..sort((left, right) {
              if (left.isActive != right.isActive) {
                return right.isActive ? 1 : -1;
              }
              if (left.minimumOrderAmount != right.minimumOrderAmount) {
                return left.minimumOrderAmount.compareTo(
                  right.minimumOrderAmount,
                );
              }
              return right.discountValue.compareTo(left.discountValue);
            });
      availableCoupons.assignAll(_dedupeCoupons(coupons));
    } catch (error) {
      debugPrint('OrderController.loadCouponsForCart failed: $error');
      couponFeedback.value = 'Coupons could not be loaded right now.';
      availableCoupons.clear();
    } finally {
      isLoadingCoupons.value = false;
    }
  }

  Future<List<dynamic>> _fetchCouponDocuments() async {
    final response = await _firestoreGet('adminCoupons');
    if (response['documents'] is List) {
      return response['documents'] as List;
    }
    if (response['data'] is List) {
      return response['data'] as List;
    }
    return const [];
  }

  Future<bool> applyCoupon([CheckoutCoupon? coupon]) async {
    final cart = _cartController;
    final code = (coupon?.code ?? couponCodeController.text)
        .trim()
        .toUpperCase();
    if (code.isEmpty) {
      couponFeedback.value = 'Enter a coupon code first.';
      return false;
    }
    if (cart.items.isEmpty) {
      couponFeedback.value = 'Add items before applying a coupon.';
      return false;
    }

    isApplyingCoupon.value = true;
    couponFeedback.value = null;
    try {
      final resolved = coupon ?? await _getCouponByCode(code);

      if (resolved == null) {
        couponFeedback.value = 'Coupon not found.';
        return false;
      }

      final message = couponEligibilityMessage(resolved, cart.items);
      if (message != null) {
        couponFeedback.value = message;
        return false;
      }

      selectedCoupon.value = resolved;
      couponCodeController.text = resolved.code;
      couponFeedback.value = '${resolved.code} applied successfully.';
      return true;
    } catch (error) {
      debugPrint('OrderController.applyCoupon failed: $error');
      couponFeedback.value = error is ApiException && error.message.isNotEmpty
          ? error.message
          : 'Failed to apply this coupon right now.';
      return false;
    } finally {
      isApplyingCoupon.value = false;
    }
  }

  Future<CheckoutCoupon?> _getCouponByCode(String code) async {
    final normalized = _normalizeCodeToken(code);
    if (normalized.isEmpty) return null;

    if (availableCoupons.isEmpty) {
      await loadCouponsForCart();
    }

    final cached = availableCoupons.firstWhereOrNull(
      (item) => item.matchKeys.contains(normalized),
    );
    if (cached != null) return cached;

    final documents = await _fetchCouponDocuments();
    final coupons = documents
        .whereType<Map>()
        .map(_parseCouponDocument)
        .whereType<CheckoutCoupon>()
        .toList();
    final deduped = _dedupeCoupons(coupons);
    if (deduped.isNotEmpty) {
      availableCoupons.assignAll(deduped);
    }
    return deduped.firstWhereOrNull(
      (item) => item.matchKeys.contains(normalized),
    );
  }

  CheckoutCoupon? _parseCouponDocument(Map doc) {
    try {
      return CheckoutCoupon.fromFirestoreDocument(doc);
    } catch (error) {
      debugPrint('OrderController._parseCouponDocument skipped: $error');
      return null;
    }
  }

  void removeAppliedCoupon() {
    selectedCoupon.value = null;
    couponCodeController.clear();
    couponFeedback.value = 'Coupon removed.';
  }

  void clearInvalidCoupon(String message) {
    selectedCoupon.value = null;
    couponCodeController.clear();
    couponFeedback.value = message;
  }

  String? couponEligibilityMessage(
    CheckoutCoupon coupon,
    List<CartItemModel> items,
  ) {
    if (!coupon.isActive) {
      return coupon.status == CouponStatus.scheduled
          ? 'This coupon is scheduled and not active yet.'
          : 'This coupon has expired.';
    }
    if (!_matchesTargetUser(coupon)) {
      return 'This coupon is not assigned to your account.';
    }
    if (!_matchesCouponCategory(coupon, items)) {
      return 'This coupon does not match items in your cart.';
    }
    final itemsTotal = _roundCurrency(
      items.fold<double>(0, (sum, item) => sum + item.totalPrice),
    );
    if (itemsTotal <= 0) return 'Add items before applying a coupon.';
    if (itemsTotal < coupon.minimumOrderAmount) {
      return 'Minimum order ₹${_formatAmount(coupon.minimumOrderAmount)} required.';
    }
    return null;
  }

  Future<void> selectAddress(AddressModel address) async {
    if (selectingCheckoutAddressId.value != null) return;
    selectingCheckoutAddressId.value = address.id;
    try {
      final normalizedAddress = address.address.trim();
      if (normalizedAddress.isEmpty) {
        await _showAddressSelectionError(
          'Invalid Address',
          'Selected address is missing details.',
        );
        return;
      }

      isValidatingCartAvailability.value = true;
      var selected = address.copyWith(
        address: normalizedAddress,
        isSelected: true,
      );
      selectedCheckoutAddress.value = selected;
      selectedCheckoutAddress.refresh();
      _hasManualCheckoutAddress = true;
      deliveryAddressController.text = selected.address.trim();

      if (!_hasValidCoordinates(selected.latitude, selected.longitude)) {
        final geocode = await _locationLookupService.geocodeAddress(
          normalizedAddress,
        );
        if (geocode != null) {
          selected = selected.copyWith(
            address: geocode.address.isNotEmpty
                ? geocode.address
                : normalizedAddress,
            latitude: geocode.latitude,
            longitude: geocode.longitude,
            placeId: geocode.placeId,
          );
        }
      }

      if (!_hasValidCoordinates(selected.latitude, selected.longitude)) {
        await _showAddressSelectionError(
          'Invalid address location',
          'Selected address does not have valid map coordinates. Please update this address and try again.',
        );
        return;
      }

      final user = _authController?.currentUser;
      selected = selected.copyWith(
        fullName: selected.fullName.trim().isNotEmpty
            ? selected.fullName.trim()
            : user?.name.isNotEmpty == true
            ? user!.name
            : 'Customer',
        contactNumber: selected.contactNumber.trim().isNotEmpty
            ? selected.contactNumber.trim()
            : user?.phone ?? '',
        address: selected.address.trim(),
        isSelected: true,
      );

      selectedCheckoutAddress.value = selected;
      selectedCheckoutAddress.refresh();
      deliveryAddressController.text = selected.address.trim();
      await _storage.write(_selectedAddressStorageKey, selected.toJson());
      await _profileController?.useAddress(selected);
      await _updateUserLocation(selected);

      final vendorResolution = await _resolveVendor(selected);
      debugPrint(
        'OrderController.selectAddress: resolved vendors=${vendorResolution.debugSummary}',
      );
      await _persistSelectedVendorContext(vendorResolution);
      final checkoutItems = _cartController.items
          .where((item) => item.quantity > 0)
          .toList(growable: false);
      final unavailable = await _findUnavailableCartItems(
        checkoutItems,
        vendorResolution,
      );
      debugPrint(
        'OrderController.selectAddress: checkoutItems=${checkoutItems.length}, unavailable=${unavailable.map((item) => item.product.id).join(',')}',
      );
      if (unavailable.isNotEmpty) {
        await _handleUnavailableCartItems(unavailable);
        return;
      }

      _notifyAction(
        'Address Selected',
        'Delivery Address selected for checkout.',
        category: 'address',
      );
    } catch (error) {
      debugPrint('OrderController.selectAddress failed: $error');
      await _showAddressSelectionError(
        'Failed to select address',
        'Please try again.',
      );
    } finally {
      isValidatingCartAvailability.value = false;
      selectingCheckoutAddressId.value = null;
    }
  }

  Future<void> loadOrders() async {
    final fromApi = await _tryFetchOrders();
    if (fromApi.isNotEmpty) {
      orders.assignAll(fromApi);
      latestOrder.value = fromApi.first;
      activeProductOrder.value = _latestActiveProductOrder(fromApi);
      await _persistOrders();
      unawaited(_enrichOrdersMissingItemDetails(fromApi));
      return;
    }

    final rawOrders =
        _storage.read<List<dynamic>>(_ordersStorageKey) ?? <dynamic>[];
    final restored =
        rawOrders
            .whereType<Map>()
            .map((item) => OrderModel.fromJson(Map<String, dynamic>.from(item)))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    orders.assignAll(restored);
    latestOrder.value = restored.firstOrNull;
    activeProductOrder.value = _latestActiveProductOrder(restored);
  }

  Future<void> syncActiveProductOrder() async {
    if (isSyncingActiveOrder.value) return;
    final userId = _authController?.currentUser?.id ?? '';
    if (userId.isEmpty) return;

    isSyncingActiveOrder.value = true;
    try {
      final fromApi = await _tryFetchOrders(userIdOverride: userId);
      if (fromApi.isEmpty) {
        activeProductOrder.value = _latestActiveProductOrder(orders);
        return;
      }

      orders.assignAll(fromApi);
      latestOrder.value = fromApi.firstOrNull;
      unawaited(_enrichOrdersMissingItemDetails(fromApi));
      var active = _latestActiveProductOrder(fromApi);
      if (active != null && active.resolvedItemCount == 0) {
        for (final id in _orderIdentifiers(active)) {
          final detailed = await _tryFetchOrderById(id);
          if (detailed != null) {
            active = detailed;
            final index = orders.indexWhere((item) => item.id == detailed.id);
            if (index >= 0) {
              orders[index] = detailed;
            }
            break;
          }
        }
      }
      activeProductOrder.value = active;
      await _persistOrders();
    } catch (error) {
      debugPrint('OrderController.syncActiveProductOrder failed: $error');
    } finally {
      isSyncingActiveOrder.value = false;
    }
  }

  void openOrder(OrderModel order) {
    selectedOrder.value = order;
    if (order.isProductOrder && !order.isInactive) {
      activeProductOrder.value = order;
      Get.toNamed(AppRoutes.liveTracking, arguments: {'orderId': order.id});
      return;
    }
    Get.toNamed(
      AppRoutes.customerOrderDetails,
      arguments: {'orderId': order.id},
    );
  }

  OrderModel? findOrderById(String orderId) {
    final normalized = orderId.trim();
    if (normalized.isEmpty) return null;
    return orders.firstWhereOrNull(
      (order) => _orderIdentifiers(order).contains(normalized),
    );
  }

  List<String> orderIdentifiers(OrderModel order) => _orderIdentifiers(order);

  Future<void> handleRealtimeOrderPayload(Map<String, dynamic> payload) async {
    final order = OrderModel.fromJson(payload);
    if (order.id.isEmpty) {
      return;
    }
    await _upsertOrder(order);
  }

  Future<OrderModel?> refreshTrackingOrder(String? orderId) async {
    final localOrder = orderId == null || orderId.trim().isEmpty
        ? (activeProductOrder.value ?? selectedOrder.value ?? latestOrder.value)
        : findOrderById(orderId);
    final identifiers = localOrder == null
        ? [orderId?.trim() ?? '']
        : _orderIdentifiers(localOrder);

    for (final id in identifiers.where((item) => item.isNotEmpty)) {
      final detailed = await _tryFetchOrderById(id);
      if (detailed != null) {
        await _upsertOrder(detailed);
        selectedOrder.value = detailed;
        return detailed;
      }
    }

    if (localOrder != null) {
      selectedOrder.value = localOrder;
    }
    return localOrder;
  }

  Future<OrderModel?> refreshOrderDetails(OrderModel order) async {
    for (final id in _orderIdentifiers(order)) {
      final detailed = await _tryFetchOrderById(id);
      if (detailed != null) {
        await _upsertOrder(detailed);
        return detailed;
      }
    }
    return null;
  }

  Future<void> placeOrder() async {
    final cart = _cartController;
    final checkoutItems = cart.items
        .where((item) => item.quantity > 0)
        .toList(growable: false);
    final totals = calculateCheckoutTotals(checkoutItems);
    if (checkoutItems.isEmpty || totals.grandTotal <= 0) {
      return;
    }
    if (isValidatingCartAvailability.value) return;
    if (isPlacingOrder.value) return;

    isPlacingOrder.value = true;
    try {
      if (await _hasIncompleteProductOrder()) {
        Get.dialog(
          AlertDialog(
            title: const Text('Order In Progress'),
            content: const Text(
              'You already have an active order. Please wait until it is delivered or cancelled.',
            ),
            actions: [TextButton(onPressed: Get.back, child: const Text('OK'))],
          ),
        );
        return;
      }

      final address = await _ensureAddressContext();
      final vendorResolution = await _resolveVendor(address);
      debugPrint(
        'OrderController.placeOrder: resolved vendors=${vendorResolution.debugSummary}',
      );
      final unavailable = await _findUnavailableCartItems(
        checkoutItems,
        vendorResolution,
      );
      debugPrint(
        'OrderController.placeOrder: checkoutItems=${checkoutItems.length}, unavailable=${unavailable.map((item) => item.product.id).join(',')}',
      );
      if (unavailable.isNotEmpty) {
        await _handleUnavailableCartItems(unavailable);
        return;
      }

      final vendorContext = _resolveCheckoutVendorContext(
        checkoutItems,
        vendorResolution,
      );
      if (vendorContext.error != null) {
        return;
      }

      var finalAddress = address.address;
      var finalLatitude = address.latitude;
      var finalLongitude = address.longitude;
      if (!_hasValidCoordinates(finalLatitude, finalLongitude)) {
        final geocode = await _locationLookupService.geocodeAddress(
          finalAddress,
        );
        if (geocode != null) {
          finalAddress = geocode.address;
          finalLatitude = geocode.latitude;
          finalLongitude = geocode.longitude;
        }
      }

      final payload = _buildOrderPayload(
        items: checkoutItems,
        address: finalAddress,
        latitude: finalLatitude,
        longitude: finalLongitude,
        vendorContext: vendorContext,
        totals: totals,
        customerName: address.fullName,
        customerPhone: address.contactNumber,
      );

      final response = await _api.post(
        endpoint: ApiConstants.orders,
        data: payload,
      );
      final raw = response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : response;
      final parsedOrder = OrderModel.fromJson(raw);
      final createdOrder = parsedOrder.deliveryAddress.trim().isEmpty
          ? OrderModel(
              id: parsedOrder.id,
              items: parsedOrder.items,
              customerName: parsedOrder.customerName.isNotEmpty
                  ? parsedOrder.customerName
                  : address.fullName,
              customerPhone: parsedOrder.customerPhone.isNotEmpty
                  ? parsedOrder.customerPhone
                  : address.contactNumber,
              deliveryAddress: finalAddress,
              paymentMode: parsedOrder.paymentMode,
              totalPrice: parsedOrder.totalPrice,
              status: parsedOrder.status,
              createdAt: parsedOrder.createdAt,
              raw: {
                ...parsedOrder.raw,
                'deliveryAddress': finalAddress,
                'deliveryLocation': {
                  ...(parsedOrder.raw['deliveryLocation'] is Map
                      ? Map<String, dynamic>.from(
                          parsedOrder.raw['deliveryLocation'] as Map,
                        )
                      : const <String, dynamic>{}),
                  'address': finalAddress,
                  'fullName': address.fullName,
                  'contactNumber': address.contactNumber,
                  'latitude': finalLatitude,
                  'longitude': finalLongitude,
                },
              },
            )
          : parsedOrder;
      if (createdOrder.id.isEmpty) {
        throw ApiException(
          statusCode: 0,
          message: 'There Was An Error Creating The Order.',
          response: response,
        );
      }

      orders.insert(0, createdOrder);
      latestOrder.value = createdOrder;
      if (createdOrder.isProductOrder && !createdOrder.isInactive) {
        activeProductOrder.value = createdOrder;
      }
      await _persistOrders();
      selectedCoupon.value = null;
      couponCodeController.clear();
      couponFeedback.value = null;
      _notifyAction(
        'Order Placed',
        'Your order ${createdOrder.id} has been placed successfully.',
        category: 'order',
      );
      await cart.clearCart(notify: false);
      Get.offNamed(
        AppRoutes.orderSuccess,
        arguments: {'orderId': createdOrder.id},
      );
    } catch (error) {
      final message = error is ApiException
          ? error.message
          : error.toString().replaceFirst('Exception: ', '');
      debugPrint('OrderController.placeOrder failed: $message');
    } finally {
      isPlacingOrder.value = false;
    }
  }

  int? etaFor(OrderModel order) {
    final status = order.status.toLowerCase();
    if (status == 'delivered' || status == 'cancelled') return 0;

    final destination =
        _coordinateFrom(order.raw['deliveryLocation']) ??
        _coordinateFrom({
          'latitude': order.raw['customerLatitude'],
          'longitude': order.raw['customerLongitude'],
        });
    final deliveryPartner = order.raw['deliveryPartner'] is Map
        ? Map<String, dynamic>.from(order.raw['deliveryPartner'] as Map)
        : const <String, dynamic>{};
    final driver =
        _coordinateFrom(order.raw['deliveryPersonLocation']) ??
        _coordinateFrom(deliveryPartner['liveLocation']);
    final pickup = _coordinateFrom(order.raw['pickupLocation']);
    final origin =
        driver ??
        (status == 'confirmed' || status == 'accepted' || status == 'assigned'
            ? pickup
            : null);

    if (origin != null && destination != null) {
      final distanceKm = _distanceKm(origin, destination);
      if (distanceKm.isFinite && distanceKm > 0) {
        return max(1, (distanceKm / 0.35).round());
      }
    }

    return 12 + (order.items.length * 2);
  }

  Future<void> cancelOrder(
    OrderModel order, {
    String reason = 'Cancelled by customer',
  }) async {
    try {
      await _api.post(
        endpoint: '${ApiConstants.orderById(order.id)}/cancel-items',
        data: {'cancellationReason': reason},
      );
    } catch (error) {
      debugPrint('OrderController.cancelOrder failed: $error');
      return;
    }

    final refreshed = await refreshOrderDetails(order);
    if (refreshed != null) {
      return;
    }

    final updatedRaw = {
      ...order.raw,
      'status': 'cancelled',
      'deliveryStatus': 'cancelled',
    };
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
      raw: updatedRaw,
    );
    await _upsertOrder(cancelled);
    latestOrder.value = orders.firstOrNull;
    if (activeProductOrder.value?.id == order.id) {
      activeProductOrder.value = null;
    }
    await _persistOrders();
  }

  Future<AddressModel> _ensureAddressContext() async {
    await preloadCheckoutContext();
    var address = selectedCheckoutAddress.value;

    if (address == null) {
      final rawAddress = deliveryAddressController.text.trim();
      final user = _authController?.currentUser;
      if (rawAddress.isEmpty || rawAddress.startsWith('Deliver to ')) {
        throw Exception('ADDRESS_REQUIRED');
      }
      address = AddressModel(
        id: '-1',
        fullName: user?.name.isNotEmpty == true ? user!.name : 'Customer',
        contactNumber: user?.phone ?? '',
        address: rawAddress,
      );
    }

    var latitude = address.latitude;
    var longitude = address.longitude;
    var finalAddress = address.address.trim();

    if (!_hasValidCoordinates(latitude, longitude)) {
      final geocode = await _locationLookupService.geocodeAddress(finalAddress);
      if (geocode != null) {
        latitude = geocode.latitude;
        longitude = geocode.longitude;
        finalAddress = geocode.address;
      }
    }

    if (!_hasValidCoordinates(latitude, longitude)) {
      final current = await _requestLiveCoordinates();
      if (current != null) {
        latitude = current.latitude;
        longitude = current.longitude;
      }
    }

    if (!_hasValidCoordinates(latitude, longitude)) {
      throw Exception('LOCATION_REQUIRED');
    }

    final user = _authController?.currentUser;
    final normalized = address.copyWith(
      fullName: address.fullName.trim().isNotEmpty
          ? address.fullName.trim()
          : user?.name.isNotEmpty == true
          ? user!.name
          : 'Customer',
      contactNumber: address.contactNumber.trim().isNotEmpty
          ? address.contactNumber.trim()
          : user?.phone ?? '',
      address: finalAddress,
      latitude: latitude,
      longitude: longitude,
    );
    selectedCheckoutAddress.value = normalized;
    deliveryAddressController.text = normalized.address;
    await _updateUserLocation(normalized);
    return normalized;
  }

  Future<({double latitude, double longitude})?>
  _requestLiveCoordinates() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (error) {
      debugPrint('OrderController._requestLiveCoordinates failed: $error');
      return null;
    }
  }

  Future<void> _updateUserLocation(AddressModel address) async {
    try {
      await _api.patch(
        endpoint: ApiConstants.user,
        data: {
          'address': address.address,
          'liveLocation': {
            'latitude': address.latitude,
            'longitude': address.longitude,
          },
        },
      );
    } catch (error) {
      debugPrint('OrderController._updateUserLocation fallback after $error');
    }
  }

  Future<VendorResolution> _resolveVendor(AddressModel address) async {
    final payload = {
      'latitude': address.latitude,
      'longitude': address.longitude,
      'radiusKm': productRadiusKm.value,
    };
    try {
      final response = await _api.post(
        endpoint: ApiConstants.resolveVendor,
        data: payload,
      );
      return VendorResolution.fromJson(
        response,
        radiusKm: productRadiusKm.value,
      );
    } catch (error) {
      debugPrint('OrderController._resolveVendor POST failed: $error');
    }
    try {
      final response = await _api.get(
        endpoint: ApiConstants.resolveVendor,
        query: payload,
      );
      return VendorResolution.fromJson(
        response,
        radiusKm: productRadiusKm.value,
      );
    } catch (error) {
      debugPrint('OrderController._resolveVendor GET failed: $error');
      return VendorResolution.unresolved();
    }
  }

  Future<void> _persistSelectedVendorContext(
    VendorResolution resolution,
  ) async {
    final vendorIds = _unique(
      resolution.options
          .map((option) => option.vendorId)
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty),
    );
    if (vendorIds.isNotEmpty) {
      await _storage.write(_selectedVendorIdStorageKey, vendorIds.join(','));
      return;
    }
    if (resolution.wasResolved) {
      await _storage.remove(_selectedVendorIdStorageKey);
    }
  }

  Future<void> _showAddressSelectionError(String title, String message) async {
    if (Get.isDialogOpen == true) return;
    await Get.dialog<void>(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: Get.back, child: const Text('OK'))],
      ),
    );
  }

  CheckoutVendorContext _resolveCheckoutVendorContext(
    List<CartItemModel> items,
    VendorResolution resolution,
  ) {
    final resolvedOptions = resolution.options;
    final cartVendorIds = _unique(
      items.map((item) => item.product.vendorId).where((id) => id.isNotEmpty),
    );
    final cartBranchIds = _unique(
      items.map((item) => item.product.branchId).where((id) => id.isNotEmpty),
    );

    if (resolvedOptions.isEmpty &&
        cartVendorIds.isEmpty &&
        cartBranchIds.isEmpty) {
      return CheckoutVendorContext(
        error:
            'Products in your cart are not available at this selected address. Please choose a different address or add products available near this location.',
      );
    }

    if (cartVendorIds.length > 1 || cartBranchIds.length > 1) {
      final fallback = resolvedOptions.firstOrNull;
      return CheckoutVendorContext(
        vendorId: fallback?.vendorId ?? cartVendorIds.firstOrNull,
        branchId: fallback?.branchId ?? cartBranchIds.firstOrNull,
      );
    }

    final cartVendorId = cartVendorIds.firstOrNull;
    final cartBranchId = cartBranchIds.firstOrNull;
    if (cartVendorId != null || cartBranchId != null) {
      final match = resolvedOptions.firstWhereOrNull(
        (option) =>
            (cartVendorId != null && option.vendorId == cartVendorId) ||
            (cartBranchId != null && option.branchId == cartBranchId),
      );
      return CheckoutVendorContext(
        vendorId: match?.vendorId ?? cartVendorId,
        branchId: match?.branchId ?? cartBranchId,
      );
    }

    final fallback = resolvedOptions.firstOrNull;
    if (fallback == null) {
      return CheckoutVendorContext(
        error:
            'We could not find any vendor for your selected address. Please try a different address or location.',
      );
    }
    return CheckoutVendorContext(
      vendorId: fallback.vendorId,
      branchId: fallback.branchId,
    );
  }

  Future<List<CartItemModel>> _findUnavailableCartItems(
    List<CartItemModel> items,
    VendorResolution resolution,
  ) async {
    if (items.isEmpty) return const [];
    final options = resolution.options;
    if (options.isEmpty) {
      debugPrint(
        'OrderController._findUnavailableCartItems: no resolved vendor options, marking all cart items unavailable',
      );
      return items.where((item) => item.quantity > 0).toList(growable: false);
    }

    final unavailableByScope = items.where((item) {
      final vendorIds = _productVendorIds(item.product);
      final branchIds = _productBranchIds(item.product);
      if (vendorIds.isEmpty && branchIds.isEmpty) return false;
      return !options.any(
        (option) =>
            (option.vendorId != null && vendorIds.contains(option.vendorId)) ||
            (option.branchId != null && branchIds.contains(option.branchId)),
      );
    }).toList();

    final unavailableIds = unavailableByScope
        .map((item) => item.product.id)
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    final productChecked = await _findUnavailableCartItemsByProduct(
      items.where((item) => !unavailableIds.contains(item.product.id)).toList(),
      options,
    );

    return [
      ...unavailableByScope,
      ...productChecked.where(
        (item) => !unavailableIds.contains(item.product.id),
      ),
    ];
  }

  Future<List<CartItemModel>> _findUnavailableCartItemsByProduct(
    List<CartItemModel> items,
    List<ResolvedVendorOption> options,
  ) async {
    if (!Get.isRegistered<CatalogRepository>()) {
      if (!Get.isRegistered<ApiService>()) return const [];
      Get.put(CatalogRepository(Get.find<ApiService>()), permanent: true);
    }
    final vendorIds = _unique(
      options.map((option) => option.vendorId).whereType<String>(),
    );
    if (vendorIds.isEmpty || items.isEmpty) return const [];

    final repository = Get.find<CatalogRepository>();
    final availabilityByCategory = <String, Set<String>>{};
    final unavailable = <CartItemModel>[];
    final selected = selectedCheckoutAddress.value;

    for (final item in items) {
      final categoryId = _productCategoryId(item.product);
      final productId = item.product.id.trim();
      if (productId.isEmpty) continue;
      if (categoryId.isEmpty) {
        final found = await _productExistsInSelectedScope(item.product);
        if (!found) unavailable.add(item);
        continue;
      }

      final availableIds = availabilityByCategory.putIfAbsent(categoryId, () {
        return <String>{};
      });
      if (availableIds.isEmpty) {
        final products = await repository.fetchProductsByCategory(
          categoryId,
          vendorIds: vendorIds,
          latitude: selected?.latitude,
          longitude: selected?.longitude,
        );
        availableIds.addAll(products.map((product) => product.id.trim()));
        debugPrint(
          'OrderController._findUnavailableCartItemsByProduct: category=$categoryId vendors=${vendorIds.join(',')} available=${availableIds.length}',
        );
      }
      if (!availableIds.contains(productId)) {
        unavailable.add(item);
      }
    }

    return unavailable;
  }

  Future<bool> _productExistsInSelectedScope(ProductModel product) async {
    final name = product.name.trim();
    final productId = product.id.trim();
    if (name.isEmpty || productId.isEmpty) return false;
    if (!Get.isRegistered<CatalogRepository>()) return false;
    final matches = await Get.find<CatalogRepository>().searchProducts(name);
    return matches.any((item) => item.id.trim() == productId);
  }

  List<String> _productVendorIds(ProductModel product) {
    final rawVendor = product.raw['vendor'];
    final vendor = rawVendor is Map
        ? Map<String, dynamic>.from(rawVendor)
        : const <String, dynamic>{};
    return _unique([
      product.vendorId,
      product.raw['vendorId']?.toString() ?? '',
      product.raw['vendor_id']?.toString() ?? '',
      if (rawVendor is! Map) rawVendor?.toString() ?? '',
      vendor['id']?.toString() ?? '',
      vendor['_id']?.toString() ?? '',
      vendor['vendorId']?.toString() ?? '',
      vendor['vendor_id']?.toString() ?? '',
    ]);
  }

  List<String> _productBranchIds(ProductModel product) {
    final rawBranch = product.raw['branch'];
    final branch = rawBranch is Map
        ? Map<String, dynamic>.from(rawBranch)
        : const <String, dynamic>{};
    return _unique([
      product.branchId,
      product.raw['branchId']?.toString() ?? '',
      product.raw['branch_id']?.toString() ?? '',
      if (rawBranch is! Map) rawBranch?.toString() ?? '',
      branch['id']?.toString() ?? '',
      branch['_id']?.toString() ?? '',
      branch['branchId']?.toString() ?? '',
      branch['branch_id']?.toString() ?? '',
    ]);
  }

  String _productCategoryId(ProductModel product) {
    final category = product.raw['category'] is Map
        ? Map<String, dynamic>.from(product.raw['category'] as Map)
        : const <String, dynamic>{};
    return _firstNonEmpty([
          product.categoryId,
          product.raw['categoryId'],
          product.raw['category_id'],
          product.raw['productCategory'],
          product.raw['product_category'],
          category['id'],
          category['_id'],
          category['categoryId'],
          category['category_id'],
        ]) ??
        '';
  }

  Future<void> _handleUnavailableCartItems(List<CartItemModel> items) async {
    isHandlingUnavailableCart.value = true;
    try {
      final unavailableIds = items
          .map((item) => item.product.id.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      if (unavailableIds.isEmpty ||
          unavailableIds.length == _cartController.items.length) {
        await _cartController.clearCart(notify: false);
      } else {
        await _cartController.removeItemsCompletely(unavailableIds);
      }
      selectedCoupon.value = null;
      couponCodeController.clear();
      couponFeedback.value = null;
      await _showUnavailableCartDialog(
        items.length == 1
            ? "This item isn't available at your location and has been removed from your cart."
            : "These items aren't available at your location and have been removed from your cart.",
      );
      Get.offAllNamed(AppRoutes.dashboard, arguments: {'tabIndex': 0});
    } finally {
      isHandlingUnavailableCart.value = false;
    }
  }

  Future<void> _showUnavailableCartDialog(String message) async {
    if (Get.isBottomSheetOpen == true) {
      Get.back<void>();
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }

    if (Get.isDialogOpen == true) {
      Get.back<void>();
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (Get.overlayContext == null && Get.context == null) {
      AppSnackBar.show(
        'Item unavailable',
        message,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));
      return;
    }

    await Get.dialog<void>(
      _UnavailableCartDialog(message: message),
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
    );
  }

  Map<String, dynamic> _buildOrderPayload({
    required List<CartItemModel> items,
    required String address,
    required double? latitude,
    required double? longitude,
    required CheckoutVendorContext vendorContext,
    required CheckoutTotals totals,
    required String customerName,
    required String customerPhone,
  }) {
    final vendorId = vendorContext.vendorId;
    final branchId = vendorContext.branchId;
    final orderItems = items.map((item) {
      final productId = item.product.id;
      final itemVendorId = item.product.vendorId.isNotEmpty
          ? item.product.vendorId
          : vendorId;
      final itemBranchId = item.product.branchId.isNotEmpty
          ? item.product.branchId
          : branchId;
      return {
        'id': productId,
        'item': productId,
        'productId': productId,
        'product': productId,
        'product_id': productId,
        'count': item.quantity,
        'quantity': item.quantity,
        'vendorId': itemVendorId,
        'vendor_id': itemVendorId,
        'vendor': itemVendorId,
        'branchId': itemBranchId,
        'branch_id': itemBranchId,
        'branch': itemBranchId,
      };
    }).toList();
    final coupon = totals.appliedCoupon;
    final payload = <String, dynamic>{
      'items': orderItems,
      'vendorId': vendorId,
      'vendor_id': vendorId,
      'vendor': vendorId,
      'branchId': branchId,
      'branch_id': branchId,
      'branch': branchId,
      'vendorDetails': vendorId != null || branchId != null
          ? {
              'vendorId': vendorId,
              'vendor_id': vendorId,
              'branchId': branchId,
              'branch_id': branchId,
            }
          : null,
      'routingContext': vendorId != null || branchId != null
          ? {'vendorId': vendorId, 'branchId': branchId}
          : null,
      'totalPrice': totals.grandTotal,
      'subtotal': totals.grandTotal,
      'deliveryFee': totals.deliveryCharge,
      'taxAmount': totals.gstAmount,
      'paymentMode': selectedPaymentMode.value,
      'itemsTotal': totals.itemsTotal,
      'totalWithGst': totals.totalBeforeDiscount,
      'couponId': coupon?.id,
      'couponCode': coupon?.code,
      'couponDiscount': totals.couponDiscount,
      'discountAmount': totals.couponDiscount,
      'discountType': coupon?.discountType.name,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'address': address,
    };
    if (latitude != null && longitude != null) {
      payload['latitude'] = latitude;
      payload['longitude'] = longitude;
    }
    payload.removeWhere((_, value) => value == null);
    return payload;
  }

  Future<bool> _hasIncompleteProductOrder() async {
    final userId = _authController?.currentUser?.id ?? '';
    final allOrders = await _tryFetchOrders(userIdOverride: userId);
    final source = allOrders.isNotEmpty ? allOrders : orders;
    return source.any((order) {
      final status = order.status.toLowerCase();
      return status != 'delivered' && status != 'cancelled';
    });
  }

  Future<List<OrderModel>> _tryFetchOrders({String? userIdOverride}) async {
    if (!Get.isRegistered<ApiService>()) return <OrderModel>[];
    try {
      final userId = userIdOverride ?? _authController?.currentUser?.id ?? '';
      final response = await _api.get(
        endpoint: ApiConstants.orders,
        query: userId.isEmpty ? null : {'customerId': userId},
      );
      final list =
          _extractList(response)
              .whereType<Map>()
              .map(
                (item) => OrderModel.fromJson(Map<String, dynamic>.from(item)),
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

  Future<OrderModel?> _tryFetchOrderById(String id) async {
    if (!Get.isRegistered<ApiService>()) return null;
    if (id.trim().isEmpty) return null;
    try {
      final response = await _api.get(endpoint: ApiConstants.orderById(id));
      final raw = _extractOrderMap(response);
      final order = OrderModel.fromJson(raw);
      return order.id.isEmpty ? null : order;
    } catch (error) {
      debugPrint('OrderController._tryFetchOrderById failed: $error');
      return null;
    }
  }

  Future<void> _enrichOrdersMissingItemDetails(List<OrderModel> source) async {
    for (final order in source.where(_needsItemDetailRefresh)) {
      for (final id in _orderIdentifiers(order)) {
        final detailed = await _tryFetchOrderById(id);
        if (detailed != null && !_needsItemDetailRefresh(detailed)) {
          await _upsertOrder(detailed);
          break;
        }
      }
    }
  }

  bool _needsItemDetailRefresh(OrderModel order) {
    if (order.items.isEmpty) return order.resolvedItemCount > 0;
    return order.items.every((item) => item.product.name.trim().isEmpty);
  }

  OrderModel? _latestActiveProductOrder(Iterable<OrderModel> source) {
    final active =
        source
            .where((order) => order.isProductOrder && !order.isInactive)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return active.firstOrNull;
  }

  List<String> _orderIdentifiers(OrderModel order) {
    return [
          order.id,
          order.raw['_id'],
          order.raw['orderId'],
          order.raw['orderNumber'],
        ]
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _upsertOrder(OrderModel order) async {
    final incomingIds = _orderIdentifiers(order).toSet();
    final index = orders.indexWhere(
      (item) => _orderIdentifiers(item).any(incomingIds.contains),
    );
    if (index >= 0) {
      orders[index] = order;
    } else {
      orders.insert(0, order);
    }

    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    latestOrder.value = orders.firstOrNull;
    activeProductOrder.value = _latestActiveProductOrder(orders);

    final selected = selectedOrder.value;
    if (selected != null &&
        _orderIdentifiers(selected).any(incomingIds.contains)) {
      selectedOrder.value = order;
    }

    await _persistOrders();
  }

  ({double latitude, double longitude})? _coordinateFrom(Object? source) {
    if (source == null) return null;
    if (source is String) {
      final trimmed = source.trim();
      if (trimmed.isEmpty) return null;
      try {
        return _coordinateFrom(jsonDecode(trimmed));
      } catch (_) {
        return null;
      }
    }
    if (source is List && source.length >= 2) {
      final first = _double(source[0]);
      final second = _double(source[1]);
      if (first != null && second != null) {
        final latitude = first.abs() <= 90 && second.abs() <= 180
            ? first
            : second;
        final longitude = latitude == first ? second : first;
        return _validCoordinate(latitude, longitude)
            ? (latitude: latitude, longitude: longitude)
            : null;
      }
    }
    if (source is! Map) return null;

    final map = Map<String, dynamic>.from(source);
    final nested =
        map['coordinates'] ??
        map['location'] ??
        map['liveLocation'] ??
        map['geo'] ??
        map['position'];
    if (nested != null && !identical(nested, source)) {
      final coordinate = _coordinateFrom(nested);
      if (coordinate != null) return coordinate;
    }

    final latitude = _double(map['latitude'] ?? map['lat'] ?? map['_latitude']);
    final longitude = _double(
      map['longitude'] ?? map['lng'] ?? map['long'] ?? map['_longitude'],
    );
    if (latitude == null || longitude == null) return null;
    return _validCoordinate(latitude, longitude)
        ? (latitude: latitude, longitude: longitude)
        : null;
  }

  double? _double(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  bool _validCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  double _distanceKm(
    ({double latitude, double longitude}) origin,
    ({double latitude, double longitude}) destination,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(destination.latitude - origin.latitude);
    final dLon = _radians(destination.longitude - origin.longitude);
    final lat1 = _radians(origin.latitude);
    final lat2 = _radians(destination.latitude);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _radians(double value) => value * pi / 180;

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

  Map<String, dynamic> _extractOrderMap(Map<String, dynamic> response) {
    for (final key in ['data', 'order', 'result', 'payload']) {
      final value = response[key];
      if (value is Map) return Map<String, dynamic>.from(value);
      if (value is List && value.isNotEmpty && value.first is Map) {
        return Map<String, dynamic>.from(value.first as Map);
      }
    }
    return response;
  }

  Future<void> _persistOrders() async {
    await _storage.write(
      _ordersStorageKey,
      orders.map((item) => item.toJson()).toList(),
    );
  }

  Future<Map<String, dynamic>> _firestoreGet(
    String path, {
    bool isDocument = false,
  }) async {
    final firebaseHeaders = await _firebaseAuthHeaders();
    final options = DefaultFirebaseOptions.firestoreRestOptions;
    final base =
        'https://firestore.googleapis.com/v1/projects/${options.projectId}/databases/(default)/documents/$path';
    final endpoint = '$base?key=${options.apiKey}';
    return _api.get(
      endpoint: endpoint,
      authenticated: false,
      headers: firebaseHeaders,
    );
  }

  Future<Map<String, String>?> _firebaseAuthHeaders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final token = await user.getIdToken();
      if (token == null || token.trim().isEmpty) return null;
      return {'Authorization': 'Bearer $token'};
    } catch (error) {
      debugPrint('OrderController._firebaseAuthHeadersfailed: $error');
      return null;
    }
  }

  bool _hasValidCoordinates(double? lat, double? lng) {
    return lat != null && lng != null && lat.isFinite && lng.isFinite;
  }

  bool _matchesTargetUser(CheckoutCoupon coupon) {
    if (coupon.targetUserKeys.contains('all')) return true;
    final user = _authController?.currentUser;
    if (user == null) return false;
    final userTokens = _unique(
      [
        user.id,
        user.phone,
        user.phone.replaceAll(RegExp(r'\D'), ''),
        user.phone.replaceAll(RegExp(r'\D'), '').length >= 10
            ? user.phone
                  .replaceAll(RegExp(r'\D'), '')
                  .substring(
                    user.phone.replaceAll(RegExp(r'\D'), '').length - 10,
                  )
            : '',
        user.email,
        user.name,
      ].map(_normalizeText),
    );
    return coupon.targetUserKeys.any(userTokens.contains);
  }

  bool _matchesCouponCategory(
    CheckoutCoupon coupon,
    List<CartItemModel> items,
  ) {
    final category = _normalizeText(coupon.category);
    if (category.isEmpty || category == 'all' || category == 'all categories') {
      return true;
    }
    final tokens = <String>{};
    for (final item in items) {
      final product = item.product;
      [
        product.categoryId,
        product.raw['category'],
        product.raw['categoryId'],
        product.raw['category_id'],
        product.raw['categoryName'],
        product.raw['productCategory'],
        product.raw['product_category'],
      ].expand(_collectTokens).forEach(tokens.add);
    }
    return tokens.contains(category);
  }

  double _calculateCouponDiscount(
    CheckoutCoupon coupon,
    List<CartItemModel> items,
    double totalBeforeDiscount,
  ) {
    final message = couponEligibilityMessage(coupon, items);
    if (message != null) return 0;
    final itemsTotal = items.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );
    final raw = coupon.discountType == CouponDiscountType.percentage
        ? (itemsTotal * coupon.discountValue) / 100
        : coupon.discountValue;
    return _roundCurrency(max(0, min(raw, totalBeforeDiscount)));
  }

  double _roundCurrency(double value) => double.parse(value.toStringAsFixed(2));

  String _formatAmount(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  List<CheckoutCoupon> _dedupeCoupons(List<CheckoutCoupon> coupons) {
    final seen = <String>{};
    final result = <CheckoutCoupon>[];
    for (final coupon in coupons) {
      final key =
          (coupon.id.isNotEmpty ? coupon.id : '${coupon.code}-${coupon.title}')
              .trim();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(coupon);
    }
    return result;
  }

  String _normalizeText(Object? value) => value.toString().trim().toLowerCase();

  String _normalizeCodeToken(Object? value) {
    return value.toString().trim().toUpperCase().replaceAll(
      RegExp('[^A-Z0-9]'),
      '',
    );
  }

  String? _firstNonEmpty(Iterable<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  List<String> _collectTokens(Object? value) {
    if (value == null) return const [];
    if (value is Iterable) return value.expand(_collectTokens).toList();
    if (value is Map) {
      return [
        value['id'],
        value['_id'],
        value['userId'],
        value['customerId'],
        value['phone'],
        value['mobile'],
        value['contactNumber'],
        value['email'],
        value['name'],
        value['title'],
        value['label'],
        value['value'],
        value['slug'],
        value['code'],
        value['couponCode'],
        value['categoryId'],
        value['category_id'],
      ].expand(_collectTokens).toList();
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return const [];
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return _unique([
      _normalizeText(raw),
      if (digits.length >= 10) digits,
      if (digits.length >= 10) digits.substring(digits.length - 10),
      _normalizeCodeToken(raw),
    ]);
  }

  List<String> _unique(Iterable<String?> values) {
    return values
        .where((value) => value != null && value.trim().isNotEmpty)
        .map((value) => value!.trim())
        .toSet()
        .toList();
  }

  Map<String, dynamic> _decodeFirestoreFields(Object? fields) {
    if (fields is! Map) return const {};
    return fields.map(
      (key, value) => MapEntry(key.toString(), _decodeFirestoreValue(value)),
    );
  }

  Object? _decodeFirestoreValue(Object? value) {
    if (value is! Map) return value;
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('integerValue')) {
      return num.tryParse(value['integerValue'].toString());
    }
    if (value.containsKey('doubleValue')) {
      return num.tryParse(value['doubleValue'].toString());
    }
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('timestampValue')) return value['timestampValue'];
    if (value.containsKey('mapValue')) {
      final fields = value['mapValue'] is Map
          ? (value['mapValue'] as Map)['fields']
          : null;
      return _decodeFirestoreFields(fields);
    }
    if (value.containsKey('arrayValue')) {
      final values = value['arrayValue'] is Map
          ? (value['arrayValue'] as Map)['values']
          : null;
      if (values is List) return values.map(_decodeFirestoreValue).toList();
      return const [];
    }
    return null;
  }

  Object? _readPath(Map<String, dynamic> source, String path) {
    Object? current = source;
    for (final segment in path.split('.')) {
      if (current is! Map) return null;
      current = current[segment];
    }
    return current;
  }

  double _readNumber(
    Map<String, dynamic> source,
    List<String> paths,
    double fallback,
  ) {
    for (final path in paths) {
      final value = _readPath(source, path);
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  ApiService get _api => Get.find<ApiService>();

  CartController get _cartController => Get.find<CartController>();

  AuthController? get _authController =>
      Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;

  ProfileController? get _profileController =>
      Get.isRegistered<ProfileController>()
      ? Get.find<ProfileController>()
      : null;

  @override
  void onClose() {
    deliveryAddressController.dispose();
    couponCodeController.dispose();
    super.onClose();
  }

  void _notifyAction(String title, String message, {required String category}) {
    if (!Get.isRegistered<NotificationService>()) return;
    unawaited(
      Get.find<NotificationService>().record(
        title: title,
        message: message,
        category: category,
      ),
    );
  }
}

class _UnavailableCartDialog extends StatelessWidget {
  const _UnavailableCartDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 1.4),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close),
                    color: AppColors.primary,
                    iconSize: 15,
                    onPressed: Get.back,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Item unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: Get.back,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckoutTotals {
  const CheckoutTotals({
    required this.itemsTotal,
    required this.gstAmount,
    required this.totalBeforeDiscount,
    required this.deliveryCharge,
    required this.couponDiscount,
    required this.grandTotal,
    required this.hasValidItems,
    required this.appliedCoupon,
  });

  final double itemsTotal;
  final double gstAmount;
  final double totalBeforeDiscount;
  final double deliveryCharge;
  final double couponDiscount;
  final double grandTotal;
  final bool hasValidItems;
  final CheckoutCoupon? appliedCoupon;
}

class FirestoreAuthUnavailableException implements Exception {
  const FirestoreAuthUnavailableException();

  @override
  String toString() => 'Firestore auth unavailable';
}

enum CouponDiscountType { percentage, fixed }

enum CouponStatus { scheduled, active, expired }

class CheckoutCoupon {
  const CheckoutCoupon({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.category,
    required this.discountType,
    required this.discountValue,
    required this.minimumOrderAmount,
    required this.targetUserKeys,
    required this.matchKeys,
    required this.status,
    required this.isActive,
  });

  final String id;
  final String code;
  final String title;
  final String description;
  final String category;
  final CouponDiscountType discountType;
  final double discountValue;
  final double minimumOrderAmount;
  final List<String> targetUserKeys;
  final List<String> matchKeys;
  final CouponStatus status;
  final bool isActive;

  factory CheckoutCoupon.fromFirestoreDocument(Map document) {
    final name = document['name']?.toString() ?? '';
    final id = _CouponParser.stringValue([
      name.split('/').last,
      document['id'],
      document['_id'],
      document['documentId'],
    ]);
    final fields = document.containsKey('fields')
        ? _CouponParser.decodeFields(document['fields'])
        : Map<String, dynamic>.from(document);
    final title = _CouponParser.stringValue([
      fields['title'],
      fields['name'],
      fields['couponTitle'],
      fields['couponName'],
      fields['couponCode'],
      fields['code'],
    ]);
    final description = _CouponParser.stringValue([
      fields['description'],
      fields['details'],
      fields['subtitle'],
      title,
    ]);
    final startAt = _CouponParser.dateValue([
      fields['startDate'],
      fields['startAt'],
      fields['validFrom'],
      fields['fromDate'],
    ]);
    final endAt = _CouponParser.dateValue([
      fields['endDate'],
      fields['endAt'],
      fields['validTill'],
      fields['validUntil'],
      fields['toDate'],
    ]);
    final discountValue = _CouponParser.numberValue([
      fields['discountValue'],
      fields['discount'],
      fields['amount'],
      fields['value'],
    ]);
    final targetSource =
        fields['targetUser'] ??
        fields['assignedUser'] ??
        fields['assignedTo'] ??
        fields['user'] ??
        fields['customer'] ??
        fields['customerId'] ??
        fields['userId'] ??
        'all';

    if (id.isEmpty ||
        title.isEmpty ||
        description.isEmpty ||
        startAt == null ||
        endAt == null ||
        endAt.isBefore(startAt) ||
        discountValue <= 0) {
      throw const FormatException('Invalid coupon');
    }

    final now = DateTime.now();
    final status = now.isBefore(startAt)
        ? CouponStatus.scheduled
        : now.isAfter(endAt)
        ? CouponStatus.expired
        : CouponStatus.active;
    final codeSource =
        fields['code'] ??
        fields['couponCode'] ??
        fields['coupon'] ??
        fields['coupon_code'] ??
        title;
    return CheckoutCoupon(
      id: id,
      code: _CouponParser.displayCode(codeSource),
      title: title,
      description: description,
      category: _CouponParser.stringValue([
        _CouponParser.categoryValue(fields['category']),
        fields['categoryName'],
        fields['productCategory'],
        fields['product_category'],
        'all',
      ]),
      discountType: _CouponParser.discountType(
        fields['discountType'] ?? fields['type'] ?? fields['discount_mode'],
      ),
      discountValue: discountValue,
      minimumOrderAmount: _CouponParser.numberValue([
        fields['minimumOrderAmount'],
        fields['minimumOrder'],
        fields['minOrderAmount'],
        fields['minOrder'],
        fields['minimum_purchase_amount'],
        fields['min_purchase_amount'],
        fields['minimumCartAmount'],
        fields['minimumCartValue'],
      ]),
      targetUserKeys: _CouponParser.collectTokens(targetSource),
      matchKeys: _CouponParser.collectTokens([
        title,
        fields['title'],
        fields['code'],
        fields['couponCode'],
        fields['coupon'],
        fields['coupon_code'],
        fields['name'],
        id,
      ]),
      status: status,
      isActive: status == CouponStatus.active,
    );
  }
}

class _CouponParser {
  static Map<String, dynamic> decodeFields(Object? fields) {
    if (fields is! Map) return const {};
    return fields.map(
      (key, value) => MapEntry(key.toString(), decodeValue(value)),
    );
  }

  static Object? decodeValue(Object? value) {
    if (value is! Map) return value;
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('integerValue')) {
      return num.tryParse(value['integerValue'].toString());
    }
    if (value.containsKey('doubleValue')) {
      return num.tryParse(value['doubleValue'].toString());
    }
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('timestampValue')) return value['timestampValue'];
    if (value.containsKey('mapValue')) {
      final fields = value['mapValue'] is Map
          ? (value['mapValue'] as Map)['fields']
          : null;
      return decodeFields(fields);
    }
    if (value.containsKey('arrayValue')) {
      final values = value['arrayValue'] is Map
          ? (value['arrayValue'] as Map)['values']
          : null;
      if (values is List) return values.map(decodeValue).toList();
      return const [];
    }
    return null;
  }

  static String stringValue(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String categoryValue(Object? value) {
    if (value is Map) {
      return stringValue([
        value['name'],
        value['title'],
        value['id'],
        value['_id'],
        value['label'],
        value['value'],
      ]);
    }
    return value?.toString().trim() ?? '';
  }

  static double numberValue(List<Object?> values) {
    for (final value in values) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  static DateTime? dateValue(List<Object?> values) {
    for (final value in values) {
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      if (value is Map && value['seconds'] is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          (value['seconds'] as num).toInt() * 1000,
        );
      }
    }
    return null;
  }

  static CouponDiscountType discountType(Object? value) {
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'fixed' ||
        normalized == 'flat' ||
        normalized == 'amount' ||
        normalized == 'cash') {
      return CouponDiscountType.fixed;
    }
    return CouponDiscountType.percentage;
  }

  static String displayCode(Object? value) =>
      value.toString().trim().toUpperCase();

  static List<String> collectTokens(Object? value) {
    if (value == null) return const [];
    if (value is Iterable) return value.expand(collectTokens).toSet().toList();
    if (value is Map) {
      return [
        value['id'],
        value['_id'],
        value['userId'],
        value['customerId'],
        value['phone'],
        value['mobile'],
        value['contactNumber'],
        value['email'],
        value['name'],
        value['title'],
        value['label'],
        value['value'],
        value['slug'],
        value['code'],
        value['couponCode'],
        value['categoryId'],
        value['category_id'],
      ].expand(collectTokens).toSet().toList();
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return const [];
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return {
      raw.toLowerCase(),
      if (digits.length >= 10) digits,
      if (digits.length >= 10) digits.substring(digits.length - 10),
      raw.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), ''),
    }.where((item) => item.isNotEmpty).toList();
  }
}

class VendorResolution {
  VendorResolution({required this.options, this.wasResolved = true});

  final List<ResolvedVendorOption> options;
  final bool wasResolved;

  String get debugSummary => options
      .map(
        (option) =>
            'v=${option.vendorId ?? '-'} b=${option.branchId ?? '-'} d=${option.distanceKm?.toStringAsFixed(2) ?? '-'}',
      )
      .join(' | ');

  factory VendorResolution.empty() => VendorResolution(options: const []);

  factory VendorResolution.unresolved() =>
      VendorResolution(options: const [], wasResolved: false);

  factory VendorResolution.fromJson(
    Map<String, dynamic> json, {
    double? radiusKm,
  }) {
    final options = <ResolvedVendorOption>[];
    final vendors = _extractVendors(json);
    for (final vendor in vendors) {
      final option = ResolvedVendorOption.fromJson(vendor);
      if ((option.vendorId != null || option.branchId != null) &&
          _isWithinRadius(vendor, radiusKm)) {
        options.add(option);
      }
    }
    if (vendors.isEmpty && _isResponseWithinRadius(json, radiusKm)) {
      for (final vendorId in _extractVendorIds(json)) {
        options.add(
          ResolvedVendorOption(
            vendorId: vendorId,
            distanceKm: _distanceKmFrom(json),
          ),
        );
      }
    }
    for (final directSource in _extractDirectSources(json)) {
      if (!_isResponseWithinRadius(directSource, radiusKm)) continue;
      final direct = ResolvedVendorOption.fromJson(directSource);
      if (direct.vendorId != null || direct.branchId != null) {
        options.add(direct);
      }
    }
    final seen = <String>{};
    return VendorResolution(
      options: options.where((option) {
        final key = '${option.vendorId ?? ''}|${option.branchId ?? ''}';
        if (seen.contains(key)) return false;
        seen.add(key);
        return true;
      }).toList(),
    );
  }

  static bool _isResponseWithinRadius(
    Map<String, dynamic> source,
    double? radiusKm,
  ) {
    if (!_isWithinRadius(source, radiusKm)) return false;
    for (final candidate in [
      source['nearestVendor'],
      if (source['data'] is Map) (source['data'] as Map)['nearestVendor'],
      if (source['result'] is Map) (source['result'] as Map)['nearestVendor'],
    ]) {
      if (candidate is! Map) continue;
      final nested = Map<String, dynamic>.from(candidate);
      if (_distanceKmFrom(nested) != null &&
          !_isWithinRadius(nested, radiusKm)) {
        return false;
      }
    }
    return true;
  }

  static bool _isWithinRadius(Map<String, dynamic> source, double? radiusKm) {
    if (radiusKm == null || radiusKm <= 0) return true;
    final distanceKm = _distanceKmFrom(source);
    return distanceKm == null || distanceKm <= radiusKm;
  }

  static List<Map<String, dynamic>> _extractVendors(Map<String, dynamic> json) {
    final candidates = [
      json['vendors'],
      json['nearbyVendors'],
      json['availableVendors'],
      json['branches'],
      json['stores'],
      json['data'],
      if (json['data'] is Map) (json['data'] as Map)['vendors'],
      if (json['data'] is Map) (json['data'] as Map)['nearbyVendors'],
      if (json['data'] is Map) (json['data'] as Map)['availableVendors'],
      if (json['data'] is Map) (json['data'] as Map)['branches'],
      if (json['data'] is Map) (json['data'] as Map)['stores'],
      if (json['result'] is Map) (json['result'] as Map)['vendors'],
      if (json['result'] is Map) (json['result'] as Map)['nearbyVendors'],
      if (json['result'] is Map) (json['result'] as Map)['availableVendors'],
      if (json['result'] is Map) (json['result'] as Map)['branches'],
      if (json['result'] is Map) (json['result'] as Map)['stores'],
    ];
    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return const [];
  }

  static List<String> _extractVendorIds(Map<String, dynamic> json) {
    final candidates = [
      json['vendorIds'],
      json['vendor_ids'],
      if (json['data'] is Map) (json['data'] as Map)['vendorIds'],
      if (json['data'] is Map) (json['data'] as Map)['vendor_ids'],
      if (json['result'] is Map) (json['result'] as Map)['vendorIds'],
      if (json['result'] is Map) (json['result'] as Map)['vendor_ids'],
    ];
    return candidates
        .whereType<List>()
        .expand((items) => items)
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  static List<Map<String, dynamic>> _extractDirectSources(
    Map<String, dynamic> json,
  ) {
    final candidates = [
      json,
      json['nearestVendor'],
      json['vendor'],
      json['branch'],
      json['store'],
      if (json['data'] is Map) json['data'],
      if (json['data'] is Map) (json['data'] as Map)['nearestVendor'],
      if (json['data'] is Map) (json['data'] as Map)['vendor'],
      if (json['data'] is Map) (json['data'] as Map)['branch'],
      if (json['data'] is Map) (json['data'] as Map)['store'],
      if (json['result'] is Map) json['result'],
      if (json['result'] is Map) (json['result'] as Map)['nearestVendor'],
      if (json['result'] is Map) (json['result'] as Map)['vendor'],
      if (json['result'] is Map) (json['result'] as Map)['branch'],
      if (json['result'] is Map) (json['result'] as Map)['store'],
    ];
    return candidates
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static double? _distanceKmFrom(Map<String, dynamic> source) {
    for (final key in const [
      'distanceKm',
      'distance_km',
      'distanceKM',
      'distance',
      'distanceInKm',
      'distance_in_km',
    ]) {
      final parsed = _numberFrom(source[key]);
      if (parsed != null) return parsed;
    }
    for (final key in const [
      'distanceMeters',
      'distance_meters',
      'distanceInMeters',
      'distance_in_meters',
    ]) {
      final parsed = _numberFrom(source[key]);
      if (parsed != null) return parsed / 1000;
    }
    return null;
  }

  static double? _numberFrom(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    if (value is Map) {
      for (final key in const ['km', 'text', 'value']) {
        final parsed = _numberFrom(value[key]);
        if (parsed != null) return parsed;
      }
      return null;
    }
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final direct = double.tryParse(raw);
    if (direct != null) return direct;
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(raw);
    return match == null ? null : double.tryParse(match.group(0)!);
  }
}

class ResolvedVendorOption {
  const ResolvedVendorOption({
    this.vendorId,
    this.branchId,
    this.label,
    this.distanceKm,
  });

  final String? vendorId;
  final String? branchId;
  final String? label;
  final double? distanceKm;

  factory ResolvedVendorOption.fromJson(Map<String, dynamic> json) {
    String? id(Object? value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    final vendor = json['vendor'] is Map
        ? Map<String, dynamic>.from(json['vendor'] as Map)
        : const <String, dynamic>{};
    final branch = json['branch'] is Map
        ? Map<String, dynamic>.from(json['branch'] as Map)
        : const <String, dynamic>{};
    return ResolvedVendorOption(
      vendorId:
          id(json['vendorId']) ??
          id(json['vendor_id']) ??
          id(json['id']) ??
          id(vendor['id']) ??
          id(vendor['vendorId']),
      branchId:
          id(json['branchId']) ??
          id(json['branch_id']) ??
          id(branch['id']) ??
          id(branch['branchId']),
      label: id(json['branchName']) ?? id(json['name']),
      distanceKm: VendorResolution._distanceKmFrom(json),
    );
  }
}

class CheckoutVendorContext {
  const CheckoutVendorContext({this.vendorId, this.branchId, this.error});

  final String? vendorId;
  final String? branchId;
  final String? error;
}
