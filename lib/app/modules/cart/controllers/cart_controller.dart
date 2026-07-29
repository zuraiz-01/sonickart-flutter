import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../data/models/cart_item_model.dart';
import '../../../data/models/product_model.dart';

class CartController extends GetxController {
  @visibleForTesting
  static const legacyStorageKey = 'cart_items';

  @visibleForTesting
  static const guestSessionStorageKey = 'cart_guest_session_id';

  static const _legacyMigrationStorageKey = 'cart_owner_migration_version';
  static const _legacyMigrationVersion = 1;
  static const _authenticatedStoragePrefix = 'cart_items_user_';
  static const _guestStoragePrefix = 'cart_items_guest_';
  static const _pendingServerSyncPrefix = 'cart_pending_server_sync_';

  final GetStorage _storage;

  CartController(this._storage);

  final items = <CartItemModel>[].obs;
  final isSyncingCart = false.obs;
  final isClearingCart = false.obs;

  Future<void>? _syncInFlight;
  String? _syncOwnerHint;
  _CartOwner? _activeOwner;
  String? _hydratedStorageKey;
  String? _detachedAuthenticatedScopeKey;
  int _latestSyncRequest = 0;
  int _operationVersion = 0;
  Future<void>? _cartMutationQueue;

  int get totalItems => items.fold<int>(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      items.fold<double>(0, (sum, item) => sum + item.totalPrice);

  double get grandTotal => subtotal;

  bool get isEmpty => items.isEmpty;

  @visibleForTesting
  static String authenticatedStorageKey(String ownerId) {
    return '$_authenticatedStoragePrefix${_encodeOwnerIdentity(ownerId)}';
  }

  @visibleForTesting
  static String guestStorageKey(String guestSessionId) {
    return '$_guestStoragePrefix${_encodeOwnerIdentity(guestSessionId)}';
  }

  @override
  void onInit() {
    super.onInit();
    debugPrint('CartController.onInit: cart controller started');
    unawaited(syncCartFromStorage());
  }

  Future<void> syncCartFromStorage() {
    final pendingMutation = _cartMutationQueue;
    if (pendingMutation != null) {
      return pendingMutation
          .catchError((Object error, StackTrace stackTrace) {
            debugPrint(
              'CartController.syncCartFromStorage: pending mutation failed '
              'before sync after $error',
            );
          })
          .then((_) => _syncCartFromStorageUnlocked());
    }
    return _syncCartFromStorageUnlocked();
  }

  Future<void> _syncCartFromStorageUnlocked() {
    final ownerHint = _currentOwnerHint();
    final inFlight = _syncInFlight;
    if (inFlight != null && _syncOwnerHint == ownerHint) {
      debugPrint(
        'CartController.syncCartFromStorage: sharing in-flight cart sync',
      );
      return inFlight;
    }

    if (_activeOwner?.scopeKey != ownerHint) {
      _activeOwner = null;
      _hydratedStorageKey = null;
      _operationVersion++;
      items.clear();
    }

    final request = ++_latestSyncRequest;
    isSyncingCart.value = true;
    late final Future<void> future;
    future = _hydrateAndSync(request).whenComplete(() {
      if (identical(_syncInFlight, future)) {
        _syncInFlight = null;
        _syncOwnerHint = null;
      }
      if (_latestSyncRequest == request) {
        isSyncingCart.value = false;
      }
    });
    _syncOwnerHint = ownerHint;
    _syncInFlight = future;
    return future;
  }

  Future<void> rebindToCurrentSession() {
    return _queueCartMutation(_rebindToCurrentSessionNow);
  }

  Future<void> _rebindToCurrentSessionNow() async {
    final guestOwner = _activeOwner?.isAuthenticated == false
        ? _activeOwner
        : _storedGuestOwner;
    final guestItems = guestOwner == null
        ? const <CartItemModel>[]
        : _deduplicate(
            _activeOwner == guestOwner
                ? items.toList()
                : _readStoredCart(guestOwner.storageKey),
          );
    _detachedAuthenticatedScopeKey = null;

    final authenticatedOwner = _authenticatedOwner;
    if (authenticatedOwner != null && guestItems.isNotEmpty) {
      _latestSyncRequest++;
      _syncInFlight = null;
      _syncOwnerHint = null;
      _activeOwner = authenticatedOwner;
      _hydratedStorageKey = authenticatedOwner.storageKey;
      isSyncingCart.value = false;

      final localAuthenticatedItems = _readStoredCart(
        authenticatedOwner.storageKey,
      );
      final serverResult = await _tryFetchServerCart();
      if (serverResult.classification ==
          _CartFetchClassification.unauthorized) {
        await detachFromCurrentSession();
        return;
      }

      final baseItems =
          serverResult.classification == _CartFetchClassification.success
          ? serverResult.items
          : localAuthenticatedItems;
      final mergedItems = _deduplicate([...baseItems, ...guestItems]);
      _operationVersion++;
      items.assignAll(mergedItems);
      await _persistSnapshot(authenticatedOwner, mergedItems);

      final flushed = await _flushLocalSnapshotToServer(
        authenticatedOwner,
        mergedItems,
      );
      if (flushed) {
        await _clearPendingServerSync(authenticatedOwner);
        await _removeGuestCart(guestOwner);
      } else {
        await _markPendingServerSync(authenticatedOwner);
      }
      _operationVersion++;
      debugPrint(
        'CartController.rebindToCurrentSession: merged guest cart into '
        'authenticated cart with ${mergedItems.length} lines',
      );
      return;
    }

    _invalidateVisibleOwner();
    await _syncCartFromStorageUnlocked();
  }

  Future<void> detachFromCurrentSession({
    bool rotateGuestSession = true,
  }) async {
    final detachedOwner = _activeOwner ?? _authenticatedOwner;
    if (detachedOwner?.isAuthenticated == true) {
      _detachedAuthenticatedScopeKey = detachedOwner?.scopeKey;
    }
    _invalidateVisibleOwner();
    if (rotateGuestSession) {
      await _storage.remove(guestSessionStorageKey);
    }
    debugPrint(
      'CartController.detachFromCurrentSession: visible cart detached',
    );
  }

  Future<void> _hydrateAndSync(int request) async {
    final owner = await _resolveCurrentOwner();
    await _migrateLegacyGlobalCart(owner);
    if (request != _latestSyncRequest) return;

    if (_activeOwner != owner) {
      _activeOwner = owner;
      _hydratedStorageKey = null;
      _operationVersion++;
      items.clear();
    }

    if (_hydratedStorageKey != owner.storageKey) {
      final restoredItems = _readStoredCart(owner.storageKey);
      if (!_isCurrentRequest(request, owner)) return;
      items.assignAll(restoredItems);
      _hydratedStorageKey = owner.storageKey;
      debugPrint(
        'CartController.syncCartFromStorage: restored '
        '${items.length} lines for ${owner.logLabel}',
      );
    }

    if (!owner.isAuthenticated) return;

    final operationAtFetch = _operationVersion;
    if (_hasPendingServerSync(owner)) {
      final flushed = await _flushLocalSnapshotToServer(owner, items.toList());
      if (!_isCurrentRequest(request, owner) ||
          operationAtFetch != _operationVersion) {
        return;
      }
      if (!flushed) {
        debugPrint(
          'CartController.syncCartFromStorage: pending local cart preserved '
          'because server flush failed for request $request',
        );
        return;
      }
      await _clearPendingServerSync(owner);
      debugPrint(
        'CartController.syncCartFromStorage: pending local cart flushed '
        'and preserved for request $request',
      );
      return;
    }

    final result = await _tryFetchServerCart();
    if (!_isCurrentRequest(request, owner) ||
        operationAtFetch != _operationVersion) {
      debugPrint(
        'CartController.syncCartFromStorage: ignored stale response '
        'for request $request',
      );
      return;
    }

    switch (result.classification) {
      case _CartFetchClassification.success:
        final authoritativeItems = _deduplicate(result.items);
        items.assignAll(authoritativeItems);
        _operationVersion++;
        await _persistSnapshot(owner, authoritativeItems);
        _operationVersion++;
        debugPrint(
          'CartController.syncCartFromStorage: server success '
          'with ${authoritativeItems.length} lines for request $request',
        );
      case _CartFetchClassification.unauthorized:
        debugPrint(
          'CartController.syncCartFromStorage: session invalid '
          'for request $request',
        );
        await detachFromCurrentSession();
      case _CartFetchClassification.failure:
        debugPrint(
          'CartController.syncCartFromStorage: server failure preserved '
          '${items.length} local lines for request $request',
        );
    }
  }

  Future<void> addItem(ProductModel product) {
    final productId = product.id.trim();
    if (productId.isEmpty) {
      AppSnackBar.show(
        'Product Error',
        'This product cannot be added right now.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return Future<void>.value();
    }

    return _queueCartMutation(() => _addItemNow(product, productId));
  }

  Future<void> _addItemNow(ProductModel product, String normalizedId) async {
    final owner = await _prepareForMutation();
    final normalizedProduct = _normalizedProduct(product, normalizedId);
    _operationVersion++;
    try {
      debugPrint(
        'CartController.addItem: requested add for '
        '$normalizedId ${normalizedProduct.name}',
      );
      final itemIndex = items.indexWhere(
        (item) => _cartProductId(item) == normalizedId,
      );
      if (itemIndex >= 0) {
        final currentItem = items[itemIndex];
        items[itemIndex] = currentItem.copyWith(
          product: normalizedProduct,
          quantity: currentItem.quantity + 1,
        );
        debugPrint(
          'CartController.addItem: incremented $normalizedId '
          'to ${items[itemIndex].quantity}',
        );
      } else {
        items.add(CartItemModel(product: normalizedProduct, quantity: 1));
        debugPrint('CartController.addItem: added new product $normalizedId');
      }
      await _persistSnapshot(owner, items);
      _notifyAction(
        'Cart Updated',
        '${normalizedProduct.name.trim().isEmpty ? 'Product' : normalizedProduct.name.trim()} '
            'added to cart.',
      );
      final synced = await _tryAddOneToServer(normalizedId, owner);
      if (!synced) {
        await _markPendingServerSync(owner);
      }
    } finally {
      _operationVersion++;
    }
  }

  Future<void> removeItem(String productId) {
    final normalizedProductId = productId.trim();
    if (normalizedProductId.isEmpty) return Future<void>.value();

    return _queueCartMutation(() => _removeItemNow(normalizedProductId));
  }

  Future<void> _removeItemNow(String productId) async {
    final owner = await _prepareForMutation();
    final itemIndex = items.indexWhere(
      (item) => _cartProductId(item) == productId,
    );
    if (itemIndex < 0) {
      debugPrint('CartController.removeItem: item $productId not found');
      return;
    }

    _operationVersion++;
    try {
      debugPrint('CartController.removeItem: requested remove for $productId');
      final currentItem = items[itemIndex];
      final productName = currentItem.product.name.trim().isEmpty
          ? 'Product'
          : currentItem.product.name.trim();
      if (currentItem.quantity > 1) {
        items[itemIndex] = currentItem.copyWith(
          quantity: currentItem.quantity - 1,
        );
        debugPrint(
          'CartController.removeItem: decremented $productId '
          'to ${items[itemIndex].quantity}',
        );
      } else {
        items.removeAt(itemIndex);
        debugPrint('CartController.removeItem: removed line for $productId');
      }
      await _persistSnapshot(owner, items);
      _notifyAction('Cart Updated', '$productName removed from cart.');
      final synced = await _tryRemoveOneFromServer(productId, owner);
      if (!synced) {
        await _markPendingServerSync(owner);
      }
    } finally {
      _operationVersion++;
    }
  }

  Future<void> _queueCartMutation(Future<void> Function() mutation) {
    final previous = _cartMutationQueue ?? Future<void>.value();
    late final Future<void> next;
    next = previous
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint(
            'CartController._queueCartMutation: previous mutation failed '
            'after $error',
          );
        })
        .then((_) => mutation())
        .whenComplete(() {
          if (identical(_cartMutationQueue, next)) {
            _cartMutationQueue = null;
          }
        });
    _cartMutationQueue = next;
    return next;
  }

