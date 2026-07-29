import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sonic_cart/app/core/constants/api_constants.dart';
import 'package:sonic_cart/app/core/network/api_service.dart';
import 'package:sonic_cart/app/data/models/address_model.dart';
import 'package:sonic_cart/app/modules/profile/controllers/profile_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageContainer = 'profile_address_catalog_test';
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async {
          return '.dart_tool/test_storage/profile_address_catalog';
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
    'selecting saved address updates catalog vendor scope without waiting for profile location patch',
    () async {
      final storage = GetStorage(storageContainer);
      await storage.write('accessToken', 'token-user-a');
      final api = _ProfileAddressFakeApiService(storage);
      Get.put<ApiService>(api);
      final controller = ProfileController(storage);
      addTearDown(controller.onClose);

      final address = AddressModel(
        id: 'addr-1',
        fullName: 'Customer',
        contactNumber: '0300000000',
        address: 'New serviceable address',
        latitude: 24.8607,
        longitude: 67.0011,
        isSelected: false,
      );
      controller.addresses.assignAll([address]);

      await controller
          .useAddress(address)
          .timeout(const Duration(milliseconds: 300));

      expect(api.userPatchCalls, 1);
      expect(api.resolveVendorCalls, 1);
      expect(api.userPatchCompleter.isCompleted, isFalse);
      expect(storage.read<String>('selectedVendorId'), 'vendor-new');
      expect(
        storage.read<Map<String, dynamic>>('selectedAddress')?['vendorId'],
        'vendor-new',
      );

      api.completeUserPatch();
    },
  );
}

class _ProfileAddressFakeApiService extends ApiService {
  _ProfileAddressFakeApiService(GetStorage storage) : super(storage: storage);

  final userPatchCompleter = Completer<Map<String, dynamic>>();
  int userPatchCalls = 0;
  int resolveVendorCalls = 0;

  void completeUserPatch() {
    if (userPatchCompleter.isCompleted) return;
    userPatchCompleter.complete(const {'success': true});
  }

  @override
  Future<Map<String, dynamic>> patch({
    required String endpoint,
    Map<String, dynamic>? data,
    bool authenticated = true,
    Map<String, String>? headers,
  }) {
    if (endpoint == ApiConstants.user) {
      userPatchCalls += 1;
      return userPatchCompleter.future;
    }
    return Future.value(const {'success': true});
  }

  @override
  Future<Map<String, dynamic>> get({
    required String endpoint,
    Map<String, dynamic>? query,
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    if (endpoint == ApiConstants.resolveVendor) {
      resolveVendorCalls += 1;
      return {
        'vendorIds': ['vendor-new'],
      };
    }
    return const {};
  }
}
