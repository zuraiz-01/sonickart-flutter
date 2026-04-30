import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.description,
    required this.placeId,
    this.primaryText = '',
    this.secondaryText = '',
  });

  final String description;
  final String placeId;
  final String primaryText;
  final String secondaryText;

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final formatting = json['structured_formatting'] is Map
        ? Map<String, dynamic>.from(json['structured_formatting'] as Map)
        : const <String, dynamic>{};
    return PlaceSuggestion(
      description: json['description']?.toString() ?? '',
      placeId: json['place_id']?.toString() ?? '',
      primaryText: formatting['main_text']?.toString() ?? '',
      secondaryText: formatting['secondary_text']?.toString() ?? '',
    );
  }
}

class PlaceDetailsResult {
  const PlaceDetailsResult({
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.placeId,
  });

  final String address;
  final double? latitude;
  final double? longitude;
  final String placeId;
}

class DistanceMatrixResult {
  const DistanceMatrixResult({
    required this.distanceMeters,
    required this.distanceText,
    required this.durationSeconds,
    required this.durationText,
  });

  final int distanceMeters;
  final String distanceText;
  final int durationSeconds;
  final String durationText;
}

class LocationLookupService {
  static const String _googleMapsApiKey =
      'AIzaSyB5dcpM7PWKnErsIQjyzEG9CUxup0Ysuxs';
  static const String _geocodeBaseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';
  static const String _placeAutocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const String _placeDetailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';
  static const String _distanceMatrixUrl =
      'https://maps.googleapis.com/maps/api/distancematrix/json';

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12);

  bool get isConfigured => _googleMapsApiKey.trim().isNotEmpty;

  Future<String?> reverseGeocodeToAddress({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _getJson(
      _geocodeBaseUrl,
      query: {'latlng': '$latitude,$longitude', 'key': _googleMapsApiKey},
    );

    if (response?['status'] == 'OK' && response?['results'] is List) {
      final results = response!['results'] as List;
      if (results.isNotEmpty) {
        return (results.first as Map)['formatted_address']?.toString();
      }
    }

    debugPrint(
      'LocationLookupService.reverseGeocodeToAddress failed: ${response?['status']} ${response?['error_message']}',
    );
    return null;
  }

  Future<PlaceDetailsResult?> geocodeAddress(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;

    final response = await _getJson(
      _geocodeBaseUrl,
      query: {'address': trimmed, 'key': _googleMapsApiKey},
    );

    if (response?['status'] == 'OK' && response?['results'] is List) {
      final results = response!['results'] as List;
      if (results.isNotEmpty) {
        final first = Map<String, dynamic>.from(results.first as Map);
        final geometry = first['geometry'] is Map
            ? Map<String, dynamic>.from(first['geometry'] as Map)
            : const <String, dynamic>{};
        final location = geometry['location'] is Map
            ? Map<String, dynamic>.from(geometry['location'] as Map)
            : const <String, dynamic>{};

        return PlaceDetailsResult(
          address: first['formatted_address']?.toString() ?? trimmed,
          latitude: _toDouble(location['lat']),
          longitude: _toDouble(location['lng']),
          placeId: first['place_id']?.toString() ?? '',
        );
      }
    }

    return null;
  }

  Future<List<PlaceSuggestion>> getPlaceSuggestions(
    String query, {
    double? latitude,
    double? longitude,
    int? radiusMeters,
    bool strictBounds = false,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final queryParams = {
      'input': trimmed,
      'key': _googleMapsApiKey,
      'language': 'en',
      'components': 'country:IN',
    };
    if (latitude != null && longitude != null) {
      queryParams['location'] = '$latitude,$longitude';
      queryParams['radius'] = '${radiusMeters ?? 50000}';
      if (strictBounds) queryParams['strictbounds'] = 'true';
    }

    final response = await _getJson(_placeAutocompleteUrl, query: queryParams);

    if (response?['status'] == 'OK' && response?['predictions'] is List) {
      final predictions = response!['predictions'] as List;
      return predictions
          .map(
            (item) => PlaceSuggestion.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where(
            (item) => item.description.isNotEmpty && item.placeId.isNotEmpty,
          )
          .toList();
    }

    return const [];
  }

  Future<PlaceDetailsResult?> getPlaceDetails(String placeId) async {
    if (placeId.trim().isEmpty) return null;

    final response = await _getJson(
      _placeDetailsUrl,
      query: {
        'place_id': placeId,
        'key': _googleMapsApiKey,
        'language': 'en',
        'fields': 'formatted_address,geometry,place_id',
      },
    );

    if (response?['status'] == 'OK' && response?['result'] is Map) {
      final result = Map<String, dynamic>.from(response!['result'] as Map);
      final geometry = result['geometry'] is Map
          ? Map<String, dynamic>.from(result['geometry'] as Map)
          : const <String, dynamic>{};
      final location = geometry['location'] is Map
          ? Map<String, dynamic>.from(geometry['location'] as Map)
          : const <String, dynamic>{};
      return PlaceDetailsResult(
        address: result['formatted_address']?.toString() ?? '',
        latitude: _toDouble(location['lat']),
        longitude: _toDouble(location['lng']),
        placeId: result['place_id']?.toString() ?? placeId,
      );
    }

    return null;
  }

  Future<DistanceMatrixResult?> getDistanceMatrix({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final response = await _getJson(
      _distanceMatrixUrl,
      query: {
        'origins': '$originLatitude,$originLongitude',
        'destinations': '$destinationLatitude,$destinationLongitude',
        'mode': 'driving',
        'units': 'metric',
        'key': _googleMapsApiKey,
      },
    );

    if (response?['status'] != 'OK' || response?['rows'] is! List) {
      debugPrint(
        'LocationLookupService.getDistanceMatrix failed: ${response?['status']} ${response?['error_message']}',
      );
      return null;
    }

    final rows = response!['rows'] as List;
    if (rows.isEmpty || rows.first is! Map) return null;
    final elements = (rows.first as Map)['elements'];
    if (elements is! List || elements.isEmpty || elements.first is! Map) {
      return null;
    }
    final element = Map<String, dynamic>.from(elements.first as Map);
    if (element['status'] != 'OK') return null;
    final distance = element['distance'] is Map
        ? Map<String, dynamic>.from(element['distance'] as Map)
        : const <String, dynamic>{};
    final duration = element['duration'] is Map
        ? Map<String, dynamic>.from(element['duration'] as Map)
        : const <String, dynamic>{};
    final distanceMeters = _toDouble(distance['value'])?.round();
    final durationSeconds = _toDouble(duration['value'])?.round();
    if (distanceMeters == null || durationSeconds == null) return null;

    return DistanceMatrixResult(
      distanceMeters: distanceMeters,
      distanceText: distance['text']?.toString() ?? '',
      durationSeconds: durationSeconds,
      durationText: duration['text']?.toString() ?? '',
    );
  }

  Future<Map<String, dynamic>?> _getJson(
    String url, {
    required Map<String, String> query,
  }) async {
    if (!isConfigured) {
      debugPrint('LocationLookupService not configured with Google Maps key.');
      return null;
    }

    final uri = Uri.parse(url).replace(queryParameters: query);
    try {
      final request = await _client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await response.transform(utf8.decoder).join();
      if (body.trim().isEmpty) return null;
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (error) {
      debugPrint('LocationLookupService request failed for $uri: $error');
    }
    return null;
  }

  double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