  Future<void> clearCart({bool notify = true}) async {
    return _queueCartMutation(() => _clearCartNow(notify: notify));
  }

  Future<void> _clearCartNow({required bool notify}) async {
    debugPrint('CartController.clearCart: clear cart requested');
    if (isClearingCart.value) {
      debugPrint('CartController.clearCart: already clearing, skipping');
      return;
    }

    isClearingCart.value = true;
    _CartOwner? owner;
    try {
      owner = await _prepareForMutation();
      _operationVersion++;
      items.clear();
      await _persistSnapshot(owner, items);
      final synced = await _tryClearServerCart(owner);
      if (!synced) {
        await _markPendingServerSync(owner);
      }
      if (notify) {
        _notifyAction('Cart Cleared', 'All items were removed from your cart.');
      }
      debugPrint('CartController.clearCart: cart cleared successfully');
    } finally {
      if (owner != null) {
        _operationVersion++;
      }
      isClearingCart.value = false;
    }
  }

  Future<void> removeItemsCompletely(List<String> productIds) async {
    return _queueCartMutation(() => _removeItemsCompletelyNow(productIds));
  }

  Future<void> _removeItemsCompletelyNow(List<String> productIds) async {
    final ids = productIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return;

    final owner = await _prepareForMutation();
    _operationVersion++;
    try {
      final quantitiesById = <String, int>{
        for (final item in items)
          if (ids.contains(_cartProductId(item)))
            _cartProductId(item): item.quantity,
      };
      if (quantitiesById.isEmpty) return;
      items.removeWhere((item) => ids.contains(_cartProductId(item)));
      await _persistSnapshot(owner, items);
      var synced = true;
      for (final entry in quantitiesById.entries) {
        synced =
            await _tryRemoveLineCompletelyFromServer(
              entry.key,
              quantity: entry.value,
              owner: owner,
            ) &&
            synced;
      }
      if (!synced) {
        await _markPendingServerSync(owner);
      }
    } finally {
      _operationVersion++;
    }
  }

