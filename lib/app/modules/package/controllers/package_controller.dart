import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../../firebase_options.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../core/services/location_lookup_service.dart';
import '../../../data/models/package_order_model.dart';
import '../../../routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';

enum PackageViewMode { send, orders }

enum PackageStep { initial, pickup, drop, type, review }

enum PackageOrderType { send, receive }

enum PackageMapTarget { pickup, drop }

extension PackageOrderTypeX on PackageOrderType {
  String get apiValue => this == PackageOrderType.receive ? 'receive' : 'send';
}

class PackageController extends GetxController {
  PackageController(this._storage);

  static const _storageKey = 'package_orders';
  static const _defaultPackageTypes = [
    'Documents',
    'Food',
    'Parcel',
    'Medicine',
  ];
  static const _defaultBaseDeliveryCharge = 30.0;
  static const _defaultChargePerKm = 8.0;
  static const _defaultMaxPackageDistanceKm = 30.0;
  static const _defaultPackageMapRadiusMeters = 50000;

  final GetStorage _storage;
  final LocationLookupService _locationLookupService = LocationLookupService();

  final pickupController = TextEditingController();
  final dropController = TextEditingController();

  final viewMode = PackageViewMode.send.obs;
  final currentStep = PackageStep.initial.obs;
  final packageOrderType = PackageOrderType.send.obs;
  final selectedPackageType = RxnString();
  final agreementChecked = false.obs;
  final orders = <PackageOrderModel>[].obs;
  final isSubmitting = false.obs;
  final isLoadingOrders = false.obs;
  final isResolvingPickup = false.obs;
  final isResolvingDrop = false.obs;
  final isCalculatingRoute = false.obs;
  final isMapPickerVisible = false.obs;
  final isMapConfirming = false.obs;
  final isDistanceExceededVisible = false.obs;
  final exceedingDistanceKm = 0.0.obs;
  final selectedOrder = Rxn<PackageOrderModel>();

  final pickupLatitude = Rxn<double>();
  final pickupLongitude = Rxn<double>();
  final pickupPlaceId = ''.obs;
  final pickupAddressText = ''.obs;
  final dropLatitude = Rxn<double>();
  final dropLongitude = Rxn<double>();
  final dropPlaceId = ''.obs;
  final dropAddressText = ''.obs;
  final pickupSuggestions = <PlaceSuggestion>[].obs;
  final dropSuggestions = <PlaceSuggestion>[].obs;
  final mapPickerTarget = Rxn<PackageMapTarget>();
  final mapDraftAddress = ''.obs;
  final mapDraftLatitude = Rxn<double>();
  final mapDraftLongitude = Rxn<double>();

  final _packageTypes = <String>[..._defaultPackageTypes].obs;
  final _baseDeliveryCharge = _defaultBaseDeliveryCharge.obs;
  final _chargePerKm = _defaultChargePerKm.obs;
  final _maxPackageDistanceKm = _defaultMaxPackageDistanceKm.obs;
  final _packageMapRadiusMeters = _defaultPackageMapRadiusMeters.obs;
  final _distanceMeters = 0.0.obs;
  final _distanceText = ''.obs;
  final _durationSeconds = 0.obs;
  final _durationText = ''.obs;

  Timer? _pickupDebounce;
  Timer? _dropDebounce;

  List<String> get packageTypes => _packageTypes.toList(growable: false);

  double get distanceKm => _distanceMeters.value / 1000;

  String get distanceText => _distanceText.value.isNotEmpty
      ? _distanceText.value
      : (distanceKm > 0 ? '${distanceKm.toStringAsFixed(1)} km' : '--');

  int get durationSeconds => _durationSeconds.value;

  String get durationText =>
      _durationText.value.isNotEmpty ? _durationText.value : '--';

  double get deliveryCharge => _distanceMeters.value > 0
      ? _baseDeliveryCharge.value + (distanceKm * _chargePerKm.value)
      : 0;

  double get totalPrice => deliveryCharge;

  double get maxPackageDistanceKm => _maxPackageDistanceKm.value;

  String get mapPickerTitle => mapPickerTarget.value == PackageMapTarget.pickup
      ? 'Confirm Pickup Location'
      : 'Confirm Drop Location';

  String get mapPickerFallbackText =>
      mapPickerTarget.value == PackageMapTarget.pickup
      ? 'Move the pin on map to set exact pickup location'
      : 'Move the pin on map to set exact drop location';

  bool get canMoveFromPickup =>
      pickupController.text.trim().isNotEmpty &&
      _hasValidCoordinates(pickupLatitude.value, pickupLongitude.value);

  bool get canMoveFromDrop =>
      dropController.text.trim().isNotEmpty &&
      _hasValidCoordinates(dropLatitude.value, dropLongitude.value);

  bool get canAttemptPickup => pickupAddressText.value.trim().isNotEmpty;

