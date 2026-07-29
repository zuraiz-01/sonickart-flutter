import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../firebase_options.dart';
import '../network/api_service.dart';
import 'firebase_bootstrap.dart';
import 'location_lookup_service.dart';

typedef ServiceAreaRulesLoader = Future<List<ServiceAreaRule>> Function();

abstract interface class ServiceAreaLocationProvider {
  Future<bool> isLocationServiceEnabled();

  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();

  Future<Position?> getLastKnownPosition();

  Future<Position> getCurrentPosition({
    required LocationSettings locationSettings,
  });
}

final class GeolocatorServiceAreaLocationProvider
    implements ServiceAreaLocationProvider {
  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  @override
  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  @override
  Future<Position?> getLastKnownPosition() {
    return Geolocator.getLastKnownPosition();
  }

  @override
  Future<Position> getCurrentPosition({
    required LocationSettings locationSettings,
  }) {
    return Geolocator.getCurrentPosition(locationSettings: locationSettings);
  }
}

class ServiceAreaGateService {
  ServiceAreaGateService({
    required ApiService apiService,
    FirebaseAuth? firebaseAuth,
    LocationLookupService? locationLookupService,
    ServiceAreaLocationProvider? locationProvider,
    DateTime Function()? clock,
  }) : _apiService = apiService,
       _firebaseAuth = firebaseAuth,
       _locationLookupService =
           locationLookupService ?? LocationLookupService(),
       _locationProvider =
           locationProvider ?? GeolocatorServiceAreaLocationProvider(),
       _serviceAreaRulesLoader = null,
       _clock = clock ?? DateTime.now;

  ServiceAreaGateService.withRulesLoader({
    required ServiceAreaRulesLoader serviceAreaRulesLoader,
    required ServiceAreaLocationProvider locationProvider,
    LocationLookupService? locationLookupService,
    DateTime Function()? clock,
  }) : _apiService = null,
       _firebaseAuth = null,
       _locationLookupService =
           locationLookupService ?? LocationLookupService(),
       _locationProvider = locationProvider,
       _serviceAreaRulesLoader = serviceAreaRulesLoader,
       _clock = clock ?? DateTime.now;

  static const _collectionName = 'serviceAreas';
  static const _genericBlockedMessage =
      'We are currently live in select areas and expanding quickly to more neighbourhoods and cities.';
  static const _serviceAreasUnavailableMessage =
      'Service areas are not available right now. Please try again shortly.';
  static const lastKnownLocationMaxAge = Duration(minutes: 5);
  static const lastKnownLocationMaxAccuracyMeters = 100.0;
  static const currentLocationMaxAge = Duration(minutes: 2);
  static const currentLocationMaxAccuracyMeters = 200.0;
  static const _lastKnownLocationTimeout = Duration(seconds: 2);

  final ApiService? _apiService;
  final FirebaseAuth? _firebaseAuth;
  final LocationLookupService _locationLookupService;
  final ServiceAreaLocationProvider _locationProvider;
  final ServiceAreaRulesLoader? _serviceAreaRulesLoader;
  final DateTime Function() _clock;

