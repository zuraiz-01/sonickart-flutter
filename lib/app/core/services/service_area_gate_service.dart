import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../firebase_options.dart';
import '../network/api_service.dart';
import 'location_lookup_service.dart';

class ServiceAreaGateService {
  ServiceAreaGateService({
    required ApiService apiService,
    FirebaseAuth? firebaseAuth,
    LocationLookupService? locationLookupService,
  }) : _apiService = apiService,
       _firebaseAuth = firebaseAuth,
       _locationLookupService =
           locationLookupService ?? LocationLookupService();

  static const _collectionName = 'serviceAreas';

  final ApiService _apiService;
  final FirebaseAuth? _firebaseAuth;
  final LocationLookupService _locationLookupService;

  Future<ServiceAreaGateResult> evaluate() async {
    try {
      final areas = await _fetchServiceAreas();
      final activeCoordinateAreas = areas
          .where((area) => area.isActive && area.hasCoordinateRule)
          .toList();

      if (activeCoordinateAreas.isEmpty) {
        return ServiceAreaGateResult.allowed();
      }

      final positionResult = await _resolvePosition();
      if (positionResult.position == null) {
        return ServiceAreaGateResult.blocked(
          reason: ServiceAreaBlockReason.locationUnavailable,
          locationLabel: positionResult.label,
          message:
              'Please allow location access so we can check service availability in your area.',
        );
      }

      final position = positionResult.position!;
      final notWorkingMatch = _firstMatchingArea(
        activeCoordinateAreas.where((area) => area.status == 'not_working'),
        position,
      );
      if (notWorkingMatch != null) {
        return ServiceAreaGateResult.blocked(
          reason: ServiceAreaBlockReason.notWorkingArea,
          locationLabel: await _locationLabel(position),
          matchedArea: notWorkingMatch,
          message: notWorkingMatch.message.isNotEmpty
              ? notWorkingMatch.message
              : 'Service is not available in this area yet.',
        );
      }

      final workingAreas = activeCoordinateAreas
          .where((area) => area.status == 'working')
          .toList();
      if (workingAreas.isEmpty) {
        return ServiceAreaGateResult.allowed(
          locationLabel: positionResult.label,
        );
      }

      final workingMatch = _firstMatchingArea(workingAreas, position);
      if (workingMatch != null) {
        return ServiceAreaGateResult.allowed(
          locationLabel: await _locationLabel(position),
          matchedArea: workingMatch,
        );
      }

      return ServiceAreaGateResult.blocked(
        reason: ServiceAreaBlockReason.outsideWorkingArea,
        locationLabel: await _locationLabel(position),
        message:
            'We are currently live in select areas and expanding quickly to more neighbourhoods and cities.',
      );
    } catch (error) {
      debugPrint('ServiceAreaGateService.evaluate failed: $error');
      return ServiceAreaGateResult.allowed();
    }
  }

  Future<List<ServiceAreaRule>> _fetchServiceAreas() async {
    final headers = await _firebaseAuthHeaders();
    if (headers == null) return const [];

    final options = DefaultFirebaseOptions.currentPlatform;
    final endpoint =
        'https://firestore.googleapis.com/v1/projects/${options.projectId}/databases/(default)/documents/$_collectionName?key=${options.apiKey}';
    final response = await _apiService.get(
      endpoint: endpoint,
      authenticated: false,
      headers: headers,
    );
    final documents = response['documents'];
    if (documents is! List) return const [];

    return documents
        .whereType<Map>()
        .map((doc) {
          final data = Map<String, dynamic>.from(doc);
          final name = data['name']?.toString() ?? '';
          final id = name.split('/').isEmpty ? '' : name.split('/').last;
          return ServiceAreaRule.fromFirestore(
            id: id,
            fields: _decodeFirestoreFields(data['fields']),
          );
        })
        .where((area) => area.id.isNotEmpty)
        .toList()
      ..sort((left, right) {
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
      if (Firebase.apps.isEmpty) return null;
      final auth = _firebaseAuth ?? FirebaseAuth.instance;
      var user = auth.currentUser;
      user ??= (await auth.signInAnonymously()).user;
      final token = await user?.getIdToken();
      if (token == null || token.trim().isEmpty) return null;
      return {'Authorization': 'Bearer $token'};
    } catch (error) {
      debugPrint('ServiceAreaGateService._firebaseAuthHeaders failed: $error');
      return null;
    }
  }

  Future<_PositionResult> _resolvePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const _PositionResult(
          label: 'Location services are off',
          position: null,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const _PositionResult(
          label: 'Location permission required',
          position: null,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return _PositionResult(
        label: _coordinateLabel(position.latitude, position.longitude),
        position: position,
      );
    } catch (error) {
      debugPrint('ServiceAreaGateService._resolvePosition failed: $error');
      return const _PositionResult(
        label: 'Unable to read live location',
        position: null,
      );
    }
  }

  Future<String> _locationLabel(Position position) async {
    try {
      final address = await _locationLookupService.reverseGeocodeToAddress(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (address != null && address.trim().isNotEmpty) {
        return address.trim();
      }
    } catch (error) {
      debugPrint('ServiceAreaGateService._locationLabel failed: $error');
    }
    return _coordinateLabel(position.latitude, position.longitude);
  }

  ServiceAreaRule? _firstMatchingArea(
    Iterable<ServiceAreaRule> areas,
    Position position,
  ) {
    for (final area in areas) {
      final distanceKm = _distanceKm(
        position.latitude,
        position.longitude,
        area.latitude!,
        area.longitude!,
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
    final status = fields['status']?.toString() == 'not_working'
        ? 'not_working'
        : 'working';
    return ServiceAreaRule(
      id: id,
      name: fields['name']?.toString() ?? '',
      city: fields['city']?.toString() ?? '',
      province: fields['province']?.toString() ?? '',
      status: status,
      message:
          fields['message']?.toString() ??
          (status == 'not_working'
              ? 'Service is not available in this area yet.'
              : 'Service is available in this area.'),
      isActive: fields['isActive'] != false,
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
    required this.isAllowed,
    required this.reason,
    this.locationLabel = '',
    this.message = '',
    this.matchedArea,
  });

  final bool isAllowed;
  final ServiceAreaBlockReason reason;
  final String locationLabel;
  final String message;
  final ServiceAreaRule? matchedArea;

  factory ServiceAreaGateResult.allowed({
    String locationLabel = '',
    ServiceAreaRule? matchedArea,
  }) {
    return ServiceAreaGateResult(
      isAllowed: true,
      reason: ServiceAreaBlockReason.none,
      locationLabel: locationLabel,
      matchedArea: matchedArea,
    );
  }

  factory ServiceAreaGateResult.blocked({
    required ServiceAreaBlockReason reason,
    required String locationLabel,
    required String message,
    ServiceAreaRule? matchedArea,
  }) {
    return ServiceAreaGateResult(
      isAllowed: false,
      reason: reason,
      locationLabel: locationLabel,
      message: message,
      matchedArea: matchedArea,
    );
  }
}

enum ServiceAreaBlockReason {
  none,
  locationUnavailable,
  notWorkingArea,
  outsideWorkingArea,
}

class _PositionResult {
  const _PositionResult({required this.label, required this.position});

  final String label;
  final Position? position;
}
