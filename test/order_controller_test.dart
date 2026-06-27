import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sonic_cart/app/core/constants/api_constants.dart';
import 'package:sonic_cart/app/core/network/api_service.dart';
import 'package:sonic_cart/app/data/models/address_model.dart';
import 'package:sonic_cart/app/data/models/order_model.dart';
import 'package:sonic_cart/app/modules/order_controller.dart';
import 'package:sonic_cart/app/modules/profile/controllers/profile_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageContainer = 'order_controller_test';
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async {
          return '.dart_tool/test_storage/order_controller';
        });
    await GetStorage.init(storageContainer);
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
    'checkout recipient uses updated saved address name for selected address',
    () async {
      final storage = GetStorage(storageContainer);
      final profile = ProfileController(storage);
      Get.put<ProfileController>(profile);

      final controller = OrderController(storage);
      addTearDown(controller.onClose);

      const oldSelectedAddress = AddressModel(
        id: 'addr-1',
        fullName: 'Old Customer',
        contactNumber: '0300000000',
        address: 'Old street',
        latitude: 24.95,
        longitude: 67.05,
        isSelected: true,
      );
      final updatedAddress = oldSelectedAddress.copyWith(
        fullName: 'New Customer',
        contactNumber: '0311111111',
        address: 'Updated street',
      );

      controller.selectedCheckoutAddress.value = oldSelectedAddress;
      controller.deliveryAddressController.text = oldSelectedAddress.address;
      profile.addresses.assignAll([updatedAddress]);
      profile.selectedAddressId.value = updatedAddress.id;

      expect(controller.deliveryRecipient, 'New Customer');

      await controller.preloadCheckoutContext();

      expect(
        controller.selectedCheckoutAddress.value?.fullName,
        'New Customer',
      );
      expect(
        controller.selectedCheckoutAddress.value?.contactNumber,
        '0311111111',
      );
      expect(
        controller.selectedCheckoutAddress.value?.address,
        'Updated street',
      );
    },
  );

  group('OrderController realtime tracking updates', () {
    test(
      'keeps delivery destination when generic tracking coords arrive',
      () async {
        final controller = OrderController(GetStorage(storageContainer));
        addTearDown(controller.onClose);
        controller.orders.assignAll([_baseOrderWithoutDeliveryLocation()]);

        await controller.handleRealtimeOrderPayload({
          'orderId': 'ORD1',
          'status': 'in_transit',
          'latitude': 25.1122,
          'longitude': 67.3344,
        });

        final updated = controller.findOrderById('ORD1')!;
        final deliveryLocation = Map<String, dynamic>.from(
          updated.raw['deliveryLocation'] as Map,
        );
        final deliveryPersonLocation = Map<String, dynamic>.from(
          updated.raw['deliveryPersonLocation'] as Map,
        );

        expect(updated.status, 'in_transit');
        expect(updated.deliveryAddress, 'Customer drop address');
        expect(deliveryLocation['latitude'], 24.8607);
        expect(deliveryLocation['longitude'], 67.0011);
        expect(updated.raw['latitude'], 24.8607);
        expect(updated.raw['longitude'], 67.0011);
        expect(deliveryPersonLocation['latitude'], 25.1122);
        expect(deliveryPersonLocation['longitude'], 67.3344);
      },
    );

    test(
      'does not let partial deliveryLocation overwrite drop address',
      () async {
        final controller = OrderController(GetStorage(storageContainer));
        addTearDown(controller.onClose);
        controller.orders.assignAll([_baseOrderWithDeliveryLocation()]);

        await controller.handleRealtimeOrderPayload({
          'orderId': 'ORD1',
          'deliveryStatus': 'in_transit',
          'deliveryLocation': {'latitude': 25.1122, 'longitude': 67.3344},
        });

        final updated = controller.findOrderById('ORD1')!;
        final deliveryLocation = Map<String, dynamic>.from(
          updated.raw['deliveryLocation'] as Map,
        );
        final deliveryPersonLocation = Map<String, dynamic>.from(
          updated.raw['deliveryPersonLocation'] as Map,
        );

        expect(updated.status, 'in_transit');
        expect(deliveryLocation['address'], 'Customer drop address');
        expect(deliveryLocation['latitude'], 24.8607);
        expect(deliveryLocation['longitude'], 67.0011);
        expect(deliveryPersonLocation['latitude'], 25.1122);
        expect(deliveryPersonLocation['longitude'], 67.3344);
      },
    );

    test(
      'protects drop address from in-transit detail payload coords',
      () async {
        final controller = OrderController(GetStorage(storageContainer));
        addTearDown(controller.onClose);
        controller.orders.assignAll([_baseOrderWithDeliveryLocation()]);

        await controller.handleRealtimeOrderPayload({
          'id': 'ORD1',
          'items': const [],
          'customerName': 'Customer',
          'customerPhone': '03000000000',
          'paymentMode': 'COD',
          'totalPrice': 500,
          'status': 'in_transit',
          'deliveryLocation': {'latitude': 25.1122, 'longitude': 67.3344},
        });

        final updated = controller.findOrderById('ORD1')!;
        final deliveryLocation = Map<String, dynamic>.from(
          updated.raw['deliveryLocation'] as Map,
        );
        final deliveryPersonLocation = Map<String, dynamic>.from(
          updated.raw['deliveryPersonLocation'] as Map,
        );

        expect(updated.status, 'in_transit');
        expect(deliveryLocation['latitude'], 24.8607);
        expect(deliveryLocation['longitude'], 67.0011);
        expect(deliveryPersonLocation['latitude'], 25.1122);
        expect(deliveryPersonLocation['longitude'], 67.3344);
      },
    );

    test('reads GeoJSON delivery rider coordinates in lng-lat order', () async {
      final controller = OrderController(GetStorage(storageContainer));
      addTearDown(controller.onClose);
      controller.orders.assignAll([_baseOrderWithDeliveryLocation()]);

      await controller.handleRealtimeOrderPayload({
        'orderId': 'ORD1',
        'deliveryStatus': 'in_transit',
        'deliveryPersonLocation': {
          'type': 'Point',
          'coordinates': [67.3344, 25.1122],
        },
      });

      final updated = controller.findOrderById('ORD1')!;
      final deliveryLocation = Map<String, dynamic>.from(
        updated.raw['deliveryLocation'] as Map,
      );
      final deliveryPersonLocation = Map<String, dynamic>.from(
        updated.raw['deliveryPersonLocation'] as Map,
      );

      expect(updated.status, 'in_transit');
      expect(deliveryLocation['latitude'], 24.8607);
      expect(deliveryLocation['longitude'], 67.0011);
      expect(deliveryPersonLocation['latitude'], 25.1122);
      expect(deliveryPersonLocation['longitude'], 67.3344);
    });

    test(
      'accepted realtime update immediately hydrates partner name and phone',
      () async {
        final storage = GetStorage(storageContainer);
        final api = _AcceptedOrderApiService(storage);
        Get.put<ApiService>(api);
        final controller = OrderController(storage);
        addTearDown(controller.onClose);
        controller.orders.assignAll([_baseOrderWithoutDeliveryLocation()]);

        await controller.handleRealtimeOrderPayload({
          'orderId': 'ORD1',
          'deliveryStatus': 'accepted',
        });

        final updated = controller.findOrderById('ORD1')!;
        expect(updated.status, 'accepted');
        expect(controller.deliveryPartnerNameFor(updated), 'Ahmed Rider');
        expect(controller.deliveryPartnerPhoneFor(updated), '03001234567');
        expect(api.orderDetailRequests, 1);
      },
    );
  });
}