  Future<ServiceAreaGateResult> evaluate() async {
    try {
      final positionResult = await _resolvePosition();
      if (positionResult.position == null) {
        return _resultForUnavailablePosition(positionResult);
      }

      final position = positionResult.position!;
      debugPrint(
        'ServiceAreaGateService.evaluate: checking '
        '${_safePositionSummary(position)}',
      );
      return await _evaluateCoordinate(
        latitude: position.latitude,
        longitude: position.longitude,
        locationLabel: await _locationLabel(
          position.latitude,
          position.longitude,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('ServiceAreaGateService.evaluate failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return ServiceAreaGateResult.temporarilyUnavailable(
        locationLabel: 'Live location unavailable',
        message: _serviceAreasUnavailableMessage,
      );
    }
  }

  Future<ServiceAreaGateResult> evaluateManualLocation({
    required double latitude,
    required double longitude,
    required String locationLabel,
  }) async {
    if (!_isValidCoordinate(latitude, longitude)) {
      return ServiceAreaGateResult.temporarilyUnavailable(
        locationLabel: locationLabel.trim().isEmpty
            ? 'Selected location unavailable'
            : locationLabel.trim(),
        message: 'Please select a valid delivery location.',
      );
    }
    try {
      return await _evaluateCoordinate(
        latitude: latitude,
        longitude: longitude,
        locationLabel: locationLabel,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'ServiceAreaGateService.evaluateManualLocation failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return ServiceAreaGateResult.temporarilyUnavailable(
        locationLabel: locationLabel,
        message: _serviceAreasUnavailableMessage,
      );
    }
  }

  Future<ServiceAreaGateResult> _evaluateCoordinate({
    required double latitude,
    required double longitude,
    required String locationLabel,
  }) async {
    final safeLabel = locationLabel.trim().isNotEmpty
        ? locationLabel.trim()
        : _coordinateLabel(latitude, longitude);
    final areas = await _fetchServiceAreas();
    debugPrint(
      'ServiceAreaGateService.evaluate: fetched ${areas.length} service areas',
    );
    if (areas.isNotEmpty) {
      debugPrint(
        'ServiceAreaGateService.evaluate: areas=${areas.map(_debugAreaSummary).join(' | ')}',
      );
    }
    if (areas.isEmpty) {
      return ServiceAreaGateResult.blocked(
        reason: ServiceAreaBlockReason.outsideWorkingArea,
        locationLabel: safeLabel,
        message: _serviceAreasUnavailableMessage,
        latitude: latitude,
        longitude: longitude,
      );
    }

    final activeAreas = areas.where((area) => area.isActive).toList();
    if (activeAreas.isEmpty) {
      return ServiceAreaGateResult.blocked(
        reason: ServiceAreaBlockReason.outsideWorkingArea,
        locationLabel: safeLabel,
        message: _serviceAreasUnavailableMessage,
        latitude: latitude,
        longitude: longitude,
      );
    }

    final invalidWorkingAreas = activeAreas.where(
      (area) => area.status == 'working' && !area.hasCoordinateRule,
    );
    if (invalidWorkingAreas.isNotEmpty) {
      return ServiceAreaGateResult.temporarilyUnavailable(
        locationLabel: safeLabel,
        message: _serviceAreasUnavailableMessage,
        latitude: latitude,
        longitude: longitude,
      );
    }

    final activeCoordinateAreas = activeAreas
        .where((area) => area.hasCoordinateRule)
        .toList();
    final workingAreas = activeCoordinateAreas
        .where((area) => area.status == 'working')
        .toList();
    debugPrint(
      'ServiceAreaGateService.evaluate: activeCoordinateAreas=${activeCoordinateAreas.length}, workingAreas=${workingAreas.length}',
    );

    final notWorkingMatch = _firstMatchingArea(
      activeCoordinateAreas.where((area) => area.status == 'not_working'),
      latitude,
      longitude,
    );
    if (notWorkingMatch != null) {
      return ServiceAreaGateResult.blocked(
        reason: ServiceAreaBlockReason.notWorkingArea,
        locationLabel: safeLabel,
        matchedArea: notWorkingMatch,
        message: notWorkingMatch.message.isNotEmpty
            ? notWorkingMatch.message
            : 'Service is not available in this area yet.',
        latitude: latitude,
        longitude: longitude,
      );
    }

    if (workingAreas.isEmpty) {
      return ServiceAreaGateResult.blocked(
        reason: ServiceAreaBlockReason.outsideWorkingArea,
        locationLabel: safeLabel,
        message: _serviceAreasUnavailableMessage,
        latitude: latitude,
        longitude: longitude,
      );
    }

    final workingMatch = _firstMatchingArea(workingAreas, latitude, longitude);
    if (workingMatch != null) {
      return ServiceAreaGateResult.allowed(
        locationLabel: safeLabel,
        matchedArea: workingMatch,
        latitude: latitude,
        longitude: longitude,
      );
    }

    return ServiceAreaGateResult.blocked(
      reason: ServiceAreaBlockReason.outsideWorkingArea,
      locationLabel: safeLabel,
      message: _genericBlockedMessage,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<List<ServiceAreaRule>> _fetchServiceAreas() async {
    final loader = _serviceAreaRulesLoader;
    if (loader != null) return loader();

    final headers = await _firebaseAuthHeaders();
    if (headers == null) {
      throw StateError('Firebase authentication is temporarily unavailable');
    }

    final options = DefaultFirebaseOptions.currentPlatform;
    final endpoint =
        'https://firestore.googleapis.com/v1/projects/${options.projectId}/databases/(default)/documents/$_collectionName?key=${options.apiKey}';
    final response = await _apiService!.get(
      endpoint: endpoint,
      authenticated: false,
      headers: headers,
    );
    if (response.isEmpty) return const [];
    if (!response.containsKey('documents')) {
      throw const FormatException('Incomplete Firestore service-area response');
    }
    final documents = response['documents'];
    if (documents is! List) {
      throw const FormatException('Invalid Firestore service-area documents');
    }

    final areas = <ServiceAreaRule>[];
    for (final document in documents) {
      if (document is! Map) {
        throw const FormatException('Invalid Firestore service-area document');
      }
      final data = Map<String, dynamic>.from(document);
      if (data['fields'] is! Map) {
        throw const FormatException('Missing Firestore service-area fields');
      }
      final name = data['name']?.toString() ?? '';
      final id = name.split('/').isEmpty ? '' : name.split('/').last;
      final area = ServiceAreaRule.fromFirestore(
        id: id,
        fields: _decodeFirestoreFields(data['fields']),
      );
      if (area.id.isEmpty) {
        throw const FormatException('Missing Firestore service-area id');
      }
      areas.add(area);
    }
    return areas..sort((left, right) {
      if (left.sortOrder != right.sortOrder) {
        return left.sortOrder.compareTo(right.sortOrder);
      }
      return '${left.city} ${left.name}'.compareTo(
        '${right.city} ${right.name}',
      );
    });
  }

  Future<Map<String, String>?> _firebaseAuthHeaders() async {
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint(
          'ServiceAreaGateService._firebaseAuthHeaders: Firebase not initialized, retrying initialization',
        );
        await FirebaseBootstrap.initialize();
        if (Firebase.apps.isEmpty) {
          debugPrint(
            'ServiceAreaGateService._firebaseAuthHeaders: Firebase still not initialized. lastError=${FirebaseBootstrap.lastError}',
          );
          return null;
        }
      }
      final auth = _firebaseAuth ?? FirebaseAuth.instance;
      var user = auth.currentUser;
      user ??= (await auth.signInAnonymously()).user;
      final token = await user?.getIdToken();
      if (token == null || token.trim().isEmpty) {
        debugPrint(
          'ServiceAreaGateService._firebaseAuthHeaders: missing Firebase auth token',
        );
        return null;
      }
      return {'Authorization': 'Bearer $token'};
    } catch (error) {
      debugPrint('ServiceAreaGateService._firebaseAuthHeaders failed: $error');
      return null;
    }
  }

  Future<_PositionResult> _resolvePosition() async {
    try {
      final serviceEnabled = await _locationProvider.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const _PositionResult(
          label: 'Location services are off',
          position: null,
          state: ServiceAreaGateState.locationServicesDisabled,
        );
      }

      var permission = await _locationProvider.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _locationProvider.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const _PositionResult(
          label: 'Location permission required',
          position: null,
          state: ServiceAreaGateState.locationPermissionRequired,
        );
      }
      if (permission == LocationPermission.unableToDetermine) {
        return const _PositionResult(
          label: 'Location permission unavailable',
          position: null,
          state: ServiceAreaGateState.temporarilyUnavailable,
        );
      }

      Position? lastKnown;
      try {
        lastKnown = await _locationProvider.getLastKnownPosition().timeout(
          _lastKnownLocationTimeout,
        );
      } catch (error) {
        debugPrint(
          'ServiceAreaGateService._resolvePosition: '
          'last-known lookup unavailable: $error',
        );
      }
      if (lastKnown != null &&
          _isReliablePosition(
            lastKnown,
            maxAge: lastKnownLocationMaxAge,
            maxAccuracyMeters: lastKnownLocationMaxAccuracyMeters,
          )) {
        debugPrint(
          'ServiceAreaGateService._resolvePosition: using reliable last known '
          '${_safePositionSummary(lastKnown)}',
        );
        return _PositionResult(
          label: _coordinateLabel(lastKnown.latitude, lastKnown.longitude),
          position: lastKnown,
          state: ServiceAreaGateState.checking,
        );
      }
      if (lastKnown != null) {
        debugPrint(
          'ServiceAreaGateService._resolvePosition: rejected last known '
          '${_safePositionSummary(lastKnown)}',
        );
      }

      try {
        final position = await _locationProvider.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        if (_isReliablePosition(
          position,
          maxAge: currentLocationMaxAge,
          maxAccuracyMeters: currentLocationMaxAccuracyMeters,
        )) {
          debugPrint(
            'ServiceAreaGateService._resolvePosition: reliable live location '
            '${_safePositionSummary(position)}',
          );
          return _PositionResult(
            label: _coordinateLabel(position.latitude, position.longitude),
            position: position,
            state: ServiceAreaGateState.checking,
          );
        }
        debugPrint(
          'ServiceAreaGateService._resolvePosition: rejected live location '
          '${_safePositionSummary(position)}',
        );
      } catch (error) {
        debugPrint(
          'ServiceAreaGateService._resolvePosition: '
          'high accuracy unavailable: $error',
        );
      }

      try {
        final position = await _locationProvider.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (_isReliablePosition(
          position,
          maxAge: currentLocationMaxAge,
          maxAccuracyMeters: currentLocationMaxAccuracyMeters,
        )) {
          debugPrint(
            'ServiceAreaGateService._resolvePosition: reliable medium location '
            '${_safePositionSummary(position)}',
          );
          return _PositionResult(
            label: _coordinateLabel(position.latitude, position.longitude),
            position: position,
            state: ServiceAreaGateState.checking,
          );
        }
        debugPrint(
          'ServiceAreaGateService._resolvePosition: rejected medium location '
          '${_safePositionSummary(position)}',
        );
      } catch (error) {
        debugPrint(
          'ServiceAreaGateService._resolvePosition: '
          'medium accuracy unavailable: $error',
        );
      }

      return const _PositionResult(
        label: 'Unable to read live location',
        position: null,
        state: ServiceAreaGateState.temporarilyUnavailable,
      );
    } catch (error) {
      debugPrint('ServiceAreaGateService._resolvePosition failed: $error');
      return const _PositionResult(
        label: 'Unable to read live location',
        position: null,
        state: ServiceAreaGateState.temporarilyUnavailable,
      );
    }
  }