  int getItemCount(String productId) {
    final normalizedProductId = productId.trim();
    final index = items.indexWhere(
      (item) => _cartProductId(item) == normalizedProductId,
    );
    return index >= 0 ? items[index].quantity : 0;
  }

  Future<bool> _flushLocalSnapshotToServer(
    _CartOwner owner,
    Iterable<CartItemModel> snapshot,
  ) async {
    if (!owner.isAuthenticated) return true;
    if (!_canMutateServer(owner)) return false;
    final normalizedSnapshot = _deduplicate(snapshot);
    try {
      final cleared = await _tryClearServerCart(owner);
      if (!cleared) return false;
      for (final item in normalizedSnapshot) {
        final productId = _cartProductId(item);
        for (var i = 0; i < item.quantity; i++) {
          final added = await _tryAddOneToServer(productId, owner);
          if (!added) return false;
        }
      }
      return true;
    } catch (error) {
      debugPrint(
        'CartController._flushLocalSnapshotToServer: failed after $error',
      );
      return false;
    }
  }

  Future<bool> _removeGuestCart(_CartOwner? owner) async {
    if (owner == null || owner.isAuthenticated) return true;
    await _storage.remove(owner.storageKey);
    final currentGuestId = _storage.read<String>(guestSessionStorageKey);
    if (currentGuestId?.trim() == owner.identity) {
      await _storage.remove(guestSessionStorageKey);
    }
    return true;
  }