OrderModel _baseOrderWithoutDeliveryLocation() {
  return OrderModel(
    id: 'ORD1',
    items: const [],
    customerName: 'Customer',
    customerPhone: '03000000000',
    deliveryAddress: 'Customer drop address',
    paymentMode: 'COD',
    totalPrice: 500,
    status: 'assigned',
    createdAt: DateTime.utc(2026, 1, 1),
    raw: {
      'id': 'ORD1',
      'orderId': 'ORD1',
      'deliveryAddress': 'Customer drop address',
      'latitude': 24.8607,
      'longitude': 67.0011,
      'status': 'assigned',
      'createdAt': '2026-01-01T00:00:00.000Z',
      'totalPrice': 500,
    },
  );
}

OrderModel _baseOrderWithDeliveryLocation() {
  final base = _baseOrderWithoutDeliveryLocation();
  return base.copyWith(
    raw: {
      ...base.raw,
      'deliveryLocation': {
        'address': 'Customer drop address',
        'latitude': 24.8607,
        'longitude': 67.0011,
      },
    },
  );
}

class _AcceptedOrderApiService extends ApiService {
  _AcceptedOrderApiService(GetStorage storage) : super(storage: storage);

  int orderDetailRequests = 0;

  @override
  Future<Map<String, dynamic>> get({
    required String endpoint,
    Map<String, dynamic>? query,
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    if (endpoint == ApiConstants.orderById('ORD1')) {
      orderDetailRequests += 1;
      return {
        'id': 'ORD1',
        'orderId': 'ORD1',
        'deliveryStatus': 'accepted',
        'deliveryAddress': 'Customer drop address',
        'totalPrice': 500,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'deliveryPartner': {
          'id': 'partner-1',
          'name': 'Ahmed Rider',
          'phone': '03001234567',
        },
      };
    }
    return const {};
  }
}