  ServiceAreaGateResult _resultForUnavailablePosition(
    _PositionResult positionResult,
  ) {
    return switch (positionResult.state) {
      ServiceAreaGateState.locationPermissionRequired =>
        ServiceAreaGateResult.locationPermissionRequired(
          locationLabel: positionResult.label,
        ),
      ServiceAreaGateState.locationServicesDisabled =>
        ServiceAreaGateResult.locationServicesDisabled(
          locationLabel: positionResult.label,
        ),
      _ => ServiceAreaGateResult.temporarilyUnavailable(
        locationLabel: positionResult.label,
        message: 'Unable to verify your current service area right now.',
      ),
    };
  }

  bool _isReliablePosition(
    Position position, {
    required Duration maxAge,
    required double maxAccuracyMeters,
  }) {
    if (!_isValidCoordinate(position.latitude, position.longitude) ||
        !position.accuracy.isFinite ||
        position.accuracy <= 0 ||
        position.accuracy > maxAccuracyMeters) {
      return false;
    }
    final age = _clock().difference(position.timestamp);
    if (age > maxAge) return false;
    return !age.isNegative || age.abs() <= const Duration(minutes: 1);
  }

  Future<String> _locationLabel(double latitude, double longitude) async {
    try {
      final address = await _locationLookupService.reverseGeocodeToAddress(
        latitude: latitude,
        longitude: longitude,
      );
      if (address != null && address.trim().isNotEmpty) {
        return address.trim();
      }
    } catch (error) {
      debugPrint('ServiceAreaGateService._locationLabel failed: $error');
    }
    return _coordinateLabel(latitude, longitude);
  }