  String _pendingSyncKey(_CartOwner owner) {
    return '$_pendingServerSyncPrefix${_encodeOwnerIdentity(owner.storageKey)}';
  }

  bool _hasPendingServerSync(_CartOwner owner) {
    return owner.isAuthenticated &&
        _storage.read(_pendingSyncKey(owner)) == true;
  }

  Future<void> _markPendingServerSync(_CartOwner owner) async {
    if (!owner.isAuthenticated) return;
    await _storage.write(_pendingSyncKey(owner), true);
    debugPrint(
      'CartController: marked pending server sync for ${owner.logLabel}',
    );
  }

  Future<void> _clearPendingServerSync(_CartOwner owner) async {
    if (!owner.isAuthenticated) return;
    await _storage.remove(_pendingSyncKey(owner));
  }

  String _cartProductId(CartItemModel item) {
    return item.product.id.trim();
  }

  ProductModel _normalizedProduct(ProductModel product, String productId) {
    if (product.id == productId) return product;
    return ProductModel.fromJson({...product.toJson(), 'id': productId});
  }

  CartItemModel _normalizedCartItem(CartItemModel item) {
    final productId = _cartProductId(item);
    return item.copyWith(
      product: _normalizedProduct(item.product, productId),
      quantity: item.quantity,
    );
  }

