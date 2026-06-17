import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sonic_cart/app/core/constants/api_constants.dart';
import 'package:sonic_cart/app/core/network/api_service.dart';
import 'package:sonic_cart/app/core/services/app_session_scope.dart';
import 'package:sonic_cart/app/data/models/address_model.dart';
import 'package:sonic_cart/app/modules/profile/controllers/profile_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageContainer = 'profile_controller_test';
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async {
          return '.dart_tool/test_storage/profile_controller';
        });
    await GetStorage.init();
    await GetStorage.init(storageContainer);
  });

  tearDown(() async {
    await GetStorage().erase();
    await GetStorage(storageContainer).erase();
    Get.reset();
    Get.testMode = false;
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test(
    'manual service location replaces stale selected live address label',
    () async {
      final storage = GetStorage(storageContainer);
      final controller = ProfileController(storage);

      controller.addresses.assignAll([
        const AddressModel(
          id: 'live-location',
          fullName: 'Customer',
          contactNumber: '',
          address: 'Old live location',
          latitude: 10,
          longitude: 10,
          isSelected: true,
        ),
      ]);

      await controller.applyServiceAreaLocation(
        address: 'Serviceable manual address',
        latitude: 24.8607,
        longitude: 67.0011,
      );

      expect(controller.dashboardAddressLabel, 'Serviceable manual address');
      expect(controller.addresses.any((item) => item.isSelected), isFalse);
    },
  );

  test(
    'stored temporary service location does not override fresh live label on app start',
    () async {
      final storage = GetStorage(storageContainer);
      await storage.write(
        'selectedAddress',
        const AddressModel(
          id: 'service-location',
          fullName: 'Customer',
          contactNumber: '',
          address: 'Previous manual service address',
          latitude: 24.8607,
          longitude: 67.0011,
          isSelected: true,
        ).toJson(),
      );

      final controller = ProfileController(storage);
      controller.liveLocationAddress.value = 'Fresh live location';

      expect(controller.activeAddress, isNull);
      expect(controller.dashboardAddressLabel, 'Fresh live location');

      controller.selectedAddressId.value = 'service-location';

      expect(
        controller.dashboardAddressLabel,
        'Previous manual service address',
      );
    },
  );

  test(
    'authenticated refresh preserves guest selected service location',
    () async {
      final storage = GetStorage(storageContainer);
      await storage.write('accessToken', 'token');
      await storage.write('isLoggedIn', true);
      await storage.write('currentUser', {
        'id': 'user-1',
        'name': 'Ali Raza',
        'phone': '03000000000',
      });
      await storage.write('selectedLocationServiceable', true);
      await storage.write(
        AppSessionScope.selectedServiceLocationSessionKey,
        AppSessionScope.id,
      );
      await storage.write('selectedVendorId', 'vendor-1');
      await storage.write(
        'selectedAddress',
        const AddressModel(
          id: 'service-location',
          fullName: 'Customer',
          contactNumber: '',
          address: 'Guest selected serviceable address',
          latitude: 24.8607,
          longitude: 67.0011,
          vendorId: 'vendor-1',
          isSelected: true,
        ).toJson(),
      );

      final controller = ProfileController(storage);
      await controller.refreshForAuthenticatedSession();

      final selectedAddress = storage.read('selectedAddress') as Map;
      expect(controller.selectedAddressId.value, 'service-location');
      expect(
        controller.dashboardAddressLabel,
        'Guest selected serviceable address',
      );
      expect(selectedAddress['id'], 'service-location');
      expect(selectedAddress['vendorId'], 'vendor-1');
      expect(storage.read<bool>('selectedLocationServiceable'), isTrue);
      expect(storage.read<String>('selectedVendorId'), 'vendor-1');
    },
  );

  test(
    'authenticated refresh does not preserve old app session service location',
    () async {
      final storage = GetStorage(storageContainer);
      await storage.write('accessToken', 'token');
      await storage.write('isLoggedIn', true);
      await storage.write('currentUser', {
        'id': 'user-1',
        'name': 'Ali Raza',
        'phone': '03000000000',
      });
      await storage.write('selectedLocationServiceable', true);
      await storage.write(
        AppSessionScope.selectedServiceLocationSessionKey,
        'old-app-run',
      );
      await storage.write('selectedVendorId', 'vendor-1');
      await storage.write(
        'selectedAddress',
        const AddressModel(
          id: 'service-location',
          fullName: 'Customer',
          contactNumber: '',
          address: 'Old app run serviceable address',
          latitude: 24.8607,
          longitude: 67.0011,
          vendorId: 'vendor-1',
          isSelected: true,
        ).toJson(),
      );

      final controller = ProfileController(storage);
      await controller.refreshForAuthenticatedSession();

      expect(controller.selectedAddressId.value, isNull);
      expect(
        controller.dashboardAddressLabel,
        isNot('Old app run serviceable address'),
      );
    },
  );

  test(
    'save address keeps draft coordinates when API response omits them',
    () async {
      Get.testMode = true;
      final storage = GetStorage(storageContainer);
      await storage.write('accessToken', 'token');
      await storage.write('isLoggedIn', true);
      await storage.write('currentUser', {
        'id': 'user-1',
        'name': 'Ali Raza',
        'phone': '03000000000',
      });
      Get.put<ApiService>(_ProfileFakeApiService(storage));
      final controller = ProfileController(storage);
      controller.addressNameController.text = 'Ali Raza';
      controller.addressPhoneController.text = '0300000000';
      controller.addressLineController.text = 'New selected address';
      controller.draftLatitude.value = 24.95;
      controller.draftLongitude.value = 67.05;
      controller.draftPlaceId.value = 'place-1';

      await controller.saveAddress();

      final selectedAddress = Map<String, dynamic>.from(
        storage.read('selectedAddress') as Map,
      );
      expect(selectedAddress['id'], 'addr-1');
      expect(selectedAddress['latitude'], 24.95);
      expect(selectedAddress['longitude'], 67.05);
      expect(selectedAddress['placeId'], 'place-1');
      expect(selectedAddress['vendorId'], 'vendor-1');
      expect(storage.read<String>('selectedVendorId'), 'vendor-1');
      expect(storage.read<bool>('selectedLocationServiceable'), isTrue);
    },
  );

  test('home greeting shows Customer for guest users only', () async {
    final storage = GetStorage(storageContainer);
    final controller = ProfileController(storage);

    controller.addresses.assignAll([
      const AddressModel(
        id: 'addr-1',
        fullName: 'Ali Raza',
        contactNumber: '03000000000',
        address: 'Saved address',
        isSelected: true,
      ),
    ]);

    expect(controller.dashboardPrimaryLabel, 'Hi, Customer');
  });

  test(
    'home greeting uses logged-in customer name before address name',
    () async {
      final storage = GetStorage(storageContainer);
      await storage.write('accessToken', 'token');
      await storage.write('isLoggedIn', true);
      await storage.write('currentUser', {
        'id': 'user-1',
        'name': 'Ali Raza',
        'phone': '03000000000',
      });

      final controller = ProfileController(storage);
      controller.addresses.assignAll([
        const AddressModel(
          id: 'addr-1',
          fullName: 'Customer',
          contactNumber: '03000000000',
          address: 'Saved address',
          isSelected: true,
        ),
      ]);

      expect(controller.dashboardPrimaryLabel, 'Hi, Ali Raza');
    },
  );

  test('home greeting avoids generic logged-in customer placeholder', () async {
    final storage = GetStorage(storageContainer);
    await storage.write('accessToken', 'token');
    await storage.write('isLoggedIn', true);
    await storage.write('currentUser', {
      'id': 'user-1',
      'name': 'SonicKart Customer',
      'phone': '03000000000',
    });

    final controller = ProfileController(storage);

    expect(controller.dashboardPrimaryLabel, 'Hi, 03000000000');
  });
}

class _ProfileFakeApiService extends ApiService {
  _ProfileFakeApiService(GetStorage storage) : super(storage: storage);

  @override
  Future<Map<String, dynamic>> post({
    required String endpoint,
    Map<String, dynamic>? data,
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    if (endpoint == ApiConstants.addressSave) {
      return {
        'data': {
          'id': 'addr-1',
          'fullName': data?['fullName'],
          'contactNumber': data?['contactNumber'],
          'address': data?['address'],
        },
      };
    }
    return const {};
  }

  @override
  Future<Map<String, dynamic>> patch({
    required String endpoint,
    Map<String, dynamic>? data,
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    return const {};
  }

  @override
  Future<Map<String, dynamic>> get({
    required String endpoint,
    Map<String, dynamic>? query,
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    if (endpoint == ApiConstants.resolveVendor) {
      return {
        'vendorIds': ['vendor-1'],
      };
    }
    return const {};
  }
}