  bool get canAttemptDrop => dropAddressText.value.trim().isNotEmpty;

  bool get canMoveFromType => selectedPackageType.value?.isNotEmpty == true;

  bool get canSubmitReview =>
      canMoveFromPickup &&
      canMoveFromDrop &&
      canMoveFromType &&
      agreementChecked.value &&
      _distanceMeters.value > 0 &&
      distanceKm <= _maxPackageDistanceKm.value;

  @override
  void onInit() {
    super.onInit();
    debugPrint('PackageController.onInit: package flow initialized');
    loadDeliverySettings();
    loadOrders();
  }

  Future<void> loadDeliverySettings({bool force = false}) async {
    try {
      final firebaseHeaders = await _firebaseAuthHeaders();
      if (firebaseHeaders == null || !Get.isRegistered<ApiService>()) return;
      final options = DefaultFirebaseOptions.android;
      final endpoint =
          'https://firestore.googleapis.com/v1/projects/${options.projectId}/databases/(default)/documents/adminSettings/deliveryRadius?key=${options.apiKey}';
      final response = await Get.find<ApiService>().get(
        endpoint: endpoint,
        authenticated: false,
        headers: firebaseHeaders,
      );
      final fields = _decodeFirestoreFields(response['fields']);
      _packageTypes.assignAll(_readPackageTypes(fields));
      _baseDeliveryCharge.value = max(
        0,
        _readNumber(fields, const [
          'baseFee',
          'base_fee',
          'packages.baseFee',
          'packages.base_fee',
        ], _defaultBaseDeliveryCharge),
      );
      _chargePerKm.value = max(
        0,
        _readNumber(fields, const [
          'perKmFee',
          'per_km_fee',
          'packages.perKmFee',
          'packages.per_km_fee',
        ], _defaultChargePerKm),
      );
      _maxPackageDistanceKm.value = max(
        1,
        _readNumber(fields, const [
          'maxDistanceKm',
          'max_distance_km',
          'packages.maxDistanceKm',
          'packages.max_distance_km',
        ], _defaultMaxPackageDistanceKm),
      );
      _packageMapRadiusMeters.value = max(
        1000,
        _readNumber(fields, const [
          'mapRadiusMeters',
          'map_radius_meters',
          'packages.mapRadiusMeters',
          'packages.map_radius_meters',
        ], _defaultPackageMapRadiusMeters.toDouble()).round(),
      );
    } catch (error) {
      debugPrint(
        'PackageController.loadDeliverySettings: using defaults after $error',
      );
    }
  }

  void setViewMode(PackageViewMode mode) {
    debugPrint('PackageController.setViewMode: switching to $mode');
    viewMode.value = mode;
    if (mode == PackageViewMode.orders) {
      loadOrders();
    }
  }

  void startFlow(String flowType) {
    debugPrint('PackageController.startFlow: selected flow $flowType');
    resetDraft(keepOrders: true);
    packageOrderType.value = flowType == 'receive'
        ? PackageOrderType.receive
        : PackageOrderType.send;
    currentStep.value = packageOrderType.value == PackageOrderType.receive
        ? PackageStep.drop
        : PackageStep.pickup;
  }

  void goBackStep() {
    debugPrint(
      'PackageController.goBackStep: current step ${currentStep.value}',
    );
    switch (currentStep.value) {
      case PackageStep.initial:
        return;
      case PackageStep.pickup:
        currentStep.value = packageOrderType.value == PackageOrderType.receive
            ? PackageStep.drop
            : PackageStep.initial;
      case PackageStep.drop:
        currentStep.value = packageOrderType.value == PackageOrderType.receive
            ? PackageStep.initial
            : PackageStep.pickup;
      case PackageStep.type:
        currentStep.value = packageOrderType.value == PackageOrderType.receive
            ? PackageStep.pickup
            : PackageStep.drop;
      case PackageStep.review:
        currentStep.value = PackageStep.type;
    }
  }

