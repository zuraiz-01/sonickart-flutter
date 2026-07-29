import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sonic_cart/app/core/constants/api_constants.dart';
import 'package:sonic_cart/app/core/network/api_service.dart';
import 'package:sonic_cart/app/core/services/session_controller.dart';
import 'package:sonic_cart/app/data/models/cart_item_model.dart';
import 'package:sonic_cart/app/data/models/product_model.dart';
import 'package:sonic_cart/app/modules/cart/controllers/cart_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageContainer = 'cart_controller_test';
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async {
          return '.dart_tool/test_storage/cart_controller';
        });
    await GetStorage.init(storageContainer);
  });

  setUp(() {
    Get.testMode = true;
  });

  tearDown(() async {
    await GetStorage(storageContainer).erase();
    Get.reset();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test(
    'clean authenticated launch with an empty server cart stays empty',
    () async {
      final storage = GetStorage(storageContainer);
      await _authenticate(storage, 'user-a');
      final api = _registerApi(storage, [
        () async => const {'data': <dynamic>[]},
      ]);
      final controller = CartController(storage);

      await controller.syncCartFromStorage();

      expect(controller.items, isEmpty);
      expect(api.fetchCalls, 1);
      expect(storage.read<List<dynamic>>(_userCartKey('user-a')), isEmpty);
    },
  );

  test('same authenticated owner restores valid scoped cached cart', () async {
    final storage = GetStorage(storageContainer);
    await _authenticate(storage, 'user-a');
    await _seedCart(storage, _userCartKey('user-a'), [
      _cartItem(_product('apple', price: '15'), 2),
    ]);
    _registerApi(storage, [_offline]);
    final controller = CartController(storage);

    await controller.syncCartFromStorage();

    expect(controller.getItemCount('apple'), 2);
    expect(controller.totalItems, 2);
  });

  test('user B cannot restore user A scoped cached cart', () async {
    final storage = GetStorage(storageContainer);
    await _seedCart(storage, _userCartKey('user-a'), [
      _cartItem(_product('apple'), 3),
    ]);
    await _authenticate(storage, 'user-b');
    _registerApi(storage, [_offline]);
    final controller = CartController(storage);

    await controller.syncCartFromStorage();

    expect(controller.items, isEmpty);
  });

  test('successful empty server cart clears stale same-owner cache', () async {
    final storage = GetStorage(storageContainer);
    await _authenticate(storage, 'user-a');
    await _seedCart(storage, _userCartKey('user-a'), [
      _cartItem(_product('apple'), 2),
    ]);
    _registerApi(storage, [
      () async => const {'data': <dynamic>[]},
    ]);
    final controller = CartController(storage);

    await controller.syncCartFromStorage();

    expect(controller.items, isEmpty);
    expect(storage.read<List<dynamic>>(_userCartKey('user-a')), isEmpty);
  });

  test('backend failure preserves valid same-owner cached cart', () async {
    final storage = GetStorage(storageContainer);
    await _authenticate(storage, 'user-a');
    await _seedCart(storage, _userCartKey('user-a'), [
      _cartItem(_product('apple'), 2),
    ]);
    _registerApi(storage, [_offline]);
    final controller = CartController(storage);

    await controller.syncCartFromStorage();

    expect(controller.getItemCount('apple'), 2);
    expect(storage.read<List<dynamic>>(_userCartKey('user-a')), hasLength(1));
  });

  test('unauthorized fetch detaches the stale authenticated cart', () async {
    final storage = GetStorage(storageContainer);
    await _authenticate(storage, 'user-a');
    await _seedCart(storage, _userCartKey('user-a'), [
      _cartItem(_product('apple'), 2),
    ]);
    final api = _registerApi(storage, [
      () => Future<Map<String, dynamic>>.error(
        ApiException(
          statusCode: 401,
          message: 'Session expired',
          response: const {},
        ),
      ),
    ]);
    final controller = CartController(storage);

    await controller.syncCartFromStorage();
    await controller.syncCartFromStorage();

    expect(controller.items, isEmpty);
    expect(api.fetchCalls, 1);
  });

  test('logout detaches visible cart before a different user syncs', () async {
    final storage = GetStorage(storageContainer);
    await _authenticate(storage, 'user-a');
    await _seedCart(storage, _userCartKey('user-a'), [
      _cartItem(_product('apple'), 1),
    ]);
    _registerApi(storage, [
      _offline,
      () async => const {'data': <dynamic>[]},
    ]);
    final controller = CartController(storage);
    await controller.syncCartFromStorage();

    await controller.detachFromCurrentSession();

    expect(controller.items, isEmpty);
    await _authenticate(storage, 'user-b');
    await controller.rebindToCurrentSession();
    expect(controller.items, isEmpty);
  });

  test('switching users loads only the new owner scoped cart', () async {
    final storage = GetStorage(storageContainer);
    await _seedCart(storage, _userCartKey('user-a'), [
      _cartItem(_product('apple'), 1),
    ]);
    await _seedCart(storage, _userCartKey('user-b'), [
      _cartItem(_product('banana'), 4),
    ]);
    await _authenticate(storage, 'user-a');
    _registerApi(storage, [_offline, _offline]);
    final controller = CartController(storage);
    await controller.syncCartFromStorage();

    await _authenticate(storage, 'user-b');
    await controller.rebindToCurrentSession();

    expect(controller.getItemCount('apple'), 0);
    expect(controller.getItemCount('banana'), 4);
  });

  test('guest cart merges into authenticated cart after login', () async {
    final storage = GetStorage(storageContainer);
    await storage.write(CartController.guestSessionStorageKey, 'guest-a');
    await _seedCart(storage, CartController.guestStorageKey('guest-a'), [
      _cartItem(_product('apple'), 2),
    ]);
    final controller = CartController(storage);
    await controller.syncCartFromStorage();
    expect(controller.getItemCount('apple'), 2);

    await _authenticate(storage, 'user-a');
    _registerApi(storage, [_offline]);
    await controller.rebindToCurrentSession();

    expect(controller.getItemCount('apple'), 2);
    expect(storage.hasData(CartController.guestStorageKey('guest-a')), isFalse);
  });

  test('authenticated cart does not leak into guest mode', () async {
    final storage = GetStorage(storageContainer);
    await _authenticate(storage, 'user-a');
    await _seedCart(storage, _userCartKey('user-a'), [
      _cartItem(_product('apple'), 2),
    ]);
    _registerApi(storage, [_offline]);
    final controller = CartController(storage);
    await controller.syncCartFromStorage();

    await _clearAuthentication(storage);
    await controller.syncCartFromStorage();

    expect(controller.items, isEmpty);
  });

  test('legacy global cart is migrated into the current owner cart', () async {
    final storage = GetStorage(storageContainer);
    await storage.write(CartController.legacyStorageKey, [
      _cartItem(_product('legacy-item'), 5).toJson(),
    ]);
    final controller = CartController(storage);

    await controller.syncCartFromStorage();

    expect(controller.getItemCount('legacy-item'), 5);
    expect(storage.hasData(CartController.legacyStorageKey), isFalse);

    await storage.write(CartController.legacyStorageKey, [
      _cartItem(_product('legacy-item'), 2).toJson(),
    ]);
    await controller.syncCartFromStorage();
    expect(storage.hasData(CartController.legacyStorageKey), isFalse);
    expect(controller.getItemCount('legacy-item'), 7);
  });

  test('multiple initialization calls share one backend fetch', () async {
    final storage = GetStorage(storageContainer);
    await _authenticate(storage, 'user-a');
    final response = Completer<Map<String, dynamic>>();
    final api = _registerApi(storage, [() => response.future]);
    final controller = Get.put(CartController(storage), permanent: true);

    final first = controller.syncCartFromStorage();
    final second = controller.syncCartFromStorage();
    await _pumpUntil(() => api.fetchCalls == 1);

    expect(api.fetchCalls, 1);
    response.complete(const {'data': <dynamic>[]});
    await Future.wait([first, second]);
  });

  test(
    'response started for user A is ignored after user B signs in',
    () async {
      final storage = GetStorage(storageContainer);
      await _authenticate(storage, 'user-a');
      final userAResponse = Completer<Map<String, dynamic>>();
      final userBResponse = Completer<Map<String, dynamic>>();
      final api = _registerApi(storage, [
        () => userAResponse.future,
        () => userBResponse.future,
      ]);
      final controller = CartController(storage);

      final firstSync = controller.syncCartFromStorage();
      await _pumpUntil(() => api.fetchCalls == 1);
      await _authenticate(storage, 'user-b');
      final secondSync = controller.rebindToCurrentSession();
      await _pumpUntil(() => api.fetchCalls == 2);

      userBResponse.complete(const {'data': <dynamic>[]});
      await secondSync;
      userAResponse.complete({
        'data': [_cartItem(_product('apple'), 3).toJson()],
      });
      await firstSync;

      expect(controller.items, isEmpty);
    },
  );

  test(
    'authoritative server cart replaces rather than duplicates local item',
    () async {
      final storage = GetStorage(storageContainer);
      await _authenticate(storage, 'user-a');
      await _seedCart(storage, _userCartKey('user-a'), [
        _cartItem(_product('apple'), 1),
      ]);
      _registerApi(storage, [
        () async => {
          'data': [_cartItem(_product('apple'), 2).toJson()],
        },
      ]);
      final controller = CartController(storage);

      await controller.syncCartFromStorage();

      expect(controller.items, hasLength(1));
      expect(controller.getItemCount('apple'), 2);
      expect(controller.totalItems, 2);
    },
  );

  test('duplicate cart lines are merged by summing quantities', () async {
    final storage = GetStorage(storageContainer);
    await _authenticate(storage, 'user-a');
    await _seedCart(storage, _userCartKey('user-a'), [
      _cartItem(_product('apple'), 2),
      _cartItem(_product('apple'), 3),
    ]);
    _registerApi(storage, [_offline]);
    final controller = CartController(storage);

    await controller.syncCartFromStorage();

    expect(controller.items, hasLength(1));
    expect(controller.getItemCount('apple'), 5);
  });

  test(
    'invalid stored cart rows are skipped without clearing valid rows',
    () async {
      final storage = GetStorage(storageContainer);
      await _authenticate(storage, 'user-a');
      await storage.write(_userCartKey('user-a'), [
        {
          'product': {
            'id': 'bad',
            'name': 'bad',
            'category': {1: 'invalid key'},
          },
          'quantity': 1,
        },
        _cartItem(_product('apple'), 2).toJson(),
      ]);
      _registerApi(storage, [_offline]);
      final controller = CartController(storage);

      await controller.syncCartFromStorage();

      expect(controller.items, hasLength(1));
      expect(controller.getItemCount('apple'), 2);
    },
  );

  test('quantity and total calculations remain correct', () {
    final controller = CartController(GetStorage(storageContainer));
    controller.items.assignAll([
      _cartItem(_product('apple', price: '12.50'), 2),
      _cartItem(_product('banana', price: '7'), 3),
    ]);

    expect(controller.totalItems, 5);
    expect(controller.subtotal, 46);
    expect(controller.grandTotal, 46);
  });

  test(
    'add update remove and clear keep guest scoped persistence working',
    () async {
      final storage = GetStorage(storageContainer);
      final controller = CartController(storage);
      final apple = _product('apple', price: '10');

      await controller.addItem(apple);
      await controller.addItem(apple);
      expect(controller.getItemCount('apple'), 2);
      expect(controller.totalItems, 2);
      expect(controller.subtotal, 20);

      await controller.removeItem('apple');
      expect(controller.getItemCount('apple'), 1);

      final guestId = storage.read<String>(
        CartController.guestSessionStorageKey,
      );
      expect(guestId, isNotEmpty);
      expect(
        storage.read<List<dynamic>>(CartController.guestStorageKey(guestId!)),
        hasLength(1),
      );

      await controller.removeItem('apple');
      expect(controller.items, isEmpty);
      await controller.addItem(apple);
      await controller.clearCart(notify: false);
      expect(controller.items, isEmpty);
      expect(
        storage.read<List<dynamic>>(CartController.guestStorageKey(guestId)),
        isEmpty,
      );
    },
  );

  test(
    'product ids are trimmed consistently for add count remove and API',
    () async {
      final storage = GetStorage(storageContainer);
      await _authenticate(storage, 'user-a');
      _registerApi(storage, []);
      final controller = CartController(storage);

      await controller.addItem(_product('  apple  '));
      expect(controller.getItemCount('apple'), 1);
      expect(controller.getItemCount('  apple  '), 1);

      await controller.removeItem('apple');
      expect(controller.getItemCount('apple'), 0);
    },
  );

  test('successful server cart is persisted in the owner scoped key', () async {
    final storage = GetStorage(storageContainer);
    await _authenticate(storage, 'user-a');
    _registerApi(storage, [
      () async => {
        'data': [_cartItem(_product('banana'), 3).toJson()],
      },
    ]);
    final controller = CartController(storage);

    await controller.syncCartFromStorage();

    final persisted = storage.read<List<dynamic>>(_userCartKey('user-a'));
    expect(persisted, hasLength(1));
    expect(controller.getItemCount('banana'), 3);
  });

  test('guest cart restores after restart in the same guest session', () async {
    final storage = GetStorage(storageContainer);
    final firstController = CartController(storage);
    await firstController.addItem(_product('apple'));
    final guestId = storage.read<String>(CartController.guestSessionStorageKey);

    final restartedController = CartController(storage);
    await restartedController.syncCartFromStorage();

    expect(guestId, isNotEmpty);
    expect(restartedController.getItemCount('apple'), 1);
  });

  test('malformed successful response is treated as failure', () async {
    final storage = GetStorage(storageContainer);
    await _authenticate(storage, 'user-a');
    await _seedCart(storage, _userCartKey('user-a'), [
      _cartItem(_product('apple'), 2),
    ]);
    _registerApi(storage, [
      () async => const {'success': true},
    ]);
    final controller = CartController(storage);

    await controller.syncCartFromStorage();

    expect(controller.getItemCount('apple'), 2);
  });

  test(
    'older fetch cannot clear a cart modified while it was pending',
    () async {
      final storage = GetStorage(storageContainer);
      await _authenticate(storage, 'user-a');
      final response = Completer<Map<String, dynamic>>();
      final api = _registerApi(storage, [() => response.future]);
      final controller = CartController(storage);

      final sync = controller.syncCartFromStorage();
      await _pumpUntil(() => api.fetchCalls == 1);
      await controller.addItem(_product('apple'));
      response.complete(const {'data': <dynamic>[]});
      await sync;

      expect(controller.getItemCount('apple'), 1);
    },
  );

  test(
    'failed server add remains local and is not overwritten by next sync',
    () async {
      final storage = GetStorage(storageContainer);
      await _authenticate(storage, 'user-a');
      final api = _registerApi(storage, [
        () async => const {'data': <dynamic>[]},
      ]);
      final controller = CartController(storage);
      await controller.syncCartFromStorage();

      api.failNextAdd = true;
      await controller.addItem(_product('apple'));
      expect(controller.getItemCount('apple'), 1);

      await controller.syncCartFromStorage();

      expect(controller.getItemCount('apple'), 1);
      expect(api.clearCalls, 1);
      expect(api.mutationLog, contains('add:apple'));
    },
  );

  test(
    'clear cart is awaited before a following add can hit the server',
    () async {
      final storage = GetStorage(storageContainer);
      await _authenticate(storage, 'user-a');
      await _seedCart(storage, _userCartKey('user-a'), [
        _cartItem(_product('apple'), 1),
      ]);
      final api = _registerApi(storage, [_offline]);
      final controller = CartController(storage);
      await controller.syncCartFromStorage();
      final clearGate = Completer<void>();
      api.nextClearGate = clearGate.future;

      final clearFuture = controller.clearCart(notify: false);
      await _pumpUntil(() => api.clearCalls == 1);
      final addFuture = controller.addItem(_product('banana'));
      await Future<void>.delayed(Duration.zero);

      expect(api.addCalls, 0);
      clearGate.complete();
      await Future.wait([clearFuture, addFuture]);

      expect(controller.getItemCount('banana'), 1);
      expect(api.mutationLog, ['clear', 'add:banana']);
    },
  );

  test(
    'rapid add then remove for same product keeps server mutation order',
    () async {
      final storage = GetStorage(storageContainer);
      await _authenticate(storage, 'user-a');
      final api = _registerApi(storage, []);
      final controller = CartController(storage);
      final addGate = Completer<void>();
      api.nextAddGate = addGate.future;

      final addFuture = controller.addItem(_product('apple'));
      await _pumpUntil(() => api.addCalls == 1);
      expect(controller.getItemCount('apple'), 1);

      final removeFuture = controller.removeItem('apple');
      await Future<void>.delayed(Duration.zero);
      expect(api.removeCalls, 0);

      addGate.complete();
      await Future.wait([addFuture, removeFuture]);

      expect(controller.getItemCount('apple'), 0);
      expect(api.mutationLog, ['add:apple', 'remove:apple']);
    },
  );

  test(
    'removeItemsCompletely skips server calls for unknown products',
    () async {
      final storage = GetStorage(storageContainer);
      await _authenticate(storage, 'user-a');
      await _seedCart(storage, _userCartKey('user-a'), [
        _cartItem(_product('apple'), 2),
      ]);
      final api = _registerApi(storage, [_offline]);
      final controller = CartController(storage);
      await controller.syncCartFromStorage();

      await controller.removeItemsCompletely(['missing']);

      expect(controller.getItemCount('apple'), 2);
      expect(api.removeCalls, 0);
    },
  );

  test('session expiry flow clears auth ownership and visible cart', () async {
    final storage = GetStorage(storageContainer);
    await _authenticate(storage, 'user-a');
    await _seedCart(storage, _userCartKey('user-a'), [
      _cartItem(_product('apple'), 2),
    ]);
    _registerApi(storage, [_offline]);
    final controller = Get.put(CartController(storage), permanent: true);
    await controller.syncCartFromStorage();
    expect(controller.getItemCount('apple'), 2);

    await SessionController(storage).clearSessionSilently();

    expect(controller.items, isEmpty);
    expect(storage.hasData('accessToken'), isFalse);
    expect(storage.hasData('currentUser'), isFalse);
    expect(storage.hasData('isLoggedIn'), isFalse);
  });
}

typedef _FetchResponder = Future<Map<String, dynamic>> Function();

Future<Map<String, dynamic>> _offline() {
  return Future<Map<String, dynamic>>.error(StateError('offline'));
}

_CartFakeApiService _registerApi(
  GetStorage storage,
  List<_FetchResponder> responders,
) {
  final api = _CartFakeApiService(storage, responders);
  Get.put<ApiService>(api);
  return api;
}

Future<void> _authenticate(GetStorage storage, String userId) async {
  await storage.write('accessToken', 'token-$userId');
  await storage.write('refreshToken', 'refresh-$userId');
  await storage.write('isLoggedIn', true);
  await storage.write('currentUser', {
    'id': userId,
    'name': 'Test User',
    'phone': '0000000000',
  });
}

Future<void> _clearAuthentication(GetStorage storage) async {
  await storage.remove('accessToken');
  await storage.remove('refreshToken');
  await storage.remove('isLoggedIn');
  await storage.remove('currentUser');
}

String _userCartKey(String userId) {
  return CartController.authenticatedStorageKey('id:$userId');
}

Future<void> _seedCart(
  GetStorage storage,
  String key,
  List<CartItemModel> items,
) async {
  await storage.write(key, items.map((item) => item.toJson()).toList());
}

ProductModel _product(String id, {String price = '10'}) {
  return ProductModel(
    id: id,
    categoryId: 'category',
    name: id,
    description: '',
    unit: '1 pc',
    price: price,
    mrp: price,
    emoji: '',
  );
}

CartItemModel _cartItem(ProductModel product, int quantity) {
  return CartItemModel(product: product, quantity: quantity);
}

Future<void> _pumpUntil(bool Function() condition, {int attempts = 50}) async {
  for (var i = 0; i < attempts; i++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
}

class _CartFakeApiService extends ApiService {
  _CartFakeApiService(GetStorage storage, this._responders)
    : super(storage: storage);

  final List<_FetchResponder> _responders;
  int fetchCalls = 0;
  int addCalls = 0;
  int removeCalls = 0;
  int clearCalls = 0;
  Future<void>? nextAddGate;
  Future<void>? nextClearGate;
  bool failNextAdd = false;
  final mutationLog = <String>[];

  @override
  Future<Map<String, dynamic>> get({
    required String endpoint,
    Map<String, dynamic>? query,
    bool authenticated = true,
    Map<String, String>? headers,
  }) {
    if (endpoint != ApiConstants.cartFetch) {
      return Future.value(const {});
    }
    fetchCalls++;
    if (_responders.isEmpty) {
      return Future.value(const {'data': <dynamic>[]});
    }
    return _responders.removeAt(0)();
  }

  @override
  Future<Map<String, dynamic>> post({
    required String endpoint,
    Map<String, dynamic>? data,
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    if (endpoint == ApiConstants.cartAdd) {
      addCalls++;
      mutationLog.add('add:${data?['productId']}');
      final gate = nextAddGate;
      nextAddGate = null;
      if (gate != null) await gate;
      if (failNextAdd) {
        failNextAdd = false;
        throw StateError('add failed');
      }
    }
    if (endpoint == ApiConstants.cartClear) {
      clearCalls++;
      mutationLog.add('clear');
      final gate = nextClearGate;
      nextClearGate = null;
      if (gate != null) await gate;
    }
    return const {};
  }

  @override
  Future<Map<String, dynamic>> delete({
    required String endpoint,
    Map<String, dynamic>? data,
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    if (endpoint == ApiConstants.cartRemove) {
      removeCalls++;
      mutationLog.add('remove:${data?['productId']}');
    }
    if (endpoint == ApiConstants.cartClear) {
      clearCalls++;
      mutationLog.add('clear');
      final gate = nextClearGate;
      nextClearGate = null;
      if (gate != null) await gate;
    }
    return const {};
  }
}
