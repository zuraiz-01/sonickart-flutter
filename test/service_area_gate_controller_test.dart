import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sonic_cart/app/core/network/api_service.dart';
import 'package:sonic_cart/app/core/services/app_session_scope.dart';
import 'package:sonic_cart/app/core/services/service_area_gate_controller.dart';
import 'package:sonic_cart/app/core/services/service_area_gate_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async {
          return '.dart_tool/test_storage/service_area_gate_controller';
        });
    await GetStorage.init();
  });

  tearDown(() async {
    await GetStorage().erase();
    Get.reset();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test(
    'forced service area check re-evaluates after cached session check',
    () async {
      final service = _FakeServiceAreaGateService([
        ServiceAreaGateResult.allowed(
          locationLabel: 'Guest selected address',
          latitude: 24.8607,
          longitude: 67.0011,
        ),
        ServiceAreaGateResult.blocked(
          reason: ServiceAreaBlockReason.outsideWorkingArea,
          locationLabel: 'Live unserviceable location',
          message: 'Service is not available here.',
          latitude: 25.0,
          longitude: 68.0,
        ),
      ]);
      final controller = ServiceAreaGateController(
        serviceAreaGateService: service,
      );
      addTearDown(controller.onClose);

      await controller.ensureChecked();
      await controller.ensureChecked();

      expect(service.evaluateCount, 1);
      expect(controller.isBlocked, isFalse);

      await controller.ensureChecked(force: true);

      expect(service.evaluateCount, 2);
      expect(controller.isBlocked, isTrue);
      expect(GetStorage().read<bool>('selectedLocationServiceable'), isFalse);
    },
  );

  test(
    'preserving a serviceable selected address skips the next live check',
    () async {
      await GetStorage().write('selectedLocationServiceable', true);
      await GetStorage().write(
        AppSessionScope.selectedServiceLocationSessionKey,
        AppSessionScope.id,
      );
      await GetStorage().write('selectedAddress', {
        'id': 'service-location',
        'fullName': 'Customer',
        'contactNumber': '',
        'address': 'Guest selected serviceable address',
        'latitude': 24.8607,
        'longitude': 67.0011,
        'isSelected': true,
      });
      final service = _FakeServiceAreaGateService([
        ServiceAreaGateResult.blocked(
          reason: ServiceAreaBlockReason.outsideWorkingArea,
          locationLabel: 'Live unserviceable location',
          message: 'Service is not available here.',
          latitude: 25.0,
          longitude: 68.0,
        ),
      ]);
      final controller = ServiceAreaGateController(
        serviceAreaGateService: service,
      );
      addTearDown(controller.onClose);
      controller.blockedResult.value = ServiceAreaGateResult.blocked(
        reason: ServiceAreaBlockReason.outsideWorkingArea,
        locationLabel: 'Old blocked location',
        message: 'Blocked',
      );

      expect(controller.preserveSelectedServiceableLocation(), isTrue);
      await controller.ensureChecked();

      expect(controller.isBlocked, isFalse);
      expect(service.evaluateCount, 0);
      expect(
        controller.addressController.text,
        'Guest selected serviceable address',
      );
    },
  );

  test('stale serviceable selected address is not preserved', () async {
    await GetStorage().write('selectedLocationServiceable', true);
    await GetStorage().write(
      AppSessionScope.selectedServiceLocationSessionKey,
      'old-app-run',
    );
    await GetStorage().write('selectedAddress', {
      'id': 'service-location',
      'fullName': 'Customer',
      'contactNumber': '',
      'address': 'Old serviceable address',
      'latitude': 24.8607,
      'longitude': 67.0011,
      'isSelected': true,
    });
    final service = _FakeServiceAreaGateService([
      ServiceAreaGateResult.blocked(
        reason: ServiceAreaBlockReason.outsideWorkingArea,
        locationLabel: 'Live unserviceable location',
        message: 'Service is not available here.',
        latitude: 25.0,
        longitude: 68.0,
      ),
    ]);
    final controller = ServiceAreaGateController(
      serviceAreaGateService: service,
    );
    addTearDown(controller.onClose);

    expect(controller.preserveSelectedServiceableLocation(), isFalse);

    await controller.ensureChecked(force: true);

    expect(controller.isBlocked, isTrue);
    expect(service.evaluateCount, 1);
  });
}

class _FakeServiceAreaGateService extends ServiceAreaGateService {
  _FakeServiceAreaGateService(this._results)
    : super(apiService: ApiService(storage: GetStorage()));

  final List<ServiceAreaGateResult> _results;
  int evaluateCount = 0;

  @override
  Future<ServiceAreaGateResult> evaluate() async {
    final index = evaluateCount < _results.length
        ? evaluateCount
        : _results.length - 1;
    evaluateCount += 1;
    return _results[index];
  }
}
