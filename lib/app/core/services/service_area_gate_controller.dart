import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../data/models/address_model.dart';
import '../../modules/profile/controllers/profile_controller.dart';
import 'app_session_scope.dart';
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
  final confirmedResult = Rxn<ServiceAreaGateResult>();
  final evaluationState = ServiceAreaGateState.checking.obs;
  final isChecking = false.obs;
  final isResolvingLocation = false.obs;
  final isSearching = false.obs;
  final placeSuggestions = <PlaceSuggestion>[].obs;
  final statusMessage = RxnString();
  final addressController = TextEditingController();

  Timer? _suggestionDebounce;
  bool _checkedForSession = false;
  Future<void>? _activeCheck;
  int _locationRequestVersion = 0;
  final GetStorage _storage = GetStorage();

  static const _selectedAddressStorageKey = 'selectedAddress';
  static const _selectedVendorIdStorageKey = 'selectedVendorId';
  static const _selectedLocationServiceableStorageKey =
      'selectedLocationServiceable';
  static const _selectedServiceLocationSessionStorageKey =
      AppSessionScope.selectedServiceLocationSessionKey;

  bool get isBlocked => blockedResult.value?.isConfirmedOutside == true;

  bool get shouldRefreshLiveLocationOnAppOpen {
    final selectedAddress = _storedSelectedAddress;
    if (selectedAddress == null) return true;
    return _isTransientCatalogAddress(selectedAddress);
  }

  bool preserveSelectedServiceableLocation() {
    final selectedAddress = _serviceableSelectedAddress;
    if (selectedAddress == null) return false;

    _beginManualLocationRequest();
    _checkedForSession = true;
    blockedResult.value = null;
    final preservedResult = ServiceAreaGateResult.allowed(
      locationLabel: selectedAddress.address,
      latitude: selectedAddress.latitude,
      longitude: selectedAddress.longitude,
    );

    print(
      'ServiceAreaGateController: preserved serviceable location: ${selectedAddress.latitude}, ${selectedAddress.longitude}',
    );

    confirmedResult.value = preservedResult;
    evaluationState.value = preservedResult.state;
    statusMessage.value = null;
    addressController.text = selectedAddress.address;
    return true;
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(ensureChecked());
  }

  Future<void> ensureChecked({bool force = false}) async {
    if (_checkedForSession && !force) {
      final activeCheck = _activeCheck;
      if (activeCheck != null) await activeCheck;
      return;
    }
    _checkedForSession = true;
    await checkCurrentLocation(force: force);
  }

  Future<void> checkCurrentLocation({bool force = false}) async {
    final activeCheck = _activeCheck;
    if (activeCheck != null) return activeCheck;
    if (force) {
      _checkedForSession = true;
    }
    final requestVersion = _nextLocationRequestVersion();
    final check = _runCurrentLocationCheck(requestVersion);
    _activeCheck = check;

    try {
      await check;
    } finally {
      if (identical(_activeCheck, check)) {
        _activeCheck = null;
      }
    }
  }

  Future<void> _runCurrentLocationCheck(int requestVersion) async {
    isChecking.value = true;
    evaluationState.value = ServiceAreaGateState.checking;
    statusMessage.value = null;
    print(
      'ServiceAreaGateController: request=$requestVersion '
      'state=checking previous=${confirmedResult.value?.state.name ?? 'none'} '
      'overlay=$isBlocked',
    );

    try {
      final result = await _serviceAreaGateService.evaluate();
      if (!_isLatestLocationRequest(requestVersion)) return;
      await _applyResult(result, requestVersion: requestVersion);
    } catch (error, stackTrace) {
      if (!_isLatestLocationRequest(requestVersion)) return;
      debugPrint(
        'ServiceAreaGateController.checkCurrentLocation failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      await _applyResult(
        ServiceAreaGateResult.temporarilyUnavailable(
          message: 'Service area check failed. Please try again.',
        ),
        requestVersion: requestVersion,
      );
    } finally {
      if (_isLatestLocationRequest(requestVersion)) {
        isChecking.value = false;
      }
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
      final suggestions = await _locationLookupService.getPlaceSuggestions(
        query,
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
    final requestVersion = _beginManualLocationRequest();
    isResolvingLocation.value = true;
    statusMessage.value = null;
    try {
      final details = await _locationLookupService.getPlaceDetails(
        suggestion.placeId,
      );
      if (details == null ||
          details.latitude == null ||
          details.longitude == null) {
        if (!_isLatestLocationRequest(requestVersion)) return;
        statusMessage.value = 'Could not resolve selected location.';
        return;
      }
      if (!_isLatestLocationRequest(requestVersion)) return;
      addressController.text = details.address;
      placeSuggestions.clear();
      await evaluateManualLocation(
        address: details.address,
        latitude: details.latitude!,
        longitude: details.longitude!,
        placeId: details.placeId,
        requestVersion: requestVersion,
      );
    } finally {
      if (_isLatestLocationRequest(requestVersion)) {
        isResolvingLocation.value = false;
      }
    }
  }

  Future<void> submitTypedAddress() async {
    if (isResolvingLocation.value) return;
    final requestVersion = _beginManualLocationRequest();
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
        if (!_isLatestLocationRequest(requestVersion)) return;
        statusMessage.value = 'Could not find this location.';
        return;
      }
      if (!_isLatestLocationRequest(requestVersion)) return;
      addressController.text = details.address;
      await evaluateManualLocation(
        address: details.address,
        latitude: details.latitude!,
        longitude: details.longitude!,
        placeId: details.placeId,
        requestVersion: requestVersion,
      );
    } finally {
      if (_isLatestLocationRequest(requestVersion)) {
        isResolvingLocation.value = false;
      }
    }
  }

  Future<void> evaluateManualLocation({
    required String address,
    required double latitude,
    required double longitude,
    String placeId = '',
    int? requestVersion,
  }) async {
    final version = requestVersion ?? _beginManualLocationRequest();
    evaluationState.value = ServiceAreaGateState.checking;
    if (!_isValidCoordinate(latitude, longitude)) {
      evaluationState.value = ServiceAreaGateState.temporarilyUnavailable;
      statusMessage.value = 'Please select a valid delivery location.';
      return;
    }
    final result = await _serviceAreaGateService.evaluateManualLocation(
      latitude: latitude,
      longitude: longitude,
      locationLabel: address,
    );
    if (!_isLatestLocationRequest(version)) return;
    if (result.isAllowed) {
      await _applyAllowedLocation(
        address: address,
        latitude: latitude,
        longitude: longitude,
        placeId: placeId,
        refreshCatalog: true,
      );
      if (!_isLatestLocationRequest(version)) return;
      blockedResult.value = null;
      confirmedResult.value = result;
      evaluationState.value = result.state;
      statusMessage.value = null;
      return;
    }
    await _applyResult(result, requestVersion: version);
    if (!_isLatestLocationRequest(version)) return;
    statusMessage.value = result.message.isNotEmpty
        ? result.message
        : 'Service is not available at this selected location.';
  }

  Future<void> _applyResult(
    ServiceAreaGateResult result, {
    int? requestVersion,
  }) async {
    if (requestVersion != null && !_isLatestLocationRequest(requestVersion)) {
      return;
    }
    evaluationState.value = result.state;
    if (result.isAllowed) {
      final latitude = result.latitude;
      final longitude = result.longitude;
      if (latitude != null && longitude != null) {
        await _applyAllowedLocation(
          address: result.locationLabel,
          latitude: latitude,
          longitude: longitude,
          refreshCatalog: false,
        );
      }
      if (requestVersion != null && !_isLatestLocationRequest(requestVersion)) {
        return;
      }
      confirmedResult.value = result;
      blockedResult.value = null;
      statusMessage.value = null;
      _logAppliedResult(result, requestVersion: requestVersion);
      return;
    }
    if (!result.isConfirmedOutside) {
      statusMessage.value = result.message.isEmpty ? null : result.message;
      _logAppliedResult(result, requestVersion: requestVersion);
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
      print(
        'ServiceAreaGateController: applied blocked location: ${result.locationLabel} ($latitude, $longitude)',
      );
    } else {
      await _persistGuestBlockedCatalogState();
    }
    if (requestVersion != null && !_isLatestLocationRequest(requestVersion)) {
      return;
    }
    confirmedResult.value = result;
    blockedResult.value = result;
    statusMessage.value = null;
    _logAppliedResult(result, requestVersion: requestVersion);
  }

  void _logAppliedResult(ServiceAreaGateResult result, {int? requestVersion}) {
    debugPrint(
      'ServiceAreaGateController: request=${requestVersion ?? 'manual'} '
      'result=${result.state.name} '
      'confirmed=${confirmedResult.value?.state.name ?? 'none'} '
      'overlay=$isBlocked',
    );
  }

  int _nextLocationRequestVersion() => ++_locationRequestVersion;

  int _beginManualLocationRequest() {
    final requestVersion = _nextLocationRequestVersion();
    isChecking.value = false;
    return requestVersion;
  }

  bool _isLatestLocationRequest(int requestVersion) {
    return requestVersion == _locationRequestVersion;
  }

  Future<void> _applyAllowedLocation({
    required String address,
    required double latitude,
    required double longitude,
    String placeId = '',
    bool refreshCatalog = true,
  }) async {
    if (!Get.isRegistered<ProfileController>()) {
      await _persistCatalogLocation(
        id: 'service-location',
        address: address,
        latitude: latitude,
        longitude: longitude,
        placeId: placeId,
        serviceable: true,
      );
      return;
    }
    await Get.find<ProfileController>().applyServiceAreaLocation(
      address: address.trim().isNotEmpty
          ? address.trim()
          : '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
      latitude: latitude,
      longitude: longitude,
      placeId: placeId,
      refreshCatalog: refreshCatalog,
    );
  }

  Future<void> _applyBlockedLocation({
    required String address,
    required double latitude,
    required double longitude,
    String placeId = '',
  }) async {
    if (!Get.isRegistered<ProfileController>()) {
      await _persistCatalogLocation(
        id: 'blocked-service-location',
        address: address,
        latitude: latitude,
        longitude: longitude,
        placeId: placeId,
        serviceable: false,
      );
      return;
    }
    await Get.find<ProfileController>().applyBlockedServiceAreaLocation(
      address: address.trim().isNotEmpty
          ? address.trim()
          : '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
      latitude: latitude,
      longitude: longitude,
      placeId: placeId,
    );
  }

  Future<void> _persistCatalogLocation({
    required String id,
    required String address,
    required double latitude,
    required double longitude,
    required bool serviceable,
    String placeId = '',
  }) async {
    final label = address.trim().isNotEmpty
        ? address.trim()
        : '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    final catalogAddress = AddressModel(
      id: id,
      fullName: 'Customer',
      contactNumber: '',
      address: label,
      latitude: latitude,
      longitude: longitude,
      placeId: placeId.trim(),
      isSelected: true,
    );
    await _storage.write(_selectedAddressStorageKey, catalogAddress.toJson());
    await _storage.write(_selectedLocationServiceableStorageKey, serviceable);
    if (id == 'service-location' && serviceable) {
      await _storage.write(
        _selectedServiceLocationSessionStorageKey,
        AppSessionScope.id,
      );
    } else {
      await _storage.remove(_selectedServiceLocationSessionStorageKey);
    }
    if (!serviceable) {
      await _storage.remove(_selectedVendorIdStorageKey);
    }
  }

  Future<void> _persistGuestBlockedCatalogState() async {
    if (_hasBackendSession) return;
    await _storage.remove(_selectedVendorIdStorageKey);
    await _storage.remove(_selectedServiceLocationSessionStorageKey);
    await _storage.write(_selectedLocationServiceableStorageKey, false);
  }

  bool get _hasBackendSession {
    final token = _storage.read<String>('accessToken');
    return token != null && token.trim().isNotEmpty;
  }

  AddressModel? get _serviceableSelectedAddress {
    if (_storage.read(_selectedLocationServiceableStorageKey) != true) {
      return null;
    }
    if (!AppSessionScope.isCurrentSession(
      _storage.read(_selectedServiceLocationSessionStorageKey),
    )) {
      return null;
    }
    final address = _storedSelectedAddress;
    if (address == null) return null;
    final id = address.id.trim();
    if (id != 'service-location') return null;
    if (address.address.trim().isEmpty ||
        address.latitude == null ||
        address.longitude == null ||
        !_isValidCoordinate(address.latitude!, address.longitude!)) {
      return null;
    }
    return address;
  }

  AddressModel? get _storedSelectedAddress {
    final raw = _storage.read(_selectedAddressStorageKey);
    if (raw is! Map) return null;
    return AddressModel.fromJson(Map<String, dynamic>.from(raw));
  }

  bool _isTransientCatalogAddress(AddressModel address) {
    return const {
      'live-location',
      'service-location',
      'blocked-service-location',
    }.contains(address.id.trim());
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