  ServiceAreaRule? _firstMatchingArea(
    Iterable<ServiceAreaRule> areas,
    double latitude,
    double longitude,
  ) {
    for (final area in areas) {
      final distanceKm = _distanceKm(
        latitude,
        longitude,
        area.latitude!,
        area.longitude!,
      );
      debugPrint(
        'ServiceAreaGateService._firstMatchingArea: ${area.id} distance=${distanceKm.toStringAsFixed(2)}km radius=${area.radiusKm}km status=${area.status}',
      );
      if (distanceKm <= area.radiusKm!) {
        return area;
      }
    }
    return null;
  }

  double _distanceKm(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(endLatitude - startLatitude);
    final dLng = _toRadians(endLongitude - startLongitude);
    final lat1 = _toRadians(startLatitude);
    final lat2 = _toRadians(endLatitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double value) => value * math.pi / 180;

  static String _coordinateLabel(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  String _safePositionSummary(Position position) {
    final ageSeconds = _clock().difference(position.timestamp).inSeconds;
    return 'ageSeconds=$ageSeconds '
        'accuracyMeters=${position.accuracy.toStringAsFixed(1)} '
        'coordinate≈${position.latitude.toStringAsFixed(2)},'
        '${position.longitude.toStringAsFixed(2)}';
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  static String _debugAreaSummary(ServiceAreaRule area) {
    final latitude = area.latitude?.toStringAsFixed(2) ?? 'missing';
    final longitude = area.longitude?.toStringAsFixed(2) ?? 'missing';
    return '${area.id}{status:${area.status}, active:${area.isActive}, '
        'coordinate≈$latitude,$longitude, radiusKm:${area.radiusKm}}';
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
      if (values is! List) return const [];
      return values.map(_decodeFirestoreValue).toList();
    }
    return null;
  }
}

class ServiceAreaRule {
  const ServiceAreaRule({
    required this.id,
    required this.name,
    required this.city,
    required this.province,
    required this.status,
    required this.message,
    required this.isActive,
    required this.sortOrder,
    this.latitude,
    this.longitude,
    this.radiusKm,
  });

  final String id;
  final String name;
  final String city;
  final String province;
  final String status;
  final String message;
  final bool isActive;
  final int sortOrder;
  final double? latitude;
  final double? longitude;
  final double? radiusKm;

  bool get hasCoordinateRule =>
      latitude != null &&
      longitude != null &&
      radiusKm != null &&
      radiusKm! > 0;

  factory ServiceAreaRule.fromFirestore({
    required String id,
    required Map<String, dynamic> fields,
  }) {
    final areaType = fields['areaType']?.toString().trim().toLowerCase() ?? '';
    final rawStatus = fields['status']?.toString().trim().toLowerCase() ?? '';
    final status =
        areaType == 'not_working_area' ||
            areaType == 'non_working_area' ||
            areaType == 'blocked_area' ||
            rawStatus == 'not_working'
        ? 'not_working'
        : 'working';
    final activeValue = fields.containsKey('appEnabled')
        ? fields['appEnabled']
        : fields['isActive'];
    return ServiceAreaRule(
      id: fields['id']?.toString().trim().isNotEmpty == true
          ? fields['id'].toString().trim()
          : id,
      name: fields['name']?.toString() ?? '',
      city: fields['city']?.toString() ?? '',
      province:
          fields['province']?.toString() ?? fields['state']?.toString() ?? '',
      status: status,
      message:
          fields['message']?.toString() ??
          (status == 'not_working'
              ? 'Service is not available in this area yet.'
              : 'Service is available in this area.'),
      isActive: activeValue != false,
      sortOrder: _toInt(fields['sortOrder']),
      latitude: _toDouble(fields['latitude']),
      longitude: _toDouble(fields['longitude']),
      radiusKm: _toDouble(fields['radiusKm']),
    );
  }

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int _toInt(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

class ServiceAreaGateResult {
  const ServiceAreaGateResult({
    required this.state,
    required this.reason,
    this.locationLabel = '',
    this.message = '',
    this.matchedArea,
    this.latitude,
    this.longitude,
  });

  final ServiceAreaGateState state;
  final ServiceAreaBlockReason reason;
  final String locationLabel;
  final String message;
  final ServiceAreaRule? matchedArea;
  final double? latitude;
  final double? longitude;

  bool get isAllowed => state == ServiceAreaGateState.insideServiceArea;

  bool get isConfirmedOutside =>
      state == ServiceAreaGateState.outsideServiceArea;

  factory ServiceAreaGateResult.allowed({
    String locationLabel = '',
    ServiceAreaRule? matchedArea,
    double? latitude,
    double? longitude,
  }) {
    return ServiceAreaGateResult(
      state: ServiceAreaGateState.insideServiceArea,
      reason: ServiceAreaBlockReason.none,
      locationLabel: locationLabel,
      matchedArea: matchedArea,
      latitude: latitude,
      longitude: longitude,
    );
  }

  factory ServiceAreaGateResult.blocked({
    required ServiceAreaBlockReason reason,
    required String locationLabel,
    required String message,
    ServiceAreaRule? matchedArea,
    double? latitude,
    double? longitude,
  }) {
    return ServiceAreaGateResult(
      state:
          reason == ServiceAreaBlockReason.outsideWorkingArea ||
              reason == ServiceAreaBlockReason.notWorkingArea
          ? ServiceAreaGateState.outsideServiceArea
          : ServiceAreaGateState.temporarilyUnavailable,
      reason: reason,
      locationLabel: locationLabel,
      message: message,
      matchedArea: matchedArea,
      latitude: latitude,
      longitude: longitude,
    );
  }

  factory ServiceAreaGateResult.temporarilyUnavailable({
    String locationLabel = '',
    String message = '',
    double? latitude,
    double? longitude,
  }) {
    return ServiceAreaGateResult(
      state: ServiceAreaGateState.temporarilyUnavailable,
      reason: ServiceAreaBlockReason.serviceUnavailable,
      locationLabel: locationLabel,
      message: message,
      latitude: latitude,
      longitude: longitude,
    );
  }

  factory ServiceAreaGateResult.locationPermissionRequired({
    String locationLabel = 'Location permission required',
  }) {
    return ServiceAreaGateResult(
      state: ServiceAreaGateState.locationPermissionRequired,
      reason: ServiceAreaBlockReason.locationPermissionRequired,
      locationLabel: locationLabel,
      message:
          'Please allow location access so we can check service availability in your area.',
    );
  }

  factory ServiceAreaGateResult.locationServicesDisabled({
    String locationLabel = 'Location services are off',
  }) {
    return ServiceAreaGateResult(
      state: ServiceAreaGateState.locationServicesDisabled,
      reason: ServiceAreaBlockReason.locationServicesDisabled,
      locationLabel: locationLabel,
      message:
          'Please turn on location services so we can check service availability in your area.',
    );
  }
}

enum ServiceAreaGateState {
  checking,
  insideServiceArea,
  outsideServiceArea,
  temporarilyUnavailable,
  locationPermissionRequired,
  locationServicesDisabled,
}

enum ServiceAreaBlockReason {
  none,
  locationUnavailable,
  locationPermissionRequired,
  locationServicesDisabled,
  serviceUnavailable,
  notWorkingArea,
  outsideWorkingArea,
}

class _PositionResult {
  const _PositionResult({
    required this.label,
    required this.position,
    required this.state,
  });

  final String label;
  final Position? position;
  final ServiceAreaGateState state;
}