  void onPickupChanged(String value) {
    pickupAddressText.value = value;
    _clearPickupCoordinates();
    _pickupDebounce?.cancel();
    if (value.trim().length < 2) {
      pickupSuggestions.clear();
      return;
    }
    _pickupDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadSuggestions(value, isPickup: true),
    );
  }

  void onDropChanged(String value) {
    dropAddressText.value = value;
    _clearDropCoordinates();
    _dropDebounce?.cancel();
    if (value.trim().length < 2) {
      dropSuggestions.clear();
      return;
    }
    _dropDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadSuggestions(value, isPickup: false),
    );
  }

  Future<void> selectPickupSuggestion(PlaceSuggestion suggestion) async {
    await _applySuggestion(suggestion, isPickup: true);
  }

  Future<void> selectDropSuggestion(PlaceSuggestion suggestion) async {
    await _applySuggestion(suggestion, isPickup: false);
  }

  Future<void> continueFromPickup() async {
    debugPrint(
      'PackageController.continueFromPickup: pickup="${pickupController.text.trim()}"',
    );
    final resolved = await _resolvePickupIfNeeded();
    if (resolved == null) {
      _showSnack('Pickup Required', 'Please select a valid pickup location.');
      return;
    }
    if (packageOrderType.value == PackageOrderType.receive) {
      if (!await _validateRouteRange(showErrors: true)) return;
      _openMapPicker(PackageMapTarget.pickup);
      return;
    }
    _openMapPicker(PackageMapTarget.pickup);
  }

  Future<void> continueFromDrop() async {
    debugPrint(
      'PackageController.continueFromDrop: drop="${dropController.text.trim()}"',
    );
    final resolved = await _resolveDropIfNeeded();
    if (resolved == null) {
      _showSnack('Drop Required', 'Please select a valid drop location.');
      return;
    }
    if (packageOrderType.value == PackageOrderType.receive) {
      currentStep.value = PackageStep.pickup;
      return;
    }
    if (!await _validateRouteRange(showErrors: true)) return;
    _openMapPicker(PackageMapTarget.drop);
  }

  void selectPackageType(String value) {
    debugPrint('PackageController.selectPackageType: selected $value');
    selectedPackageType.value = value;
  }

  Future<void> continueFromType() async {
    debugPrint(
      'PackageController.continueFromType: selected type ${selectedPackageType.value}',
    );
    if (!canMoveFromType) {
      _showSnack('Package Type Required', 'Please select a package type.');
      return;
    }
    if (!await _updateRouteSummary(showErrors: true)) return;
    currentStep.value = PackageStep.review;
  }

  void toggleAgreement() {
    agreementChecked.toggle();
    debugPrint(
      'PackageController.toggleAgreement: agreement=${agreementChecked.value}',
    );
  }

  void onMapCameraMove(double latitude, double longitude) {
    mapDraftLatitude.value = latitude;
    mapDraftLongitude.value = longitude;
  }

  void closeMapPicker() {
    isMapPickerVisible.value = false;
    isMapConfirming.value = false;
    mapPickerTarget.value = null;
    mapDraftAddress.value = '';
    mapDraftLatitude.value = null;
    mapDraftLongitude.value = null;
  }

  void closeDistanceExceededModal() {
    isDistanceExceededVisible.value = false;
  }

  Future<void> confirmMapLocation() async {
    final target = mapPickerTarget.value;
    final latitude = mapDraftLatitude.value;
    final longitude = mapDraftLongitude.value;
    if (target == null ||
        !_hasValidCoordinates(latitude, longitude) ||
        isMapConfirming.value) {
      return;
    }

    isMapConfirming.value = true;
    try {
      final address = await _locationLookupService.reverseGeocodeToAddress(
        latitude: latitude!,
        longitude: longitude!,
      );
      _applyLocation(
        _PackageLocation(
          address:
              address ??
              _fallbackAddress(mapDraftAddress.value, latitude, longitude),
          latitude: latitude,
          longitude: longitude,
          placeId: '',
        ),
        isPickup: target == PackageMapTarget.pickup,
      );

      isMapPickerVisible.value = false;
      if (target == PackageMapTarget.pickup) {
        if (packageOrderType.value == PackageOrderType.receive) {
          if (await _updateRouteSummary(showErrors: true)) {
            currentStep.value = PackageStep.type;
          }
        } else {
          currentStep.value = PackageStep.drop;
        }
        return;
      }

      if (await _updateRouteSummary(showErrors: true)) {
        currentStep.value = PackageStep.type;
      }
    } finally {
      isMapConfirming.value = false;
    }
  }

  Future<void> submitOrder() async {
    debugPrint('PackageController.submitOrder: submit requested');
    if (!agreementChecked.value) {
      _showSnack(
        'Agreement Required',
        'Please confirm package details before proceeding.',
      );
      return;
    }
    if (!await _updateRouteSummary(showErrors: true) || !canSubmitReview) {
      _showSnack(
        'Review Incomplete',
        'Pickup, drop, package type aur valid distance complete karo.',
      );
      return;
    }
    if (isSubmitting.value) {
      debugPrint('PackageController.submitOrder: already submitting');
      return;
    }

    isSubmitting.value = true;
    try {
      final authController = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : null;
      final user = authController?.currentUser;
      final draft = PackageOrderModel(
        id: 'PKG${DateTime.now().millisecondsSinceEpoch}',
        customerName: user?.name ?? 'SonicKart Customer',
        customerPhone: user?.phone ?? '+91 0000000000',
        packageType: selectedPackageType.value ?? 'Package',
        packageOrderType: packageOrderType.value.apiValue,
        pickupAddress: pickupController.text.trim(),
        pickupLatitude: pickupLatitude.value,
        pickupLongitude: pickupLongitude.value,
        pickupPlaceId: pickupPlaceId.value,
        dropAddress: dropController.text.trim(),
        dropLatitude: dropLatitude.value,
        dropLongitude: dropLongitude.value,
        dropPlaceId: dropPlaceId.value,
        distanceKm: distanceKm,
        distanceText: distanceText,
        durationSeconds: durationSeconds,
        durationText: durationText,
        deliveryCharge: deliveryCharge.roundToDouble(),
        totalPrice: totalPrice.roundToDouble(),
        status: 'pending',
        createdAt: DateTime.now(),
      );
      final order = await _tryCreatePackageOrder(draft);
      if (order == null) {
        _showSnack(
          'Order Creation Failed',
          'Package order create nahi hua. Please check connection and try again.',
        );
        return;
      }
      await _upsertOrder(order);
      selectedOrder.value = order;
      debugPrint(
        'PackageController.submitOrder: order created ${order.id} total=${order.totalPrice}',
      );
      resetDraft(keepOrders: true);
      viewMode.value = PackageViewMode.orders;
    } finally {
      isSubmitting.value = false;
    }
  }

  void openOrder(PackageOrderModel order) {
    debugPrint('PackageController.openOrder: opening order ${order.id}');
    selectedOrder.value = order;
    Get.toNamed(AppRoutes.packageDetails, arguments: {'orderId': order.id});
  }

  PackageOrderModel? findOrderById(String orderId) {
    final normalized = _normalizeId(orderId);
    for (final order in orders) {
      if (_orderIdentifiers(order).map(_normalizeId).contains(normalized)) {
        return order;
      }
    }
    return null;
  }

  Future<PackageOrderModel?> refreshOrderDetails(String orderId) async {
    final normalized = orderId.trim();
    if (normalized.isEmpty) return selectedOrder.value;
    final remote = await _tryFetchPackageOrderById(normalized);
    if (remote != null) {
      await _upsertOrder(remote);
      selectedOrder.value = remote;
      return remote;
    }
    final local = findOrderById(normalized);
    if (local != null) selectedOrder.value = local;
    return local;
  }

  List<String> packageOrderIdentifiers(PackageOrderModel order) =>
      _orderIdentifiers(order);

  Future<bool> handleRealtimePackagePayload(
    Map<String, dynamic> payload, {
    String? fallbackOrderId,
  }) async {
    final raw = _extractObject(payload);
    final identifiers = _payloadIdentifiers(raw);
    final fallback = _normalizeId(fallbackOrderId ?? '');
    if (fallback.isNotEmpty &&
        !identifiers.map(_normalizeId).contains(fallback)) {
      return false;
    }

    final existing =
        (fallback.isNotEmpty ? findOrderById(fallback) : null) ??
        selectedOrder.value;
    final merged = existing == null
        ? raw
        : <String, dynamic>{...existing.toJson(), ...existing.raw, ...raw};
    final parsed = PackageOrderModel.fromJson(merged);
    if (parsed.id.isEmpty) return false;

    await _upsertOrder(parsed);
    selectedOrder.value = parsed;
    return true;
  }

  Future<void> cancelPackageOrder(PackageOrderModel order) async {
    if (_isTerminalStatus(order.status)) {
      _showSnack('Cannot Cancel', 'This package order cannot be cancelled.');
      return;
    }
    try {
      final updated = await _tryCancelPackageOrder(order);
      if (updated != null) {
        await _upsertOrder(updated);
        selectedOrder.value = updated;
      } else {
        final cancelled = PackageOrderModel.fromJson({
          ...order.toJson(),
          'status': 'cancelled',
          'deliveryStatus': 'cancelled',
        });
        await _upsertOrder(cancelled);
        selectedOrder.value = cancelled;
      }
      _showSnack(
        'Package Cancelled',
        'Your package order has been cancelled successfully.',
      );
    } catch (error) {
      debugPrint('PackageController.cancelPackageOrder failed: $error');
      _showSnack(
        'Cancel Failed',
        'Package cancel nahi ho saka. Dobara try karo.',
      );
    }
  }

  Future<void> loadOrders() async {
    debugPrint('PackageController.loadOrders: loading package orders');
    isLoadingOrders.value = true;
    try {
      final remote = await _tryFetchPackageOrders();
      if (remote.isNotEmpty) {
        orders.assignAll(remote);
        await _persistOrders();
        debugPrint(
          'PackageController.loadOrders: fetched ${orders.length} package orders from API',
        );
        return;
      }

      final rawOrders =
          _storage.read<List<dynamic>>(_storageKey) ?? <dynamic>[];
      final restoredOrders =
          rawOrders
              .whereType<Map>()
              .map(
                (item) =>
                    PackageOrderModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      orders.assignAll(restoredOrders);
      debugPrint(
        'PackageController.loadOrders: restored ${orders.length} package orders',
      );
    } finally {
      isLoadingOrders.value = false;
    }
  }

  Future<void> useAutoDetectedPickup() async {
    await _useCurrentLocation(isPickup: true);
  }

  Future<void> useSuggestedDrop() async {
    await _useCurrentLocation(isPickup: false);
  }

  void resetDraft({bool keepOrders = false}) {
    debugPrint('PackageController.resetDraft: clearing draft state');
    pickupController.clear();
    dropController.clear();
    pickupAddressText.value = '';
    dropAddressText.value = '';
    _clearPickupCoordinates();
    _clearDropCoordinates();
    pickupSuggestions.clear();
    dropSuggestions.clear();
    closeMapPicker();
    selectedPackageType.value = null;
    agreementChecked.value = false;
    _distanceMeters.value = 0;
    _distanceText.value = '';
    _durationSeconds.value = 0;
    _durationText.value = '';
    currentStep.value = PackageStep.initial;
    packageOrderType.value = PackageOrderType.send;
    if (!keepOrders) {
      orders.clear();
    }
  }

  Future<void> _loadSuggestions(String query, {required bool isPickup}) async {
    try {
      final bias = await _suggestionBias(
        isPickup: isPickup,
      ).timeout(const Duration(milliseconds: 800), onTimeout: () => null);
      final suggestions = await _locationLookupService.getPlaceSuggestions(
        query,
        latitude: bias?.latitude,
        longitude: bias?.longitude,
        radiusMeters: _packageMapRadiusMeters.value,
      );
      if (isPickup) {
        if (pickupController.text.trim() == query.trim()) {
          pickupSuggestions.assignAll(suggestions);
        }
      } else {
        if (dropController.text.trim() == query.trim()) {
          dropSuggestions.assignAll(suggestions);
        }
      }
    } catch (error) {
      debugPrint('PackageController._loadSuggestions failed: $error');
    }
  }

  Future<({double latitude, double longitude})?> _suggestionBias({
    required bool isPickup,
  }) async {
    final latitude = isPickup ? pickupLatitude.value : dropLatitude.value;
    final longitude = isPickup ? pickupLongitude.value : dropLongitude.value;
    if (_hasValidCoordinates(latitude, longitude)) {
      return (latitude: latitude!, longitude: longitude!);
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
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
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 8));
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (error) {
      debugPrint('PackageController._suggestionBias unavailable: $error');
      return null;
    }
  }

  Future<void> _applySuggestion(
    PlaceSuggestion suggestion, {
    required bool isPickup,
  }) async {
    final details = await _locationLookupService.getPlaceDetails(
      suggestion.placeId,
    );
    if (details == null ||
        !_hasValidCoordinates(details.latitude, details.longitude)) {
      _showSnack('Location Error', 'Could not resolve selected location.');
      return;
    }
    _applyLocation(
      _PackageLocation(
        address: details.address.isNotEmpty
            ? details.address
            : suggestion.description,
        latitude: details.latitude!,
        longitude: details.longitude!,
        placeId: details.placeId,
      ),
      isPickup: isPickup,
    );
  }

  Future<_PackageLocation?> _resolvePickupIfNeeded() async {
    if (canMoveFromPickup) {
      return _PackageLocation(
        address: pickupController.text.trim(),
        latitude: pickupLatitude.value!,
        longitude: pickupLongitude.value!,
        placeId: pickupPlaceId.value,
      );
    }
    return _resolveTypedAddress(isPickup: true);
  }

  Future<_PackageLocation?> _resolveDropIfNeeded() async {
    if (canMoveFromDrop) {
      return _PackageLocation(
        address: dropController.text.trim(),
        latitude: dropLatitude.value!,
        longitude: dropLongitude.value!,
        placeId: dropPlaceId.value,
      );
    }
    return _resolveTypedAddress(isPickup: false);
  }

  Future<_PackageLocation?> _resolveTypedAddress({
    required bool isPickup,
  }) async {
    final controller = isPickup ? pickupController : dropController;
    final address = controller.text.trim();
    if (address.isEmpty) return null;
    if (isPickup) {
      isResolvingPickup.value = true;
    } else {
      isResolvingDrop.value = true;
    }
    try {
      final details = await _locationLookupService.geocodeAddress(address);
      if (details == null ||
          !_hasValidCoordinates(details.latitude, details.longitude)) {
        return null;
      }
      final location = _PackageLocation(
        address: details.address.isNotEmpty ? details.address : address,
        latitude: details.latitude!,
        longitude: details.longitude!,
        placeId: details.placeId,
      );
      _applyLocation(location, isPickup: isPickup);
      return location;
    } finally {
      if (isPickup) {
        isResolvingPickup.value = false;
      } else {
        isResolvingDrop.value = false;
      }
    }
  }

  void _applyLocation(_PackageLocation location, {required bool isPickup}) {
    if (isPickup) {
      pickupController.text = location.address;
      pickupAddressText.value = location.address;
      pickupLatitude.value = location.latitude;
      pickupLongitude.value = location.longitude;
      pickupPlaceId.value = location.placeId;
      pickupSuggestions.clear();
    } else {
      dropController.text = location.address;
      dropAddressText.value = location.address;
      dropLatitude.value = location.latitude;
      dropLongitude.value = location.longitude;
      dropPlaceId.value = location.placeId;
      dropSuggestions.clear();
    }
    _distanceMeters.value = 0;
    _distanceText.value = '';
    _durationSeconds.value = 0;
    _durationText.value = '';
  }

  void _openMapPicker(PackageMapTarget target) {
    final isPickup = target == PackageMapTarget.pickup;
    final latitude = isPickup ? pickupLatitude.value : dropLatitude.value;
    final longitude = isPickup ? pickupLongitude.value : dropLongitude.value;
    if (!_hasValidCoordinates(latitude, longitude)) {
      _showSnack('Location Required', 'Please select a valid location first.');
      return;
    }

    mapPickerTarget.value = target;
    mapDraftLatitude.value = latitude;
    mapDraftLongitude.value = longitude;
    mapDraftAddress.value = isPickup
        ? pickupController.text.trim()
        : dropController.text.trim();
    isMapPickerVisible.value = true;
  }

  Future<bool> _validateRouteRange({required bool showErrors}) async {
    final pickup = await _resolvePickupIfNeeded();
    final drop = await _resolveDropIfNeeded();
    if (pickup == null || drop == null) return false;
    final km = _calculateDistanceKm(
      pickup.latitude,
      pickup.longitude,
      drop.latitude,
      drop.longitude,
    );
    if (km > _maxPackageDistanceKm.value) {
      if (showErrors) {
        _showDistanceExceeded(km);
      }
      return false;
    }
    return true;
  }

  Future<bool> _updateRouteSummary({required bool showErrors}) async {
    final pickup = await _resolvePickupIfNeeded();
    final drop = await _resolveDropIfNeeded();
    if (pickup == null || drop == null) {
      if (showErrors) {
        _showSnack(
          'Location Required',
          'Please select valid pickup and drop locations.',
        );
      }
      return false;
    }

    final sameLocation =
        (pickup.latitude - drop.latitude).abs() < 0.0001 &&
        (pickup.longitude - drop.longitude).abs() < 0.0001;
    if (sameLocation) {
      if (showErrors) {
        _showSnack(
          'Invalid Route',
          'Pickup and drop locations cannot be the same.',
        );
      }
      return false;
    }

    isCalculatingRoute.value = true;
    try {
      final matrix = await _locationLookupService.getDistanceMatrix(
        originLatitude: pickup.latitude,
        originLongitude: pickup.longitude,
        destinationLatitude: drop.latitude,
        destinationLongitude: drop.longitude,
      );
      if (matrix == null) {
        if (showErrors) {
          _showSnack(
            'Route Calculation Failed',
            'Unable to calculate route. Please check locations and try again.',
          );
        }
        return false;
      }
      final km = matrix.distanceMeters / 1000;
      if (km > _maxPackageDistanceKm.value) {
        if (showErrors) {
          _showDistanceExceeded(km);
        }
        return false;
      }
      _distanceMeters.value = matrix.distanceMeters.toDouble();
      _distanceText.value = matrix.distanceText.isNotEmpty
          ? matrix.distanceText
          : (km >= 1
                ? '${km.toStringAsFixed(1)} km'
                : '${matrix.distanceMeters} m');
      _durationSeconds.value = matrix.durationSeconds;
      _durationText.value = matrix.durationText.isNotEmpty
          ? matrix.durationText
          : '${max(1, (matrix.durationSeconds / 60).round())} mins';
      return true;
    } finally {
      isCalculatingRoute.value = false;
    }
  }

  Future<void> _useCurrentLocation({required bool isPickup}) async {
    if (!_locationLookupService.isConfigured) {
      _showSnack('Location Error', 'Google location lookup is not configured.');
      return;
    }
    if (!await _ensureLocationPermission()) return;
    if (isPickup) {
      isResolvingPickup.value = true;
    } else {
      isResolvingDrop.value = true;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final address = await _locationLookupService.reverseGeocodeToAddress(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _applyLocation(
        _PackageLocation(
          address:
              address ??
              '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
          latitude: position.latitude,
          longitude: position.longitude,
          placeId: '',
        ),
        isPickup: isPickup,
      );
    } finally {
      if (isPickup) {
        isResolvingPickup.value = false;
      } else {
        isResolvingDrop.value = false;
      }
    }
  }

  Future<void> _persistOrders() async {
    final payload = orders.map((order) => order.toJson()).toList();
    await _storage.write(_storageKey, payload);
    debugPrint(
      'PackageController._persistOrders: persisted ${orders.length} package orders',
    );
  }

  Future<void> _upsertOrder(PackageOrderModel order) async {
    final incomingIds = _orderIdentifiers(order).map(_normalizeId).toSet();
    final index = orders.indexWhere(
      (item) =>
          _orderIdentifiers(item).map(_normalizeId).any(incomingIds.contains),
    );
    if (index >= 0) {
      orders[index] = order;
    } else {
      orders.insert(0, order);
    }
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _persistOrders();
  }

  Future<PackageOrderModel?> _tryCreatePackageOrder(
    PackageOrderModel draft,
  ) async {
    if (!Get.isRegistered<ApiService>()) return null;
    try {
      final payload = {
        'pickupLocation': {
          'address': draft.pickupAddress,
          'latitude': draft.pickupLatitude,
          'longitude': draft.pickupLongitude,
          if (draft.pickupPlaceId.isNotEmpty) 'placeId': draft.pickupPlaceId,
        },
        'dropLocation': {
          'address': draft.dropAddress,
          'latitude': draft.dropLatitude,
          'longitude': draft.dropLongitude,
          if (draft.dropPlaceId.isNotEmpty) 'placeId': draft.dropPlaceId,
        },
        'packageType': draft.packageType,
        'distance': (draft.distanceKm * 1000).round(),
        'distanceText': draft.distanceText,
        'duration': draft.durationSeconds,
        'durationText': draft.durationText,
        'deliveryCharge': draft.deliveryCharge,
        'customerName': draft.customerName,
        'customerPhone': draft.customerPhone,
        'orderType': 'package',
        'packageOrderType': draft.packageOrderType,
        'agreement': agreementChecked.value,
      };
      final response = await Get.find<ApiService>().post(
        endpoint: ApiConstants.packageOrder,
        data: payload,
      );
      final raw = _extractObject(response);
      final parsed = PackageOrderModel.fromJson(raw);
      return parsed.id.isEmpty ? null : parsed;
    } catch (error) {
      debugPrint(
        'PackageController._tryCreatePackageOrder: local fallback after $error',
      );
      return null;
    }
  }

  Map<String, dynamic> _extractObject(Map<String, dynamic> response) {
    for (final value in [
      response['data'],
      response['order'],
      response['packageOrder'],
      response['result'],
      response['item'],
      response,
    ]) {
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        for (final nested in ['order', 'packageOrder', 'data', 'result']) {
          final nestedValue = map[nested];
          if (nestedValue is Map) {
            return Map<String, dynamic>.from(nestedValue);
          }
        }
        return map;
      }
    }
    return response;
  }

  Future<List<PackageOrderModel>> _tryFetchPackageOrders() async {
    if (!Get.isRegistered<ApiService>()) return <PackageOrderModel>[];
    try {
      final authController = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : null;
      final userId = authController?.currentUser?.id ?? '';
      final query = <String, dynamic>{};
      if (userId.isNotEmpty) query['customerId'] = userId;
      final response = await Get.find<ApiService>().get(
        endpoint: ApiConstants.packageOrder,
        query: query,
      );
      final list =
          _extractList(response)
              .whereType<Map>()
              .map(
                (item) =>
                    PackageOrderModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((order) => order.id.isNotEmpty)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (error) {
      debugPrint(
        'PackageController._tryFetchPackageOrders: local fallback after $error',
      );
      return <PackageOrderModel>[];
    }
  }

  Future<PackageOrderModel?> _tryFetchPackageOrderById(String id) async {
    if (!Get.isRegistered<ApiService>()) return null;
    try {
      for (final candidate in [id, _normalizeId(id)]) {
        if (candidate.trim().isEmpty) continue;
        final response = await Get.find<ApiService>().get(
          endpoint: ApiConstants.packageOrderById(candidate),
        );
        final parsed = PackageOrderModel.fromJson(_extractObject(response));
        if (parsed.id.isNotEmpty) return parsed;
      }
    } catch (error) {
      debugPrint('PackageController._tryFetchPackageOrderById failed: $error');
    }
    return null;
  }

  Future<PackageOrderModel?> _tryCancelPackageOrder(
    PackageOrderModel order,
  ) async {
    if (!Get.isRegistered<ApiService>()) return null;
    final ids = _orderIdentifiers(order).map(_normalizeId).toSet().toList();
    for (final id in ids) {
      if (id.trim().isEmpty) continue;
      try {
        final response = await Get.find<ApiService>().post(
          endpoint: '${ApiConstants.packageOrderById(id)}/cancel',
        );
        final parsed = PackageOrderModel.fromJson(_extractObject(response));
        if (parsed.id.isNotEmpty) return parsed;
      } catch (error) {
        debugPrint('PackageController._tryCancelPackageOrder failed: $error');
      }
    }
    return null;
  }

  List _extractList(Map<String, dynamic> response) {
    final candidates = [
      response['data'],
      response['orders'],
      response['items'],
      response['result'],
      response['results'],
    ];
    for (final value in candidates) {
      if (value is List) return value;
      if (value is Map) {
        for (final nested in ['data', 'orders', 'items', 'result', 'results']) {
          final nestedValue = value[nested];
          if (nestedValue is List) return nestedValue;
        }
      }
    }
    return [];
  }

  Future<Map<String, String>?> _firebaseAuthHeaders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final token = await user.getIdToken();
      if (token == null || token.trim().isEmpty) return null;
      return {'Authorization': 'Bearer $token'};
    } catch (error) {
      debugPrint('PackageController._firebaseAuthHeaders failed: $error');
      return null;
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack(
        'Location Off',
        'Please turn on device location to auto-detect address.',
      );
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showSnack(
        'Permission Required',
        'Location permission is needed to detect your address.',
      );
      return false;
    }
    return true;
  }

  void _clearPickupCoordinates() {
    pickupLatitude.value = null;
    pickupLongitude.value = null;
    pickupPlaceId.value = '';
    _clearRouteSummary();
  }

  void _clearDropCoordinates() {
    dropLatitude.value = null;
    dropLongitude.value = null;
    dropPlaceId.value = '';
    _clearRouteSummary();
  }

  void _clearRouteSummary() {
    _distanceMeters.value = 0;
    _distanceText.value = '';
    _durationSeconds.value = 0;
    _durationText.value = '';
  }

  bool _hasValidCoordinates(double? lat, double? lng) {
    return lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180;
  }

  double _calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const radiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return double.parse((radiusKm * c).toStringAsFixed(2));
  }

  double _toRadians(double degrees) => degrees * (pi / 180);

  String _fallbackAddress(String current, double latitude, double longitude) {
    final trimmed = current.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  List<String> _orderIdentifiers(PackageOrderModel order) {
    return [
          order.id,
          order.raw['_id'],
          order.raw['orderId'],
          order.raw['orderNumber'],
        ]
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> _payloadIdentifiers(Map<String, dynamic> payload) {
    return [
          payload['id'],
          payload['_id'],
          payload['orderId'],
          payload['orderNumber'],
          payload['packageOrderId'],
        ]
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  String _normalizeId(String value) {
    return value.trim().replaceFirst(RegExp(r'^PKG', caseSensitive: false), '');
  }

  bool _isTerminalStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'delivered' ||
        normalized == 'completed' ||
        normalized == 'cancelled';
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
    if (value.containsKey('arrayValue')) {
      final values = value['arrayValue'] is Map
          ? (value['arrayValue'] as Map)['values']
          : null;
      if (values is! List) return const [];
      return values.map(_decodeFirestoreValue).toList();
    }
    if (value.containsKey('mapValue')) {
      final fields = value['mapValue'] is Map
          ? (value['mapValue'] as Map)['fields']
          : null;
      return _decodeFirestoreFields(fields);
    }
    return null;
  }

  Object? _readPath(Map<String, dynamic> source, String path) {
    Object? current = source;
    for (final segment in path.split('.')) {
      if (current is! Map) return null;
      current = current[segment];
    }
    return current;
  }

  double _readNumber(
    Map<String, dynamic> source,
    List<String> paths,
    double fallback,
  ) {
    for (final path in paths) {
      final value = _readPath(source, path);
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  List<String> _readPackageTypes(Map<String, dynamic> fields) {
    Object? source;
    for (final path in const [
      'packageTypes',
      'package_types',
      'packages.types',
      'packages.packageTypes',
      'packages.package_types',
      'package.types',
    ]) {
      source = _readPath(fields, path);
      if (source != null) break;
    }
    final values = source is List
        ? source
        : source?.toString().split(',') ?? const <String>[];
    final normalized = values
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    return normalized.isEmpty ? [..._defaultPackageTypes] : normalized;
  }

  void _showSnack(String title, String message) {
    Get.snackbar(title, message, snackPosition: SnackPosition.BOTTOM);
  }

  void _showDistanceExceeded(double distanceKm) {
    exceedingDistanceKm.value = distanceKm;
    isDistanceExceededVisible.value = true;
  }

  @override
  void onClose() {
    _pickupDebounce?.cancel();
    _dropDebounce?.cancel();
    pickupController.dispose();
    dropController.dispose();
    super.onClose();
  }
}

class _PackageLocation {
  const _PackageLocation({
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.placeId,
  });

  final String address;
  final double latitude;
  final double longitude;
  final String placeId;
}
