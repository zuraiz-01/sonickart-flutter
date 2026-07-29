import 'package:geolocator/geolocator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cart/app/core/services/location_lookup_service.dart';
import 'package:sonic_cart/app/core/services/service_area_gate_service.dart';

void main() {
  group('ServiceAreaRule', () {
    test('parses admin working-area payload used by Firestore', () {
      final rule = ServiceAreaRule.fromFirestore(
        id: 'fallback-id',
        fields: const {
          'id': 'gulshan-karachi',
          'name': 'Gulshan',
          'city': 'Karachi',
          'state': 'Sindh',
          'province': 'Sindh',
          'country': 'India',
          'areaType': 'working_area',
          'appEnabled': true,
          'latitude': 24.8607,
          'longitude': 67.0011,
          'radiusKm': 5,
          'searchKeywords': ['gulshan', 'karachi', 'sindh', 'india'],
        },
      );

      expect(rule.id, 'gulshan-karachi');
      expect(rule.name, 'Gulshan');
      expect(rule.city, 'Karachi');
      expect(rule.province, 'Sindh');
      expect(rule.status, 'working');
      expect(rule.isActive, isTrue);
      expect(rule.hasCoordinateRule, isTrue);
      expect(rule.latitude, 24.8607);
      expect(rule.longitude, 67.0011);
      expect(rule.radiusKm, 5);
    });

    test('disables app when appEnabled is false', () {
      final rule = ServiceAreaRule.fromFirestore(
        id: 'gulshan-karachi',
        fields: const {
          'areaType': 'working_area',
          'appEnabled': false,
          'latitude': 24.8607,
          'longitude': 67.0011,
          'radiusKm': 5,
        },
      );

      expect(rule.status, 'working');
      expect(rule.isActive, isFalse);
      expect(rule.hasCoordinateRule, isTrue);
    });

    test('keeps backward compatibility with old status payload', () {
      final rule = ServiceAreaRule.fromFirestore(
        id: 'old-blocked-area',
        fields: const {
          'status': 'not_working',
          'isActive': true,
          'latitude': 24.8607,
          'longitude': 67.0011,
          'radiusKm': 5,
        },
      );

      expect(rule.status, 'not_working');
      expect(rule.isActive, isTrue);
    });
  });

  group('ServiceAreaGateService evaluation states', () {
    final now = DateTime.utc(2026, 7, 25, 12);

    test('successful inside-area result is confirmed allowed', () async {
      final service = _service(
        now: now,
        locationProvider: _FakeLocationProvider(
          lastKnown: _position(now: now, latitude: 24.8607, longitude: 67.0011),
        ),
        rules: [_workingArea()],
      );

      final result = await service.evaluate();

      expect(result.state, ServiceAreaGateState.insideServiceArea);
      expect(result.isAllowed, isTrue);
      expect(result.isConfirmedOutside, isFalse);
    });

    test(
      'successful outside-area result remains definitively blocked',
      () async {
        final service = _service(
          now: now,
          locationProvider: _FakeLocationProvider(
            lastKnown: _position(now: now, latitude: 25.5, longitude: 68.5),
          ),
          rules: [_workingArea()],
        );

        final result = await service.evaluate();

        expect(result.state, ServiceAreaGateState.outsideServiceArea);
        expect(result.isConfirmedOutside, isTrue);
        expect(result.reason, ServiceAreaBlockReason.outsideWorkingArea);
      },
    );

    test('temporary service-area fetch failure is not outside', () async {
      final service = _service(
        now: now,
        locationProvider: _FakeLocationProvider(
          lastKnown: _position(now: now, latitude: 24.8607, longitude: 67.0011),
        ),
        rulesLoader: () => throw StateError('network unavailable'),
      );

      final result = await service.evaluate();

      expect(result.state, ServiceAreaGateState.temporarilyUnavailable);
      expect(result.isConfirmedOutside, isFalse);
    });

    test('temporary location failure is not outside', () async {
      final locationProvider = _FakeLocationProvider(
        currentResults: [
          StateError('high accuracy timeout'),
          StateError('medium accuracy timeout'),
        ],
      );
      final service = _service(
        now: now,
        locationProvider: locationProvider,
        rules: [_workingArea()],
      );

      final result = await service.evaluate();

      expect(result.state, ServiceAreaGateState.temporarilyUnavailable);
      expect(result.isConfirmedOutside, isFalse);
      expect(locationProvider.currentLocationCalls, 2);
    });

    test('missing permission is a non-blocking permission state', () async {
      final service = _service(
        now: now,
        locationProvider: _FakeLocationProvider(
          permission: LocationPermission.denied,
          requestedPermission: LocationPermission.denied,
        ),
        rules: [_workingArea()],
      );

      final result = await service.evaluate();

      expect(result.state, ServiceAreaGateState.locationPermissionRequired);
      expect(result.isConfirmedOutside, isFalse);
    });

    test('disabled location services are a non-blocking state', () async {
      final service = _service(
        now: now,
        locationProvider: _FakeLocationProvider(serviceEnabled: false),
        rules: [_workingArea()],
      );

      final result = await service.evaluate();

      expect(result.state, ServiceAreaGateState.locationServicesDisabled);
      expect(result.isConfirmedOutside, isFalse);
    });

    test(
      'stale last-known location cannot prove the user is outside',
      () async {
        final locationProvider = _FakeLocationProvider(
          lastKnown: _position(
            now: now.subtract(const Duration(hours: 2)),
            latitude: 25.5,
            longitude: 68.5,
          ),
          currentResults: [
            StateError('current location timeout'),
            StateError('fallback location timeout'),
          ],
        );
        final service = _service(
          now: now,
          locationProvider: locationProvider,
          rules: [_workingArea()],
        );

        final result = await service.evaluate();

        expect(result.state, ServiceAreaGateState.temporarilyUnavailable);
        expect(result.isConfirmedOutside, isFalse);
        expect(locationProvider.currentLocationCalls, 2);
      },
    );

    test('fresh accurate last-known location is evaluated normally', () async {
      final locationProvider = _FakeLocationProvider(
        lastKnown: _position(
          now: now.subtract(const Duration(minutes: 1)),
          latitude: 24.8607,
          longitude: 67.0011,
          accuracy: 25,
        ),
      );
      final service = _service(
        now: now,
        locationProvider: locationProvider,
        rules: [_workingArea()],
      );

      final result = await service.evaluate();

      expect(result.state, ServiceAreaGateState.insideServiceArea);
      expect(locationProvider.currentLocationCalls, 0);
    });

    test(
      'fresh live location replaces a stale last-known coordinate',
      () async {
        final locationProvider = _FakeLocationProvider(
          lastKnown: _position(
            now: now.subtract(const Duration(hours: 1)),
            latitude: 25.5,
            longitude: 68.5,
          ),
          currentResults: [
            _position(now: now, latitude: 24.8607, longitude: 67.0011),
          ],
        );
        final service = _service(
          now: now,
          locationProvider: locationProvider,
          rules: [_workingArea()],
        );

        final result = await service.evaluate();

        expect(result.state, ServiceAreaGateState.insideServiceArea);
        expect(locationProvider.currentLocationCalls, 1);
      },
    );

    test('successful empty configuration is definitively outside', () async {
      final service = _service(
        now: now,
        locationProvider: _FakeLocationProvider(
          lastKnown: _position(now: now, latitude: 24.8607, longitude: 67.0011),
        ),
        rules: const [],
      );

      final result = await service.evaluate();

      expect(result.state, ServiceAreaGateState.outsideServiceArea);
      expect(result.isConfirmedOutside, isTrue);
    });

    test('intentionally disabled configuration remains outside', () async {
      final service = _service(
        now: now,
        locationProvider: _FakeLocationProvider(
          lastKnown: _position(now: now, latitude: 24.8607, longitude: 67.0011),
        ),
        rules: [_workingArea(isActive: false)],
      );

      final result = await service.evaluate();

      expect(result.state, ServiceAreaGateState.outsideServiceArea);
      expect(result.isConfirmedOutside, isTrue);
    });

    test('incomplete active working configuration is unavailable', () async {
      final service = _service(
        now: now,
        locationProvider: _FakeLocationProvider(
          lastKnown: _position(now: now, latitude: 24.8607, longitude: 67.0011),
        ),
        rules: [
          const ServiceAreaRule(
            id: 'incomplete',
            name: 'Incomplete area',
            city: 'Karachi',
            province: 'Sindh',
            status: 'working',
            message: '',
            isActive: true,
            sortOrder: 0,
          ),
        ],
      );

      final result = await service.evaluate();

      expect(result.state, ServiceAreaGateState.temporarilyUnavailable);
      expect(result.isConfirmedOutside, isFalse);
    });
  });
}

