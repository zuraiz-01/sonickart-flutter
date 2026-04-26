import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../data/models/cart_item_model.dart';
import '../../../data/models/product_model.dart';

class CartController extends GetxController {
  static const _storageKey = 'cart_items';

  final GetStorage _storage;

  CartController(this._storage);

  final items = <CartItemModel>[].obs;
  final isSyncingCart = false.obs;
  final isClearingCart = false.obs;

  int get totalItems => items.fold<int>(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      items.fold<double>(0, (sum, item) => sum + item.totalPrice);

  double get grandTotal => subtotal;

  bool get isEmpty => items.isEmpty;

  @override
  void onInit() {
    super.onInit();
    debugPrint('CartController.onInit: cart controller started');
    syncCartFromStorage();
  }

  Future<void> syncCartFromStorage() async {
    debugPrint('CartController.syncCartFromStorage: syncing cart from storage');
    isSyncingCart.value = true;
    try {
      final rawItems = _storage.read<List<dynamic>>(_storageKey) ?? <dynamic>[];
      final restoredItems = rawItems
          .map(
            (item) =>
                CartItemModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .where((item) => item.product.id.isNotEmpty && item.quantity > 0)
          .toList();
      final serverItems = await _tryFetchServerCart();
      items.assignAll(serverItems.isNotEmpty ? serverItems : restoredItems);
      debugPrint(
        'CartController.syncCartFromStorage: restored ${items.length} lines and $totalItems total items',
      );
    } catch (error, stackTrace) {
      debugPrint('CartController.syncCartFromStorage: failed with $error');
      debugPrintStack(stackTrace: stackTrace);
      items.clear();
    } finally {
      isSyncingCart.value = false;
    }
  }

  Future<void> addItem(ProductModel product) async {
    if (product.id.isEmpty) {
      Get.snackbar(
        'Product Error',
        'This product cannot be added right now.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    debugPrint(
      'CartController.addItem: requested add for ${product.id} ${product.name}',
    );
    final itemIndex = items.indexWhere((item) => item.product.id == product.id);
    if (itemIndex >= 0) {
      final currentItem = items[itemIndex];
      items[itemIndex] = currentItem.copyWith(
        quantity: currentItem.quantity + 1,
      );
      debugPrint(
        'CartController.addItem: incremented ${product.id} to ${items[itemIndex].quantity}',
      );
    } else {
      items.add(CartItemModel(product: product, quantity: 1));
      debugPrint('CartController.addItem: added new product ${product.id}');
    }
    await _persistCart();
    await _trySyncLine(product.id, getItemCount(product.id));
  }

  Future<void> removeItem(String productId) async {
    debugPrint('CartController.removeItem: requested remove for $productId');
    final itemIndex = items.indexWhere((item) => item.product.id == productId);
    if (itemIndex < 0) {
      debugPrint('CartController.removeItem: item $productId not found');
      return;
    }

    final currentItem = items[itemIndex];
    if (currentItem.quantity > 1) {
      items[itemIndex] = currentItem.copyWith(
        quantity: currentItem.quantity - 1,
      );
      debugPrint(
        'CartController.removeItem: decremented $productId to ${items[itemIndex].quantity}',
      );
    } else {
      items.removeAt(itemIndex);
      debugPrint('CartController.removeItem: removed line for $productId');
    }
    await _persistCart();
    await _trySyncLine(productId, getItemCount(productId));
  }

  Future<void> clearCart() async {
    debugPrint('CartController.clearCart: clear cart requested');
    if (isClearingCart.value) {
      debugPrint('CartController.clearCart: already clearing, skipping');
      return;
    }

    isClearingCart.value = true;
    try {
      items.clear();
      await _persistCart();
      await _tryClearServerCart();
      debugPrint('CartController.clearCart: cart cleared successfully');
    } finally {
      isClearingCart.value = false;
    }
  }

  int getItemCount(String productId) {
    final index = items.indexWhere((item) => item.product.id == productId);
    final quantity = index >= 0 ? items[index].quantity : 0;
    return quantity;
  }

  Future<void> _persistCart() async {
    final payload = items.map((item) => item.toJson()).toList();
    await _storage.write(_storageKey, payload);
    debugPrint(
      'CartController._persistCart: persisted ${items.length} lines and $totalItems total items',
    );
  }

  Future<List<CartItemModel>> _tryFetchServerCart() async {
    if (!Get.isRegistered<ApiService>()) return const [];
    if (!_hasAccessToken) return const [];
    try {
      final response = await Get.find<ApiService>().get(
        endpoint: ApiConstants.cartFetch,
      );
      final raw = _extractCartList(response);
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map(
              (item) => CartItemModel.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((item) => item.product.id.isNotEmpty && item.quantity > 0)
            .toList();
      }
    } catch (error) {
      debugPrint(
        'CartController._tryFetchServerCart: storage fallback after $error',
      );
    }
    return const [];
  }

  Future<void> _trySyncLine(String productId, int quantity) async {
    if (!Get.isRegistered<ApiService>()) return;
    if (!_hasAccessToken) {
      return;
    }
    try {
      if (quantity <= 0) {
        await Get.find<ApiService>().delete(
          endpoint: ApiConstants.cartRemove,
          data: {'productId': productId},
        );
        return;
      }
      await Get.find<ApiService>().post(
        endpoint: ApiConstants.cartAdd,
        data: {'productId': productId, 'quantity': quantity},
      );
    } catch (error) {
      debugPrint('CartController._trySyncLine: local fallback after $error');
    }
  }

  Future<void> _tryClearServerCart() async {
    if (!Get.isRegistered<ApiService>()) return;
    if (!_hasAccessToken) return;
    try {
      try {
        await Get.find<ApiService>().delete(endpoint: ApiConstants.cartClear);
      } catch (_) {
        await Get.find<ApiService>().post(endpoint: ApiConstants.cartClear);
      }
    } catch (error) {
      debugPrint(
        'CartController._tryClearServerCart: local fallback after $error',
      );
    }
  }

  Object? _extractCartList(Map<String, dynamic> response) {
    final direct = response['data'] ?? response['items'] ?? response['cart'];
    if (direct is List) return direct;
    if (direct is Map) {
      return direct['items'] ?? direct['cartItems'] ?? direct['products'];
    }
    return null;
  }

  bool get _hasAccessToken {
    final token = _storage.read<String>('accessToken');
    return token != null && token.trim().isNotEmpty;
  }
}
