import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../../modules/profile/controllers/profile_controller.dart';
import 'location_lookup_service.dart';
import 'service_area_gate_service.dart';

class ServiceAreaGateController extends GetxController {
  ServiceAreaGateController({
    required ServiceAreaGateService serviceAreaGateService,
    LocationLookupService? locationLookupService,
  }) : _serviceAreaGateService = serviceAreaGateService,
       _locationLookupService =
           locationLookupService ?? LocationLookupService();

  final ServiceAreaGateService _serviceAreaGateService;
  final LocationLookupService _locationLookupService;

  final blockedResult = Rxn<ServiceAreaGateResult>();
  final isChecking = false.obs;
  final isResolvingLocation = false.obs;
  final isSearching = false.obs;
  final placeSuggestions = <PlaceSuggestion>[].obs;
  final statusMessage = RxnString();
  final addressController = TextEditingController();

  Timer? _suggestionDebounce;
  bool _checkedForSession = false;
  Future<void>? _activeCheck;

  bool get isBlocked => blockedResult.value != null;

  @override
  void onInit() {
    super.onInit();
    unawaited(ensureChecked());
  }

  Future<void> ensureChecked({bool force = false}) async {
    if (_checkedForSession && !force) return;
    _checkedForSession = true;
    await checkCurrentLocation();
  }

  Future<void> checkCurrentLocation() async {
    if (_activeCheck != null) return _activeCheck;
    final check = _runCurrentLocationCheck();
    _activeCheck = check;
    try {
      await check;
    } finally {
      if (identical(_activeCheck, check)) {
        _activeCheck = null;
      }
    }
  }

  Future<void> _runCurrentLocationCheck() async {
    isChecking.value = true;
    statusMessage.value = null;
    try {
      final result = await _serviceAreaGateService.evaluate();
      await _applyResult(result);
    } catch (error) {
      debugPrint(
        'ServiceAreaGateController.checkCurrentLocation failed: $error',
      );
      statusMessage.value = 'Service area check failed. Please try again.';
    } finally {
      isChecking.value = false;
    }
  }

  void onAddressChanged(String value) {
    statusMessage.value = null;
    _suggestionDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      placeSuggestions.clear();
      isSearching.value = false;
      return;
    }
    _suggestionDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_fetchSuggestions(trimmed));
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (!_locationLookupService.isConfigured) return;
    isSearching.value = true;
    try {
      final bias = await _currentCoordinate();
      final suggestions = await _locationLookupService.getPlaceSuggestions(
        query,
        latitude: bias?.latitude,
        longitude: bias?.longitude,
        radiusMeters: 50000,
      );
      if (addressController.text.trim() == query) {
        placeSuggestions.assignAll(suggestions);
      }
    } finally {
      isSearching.value = false;
    }
  }

  Future<void> selectSuggestion(PlaceSuggestion suggestion) async {
    if (isResolvingLocation.value) return;
    isResolvingLocation.value = true;
    statusMessage.value = null;
    try {
      final details = await _locationLookupService.getPlaceDetails(
        suggestion.placeId,
      );
      if (details == null ||
          details.latitude == null ||
          details.longitude == null) {
        statusMessage.value = 'Could not resolve selected location.';
        return;
      }
      addressController.text = details.address;
      placeSuggestions.clear();
      await evaluateManualLocation(
        address: details.address,
        latitude: details.latitude!,
        longitude: details.longitude!,
        placeId: details.placeId,
      );
    } finally {
      isResolvingLocation.value = false;
    }
  }

  Future<void> submitTypedAddress() async {
    final address = addressController.text.trim();
    if (address.length < 4) {
      statusMessage.value = 'Enter a valid address.';
      return;
    }
    isResolvingLocation.value = true;
    statusMessage.value = null;
    try {
      final details = await _locationLookupService.geocodeAddress(address);
      if (details == null ||
          details.latitude == null ||
          details.longitude == null) {
        statusMessage.value = 'Could not find this location.';
        return;
      }
      addressController.text = details.address;
      await evaluateManualLocation(
        address: details.address,
        latitude: details.latitude!,
        longitude: details.longitude!,
        placeId: details.placeId,
      );
    } finally {
      isResolvingLocation.value = false;
    }
  }

  Future<void> evaluateManualLocation({
    required String address,
    required double latitude,
    required double longitude,
    String placeId = '',
  }) async {
    if (!_isValidCoordinate(latitude, longitude)) {
      statusMessage.value = 'Please select a valid delivery location.';
      return;
    }
    final result = await _serviceAreaGateService.evaluateManualLocation(
      latitude: latitude,
      longitude: longitude,
      locationLabel: address,
    );
    if (result.isAllowed) {
      await _applyAllowedLocation(
        address: address,
        latitude: latitude,
        longitude: longitude,
        placeId: placeId,
      );
      blockedResult.value = null;
      statusMessage.value = null;
      return;
    }
    await _applyResult(result);
    statusMessage.value = result.message.isNotEmpty
        ? result.message
        : 'Service is not available at this selected location.';
  }

  Future<void> _applyResult(ServiceAreaGateResult result) async {
    if (result.isAllowed) {
      blockedResult.value = null;
      final latitude = result.latitude;
      final longitude = result.longitude;
      if (latitude != null && longitude != null) {
        await _applyAllowedLocation(
          address: result.locationLabel,
          latitude: latitude,
          longitude: longitude,
        );
      }
      return;
    }
    final latitude = result.latitude;
    final longitude = result.longitude;
    if (latitude != null && longitude != null) {
      await _applyBlockedLocation(
        address: result.locationLabel,
        latitude: latitude,
        longitude: longitude,
      );
    }
    blockedResult.value = result;
  }

  Future<void> _applyAllowedLocation({
    required String address,
    required double latitude,
    required double longitude,
    String placeId = '',
  }) async {
    if (!Get.isRegistered<ProfileController>()) return;
    await Get.find<ProfileController>().applyServiceAreaLocation(
      address: address.trim().isNotEmpty
          ? address.trim()
          : '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
      latitude: latitude,
      longitude: longitude,
      placeId: placeId,
    );
  }

  Future<void> _applyBlockedLocation({
    required String address,
    required double latitude,
    required double longitude,
    String placeId = '',
  }) async {
    if (!Get.isRegistered<ProfileController>()) return;
    await Get.find<ProfileController>().applyBlockedServiceAreaLocation(
      address: address.trim().isNotEmpty
          ? address.trim()
          : '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
      latitude: latitude,
      longitude: longitude,
      placeId: placeId,
    );
  }

  Future<({double latitude, double longitude})?> _currentCoordinate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      return null;
    }
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  @override
  void onClose() {
    _suggestionDebounce?.cancel();
    addressController.dispose();
    super.onClose();
  }
}
