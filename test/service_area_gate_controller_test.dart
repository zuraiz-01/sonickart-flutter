import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sizer/sizer.dart';
import 'package:sonic_cart/app/core/network/api_service.dart';
import 'package:sonic_cart/app/core/services/app_session_scope.dart';
import 'package:sonic_cart/app/core/services/service_area_gate_controller.dart';
import 'package:sonic_cart/app/core/services/service_area_gate_service.dart';
import 'package:sonic_cart/app/core/widgets/service_area_gate_overlay.dart';

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

  test('new app session makes previous service location stale', () async {
    final firstSession = AppSessionScope.startNewSession(id: 'first-app-run');
    await GetStorage().write('selectedLocationServiceable', true);
    await GetStorage().write(
      AppSessionScope.selectedServiceLocationSessionKey,
      firstSession,
    );
    await GetStorage().write('selectedAddress', {
      'id': 'service-location',
      'fullName': 'Customer',
      'contactNumber': '',
      'address': 'Previous app run serviceable address',
      'latitude': 24.8607,
      'longitude': 67.0011,
      'isSelected': true,
    });

    AppSessionScope.startNewSession(id: 'second-app-run');
    final controller = ServiceAreaGateController(
      serviceAreaGateService: _FakeServiceAreaGateService([
        ServiceAreaGateResult.allowed(
          locationLabel: 'Fresh app open live location',
          latitude: 24.95,
          longitude: 67.05,
        ),
      ]),
    );
    addTearDown(controller.onClose);

    expect(controller.preserveSelectedServiceableLocation(), isFalse);
    expect(controller.shouldRefreshLiveLocationOnAppOpen, isTrue);
  });

  test(
    'saved selected address does not force live refresh on app open',
    () async {
      await GetStorage().write('selectedLocationServiceable', true);
      await GetStorage().write('selectedAddress', {
        'id': 'addr-1',
        'fullName': 'Ali',
        'contactNumber': '03000000000',
        'address': 'Saved home address',
        'latitude': 24.8607,
        'longitude': 67.0011,
        'isSelected': true,
      });

      final controller = ServiceAreaGateController(
        serviceAreaGateService: _FakeServiceAreaGateService([
          ServiceAreaGateResult.blocked(
            reason: ServiceAreaBlockReason.outsideWorkingArea,
            locationLabel: 'Different live location',
            message: 'Service is not available here.',
            latitude: 25.0,
            longitude: 68.0,
          ),
        ]),
      );
      addTearDown(controller.onClose);

      expect(controller.shouldRefreshLiveLocationOnAppOpen, isFalse);
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

  testWidgets('inside and temporary results do not show Hang Tight', (
    tester,
  ) async {
    final service = _FakeServiceAreaGateService([
      ServiceAreaGateResult.allowed(
        locationLabel: 'Inside service area',
        latitude: 24.8607,
        longitude: 67.0011,
      ),
      ServiceAreaGateResult.temporarilyUnavailable(
        message: 'Network temporarily unavailable.',
      ),
    ]);
    final controller = ServiceAreaGateController(
      serviceAreaGateService: service,
    );
    addTearDown(controller.onClose);

    await controller.ensureChecked();
    await tester.pumpWidget(_overlayTestApp(controller));

    expect(
      controller.evaluationState.value,
      ServiceAreaGateState.insideServiceArea,
    );
    expect(find.text('HANG'), findsNothing);

    await controller.ensureChecked(force: true);
    await tester.pump();

    expect(
      controller.evaluationState.value,
      ServiceAreaGateState.temporarilyUnavailable,
    );
    expect(controller.confirmedResult.value?.isAllowed, isTrue);
    expect(controller.isBlocked, isFalse);
    expect(find.text('HANG'), findsNothing);
    expect(GetStorage().read<bool>('selectedLocationServiceable'), isTrue);
  });

  testWidgets('confirmed outside result shows Hang Tight', (tester) async {
    final controller = ServiceAreaGateController(
      serviceAreaGateService: _FakeServiceAreaGateService([
        ServiceAreaGateResult.blocked(
          reason: ServiceAreaBlockReason.outsideWorkingArea,
          locationLabel: 'Outside service area',
          message: 'Service is not available here.',
          latitude: 25.5,
          longitude: 68.5,
        ),
      ]),
    );
    addTearDown(controller.onClose);

    await controller.ensureChecked();
    await tester.pumpWidget(_overlayTestApp(controller));

    expect(controller.isBlocked, isTrue);
    expect(find.text('HANG'), findsOneWidget);
    expect(find.text('TIGHT!'), findsOneWidget);
  });

  test(
    'later confirmed outside result replaces a previous inside result',
    () async {
      final service = _FakeServiceAreaGateService([
        ServiceAreaGateResult.allowed(
          locationLabel: 'Inside service area',
          latitude: 24.8607,
          longitude: 67.0011,
        ),
        ServiceAreaGateResult.blocked(
          reason: ServiceAreaBlockReason.outsideWorkingArea,
          locationLabel: 'Outside service area',
          message: 'Service is not available here.',
          latitude: 25.5,
          longitude: 68.5,
        ),
      ]);
      final controller = ServiceAreaGateController(
        serviceAreaGateService: service,
      );
      addTearDown(controller.onClose);

      await controller.ensureChecked();
      expect(controller.isBlocked, isFalse);

      await controller.ensureChecked(force: true);

      expect(controller.isBlocked, isTrue);
      expect(
        controller.confirmedResult.value?.state,
        ServiceAreaGateState.outsideServiceArea,
      );
      expect(GetStorage().read<bool>('selectedLocationServiceable'), isFalse);
    },
  );

  test('concurrent current-location checks share one evaluation', () async {
    final service = _ControllableServiceAreaGateService();
    final controller = ServiceAreaGateController(
      serviceAreaGateService: service,
    );
    addTearDown(controller.onClose);

    final first = controller.checkCurrentLocation();
    final second = controller.checkCurrentLocation(force: true);

    expect(service.evaluateCount, 1);
    service.currentLocationCompleter.complete(
      ServiceAreaGateResult.allowed(
        locationLabel: 'Inside service area',
        latitude: 24.8607,
        longitude: 67.0011,
      ),
    );
    await Future.wait([first, second]);

    expect(service.evaluateCount, 1);
    expect(controller.isBlocked, isFalse);
  });

  test(
    'older current-location result cannot overwrite newer manual success',
    () async {
      final service = _ControllableServiceAreaGateService();
      final controller = ServiceAreaGateController(
        serviceAreaGateService: service,
      );
      addTearDown(controller.onClose);

      final oldCheck = controller.checkCurrentLocation();
      await controller.evaluateManualLocation(
        address: 'New selected address',
        latitude: 24.8607,
        longitude: 67.0011,
      );
      service.currentLocationCompleter.complete(
        ServiceAreaGateResult.blocked(
          reason: ServiceAreaBlockReason.outsideWorkingArea,
          locationLabel: 'Stale outside result',
          message: 'Stale result',
          latitude: 25.5,
          longitude: 68.5,
        ),
      );
      await oldCheck;

      expect(controller.isBlocked, isFalse);
      expect(
        controller.confirmedResult.value?.state,
        ServiceAreaGateState.insideServiceArea,
      );
      expect(
        GetStorage().read<Map<String, dynamic>>('selectedAddress')?['address'],
        'New selected address',
      );
    },
  );
}

Widget _overlayTestApp(ServiceAreaGateController controller) {
  return Sizer(
    builder: (context, orientation, deviceType) {
      return MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [ServiceAreaGateOverlay(controller: controller)],
          ),
        ),
      );
    },
  );
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

class _ControllableServiceAreaGateService extends ServiceAreaGateService {
  _ControllableServiceAreaGateService()
    : super(apiService: ApiService(storage: GetStorage()));

  final currentLocationCompleter = Completer<ServiceAreaGateResult>();
  int evaluateCount = 0;

  @override
  Future<ServiceAreaGateResult> evaluate() {
    evaluateCount += 1;
    return currentLocationCompleter.future;
  }

  @override
  Future<ServiceAreaGateResult> evaluateManualLocation({
    required double latitude,
    required double longitude,
    required String locationLabel,
  }) async {
    return ServiceAreaGateResult.allowed(
      locationLabel: locationLabel,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