ServiceAreaGateService _service({
  required DateTime now,
  required ServiceAreaLocationProvider locationProvider,
  List<ServiceAreaRule>? rules,
  ServiceAreaRulesLoader? rulesLoader,
}) {
  return ServiceAreaGateService.withRulesLoader(
    locationProvider: locationProvider,
    locationLookupService: _FixedLocationLookupService(),
    serviceAreaRulesLoader: rulesLoader ?? () async => rules ?? const [],
    clock: () => now,
  );
}

ServiceAreaRule _workingArea({bool isActive = true}) {
  return ServiceAreaRule(
    id: 'working-area',
    name: 'Working area',
    city: 'Karachi',
    province: 'Sindh',
    status: 'working',
    message: '',
    isActive: isActive,
    sortOrder: 0,
    latitude: 24.8607,
    longitude: 67.0011,
    radiusKm: 5,
  );
}

Position _position({
  required DateTime now,
  required double latitude,
  required double longitude,
  double accuracy = 20,
}) {
  return Position(
    longitude: longitude,
    latitude: latitude,
    timestamp: now,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class _FakeLocationProvider implements ServiceAreaLocationProvider {
  _FakeLocationProvider({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.requestedPermission = LocationPermission.whileInUse,
    this.lastKnown,
    List<Object>? currentResults,
  }) : currentResults = [...?currentResults];

  final bool serviceEnabled;
  final LocationPermission permission;
  final LocationPermission requestedPermission;
  final Position? lastKnown;
  final List<Object> currentResults;
  int currentLocationCalls = 0;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    required LocationSettings locationSettings,
  }) async {
    currentLocationCalls += 1;
    if (currentResults.isEmpty) {
      throw StateError('No current location result');
    }
    final result = currentResults.removeAt(0);
    if (result is Position) return result;
    throw result;
  }

  @override
  Future<Position?> getLastKnownPosition() async => lastKnown;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> requestPermission() async => requestedPermission;
}

class _FixedLocationLookupService extends LocationLookupService {
  @override
  Future<String?> reverseGeocodeToAddress({
    required double latitude,
    required double longitude,
  }) async {
    return 'Test location';
  }
}