  Future<_CartOwner> _prepareForMutation() async {
    final owner = await _resolveCurrentOwner();
    await _migrateLegacyGlobalCart(owner);
    if (_activeOwner != owner || _hydratedStorageKey != owner.storageKey) {
      _latestSyncRequest++;
      _syncInFlight = null;
      _syncOwnerHint = null;
      _activeOwner = owner;
      _hydratedStorageKey = owner.storageKey;
      _operationVersion++;
      items.assignAll(_readStoredCart(owner.storageKey));
      isSyncingCart.value = false;
    }
    return owner;
  }

  List<CartItemModel> _readStoredCart(String storageKey) {
    final rawItems = _storage.read(storageKey);
    if (rawItems is! List) return const [];
    final parsedItems = <CartItemModel>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map) continue;
      try {
        final item = CartItemModel.fromJson(Map<String, dynamic>.from(rawItem));
        if (_cartProductId(item).isNotEmpty && item.quantity > 0) {
          parsedItems.add(item);
        }
      } catch (error, stackTrace) {
        debugPrint(
          'CartController._readStoredCart: skipped invalid cart row '
          'for $storageKey after $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    return _deduplicate(parsedItems);
  }

  Future<void> _persistSnapshot(
    _CartOwner owner,
    Iterable<CartItemModel> snapshot,
  ) async {
    final normalizedSnapshot = _deduplicate(snapshot);
    final payload = normalizedSnapshot.map((item) => item.toJson()).toList();
    await _storage.write(owner.storageKey, payload);
    debugPrint(
      'CartController._persistCart: persisted ${payload.length} lines '
      'for ${owner.logLabel}',
    );
  }

  Future<_CartFetchResult> _tryFetchServerCart() async {
    if (!Get.isRegistered<ApiService>()) {
      return const _CartFetchResult.failure();
    }
    try {
      final response = await Get.find<ApiService>().get(
        endpoint: ApiConstants.cartFetch,
      );
      final raw = _extractCartList(response);
      if (raw is! List) {
        return const _CartFetchResult.failure();
      }
      final serverItems = <CartItemModel>[];
      for (final rawItem in raw) {
        if (rawItem is! Map) continue;
        try {
          final item = CartItemModel.fromJson(
            Map<String, dynamic>.from(rawItem),
          );
          if (_cartProductId(item).isNotEmpty && item.quantity > 0) {
            serverItems.add(item);
          }
        } catch (error, stackTrace) {
          debugPrint(
            'CartController._tryFetchServerCart: skipped invalid server row '
            'after $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      return _CartFetchResult.success(serverItems);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return const _CartFetchResult.unauthorized();
      }
      debugPrint(
        'CartController._tryFetchServerCart: scoped cache fallback '
        'after HTTP ${error.statusCode}',
      );
      return const _CartFetchResult.failure();
    } catch (error) {
      debugPrint(
        'CartController._tryFetchServerCart: scoped cache fallback '
        'after $error',
      );
      return const _CartFetchResult.failure();
    }
  }

  Future<bool> _tryAddOneToServer(String productId, _CartOwner owner) async {
    if (!owner.isAuthenticated) return true;
    if (!_canMutateServer(owner)) return false;
    try {
      await Get.find<ApiService>().post(
        endpoint: ApiConstants.cartAdd,
        data: {'productId': productId, 'quantity': 1},
      );
      return true;
    } catch (error) {
      debugPrint(
        'CartController._tryAddOneToServer: local fallback after $error',
      );
      return false;
    }
  }

  Future<bool> _tryRemoveOneFromServer(
    String productId,
    _CartOwner owner,
  ) async {
    if (!owner.isAuthenticated) return true;
    if (!_canMutateServer(owner)) return false;
    try {
      await Get.find<ApiService>().delete(
        endpoint: ApiConstants.cartRemove,
        data: {'productId': productId},
      );
      return true;
    } catch (error) {
      debugPrint(
        'CartController._tryRemoveOneFromServer: local fallback after $error',
      );
      return false;
    }
  }

  Future<bool> _tryRemoveLineCompletelyFromServer(
    String productId, {
    required int quantity,
    required _CartOwner owner,
  }) async {
    var synced = true;
    final attempts = quantity < 1 ? 1 : quantity;
    for (var i = 0; i < attempts; i++) {
      synced = await _tryRemoveOneFromServer(productId, owner) && synced;
    }
    return synced;
  }

  Future<bool> _tryClearServerCart(_CartOwner owner) async {
    if (!owner.isAuthenticated) return true;
    if (!_canMutateServer(owner)) return false;
    try {
      try {
        await Get.find<ApiService>().delete(endpoint: ApiConstants.cartClear);
      } catch (_) {
        await Get.find<ApiService>().post(endpoint: ApiConstants.cartClear);
      }
      return true;
    } catch (error) {
      debugPrint(
        'CartController._tryClearServerCart: local fallback after $error',
      );
      return false;
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

  List<CartItemModel> _deduplicate(Iterable<CartItemModel> source) {
    final byProductId = <String, CartItemModel>{};
    for (final item in source) {
      final productId = _cartProductId(item);
      if (productId.isEmpty || item.quantity <= 0) continue;
      final normalizedItem = _normalizedCartItem(item);
      final existing = byProductId[productId];
      byProductId[productId] = normalizedItem.copyWith(
        quantity: (existing?.quantity ?? 0) + normalizedItem.quantity,
      );
    }
    return byProductId.values.toList();
  }

  Future<void> _migrateLegacyGlobalCart(_CartOwner owner) async {
    final migrationVersion = _storage.read<int>(_legacyMigrationStorageKey);
    if (migrationVersion == _legacyMigrationVersion &&
        !_storage.hasData(legacyStorageKey)) {
      return;
    }

    if (_storage.hasData(legacyStorageKey)) {
      final legacyItems = _readStoredCart(legacyStorageKey);
      if (legacyItems.isNotEmpty) {
        final existingItems = _readStoredCart(owner.storageKey);
        final migratedItems = _deduplicate([...existingItems, ...legacyItems]);
        await _persistSnapshot(owner, migratedItems);
        if (_activeOwner == owner && _hydratedStorageKey == owner.storageKey) {
          items.assignAll(migratedItems);
          _operationVersion++;
        }
        if (owner.isAuthenticated) {
          await _markPendingServerSync(owner);
        }
        debugPrint(
          'CartController.migration: migrated legacy cart data into '
          '${owner.logLabel}',
        );
      }
      await _storage.remove(legacyStorageKey);
    }
    await _storage.write(_legacyMigrationStorageKey, _legacyMigrationVersion);
  }

  _CartOwner? get _storedGuestOwner {
    final guestSessionId = _storage
        .read<String>(guestSessionStorageKey)
        ?.trim();
    if (guestSessionId == null || guestSessionId.isEmpty) return null;
    return _CartOwner.guest(guestSessionId);
  }

  Future<_CartOwner> _resolveCurrentOwner() async {
    final authenticatedOwner = _authenticatedOwner;
    if (authenticatedOwner != null) return authenticatedOwner;

    var guestSessionId = _storage.read<String>(guestSessionStorageKey)?.trim();
    if (guestSessionId == null || guestSessionId.isEmpty) {
      guestSessionId = _newGuestSessionId();
      await _storage.write(guestSessionStorageKey, guestSessionId);
    }
    return _CartOwner.guest(guestSessionId);
  }

  _CartOwner? get _authenticatedOwner {
    final token = _storage.read<String>('accessToken')?.trim() ?? '';
    if (token.isEmpty || _storage.read('isLoggedIn') != true) return null;

    final rawUser = _storage.read('currentUser');
    if (rawUser is! Map) return null;
    final user = Map<String, dynamic>.from(rawUser);
    for (final entry in <MapEntry<String, Object?>>[
      MapEntry('id', user['id'] ?? user['_id'] ?? user['userId']),
      MapEntry('phone', user['phone'] ?? user['mobile'] ?? user['phoneNumber']),
      MapEntry('email', user['email']),
    ]) {
      final value = entry.value?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        final owner = _CartOwner.authenticated('${entry.key}:$value');
        return owner.scopeKey == _detachedAuthenticatedScopeKey ? null : owner;
      }
    }
    return null;
  }

  String _currentOwnerHint() {
    final authenticatedOwner = _authenticatedOwner;
    if (authenticatedOwner != null) return authenticatedOwner.scopeKey;
    final guestId = _storage.read<String>(guestSessionStorageKey)?.trim();
    return guestId == null || guestId.isEmpty
        ? 'guest:pending'
        : _CartOwner.guest(guestId).scopeKey;
  }

  bool _isCurrentRequest(int request, _CartOwner owner) {
    return request == _latestSyncRequest &&
        _activeOwner == owner &&
        _currentOwnerHint() == owner.scopeKey;
  }

  bool _canMutateServer(_CartOwner owner) {
    return owner.isAuthenticated &&
        _activeOwner == owner &&
        _currentOwnerHint() == owner.scopeKey &&
        Get.isRegistered<ApiService>();
  }

  void _invalidateVisibleOwner() {
    _latestSyncRequest++;
    _operationVersion++;
    _syncInFlight = null;
    _syncOwnerHint = null;
    _activeOwner = null;
    _hydratedStorageKey = null;
    isSyncingCart.value = false;
    items.clear();
  }

  String _newGuestSessionId() {
    final random = Random.secure();
    final first = random.nextInt(1 << 31).toRadixString(36);
    final second = random.nextInt(1 << 31).toRadixString(36);
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '-$first$second';
  }

  void _notifyAction(String title, String message) {
    AppSnackBar.show(title, message, snackPosition: SnackPosition.BOTTOM);
  }
}

enum _CartOwnerKind { authenticated, guest }

class _CartOwner {
  const _CartOwner._(this.kind, this.identity);

  factory _CartOwner.authenticated(String identity) {
    return _CartOwner._(_CartOwnerKind.authenticated, identity);
  }

  factory _CartOwner.guest(String identity) {
    return _CartOwner._(_CartOwnerKind.guest, identity);
  }

  final _CartOwnerKind kind;
  final String identity;

  bool get isAuthenticated => kind == _CartOwnerKind.authenticated;

  String get storageKey => isAuthenticated
      ? CartController.authenticatedStorageKey(identity)
      : CartController.guestStorageKey(identity);

  String get scopeKey => '${kind.name}:${_encodeOwnerIdentity(identity)}';

  String get logLabel => isAuthenticated ? 'authenticated owner' : 'guest';

  @override
  bool operator ==(Object other) {
    return other is _CartOwner &&
        other.kind == kind &&
        other.identity == identity;
  }

  @override
  int get hashCode => Object.hash(kind, identity);
}

enum _CartFetchClassification { success, failure, unauthorized }

class _CartFetchResult {
  const _CartFetchResult.success(this.items)
    : classification = _CartFetchClassification.success;

  const _CartFetchResult.failure()
    : classification = _CartFetchClassification.failure,
      items = const [];

  const _CartFetchResult.unauthorized()
    : classification = _CartFetchClassification.unauthorized,
      items = const [];

  final _CartFetchClassification classification;
  final List<CartItemModel> items;
}

String _encodeOwnerIdentity(String value) {
  return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
}
