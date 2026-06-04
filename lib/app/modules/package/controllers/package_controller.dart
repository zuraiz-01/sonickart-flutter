// import 'dart:async';
// import 'dart:math';

// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:get/get.dart';
// import 'package:get_storage/get_storage.dart';

// import '../../../../firebase_options.dart';
// import '../../../core/constants/api_constants.dart';
// import '../../../core/network/api_service.dart';
// import '../../../core/services/local_notification_service.dart';
// import '../../../core/services/location_lookup_service.dart';
// import '../../../core/services/notification_service.dart';
// import '../../../core/widgets/app_snackbar.dart';
// import '../../../data/models/package_order_model.dart';
// import '../../../routes/app_routes.dart';
// import '../../auth/controllers/auth_controller.dart';

// enum PackageViewMode { send, orders }

// enum PackageStep { initial, pickup, drop, contact, type, review }

// enum PackageOrderType { send, receive }

// enum PackageMapTarget { pickup, dropIndex }

// extension PackageOrderTypeX on PackageOrderType {
//   String get apiValue => this == PackageOrderType.receive ? 'receive' : 'send';
// }

// class DropLocationData {
//   final TextEditingController controller = TextEditingController();
//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController phoneController = TextEditingController();
//   final Rxn<double> latitude = Rxn<double>();
//   final Rxn<double> longitude = Rxn<double>();
//   final RxString placeId = ''.obs;
//   final RxString addressText = ''.obs;
//   final RxList<PlaceSuggestion> suggestions = <PlaceSuggestion>[].obs;
//   final RxBool isResolving = false.obs;
//   Timer? debounce;

//   void dispose() {
//     controller.dispose();
//     nameController.dispose();
//     phoneController.dispose();
//     debounce?.cancel();
//   }

//   void clear() {
//     controller.clear();
//     nameController.clear();
//     phoneController.clear();
//     latitude.value = null;
//     longitude.value = null;
//     placeId.value = '';
//     addressText.value = '';
//     suggestions.clear();
//     isResolving.value = false;
//     debounce?.cancel();
//   }
// }

// class PackageController extends GetxController {
//   PackageController(this._storage);

//   static const _storageKey = 'package_orders';
//   static const _defaultPackageTypes = [
//     'Documents',
//     'Food',
//     'Parcel',
//     'Medicine',
//   ];
//   static const _defaultBaseDeliveryCharge = 30.0;
//   static const _defaultChargePerKm = 8.0;
//   static const _defaultMaxPackageDistanceKm = 30.0;
//   static const _defaultPackageMapRadiusMeters = 50000;
//   static const _maxDropCount = 5;

//   final GetStorage _storage;
//   final LocationLookupService _locationLookupService = LocationLookupService();

//   final pickupController = TextEditingController();
//   final senderNameController = TextEditingController();
//   final senderPhoneController = TextEditingController();

//   final dropLocations = <DropLocationData>[DropLocationData()].obs;

//   final viewMode = PackageViewMode.send.obs;
//   final currentStep = PackageStep.initial.obs;
//   final packageOrderType = PackageOrderType.send.obs;
//   final selectedPackageType = RxnString();
//   final agreementChecked = false.obs;
//   final orders = <PackageOrderModel>[].obs;
//   final isSubmitting = false.obs;
//   final isLoadingOrders = false.obs;
//   final isResolvingPickup = false.obs;
//   final isCalculatingRoute = false.obs;
//   final isMapPickerVisible = false.obs;
//   final isMapConfirming = false.obs;
//   final isDistanceExceededVisible = false.obs;
//   final exceedingDistanceKm = 0.0.obs;
//   final selectedOrder = Rxn<PackageOrderModel>();
//   final needsRatingForOrder = Rxn<PackageOrderModel>();
//   final _ratedOrderIds = <String>{};

//   final pickupLatitude = Rxn<double>();
//   final pickupLongitude = Rxn<double>();
//   final pickupPlaceId = ''.obs;
//   final pickupAddressText = ''.obs;
//   final pickupSuggestions = <PlaceSuggestion>[].obs;
//   final mapPickerTarget = Rxn<PackageMapTarget>();
//   final mapPickerDropIndex = 0.obs;
//   final mapDraftAddress = ''.obs;
//   final mapDraftLatitude = Rxn<double>();
//   final mapDraftLongitude = Rxn<double>();

//   final _packageTypes = <String>[..._defaultPackageTypes].obs;
//   final _baseDeliveryCharge = _defaultBaseDeliveryCharge.obs;
//   final _chargePerKm = _defaultChargePerKm.obs;
//   final _maxPackageDistanceKm = _defaultMaxPackageDistanceKm.obs;
//   final _packageMapRadiusMeters = _defaultPackageMapRadiusMeters.obs;
//   final _distanceMeters = 0.0.obs;
//   final _distanceText = ''.obs;
//   final _durationSeconds = 0.obs;
//   final _durationText = ''.obs;

//   Timer? _pickupDebounce;

//   List<String> get packageTypes => _packageTypes.toList(growable: false);

//   bool get canAddDrop =>
//       packageOrderType.value != PackageOrderType.receive &&
//       dropLocations.length < _maxDropCount;

//   int get dropCount => dropLocations.length;

//   List<MapEntry<int, DropLocationData>> get activeDropEntries => dropLocations
//       .asMap()
//       .entries
//       .where((entry) {
//         final drop = entry.value;
//         return drop.controller.text.trim().isNotEmpty ||
//             _hasValidCoordinates(drop.latitude.value, drop.longitude.value);
//       })
//       .toList(growable: false);

//   List<DropLocationData> get activeDropLocations =>
//       activeDropEntries.map((entry) => entry.value).toList(growable: false);

//   double get distanceKm => _distanceMeters.value / 1000;

//   String get distanceText => _distanceText.value.isNotEmpty
//       ? _distanceText.value
//       : (distanceKm > 0 ? '${distanceKm.toStringAsFixed(1)} km' : '--');

//   int get durationSeconds => _durationSeconds.value;

//   String get durationText =>
//       _durationText.value.isNotEmpty ? _durationText.value : '--';

//   double get deliveryCharge => _distanceMeters.value > 0
//       ? _baseDeliveryCharge.value + (distanceKm * _chargePerKm.value)
//       : 0;

//   double get totalPrice => deliveryCharge;

//   double get maxPackageDistanceKm => _maxPackageDistanceKm.value;

//   String get mapPickerTitle => mapPickerTarget.value == PackageMapTarget.pickup
//       ? 'Confirm Pickup Location'
//       : 'Confirm Drop Location #${mapPickerDropIndex.value + 1}';

//   String get mapPickerFallbackText =>
//       mapPickerTarget.value == PackageMapTarget.pickup
//       ? 'Move the pin on map to set exact pickup location'
//       : 'Move the pin on map to set exact drop location';

//   bool get canMoveFromPickup =>
//       pickupController.text.trim().isNotEmpty &&
//       _hasValidCoordinates(pickupLatitude.value, pickupLongitude.value);

//   bool get canMoveFromDrop {
//     return activeDropLocations.isNotEmpty;
//   }

//   bool get canAttemptPickup => pickupAddressText.value.trim().isNotEmpty;

//   bool get canMoveFromType => selectedPackageType.value?.isNotEmpty == true;

//   bool get canMoveFromContact {
//     final isReceive = packageOrderType.value == PackageOrderType.receive;
//     if (isReceive) {
//       final name = senderNameController.text.trim();
//       final phone = senderPhoneController.text.trim();
//       return name.length >= 2 && _isValidPhone(phone);
//     }
//     final activeDrops = activeDropLocations;
//     if (activeDrops.isEmpty) return false;
//     return activeDrops.every((drop) {
//       final name = drop.nameController.text.trim();
//       final phone = drop.phoneController.text.trim();
//       return name.length >= 2 && _isValidTenDigitPhone(phone);
//     });
//   }

//   bool get canSubmitReview =>
//       canMoveFromPickup &&
//       canMoveFromDrop &&
//       canMoveFromContact &&
//       canMoveFromType &&
//       agreementChecked.value &&
//       _distanceMeters.value > 0 &&
//       distanceKm <= _maxPackageDistanceKm.value;

//   @override
//   void onInit() {
//     super.onInit();
//     loadDeliverySettings();
//     loadOrders();
//   }

//   void addDrop() {
//     if (packageOrderType.value == PackageOrderType.receive) return;
//     if (dropLocations.length >= _maxDropCount) return;
//     dropLocations.add(DropLocationData());
//     _clearRouteSummary();
//   }

//   void removeDropAt(int index) {
//     if (dropLocations.length <= 1) return;
//     dropLocations[index].dispose();
//     dropLocations.removeAt(index);
//     _clearRouteSummary();
//   }

//   Future<void> loadDeliverySettings({bool force = false}) async {
//     try {
//       final firebaseHeaders = await _firebaseAuthHeaders();
//       if (firebaseHeaders == null || !Get.isRegistered<ApiService>()) return;
//       final options = DefaultFirebaseOptions.firestoreRestOptions;
//       final endpoint =
//           'https://firestore.googleapis.com/v1/projects/${options.projectId}/databases/(default)/documents/adminSettings/deliveryRadius?key=${options.apiKey}';
//       final response = await Get.find<ApiService>().get(
//         endpoint: endpoint,
//         authenticated: false,
//         headers: firebaseHeaders,
//       );
//       final fields = _decodeFirestoreFields(response['fields']);
//       _packageTypes.assignAll(_readPackageTypes(fields));
//       _baseDeliveryCharge.value = max(
//         0,
//         _readNumber(fields, const [
//           'baseFee',
//           'base_fee',
//           'packages.baseFee',
//           'packages.base_fee',
//         ], _defaultBaseDeliveryCharge),
//       );
//       _chargePerKm.value = max(
//         0,
//         _readNumber(fields, const [
//           'perKmFee',
//           'per_km_fee',
//           'packages.perKmFee',
//           'packages.per_km_fee',
//         ], _defaultChargePerKm),
//       );
//       _maxPackageDistanceKm.value = max(
//         1,
//         _readNumber(fields, const [
//           'maxDistanceKm',
//           'max_distance_km',
//           'packages.maxDistanceKm',
//           'packages.max_distance_km',
//         ], _defaultMaxPackageDistanceKm),
//       );
//       _packageMapRadiusMeters.value = max(
//         1000,
//         _readNumber(fields, const [
//           'mapRadiusMeters',
//           'map_radius_meters',
//           'packages.mapRadiusMeters',
//           'packages.map_radius_meters',
//         ], _defaultPackageMapRadiusMeters.toDouble()).round(),
//       );
//     } catch (error) {
//       debugPrint(
//         'PackageController.loadDeliverySettings: using defaults after $error',
//       );
//     }
//   }

//   void setViewMode(PackageViewMode mode) {
//     viewMode.value = mode;
//     if (mode == PackageViewMode.orders) {
//       loadOrders();
//     }
//   }

//   void startFlow(String flowType) {
//     resetDraft(keepOrders: true);
//     packageOrderType.value = flowType == 'receive'
//         ? PackageOrderType.receive
//         : PackageOrderType.send;
//     currentStep.value = packageOrderType.value == PackageOrderType.receive
//         ? PackageStep.drop
//         : PackageStep.pickup;
//   }

//   void goBackStep() {
//     switch (currentStep.value) {
//       case PackageStep.initial:
//         return;
//       case PackageStep.pickup:
//         currentStep.value = packageOrderType.value == PackageOrderType.receive
//             ? PackageStep.drop
//             : PackageStep.initial;
//         return;
//       case PackageStep.drop:
//         currentStep.value = packageOrderType.value == PackageOrderType.receive
//             ? PackageStep.initial
//             : PackageStep.pickup;
//         return;
//       case PackageStep.contact:
//         currentStep.value = packageOrderType.value == PackageOrderType.receive
//             ? PackageStep.pickup
//             : PackageStep.drop;
//         return;
//       case PackageStep.type:
//         currentStep.value = PackageStep.contact;
//         return;
//       case PackageStep.review:
//         currentStep.value = PackageStep.type;
//         return;
//     }
//   }

//   void onPickupChanged(String value) {
//     pickupAddressText.value = value;
//     _clearPickupCoordinates();
//     _pickupDebounce?.cancel();
//     if (value.trim().length < 2) {
//       pickupSuggestions.clear();
//       return;
//     }
//     _pickupDebounce = Timer(
//       const Duration(milliseconds: 350),
//       () => _loadSuggestions(value, isPickup: true, dropIndex: null),
//     );
//   }

//   void onDropChanged(int index, String value) {
//     if (index >= dropLocations.length) return;
//     final drop = dropLocations[index];
//     drop.addressText.value = value;
//     drop.latitude.value = null;
//     drop.longitude.value = null;
//     drop.placeId.value = '';
//     drop.debounce?.cancel();
//     if (value.trim().length < 2) {
//       drop.suggestions.clear();
//       return;
//     }
//     drop.debounce = Timer(
//       const Duration(milliseconds: 350),
//       () => _loadSuggestions(value, isPickup: false, dropIndex: index),
//     );
//   }

//   Future<void> selectPickupSuggestion(PlaceSuggestion suggestion) async {
//     await _applySuggestion(suggestion, isPickup: true, dropIndex: null);
//   }

//   Future<void> selectDropSuggestion(
//     int index,
//     PlaceSuggestion suggestion,
//   ) async {
//     await _applySuggestion(suggestion, isPickup: false, dropIndex: index);
//   }

//   Future<void> continueFromPickup() async {
//     final resolved = await _resolvePickupIfNeeded();
//     if (resolved == null) {
//       _showSnack('Pickup Required', 'Please select a valid pickup location.');
//       return;
//     }
//     if (packageOrderType.value == PackageOrderType.receive) {
//       if (!await _validateRouteRange(showErrors: true)) return;
//     }
//     _openMapPicker(PackageMapTarget.pickup, dropIndex: null);
//   }

//   Future<void> continueFromDrop() async {
//     final allResolved = await _resolveAllDropsIfNeeded();
//     if (allResolved == null) {
//       _showSnack('Drop Required', 'Please select valid drop locations.');
//       return;
//     }
//     if (packageOrderType.value == PackageOrderType.receive) {
//       currentStep.value = PackageStep.pickup;
//       return;
//     }
//     if (!await _validateRouteRange(showErrors: true)) return;
//     final firstDropIndex = _nextActiveDropIndexAfter(-1);
//     if (firstDropIndex == null) {
//       _showSnack('Drop Required', 'Please select valid drop locations.');
//       return;
//     }
//     _openMapPicker(PackageMapTarget.dropIndex, dropIndex: firstDropIndex);
//   }

//   void selectPackageType(String value) {
//     selectedPackageType.value = value;
//   }

//   void onContactChanged(String _) {
//     currentStep.refresh();
//   }

//   void onReceiverPhoneChanged(int index, String value) {
//     if (index >= 0 && index < dropLocations.length) {
//       final digits = _tenDigitPhoneText(value);
//       final phoneController = dropLocations[index].phoneController;
//       if (phoneController.text != digits) {
//         phoneController.value = TextEditingValue(
//           text: digits,
//           selection: TextSelection.collapsed(offset: digits.length),
//         );
//       }
//     }
//     currentStep.refresh();
//   }

//   void continueFromContact() {
//     if (!canMoveFromContact) {
//       _showSnack(
//         'Contact Required',
//         packageOrderType.value == PackageOrderType.receive
//             ? 'Please enter sender name and a valid sender phone number.'
//             : 'Please enter receiver name and a 10 digit phone number for all drop locations.',
//       );
//       return;
//     }
//     currentStep.value = PackageStep.type;
//   }

//   Future<void> continueFromType() async {
//     if (!canMoveFromType) {
//       _showSnack('Package Type Required', 'Please select a package type.');
//       return;
//     }
//     if (!await _updateRouteSummary(showErrors: true)) return;
//     currentStep.value = PackageStep.review;
//   }

//   void toggleAgreement() {
//     agreementChecked.toggle();
//   }

//   void onMapCameraMove(double latitude, double longitude) {
//     mapDraftLatitude.value = latitude;
//     mapDraftLongitude.value = longitude;
//   }

//   void closeMapPicker() {
//     isMapPickerVisible.value = false;
//     isMapConfirming.value = false;
//     mapPickerTarget.value = null;
//     mapDraftAddress.value = '';
//     mapDraftLatitude.value = null;
//     mapDraftLongitude.value = null;
//   }

//   void closeDistanceExceededModal() {
//     isDistanceExceededVisible.value = false;
//   }

//   Future<void> confirmMapLocation() async {
//     final target = mapPickerTarget.value;
//     final latitude = mapDraftLatitude.value;
//     final longitude = mapDraftLongitude.value;
//     if (target == null ||
//         !_hasValidCoordinates(latitude, longitude) ||
//         isMapConfirming.value) {
//       return;
//     }

//     isMapConfirming.value = true;
//     try {
//       final address = await _locationLookupService.reverseGeocodeToAddress(
//         latitude: latitude!,
//         longitude: longitude!,
//       );

//       if (target == PackageMapTarget.pickup) {
//         _applyPickupLocation(
//           _PackageLocation(
//             address:
//                 address ??
//                 _fallbackAddress(mapDraftAddress.value, latitude, longitude),
//             latitude: latitude,
//             longitude: longitude,
//             placeId: '',
//           ),
//         );
//         isMapPickerVisible.value = false;
//         if (packageOrderType.value == PackageOrderType.receive) {
//           if (await _updateRouteSummary(showErrors: true)) {
//             currentStep.value = PackageStep.contact;
//           }
//         } else {
//           currentStep.value = PackageStep.drop;
//         }
//         return;
//       }

//       final dropIdx = mapPickerDropIndex.value;
//       if (dropIdx >= 0 && dropIdx < dropLocations.length) {
//         _applyDropLocation(
//           dropIdx,
//           _PackageLocation(
//             address:
//                 address ??
//                 _fallbackAddress(mapDraftAddress.value, latitude, longitude),
//             latitude: latitude,
//             longitude: longitude,
//             placeId: '',
//           ),
//         );
//       }

//       isMapPickerVisible.value = false;
//       final nextDrop = _nextActiveDropIndexAfter(dropIdx);
//       if (nextDrop != null) {
//         _openMapPicker(PackageMapTarget.dropIndex, dropIndex: nextDrop);
//       } else if (await _updateRouteSummary(showErrors: true)) {
//         currentStep.value = PackageStep.contact;
//       }
//     } finally {
//       isMapConfirming.value = false;
//     }
//   }

//   Future<void> submitOrder() async {
//     if (!agreementChecked.value) {
//       _showSnack(
//         'Agreement Required',
//         'Please confirm package details before proceeding.',
//       );
//       return;
//     }
//     if (!await _updateRouteSummary(showErrors: true) || !canSubmitReview) {
//       _showSnack(
//         'Review Incomplete',
//         'Please complete pickup, drop, package type, and valid distance details.',
//       );
//       return;
//     }
//     if (isSubmitting.value) return;

//     isSubmitting.value = true;
//     try {
//       final authController = Get.isRegistered<AuthController>()
//           ? Get.find<AuthController>()
//           : null;
//       final user = authController?.currentUser;

//       final activeDrops = activeDropLocations;
//       final firstDrop = activeDrops.isNotEmpty ? activeDrops.first : null;
//       final dropAddresses = activeDrops
//           .map((d) => d.controller.text.trim())
//           .toList();
//       final dropLats = activeDrops.map((d) => d.latitude.value).toList();
//       final dropLngs = activeDrops.map((d) => d.longitude.value).toList();
//       final dropPids = activeDrops.map((d) => d.placeId.value).toList();
//       final dropReceiverNames = activeDrops
//           .map((d) => d.nameController.text.trim())
//           .toList();
//       final dropReceiverPhones = activeDrops
//           .map((d) => d.phoneController.text.trim())
//           .toList();

//       final draft = PackageOrderModel(
//         id: 'PKG${DateTime.now().millisecondsSinceEpoch}',
//         customerName: user?.name ?? 'SonicKart Customer',
//         customerPhone: user?.phone ?? '+91 0000000000',
//         packageType: selectedPackageType.value ?? 'Package',
//         packageOrderType: packageOrderType.value.apiValue,
//         senderName: packageOrderType.value == PackageOrderType.receive
//             ? senderNameController.text.trim()
//             : user?.name ?? 'SonicKart Customer',
//         senderPhone: packageOrderType.value == PackageOrderType.receive
//             ? senderPhoneController.text.trim()
//             : user?.phone ?? '',
//         receiverName: packageOrderType.value == PackageOrderType.receive
//             ? user?.name ?? 'SonicKart Customer'
//             : (firstDrop?.nameController.text.trim() ?? ''),
//         receiverPhone: packageOrderType.value == PackageOrderType.receive
//             ? user?.phone ?? ''
//             : (firstDrop?.phoneController.text.trim() ?? ''),
//         pickupAddress: pickupController.text.trim(),
//         pickupLatitude: pickupLatitude.value,
//         pickupLongitude: pickupLongitude.value,
//         pickupPlaceId: pickupPlaceId.value,
//         dropAddress: dropAddresses.isNotEmpty ? dropAddresses.first : '',
//         dropLatitude: dropLats.isNotEmpty ? dropLats.first : null,
//         dropLongitude: dropLngs.isNotEmpty ? dropLngs.first : null,
//         dropPlaceId: dropPids.isNotEmpty ? dropPids.first : '',
//         dropAddresses: dropAddresses,
//         dropLatitudes: dropLats,
//         dropLongitudes: dropLngs,
//         dropPlaceIds: dropPids,
//         dropReceiverNames: dropReceiverNames,
//         dropReceiverPhones: dropReceiverPhones,
//         distanceKm: distanceKm,
//         distanceText: distanceText,
//         durationSeconds: durationSeconds,
//         durationText: durationText,
//         deliveryCharge: deliveryCharge.roundToDouble(),
//         totalPrice: totalPrice.roundToDouble(),
//         status: 'pending',
//         createdAt: DateTime.now(),
//       );
//       final order = await _tryCreatePackageOrder(draft);
//       if (order == null) {
//         _showSnack(
//           'Order Creation Failed',
//           'Package order could not be created. Please check your connection and try again.',
//         );
//         return;
//       }
//       await _upsertOrder(order);
//       selectedOrder.value = order;
//       final label = order.packageOrderType == 'receive'
//           ? 'Package Receive Order Placed'
//           : 'Package Order Placed';
//       _notifyAction(
//         label,
//         'Your package order ${order.id} has been placed successfully.',
//       );
//       _showLocalPackageNotification(
//         label,
//         'Your package order ${order.id} has been placed successfully.',
//       );
//       resetDraft(keepOrders: true);
//       viewMode.value = PackageViewMode.orders;
//     } finally {
//       isSubmitting.value = false;
//     }
//   }

//   void openOrder(PackageOrderModel order) {
//     selectedOrder.value = order;
//     Get.toNamed(AppRoutes.packageDetails, arguments: {'orderId': order.id});
//   }

//   PackageOrderModel? findOrderById(String orderId) {
//     final normalized = _normalizeId(orderId);
//     for (final order in orders) {
//       if (_orderIdentifiers(order).map(_normalizeId).contains(normalized)) {
//         return order;
//       }
//     }
//     return null;
//   }

//   Future<PackageOrderModel?> refreshOrderDetails(String orderId) async {
//     final normalized = orderId.trim();
//     if (normalized.isEmpty) return selectedOrder.value;
//     final remote = await _tryFetchPackageOrderById(normalized);
//     if (remote != null) {
//       final updated = await _upsertOrder(remote);
//       selectedOrder.value = updated;
//       return updated;
//     }
//     final local = findOrderById(normalized);
//     if (local != null) selectedOrder.value = local;
//     return local;
//   }

//   List<String> packageOrderIdentifiers(PackageOrderModel order) =>
//       _orderIdentifiers(order);

//   Future<bool> handleRealtimePackagePayload(
//     Map<String, dynamic> payload, {
//     String? fallbackOrderId,
//   }) async {
//     final raw = _extractObject(payload);
//     final identifiers = _payloadIdentifiers(raw);
//     final fallback = _normalizeId(fallbackOrderId ?? '');
//     if (fallback.isNotEmpty &&
//         !identifiers.map(_normalizeId).contains(fallback)) {
//       return false;
//     }

//     final existing =
//         (fallback.isNotEmpty ? findOrderById(fallback) : null) ??
//         selectedOrder.value;
//     final merged = existing == null
//         ? raw
//         : <String, dynamic>{...existing.raw, ...existing.toJson(), ...raw};
//     final parsed = PackageOrderModel.fromJson(merged);
//     if (parsed.id.isEmpty) return false;

//     final updated = await _upsertOrder(
//       parsed,
//       allowCancellation: _hasExplicitCancellation(raw),
//     );
//     selectedOrder.value = updated;
//     return true;
//   }

//   Future<void> cancelPackageOrder(PackageOrderModel order) async {
//     if (_isTerminalStatus(order.status)) {
//       _showSnack('Cannot Cancel', 'This package order cannot be cancelled.');
//       return;
//     }
//     try {
//       final updated = await _tryCancelPackageOrder(order);
//       if (updated != null) {
//         final cancelled = await _upsertOrder(updated, allowCancellation: true);
//         selectedOrder.value = cancelled;
//       } else {
//         final cancelled = PackageOrderModel.fromJson({
//           ...order.toJson(),
//           'status': 'cancelled',
//           'deliveryStatus': 'cancelled',
//         });
//         final persisted = await _upsertOrder(
//           cancelled,
//           allowCancellation: true,
//         );
//         selectedOrder.value = persisted;
//       }
//       _showSnack(
//         'Package Cancelled',
//         'Your package order has been cancelled successfully.',
//       );
//     } catch (error) {
//       _showSnack(
//         'Cancel Failed',
//         'Package order could not be cancelled. Please try again.',
//       );
//     }
//   }

//   Future<void> loadOrders() async {
//     isLoadingOrders.value = true;
//     try {
//       final remote = await _tryFetchPackageOrders();
//       if (remote.isNotEmpty) {
//         orders.assignAll(remote);
//         await _persistOrders();
//         return;
//       }

//       final rawOrders =
//           _storage.read<List<dynamic>>(_storageKey) ?? <dynamic>[];
//       final restoredOrders =
//           rawOrders
//               .whereType<Map>()
//               .map(
//                 (item) =>
//                     PackageOrderModel.fromJson(Map<String, dynamic>.from(item)),
//               )
//               .toList()
//             ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
//       orders.assignAll(restoredOrders);
//     } finally {
//       isLoadingOrders.value = false;
//     }
//   }

//   Future<void> useAutoDetectedPickup() async {
//     await _useCurrentLocation(isPickup: true, dropIndex: null);
//   }

//   Future<void> useSuggestedDrop(int index) async {
//     await _useCurrentLocation(isPickup: false, dropIndex: index);
//   }

//   void resetDraft({bool keepOrders = false}) {
//     pickupController.clear();
//     for (final drop in dropLocations) {
//       drop.dispose();
//     }
//     dropLocations.clear();
//     dropLocations.add(DropLocationData());
//     senderNameController.clear();
//     senderPhoneController.clear();

//     pickupAddressText.value = '';
//     _clearPickupCoordinates();
//     pickupSuggestions.clear();
//     closeMapPicker();
//     selectedPackageType.value = null;
//     agreementChecked.value = false;
//     _distanceMeters.value = 0;
//     _distanceText.value = '';
//     _durationSeconds.value = 0;
//     _durationText.value = '';
//     currentStep.value = PackageStep.initial;
//     packageOrderType.value = PackageOrderType.send;
//     if (!keepOrders) {
//       orders.clear();
//     }
//   }

//   Future<void> _loadSuggestions(
//     String query, {
//     required bool isPickup,
//     int? dropIndex,
//   }) async {
//     try {
//       final bias = await _suggestionBias(
//         isPickup: isPickup,
//         dropIndex: dropIndex,
//       ).timeout(const Duration(milliseconds: 800), onTimeout: () => null);
//       final suggestions = await _locationLookupService.getPlaceSuggestions(
//         query,
//         latitude: bias?.latitude,
//         longitude: bias?.longitude,
//         radiusMeters: _packageMapRadiusMeters.value,
//       );
//       if (isPickup) {
//         if (pickupController.text.trim() == query.trim()) {
//           pickupSuggestions.assignAll(suggestions);
//         }
//       } else if (dropIndex != null && dropIndex < dropLocations.length) {
//         final drop = dropLocations[dropIndex];
//         if (drop.controller.text.trim() == query.trim()) {
//           drop.suggestions.assignAll(suggestions);
//         }
//       }
//     } catch (error) {
//       debugPrint('PackageController._loadSuggestions failed: $error');
//     }
//   }

//   Future<({double latitude, double longitude})?> _suggestionBias({
//     required bool isPickup,
//     int? dropIndex,
//   }) async {
//     if (isPickup) {
//       final lat = pickupLatitude.value;
//       final lng = pickupLongitude.value;
//       if (_hasValidCoordinates(lat, lng)) {
//         return (latitude: lat!, longitude: lng!);
//       }
//     } else if (dropIndex != null && dropIndex < dropLocations.length) {
//       final drop = dropLocations[dropIndex];
//       final lat = drop.latitude.value;
//       final lng = drop.longitude.value;
//       if (_hasValidCoordinates(lat, lng)) {
//         return (latitude: lat!, longitude: lng!);
//       }
//     }

//     try {
//       final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) return null;
//       var permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//       }
//       if (permission == LocationPermission.denied ||
//           permission == LocationPermission.deniedForever) {
//         return null;
//       }
//       final position = await Geolocator.getCurrentPosition(
//         locationSettings: const LocationSettings(
//           accuracy: LocationAccuracy.high,
//         ),
//       ).timeout(const Duration(seconds: 8));
//       return (latitude: position.latitude, longitude: position.longitude);
//     } catch (error) {
//       return null;
//     }
//   }

//   Future<void> _applySuggestion(
//     PlaceSuggestion suggestion, {
//     required bool isPickup,
//     int? dropIndex,
//   }) async {
//     final details = await _locationLookupService.getPlaceDetails(
//       suggestion.placeId,
//     );
//     if (details == null ||
//         !_hasValidCoordinates(details.latitude, details.longitude)) {
//       _showSnack('Location Error', 'Could not resolve selected location.');
//       return;
//     }
//     if (isPickup) {
//       _applyPickupLocation(
//         _PackageLocation(
//           address: details.address.isNotEmpty
//               ? details.address
//               : suggestion.description,
//           latitude: details.latitude!,
//           longitude: details.longitude!,
//           placeId: details.placeId,
//         ),
//       );
//     } else if (dropIndex != null && dropIndex < dropLocations.length) {
//       _applyDropLocation(
//         dropIndex,
//         _PackageLocation(
//           address: details.address.isNotEmpty
//               ? details.address
//               : suggestion.description,
//           latitude: details.latitude!,
//           longitude: details.longitude!,
//           placeId: details.placeId,
//         ),
//       );
//     }
//   }

//   Future<_PackageLocation?> _resolvePickupIfNeeded() async {
//     if (canMoveFromPickup) {
//       return _PackageLocation(
//         address: pickupController.text.trim(),
//         latitude: pickupLatitude.value!,
//         longitude: pickupLongitude.value!,
//         placeId: pickupPlaceId.value,
//       );
//     }
//     return _resolveTypedAddress(isPickup: true, dropIndex: null);
//   }

//   Future<List<_PackageLocation>?> _resolveAllDropsIfNeeded() async {
//     final results = <_PackageLocation>[];
//     for (final entry in activeDropEntries) {
//       final i = entry.key;
//       final drop = entry.value;
//       if (drop.controller.text.trim().isEmpty) continue;
//       if (_hasValidCoordinates(drop.latitude.value, drop.longitude.value)) {
//         results.add(
//           _PackageLocation(
//             address: drop.controller.text.trim(),
//             latitude: drop.latitude.value!,
//             longitude: drop.longitude.value!,
//             placeId: drop.placeId.value,
//           ),
//         );
//       } else {
//         final resolved = await _resolveTypedAddress(
//           isPickup: false,
//           dropIndex: i,
//         );
//         if (resolved == null) return null;
//         results.add(resolved);
//       }
//     }
//     if (results.isEmpty) return null;
//     return results;
//   }

//   Future<_PackageLocation?> _resolveTypedAddress({
//     required bool isPickup,
//     int? dropIndex,
//   }) async {
//     final controller = isPickup
//         ? pickupController
//         : (dropIndex != null && dropIndex < dropLocations.length
//               ? dropLocations[dropIndex].controller
//               : null);
//     if (controller == null) return null;
//     final address = controller.text.trim();
//     if (address.isEmpty) return null;
//     if (isPickup) {
//       isResolvingPickup.value = true;
//     } else if (dropIndex != null && dropIndex < dropLocations.length) {
//       dropLocations[dropIndex].isResolving.value = true;
//     }
//     try {
//       final details = await _locationLookupService.geocodeAddress(address);
//       if (details == null ||
//           !_hasValidCoordinates(details.latitude, details.longitude)) {
//         return null;
//       }
//       final location = _PackageLocation(
//         address: details.address.isNotEmpty ? details.address : address,
//         latitude: details.latitude!,
//         longitude: details.longitude!,
//         placeId: details.placeId,
//       );
//       if (isPickup) {
//         _applyPickupLocation(location);
//       } else if (dropIndex != null && dropIndex < dropLocations.length) {
//         _applyDropLocation(dropIndex, location);
//       }
//       return location;
//     } finally {
//       if (isPickup) {
//         isResolvingPickup.value = false;
//       } else if (dropIndex != null && dropIndex < dropLocations.length) {
//         dropLocations[dropIndex].isResolving.value = false;
//       }
//     }
//   }

//   void _applyPickupLocation(_PackageLocation location) {
//     pickupController.text = location.address;
//     pickupAddressText.value = location.address;
//     pickupLatitude.value = location.latitude;
//     pickupLongitude.value = location.longitude;
//     pickupPlaceId.value = location.placeId;
//     pickupSuggestions.clear();
//     _clearRouteSummary();
//   }

//   void _applyDropLocation(int index, _PackageLocation location) {
//     if (index >= dropLocations.length) return;
//     final drop = dropLocations[index];
//     drop.controller.text = location.address;
//     drop.addressText.value = location.address;
//     drop.latitude.value = location.latitude;
//     drop.longitude.value = location.longitude;
//     drop.placeId.value = location.placeId;
//     drop.suggestions.clear();
//     _clearRouteSummary();
//   }

//   void _openMapPicker(PackageMapTarget target, {int? dropIndex}) {
//     if (target == PackageMapTarget.pickup) {
//       if (!_hasValidCoordinates(pickupLatitude.value, pickupLongitude.value)) {
//         _showSnack(
//           'Location Required',
//           'Please select a valid location first.',
//         );
//         return;
//       }
//       mapPickerTarget.value = target;
//       mapDraftLatitude.value = pickupLatitude.value;
//       mapDraftLongitude.value = pickupLongitude.value;
//       mapDraftAddress.value = pickupController.text.trim();
//       isMapPickerVisible.value = true;
//       return;
//     }

//     final idx = dropIndex ?? 0;
//     mapPickerDropIndex.value = idx;
//     if (idx >= dropLocations.length) return;
//     final drop = dropLocations[idx];
//     if (!_hasValidCoordinates(drop.latitude.value, drop.longitude.value)) {
//       _showSnack('Location Required', 'Please select a valid location first.');
//       return;
//     }
//     mapPickerTarget.value = target;
//     mapDraftLatitude.value = drop.latitude.value;
//     mapDraftLongitude.value = drop.longitude.value;
//     mapDraftAddress.value = drop.controller.text.trim();
//     isMapPickerVisible.value = true;
//   }

//   int? _nextActiveDropIndexAfter(int index) {
//     for (final entry in activeDropEntries) {
//       if (entry.key > index) return entry.key;
//     }
//     return null;
//   }

//   Future<bool> _validateRouteRange({required bool showErrors}) async {
//     final pickup = await _resolvePickupIfNeeded();
//     final drops = await _resolveAllDropsIfNeeded();
//     if (pickup == null || drops == null || drops.isEmpty) return false;

//     final allPoints = [pickup, ...drops];
//     for (var i = 0; i < allPoints.length - 1; i++) {
//       final km = _calculateDistanceKm(
//         allPoints[i].latitude,
//         allPoints[i].longitude,
//         allPoints[i + 1].latitude,
//         allPoints[i + 1].longitude,
//       );
//       if (km > _maxPackageDistanceKm.value) {
//         if (showErrors) _showDistanceExceeded(km);
//         return false;
//       }
//     }
//     return true;
//   }

//   Future<bool> _updateRouteSummary({required bool showErrors}) async {
//     final pickup = await _resolvePickupIfNeeded();
//     final drops = await _resolveAllDropsIfNeeded();
//     if (pickup == null || drops == null || drops.isEmpty) {
//       if (showErrors) {
//         _showSnack(
//           'Location Required',
//           'Please select valid pickup and drop locations.',
//         );
//       }
//       return false;
//     }

//     final allPoints = [pickup, ...drops];

//     for (var i = 0; i < allPoints.length - 1; i++) {
//       final same =
//           (allPoints[i].latitude - allPoints[i + 1].latitude).abs() < 0.0001 &&
//           (allPoints[i].longitude - allPoints[i + 1].longitude).abs() < 0.0001;
//       if (same) {
//         if (showErrors) {
//           _showSnack(
//             'Invalid Route',
//             'Consecutive locations cannot be the same.',
//           );
//         }
//         return false;
//       }
//     }

//     isCalculatingRoute.value = true;
//     try {
//       var totalMeters = 0.0;
//       var totalSeconds = 0;
//       final segments = <String>[];

//       for (var i = 0; i < allPoints.length - 1; i++) {
//         final matrix = await _locationLookupService.getDistanceMatrix(
//           originLatitude: allPoints[i].latitude,
//           originLongitude: allPoints[i].longitude,
//           destinationLatitude: allPoints[i + 1].latitude,
//           destinationLongitude: allPoints[i + 1].longitude,
//         );
//         if (matrix == null) {
//           final km = _calculateDistanceKm(
//             allPoints[i].latitude,
//             allPoints[i].longitude,
//             allPoints[i + 1].latitude,
//             allPoints[i + 1].longitude,
//           );
//           totalMeters += km * 1000;
//           totalSeconds += (km / 0.35).round() * 60;
//           segments.add('${km.toStringAsFixed(1)} km');
//         } else {
//           totalMeters += matrix.distanceMeters;
//           totalSeconds += matrix.durationSeconds;
//           segments.add(matrix.distanceText);
//         }
//       }

//       final totalKm = totalMeters / 1000;
//       if (totalKm > _maxPackageDistanceKm.value) {
//         if (showErrors) _showDistanceExceeded(totalKm);
//         return false;
//       }

//       _distanceMeters.value = totalMeters;
//       _distanceText.value = segments.join(' → ');
//       _durationSeconds.value = totalSeconds;
//       _durationText.value = totalSeconds >= 3600
//           ? '${(totalSeconds / 3600).floor()}h ${((totalSeconds % 3600) / 60).round()}m'
//           : '${max(1, (totalSeconds / 60).round())} mins';
//       return true;
//     } finally {
//       isCalculatingRoute.value = false;
//     }
//   }

//   Future<void> _useCurrentLocation({
//     required bool isPickup,
//     int? dropIndex,
//   }) async {
//     if (!_locationLookupService.isConfigured) {
//       _showSnack('Location Error', 'Google location lookup is not configured.');
//       return;
//     }
//     if (!await _ensureLocationPermission()) return;
//     if (isPickup) {
//       isResolvingPickup.value = true;
//     } else if (dropIndex != null && dropIndex < dropLocations.length) {
//       dropLocations[dropIndex].isResolving.value = true;
//     }
//     try {
//       final position = await Geolocator.getCurrentPosition(
//         locationSettings: const LocationSettings(
//           accuracy: LocationAccuracy.high,
//         ),
//       );
//       final address = await _locationLookupService.reverseGeocodeToAddress(
//         latitude: position.latitude,
//         longitude: position.longitude,
//       );
//       final location = _PackageLocation(
//         address:
//             address ??
//             '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
//         latitude: position.latitude,
//         longitude: position.longitude,
//         placeId: '',
//       );
//       if (isPickup) {
//         _applyPickupLocation(location);
//       } else if (dropIndex != null && dropIndex < dropLocations.length) {
//         _applyDropLocation(dropIndex, location);
//       }
//     } finally {
//       if (isPickup) {
//         isResolvingPickup.value = false;
//       } else if (dropIndex != null && dropIndex < dropLocations.length) {
//         dropLocations[dropIndex].isResolving.value = false;
//       }
//     }
//   }

//   Future<void> _persistOrders() async {
//     final payload = orders.map((order) => order.toJson()).toList();
//     await _storage.write(_storageKey, payload);
//   }

//   Future<PackageOrderModel> _upsertOrder(
//     PackageOrderModel order, {
//     bool allowCancellation = false,
//   }) async {
//     final incomingIds = _orderIdentifiers(order).map(_normalizeId).toSet();
//     final index = orders.indexWhere(
//       (item) =>
//           _orderIdentifiers(item).map(_normalizeId).any(incomingIds.contains),
//     );
//     final existing = index >= 0 ? orders[index] : null;
//     final nextOrder = index >= 0
//         ? _protectStatusRegression(
//             orders[index],
//             order,
//             allowCancellation: allowCancellation,
//           )
//         : order;
//     if (index >= 0) {
//       orders[index] = nextOrder;
//     } else {
//       orders.insert(0, nextOrder);
//     }
//     orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
//     await _persistOrders();
//     _notifyPackageStatusChange(existing, nextOrder);
//     return nextOrder;
//   }

//   void _notifyPackageStatusChange(
//     PackageOrderModel? existing,
//     PackageOrderModel nextOrder,
//   ) {
//     final status = _normalizeStatus(nextOrder.status);
//     if (!_shouldNotifyPackageStatus(status)) return;
//     final previousStatus = existing == null
//         ? ''
//         : _normalizeStatus(existing.status);
//     if (existing != null && previousStatus == status) return;
//     final title = existing == null
//         ? (nextOrder.packageOrderType == 'receive'
//               ? 'Package Receive Order Sent'
//               : 'Package Order Sent')
//         : 'Package ${_statusTitle(status)}';
//     final message = existing == null
//         ? 'Your package order ${nextOrder.id} has been sent.'
//         : 'Your package order ${nextOrder.id} is ${_statusTitle(status).toLowerCase()}.';
//     _showLocalPackageNotification(title, message);

//     final wasDelivered =
//         previousStatus == 'delivered' || previousStatus == 'completed';
//     if (!wasDelivered &&
//         existing != null &&
//         (status == 'delivered' || status == 'completed') &&
//         !_ratedOrderIds.contains(nextOrder.id) &&
//         !_ratedOrderIds.containsAll(_orderIdentifiers(nextOrder))) {
//       needsRatingForOrder.value = nextOrder;
//     }
//   }

//   bool _shouldNotifyPackageStatus(String status) {
//     return const {
//       'placed',
//       'pending',
//       'sent',
//       'send',
//       'confirmed',
//       'accepted',
//       'assigned',
//       'picked',
//       'picked_up',
//       'arriving',
//       'out_for_delivery',
//       'delivered',
//       'completed',
//       'cancelled',
//       'prepared',
//       'ready',
//     }.contains(status);
//   }

//   String _statusTitle(String status) {
//     final normalized = status == 'picked' ? 'picked_up' : status;
//     return normalized
//         .replaceAll('_', ' ')
//         .split(RegExp(r'\s+'))
//         .where((word) => word.isNotEmpty)
//         .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
//         .join(' ');
//   }

//   PackageOrderModel _protectStatusRegression(
//     PackageOrderModel existing,
//     PackageOrderModel incoming, {
//     required bool allowCancellation,
//   }) {
//     final existingStatus = _normalizeStatus(existing.status);
//     final incomingStatus = _normalizeStatus(incoming.status);
//     final existingIsDone =
//         existingStatus == 'delivered' || existingStatus == 'completed';
//     final incomingIsCancel =
//         incomingStatus == 'cancel' ||
//         incomingStatus == 'canceled' ||
//         incomingStatus == 'cancelled';
//     final existingIsActive =
//         existingStatus.isNotEmpty &&
//         existingStatus != 'cancelled' &&
//         existingStatus != 'delivered' &&
//         existingStatus != 'completed';
//     if (existingIsActive && incomingIsCancel && !allowCancellation) {
//       return PackageOrderModel.fromJson({
//         ...incoming.raw,
//         ...incoming.toJson(),
//         'status': existing.status,
//         'deliveryStatus': existing.status,
//       });
//     }
//     if (!existingIsDone || !incomingIsCancel) return incoming;
//     return PackageOrderModel.fromJson({
//       ...incoming.raw,
//       ...incoming.toJson(),
//       'status': existing.status,
//       'deliveryStatus': existing.status,
//     });
//   }

//   Future<PackageOrderModel?> _tryCreatePackageOrder(
//     PackageOrderModel draft,
//   ) async {
//     if (!Get.isRegistered<ApiService>()) return null;
//     try {
//       final dropLocationsPayload = <Map<String, dynamic>>[];
//       final receiverContacts = <Map<String, dynamic>>[];
//       final dropAddrList = <String>[];
//       final dropLatList = <double?>[];
//       final dropLngList = <double?>[];
//       final dropPidList = <String>[];
//       final dropReceiverNames = <String>[];
//       final dropReceiverPhones = <String>[];
//       final dropPaymentAmounts = <double>[];
//       final dropPaymentStatuses = <String>[];
//       final activeDrops = activeDropLocations;
//       for (var index = 0; index < activeDrops.length; index++) {
//         final drop = activeDrops[index];
//         final addr = drop.controller.text.trim();
//         final rName = drop.nameController.text.trim();
//         final rPhone = drop.phoneController.text.trim();
//         final isFinalDrop = index == activeDrops.length - 1;
//         final paymentAmount = isFinalDrop
//             ? draft.deliveryCharge.roundToDouble()
//             : 0.0;
//         final paymentStatus = paymentAmount > 0 ? 'pending' : 'not_required';
//         dropAddrList.add(addr);
//         dropLatList.add(drop.latitude.value);
//         dropLngList.add(drop.longitude.value);
//         dropPidList.add(drop.placeId.value);
//         dropReceiverNames.add(rName);
//         dropReceiverPhones.add(rPhone);
//         dropPaymentAmounts.add(paymentAmount);
//         dropPaymentStatuses.add(paymentStatus);
//         dropLocationsPayload.add({
//           'sequence': index + 1,
//           'dropNumber': index + 1,
//           'drop_number': index + 1,
//           if (addr.isNotEmpty) 'address': addr,
//           if (_hasValidCoordinates(drop.latitude.value, drop.longitude.value))
//             'latitude': drop.latitude.value,
//           if (_hasValidCoordinates(drop.latitude.value, drop.longitude.value))
//             'longitude': drop.longitude.value,
//           if (drop.placeId.value.isNotEmpty) 'placeId': drop.placeId.value,
//           if (drop.placeId.value.isNotEmpty) 'place_id': drop.placeId.value,
//           if (rName.isNotEmpty) 'receiverName': rName,
//           if (rName.isNotEmpty) 'receiver_name': rName,
//           if (rPhone.isNotEmpty) 'receiverPhone': rPhone,
//           if (rPhone.isNotEmpty) 'receiver_phone': rPhone,
//           'paymentAmount': paymentAmount,
//           'payment_amount': paymentAmount,
//           'amountToCollect': paymentAmount,
//           'amount_to_collect': paymentAmount,
//           'paymentStatus': paymentStatus,
//           'payment_status': paymentStatus,
//           'status': 'pending',
//           'dropStatus': 'pending',
//           'drop_status': 'pending',
//         });
//         receiverContacts.add({
//           'sequence': index + 1,
//           'dropNumber': index + 1,
//           'drop_number': index + 1,
//           'name': rName,
//           'receiverName': rName,
//           'receiver_name': rName,
//           'phone': rPhone,
//           'receiverPhone': rPhone,
//           'receiver_phone': rPhone,
//           'paymentAmount': paymentAmount,
//           'payment_amount': paymentAmount,
//           'amountToCollect': paymentAmount,
//           'amount_to_collect': paymentAmount,
//           'paymentStatus': paymentStatus,
//           'payment_status': paymentStatus,
//         });
//       }

//       final payload = {
//         'pickupLocation': {
//           'address': draft.pickupAddress,
//           'latitude': draft.pickupLatitude,
//           'longitude': draft.pickupLongitude,
//           if (draft.pickupPlaceId.isNotEmpty) 'placeId': draft.pickupPlaceId,
//         },
//         'dropLocation': dropLocationsPayload.isNotEmpty
//             ? dropLocationsPayload.first
//             : null,
//         'dropAddresses': dropAddrList,
//         'dropLatitudes': dropLatList,
//         'dropLongitudes': dropLngList,
//         'dropPlaceIds': dropPidList,
//         'dropReceiverNames': dropReceiverNames,
//         'dropReceiverPhones': dropReceiverPhones,
//         'dropPaymentAmounts': dropPaymentAmounts,
//         'dropPaymentStatuses': dropPaymentStatuses,
//         'dropLocations': dropLocationsPayload,
//         'drop_locations': dropLocationsPayload,
//         'drop_addresses': dropAddrList,
//         'drop_latitudes': dropLatList,
//         'drop_longitudes': dropLngList,
//         'drop_place_ids': dropPidList,
//         'drop_receiver_names': dropReceiverNames,
//         'drop_receiver_phones': dropReceiverPhones,
//         'drop_payment_amounts': dropPaymentAmounts,
//         'drop_payment_statuses': dropPaymentStatuses,
//         'receiverContacts': receiverContacts,
//         'receiver_contacts': receiverContacts,
//         'totalDrops': dropLocationsPayload.length,
//         'total_drops': dropLocationsPayload.length,
//         'currentDropIndex': 0,
//         'current_drop_index': 0,
//         'packageType': draft.packageType,
//         'distance': (draft.distanceKm * 1000).round(),
//         'distanceText': draft.distanceText,
//         'duration': draft.durationSeconds,
//         'durationText': draft.durationText,
//         'deliveryCharge': draft.deliveryCharge,
//         'customerName': draft.customerName,
//         'customerPhone': draft.customerPhone,
//         'senderName': draft.senderName,
//         'senderPhone': draft.senderPhone,
//         'receiverName': draft.receiverName,
//         'receiverPhone': draft.receiverPhone,
//         'sender': {'name': draft.senderName, 'phone': draft.senderPhone},
//         'receiver': {'name': draft.receiverName, 'phone': draft.receiverPhone},
//         'orderType': 'package',
//         'packageOrderType': draft.packageOrderType,
//         'agreement': agreementChecked.value,
//       };
//       debugPrint(
//         'PackageController.createPackage drops=${dropLocationsPayload.length} '
//         'addresses=${dropAddrList.length} contacts=${receiverContacts.length}',
//       );
//       final response = await Get.find<ApiService>().post(
//         endpoint: ApiConstants.packageOrder,
//         data: payload,
//       );
//       final raw = _extractObject(response);
//       final parsed = PackageOrderModel.fromJson(raw);
//       return parsed.id.isEmpty ? null : parsed;
//     } catch (error) {
//       return null;
//     }
//   }

//   Map<String, dynamic> _extractObject(Map<String, dynamic> response) {
//     for (final value in [
//       response['data'],
//       response['order'],
//       response['packageOrder'],
//       response['result'],
//       response['item'],
//       response,
//     ]) {
//       if (value is Map) {
//         final map = Map<String, dynamic>.from(value);
//         for (final nested in ['order', 'packageOrder', 'data', 'result']) {
//           final nestedValue = map[nested];
//           if (nestedValue is Map) {
//             return Map<String, dynamic>.from(nestedValue);
//           }
//         }
//         return map;
//       }
//     }
//     return response;
//   }

//   Future<List<PackageOrderModel>> _tryFetchPackageOrders() async {
//     if (!Get.isRegistered<ApiService>()) return <PackageOrderModel>[];
//     try {
//       final authController = Get.isRegistered<AuthController>()
//           ? Get.find<AuthController>()
//           : null;
//       final userId = authController?.currentUser?.id ?? '';
//       final query = <String, dynamic>{};
//       if (userId.isNotEmpty) query['customerId'] = userId;
//       final response = await Get.find<ApiService>().get(
//         endpoint: ApiConstants.packageOrder,
//         query: query,
//       );
//       final list =
//           _extractList(response)
//               .whereType<Map>()
//               .map(
//                 (item) =>
//                     PackageOrderModel.fromJson(Map<String, dynamic>.from(item)),
//               )
//               .where((order) => order.id.isNotEmpty)
//               .toList()
//             ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
//       return list;
//     } catch (error) {
//       return <PackageOrderModel>[];
//     }
//   }

//   Future<PackageOrderModel?> _tryFetchPackageOrderById(String id) async {
//     if (!Get.isRegistered<ApiService>()) return null;
//     try {
//       for (final candidate in [id, _normalizeId(id)]) {
//         if (candidate.trim().isEmpty) continue;
//         final response = await Get.find<ApiService>().get(
//           endpoint: ApiConstants.packageOrderById(candidate),
//         );
//         final parsed = PackageOrderModel.fromJson(_extractObject(response));
//         if (parsed.id.isNotEmpty) return parsed;
//       }
//     } catch (error) {
//       debugPrint('PackageController._tryFetchPackageOrderById failed: $error');
//     }
//     return null;
//   }

//   Future<PackageOrderModel?> _tryCancelPackageOrder(
//     PackageOrderModel order,
//   ) async {
//     if (!Get.isRegistered<ApiService>()) return null;
//     final ids = _orderIdentifiers(order).map(_normalizeId).toSet().toList();
//     for (final id in ids) {
//       if (id.trim().isEmpty) continue;
//       try {
//         final response = await Get.find<ApiService>().post(
//           endpoint: '${ApiConstants.packageOrderById(id)}/cancel',
//         );
//         final parsed = PackageOrderModel.fromJson(_extractObject(response));
//         if (parsed.id.isNotEmpty) return parsed;
//       } catch (error) {
//         debugPrint('PackageController._tryCancelPackageOrder failed: $error');
//       }
//     }
//     return null;
//   }

//   List _extractList(Map<String, dynamic> response) {
//     final candidates = [
//       response['data'],
//       response['orders'],
//       response['items'],
//       response['result'],
//       response['results'],
//     ];
//     for (final value in candidates) {
//       if (value is List) return value;
//       if (value is Map) {
//         for (final nested in ['data', 'orders', 'items', 'result', 'results']) {
//           final nestedValue = value[nested];
//           if (nestedValue is List) return nestedValue;
//         }
//       }
//     }
//     return [];
//   }

//   Future<Map<String, String>?> _firebaseAuthHeaders() async {
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user == null) return null;
//       final token = await user.getIdToken();
//       if (token == null || token.trim().isEmpty) return null;
//       return {'Authorization': 'Bearer $token'};
//     } catch (error) {
//       return null;
//     }
//   }

//   Future<bool> _ensureLocationPermission() async {
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       _showSnack(
//         'Location Off',
//         'Please turn on device location to auto-detect address.',
//       );
//       return false;
//     }
//     var permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//     if (permission == LocationPermission.denied ||
//         permission == LocationPermission.deniedForever) {
//       _showSnack(
//         'Permission Required',
//         'Location permission is needed to detect your address.',
//       );
//       return false;
//     }
//     return true;
//   }

//   void _clearPickupCoordinates() {
//     pickupLatitude.value = null;
//     pickupLongitude.value = null;
//     pickupPlaceId.value = '';
//     _clearRouteSummary();
//   }

//   void _clearRouteSummary() {
//     _distanceMeters.value = 0;
//     _distanceText.value = '';
//     _durationSeconds.value = 0;
//     _durationText.value = '';
//   }

//   bool _hasValidCoordinates(double? lat, double? lng) {
//     return lat != null &&
//         lng != null &&
//         lat.isFinite &&
//         lng.isFinite &&
//         lat.abs() <= 90 &&
//         lng.abs() <= 180;
//   }

//   double _calculateDistanceKm(
//     double lat1,
//     double lon1,
//     double lat2,
//     double lon2,
//   ) {
//     const radiusKm = 6371.0;
//     final dLat = _toRadians(lat2 - lat1);
//     final dLon = _toRadians(lon2 - lon1);
//     final a =
//         sin(dLat / 2) * sin(dLat / 2) +
//         cos(_toRadians(lat1)) *
//             cos(_toRadians(lat2)) *
//             sin(dLon / 2) *
//             sin(dLon / 2);
//     final c = 2 * atan2(sqrt(a), sqrt(1 - a));
//     return double.parse((radiusKm * c).toStringAsFixed(2));
//   }

//   double _toRadians(double degrees) => degrees * (pi / 180);

//   String _fallbackAddress(String current, double latitude, double longitude) {
//     final trimmed = current.trim();
//     if (trimmed.isNotEmpty) return trimmed;
//     return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
//   }

//   List<String> _orderIdentifiers(PackageOrderModel order) {
//     return [
//           order.id,
//           order.raw['_id'],
//           order.raw['orderId'],
//           order.raw['orderNumber'],
//         ]
//         .map((value) => value?.toString().trim() ?? '')
//         .where((value) => value.isNotEmpty)
//         .toSet()
//         .toList();
//   }

//   List<String> _payloadIdentifiers(Map<String, dynamic> payload) {
//     return [
//           payload['id'],
//           payload['_id'],
//           payload['orderId'],
//           payload['orderNumber'],
//           payload['packageOrderId'],
//         ]
//         .map((value) => value?.toString().trim() ?? '')
//         .where((value) => value.isNotEmpty)
//         .toSet()
//         .toList();
//   }

//   String _normalizeId(String value) {
//     return value.trim().replaceFirst(RegExp(r'^PKG', caseSensitive: false), '');
//   }

//   String _normalizeStatus(String status) {
//     final normalized = status.trim().toLowerCase().replaceAll(
//       RegExp(r'[-\s]+'),
//       '_',
//     );
//     if (normalized == 'cancel' || normalized == 'canceled') return 'cancelled';
//     return normalized;
//   }

//   bool _hasExplicitCancellation(Map<String, dynamic> raw) {
//     final status = _normalizeStatus(raw['status']?.toString() ?? '');
//     if (status == 'cancelled') return true;
//     if (raw['isCancelled'] == true || raw['isCanceled'] == true) return true;
//     return [
//       raw['cancelledAt'],
//       raw['canceledAt'],
//       raw['cancelled_at'],
//       raw['canceled_at'],
//       raw['cancellationReason'],
//       raw['cancellation_reason'],
//       raw['cancelReason'],
//       raw['cancelledBy'],
//       raw['canceledBy'],
//     ].any((value) => value?.toString().trim().isNotEmpty == true);
//   }

//   bool _isTerminalStatus(String status) {
//     final normalized = _normalizeStatus(status);
//     return normalized == 'delivered' ||
//         normalized == 'completed' ||
//         normalized == 'cancelled';
//   }

//   bool _isValidPhone(String value) {
//     final digits = value.replaceAll(RegExp(r'\D'), '');
//     return digits.length >= 7 && digits.length <= 15;
//   }

//   bool _isValidTenDigitPhone(String value) {
//     final digits = _tenDigitPhoneText(value);
//     return digits.length == 10;
//   }

//   String _tenDigitPhoneText(String value) {
//     final digits = value.replaceAll(RegExp(r'\D'), '');
//     return digits.length <= 10 ? digits : digits.substring(0, 10);
//   }

//   Map<String, dynamic> _decodeFirestoreFields(Object? fields) {
//     if (fields is! Map) return const {};
//     return fields.map(
//       (key, value) => MapEntry(key.toString(), _decodeFirestoreValue(value)),
//     );
//   }

//   Object? _decodeFirestoreValue(Object? value) {
//     if (value is! Map) return value;
//     if (value.containsKey('stringValue')) return value['stringValue'];
//     if (value.containsKey('integerValue')) {
//       return num.tryParse(value['integerValue'].toString());
//     }
//     if (value.containsKey('doubleValue')) {
//       return num.tryParse(value['doubleValue'].toString());
//     }
//     if (value.containsKey('booleanValue')) return value['booleanValue'];
//     if (value.containsKey('arrayValue')) {
//       final values = value['arrayValue'] is Map
//           ? (value['arrayValue'] as Map)['values']
//           : null;
//       if (values is! List) return const [];
//       return values.map(_decodeFirestoreValue).toList();
//     }
//     if (value.containsKey('mapValue')) {
//       final fields = value['mapValue'] is Map
//           ? (value['mapValue'] as Map)['fields']
//           : null;
//       return _decodeFirestoreFields(fields);
//     }
//     return null;
//   }

//   Object? _readPath(Map<String, dynamic> source, String path) {
//     Object? current = source;
//     for (final segment in path.split('.')) {
//       if (current is! Map) return null;
//       current = current[segment];
//     }
//     return current;
//   }

//   double _readNumber(
//     Map<String, dynamic> source,
//     List<String> paths,
//     double fallback,
//   ) {
//     for (final path in paths) {
//       final value = _readPath(source, path);
//       if (value is num) return value.toDouble();
//       if (value is String) {
//         final parsed = double.tryParse(value);
//         if (parsed != null) return parsed;
//       }
//     }
//     return fallback;
//   }

//   List<String> _readPackageTypes(Map<String, dynamic> fields) {
//     Object? source;
//     for (final path in const [
//       'packageTypes',
//       'package_types',
//       'packages.types',
//       'packages.packageTypes',
//       'packages.package_types',
//       'package.types',
//     ]) {
//       source = _readPath(fields, path);
//       if (source != null) break;
//     }
//     final values = source is List
//         ? source
//         : source?.toString().split(',') ?? const <String>[];
//     final normalized = values
//         .map((item) => item.toString().trim())
//         .where((item) => item.isNotEmpty)
//         .toSet()
//         .toList();
//     return normalized.isEmpty ? [..._defaultPackageTypes] : normalized;
//   }

//   void _showSnack(String title, String message) {
//     AppSnackBar.show(title, message, snackPosition: SnackPosition.BOTTOM);
//   }

//   void _notifyAction(String title, String message) {
//     _showSnack(title, message);
//     if (!Get.isRegistered<NotificationService>()) return;
//     unawaited(
//       Get.find<NotificationService>().record(
//         title: title,
//         message: message,
//         category: 'package',
//       ),
//     );
//   }

//   void _showDistanceExceeded(double distanceKm) {
//     exceedingDistanceKm.value = distanceKm;
//     isDistanceExceededVisible.value = true;
//   }

//   Future<void> submitDeliveryRating({
//     required String orderId,
//     required int rating,
//     String feedback = '',
//   }) async {
//     _ratedOrderIds.add(orderId);
//     needsRatingForOrder.value = null;
//     if (!Get.isRegistered<ApiService>()) return;
//     try {
//       await Get.find<ApiService>().post(
//         endpoint: ApiConstants.packageOrderRating(orderId),
//         data: {
//           'orderId': orderId,
//           'rating': rating.clamp(1, 5),
//           if (feedback.isNotEmpty) 'feedback': feedback,
//         },
//       );
//     } catch (error) {
//       debugPrint('PackageController.submitDeliveryRating failed: $error');
//     }
//   }

//   String deliveryPartnerNameFor(PackageOrderModel order) {
//     final partner = order.raw['deliveryPartner'] is Map
//         ? Map<String, dynamic>.from(order.raw['deliveryPartner'] as Map)
//         : const <String, dynamic>{};
//     return _firstNonEmpty([
//           partner['name'],
//           partner['fullName'],
//           order.raw['deliveryPersonName'],
//           order.raw['riderName'],
//           order.raw['driverName'],
//           order.raw['deliveryPartnerName'],
//         ]) ??
//         '';
//   }

//   @override
//   void onClose() {
//     _pickupDebounce?.cancel();
//     for (final drop in dropLocations) {
//       drop.dispose();
//     }
//     pickupController.dispose();
//     senderNameController.dispose();
//     senderPhoneController.dispose();

//     super.onClose();
//   }

//   String? _firstNonEmpty(Iterable<Object?> values) {
//     for (final value in values) {
//       final text = value?.toString().trim() ?? '';
//       if (text.isNotEmpty) return text;
//     }
//     return null;
//   }
// }

// class _PackageLocation {
//   const _PackageLocation({
//     required this.address,
//     required this.latitude,
//     required this.longitude,
//     required this.placeId,
//   });

//   final String address;
//   final double latitude;
//   final double longitude;
//   final String placeId;
// }
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
import '../../../core/services/local_notification_service.dart';
import '../../../core/services/location_lookup_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../data/models/package_order_model.dart';
import '../../../routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/utils/auth_guard.dart';

enum PackageViewMode { send, orders }

enum PackageStep { initial, pickup, drop, contact, type, review }

enum PackageOrderType { send, receive }

enum PackageMapTarget { pickup, dropIndex }

extension PackageOrderTypeX on PackageOrderType {
  String get apiValue => this == PackageOrderType.receive ? 'receive' : 'send';
}

class DropLocationData {
  final TextEditingController controller = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final Rxn<double> latitude = Rxn<double>();
  final Rxn<double> longitude = Rxn<double>();
  final RxString placeId = ''.obs;
  final RxString addressText = ''.obs;
  final RxList<PlaceSuggestion> suggestions = <PlaceSuggestion>[].obs;
  final RxBool isResolving = false.obs;
  Timer? debounce;

  void dispose() {
    controller.dispose();
    nameController.dispose();
    phoneController.dispose();
    debounce?.cancel();
  }

  void clear() {
    controller.clear();
    nameController.clear();
    phoneController.clear();
    latitude.value = null;
    longitude.value = null;
    placeId.value = '';
    addressText.value = '';
    suggestions.clear();
    isResolving.value = false;
    debounce?.cancel();
  }
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
  static const _maxDropCount = 5;

  final GetStorage _storage;
  final LocationLookupService _locationLookupService = LocationLookupService();

  final pickupController = TextEditingController();
  final senderNameController = TextEditingController();
  final senderPhoneController = TextEditingController();

  final dropLocations = <DropLocationData>[DropLocationData()].obs;

  final viewMode = PackageViewMode.send.obs;
  final currentStep = PackageStep.initial.obs;
  final packageOrderType = PackageOrderType.send.obs;
  final selectedPackageType = RxnString();
  final agreementChecked = false.obs;
  final orders = <PackageOrderModel>[].obs;
  final isSubmitting = false.obs;
  final isLoadingOrders = false.obs;
  final isResolvingPickup = false.obs;
  final isCalculatingRoute = false.obs;
  final isMapPickerVisible = false.obs;
  final isMapConfirming = false.obs;
  final isDistanceExceededVisible = false.obs;
  final exceedingDistanceKm = 0.0.obs;
  final selectedOrder = Rxn<PackageOrderModel>();
  final needsRatingForOrder = Rxn<PackageOrderModel>();
  final _ratedOrderIds = <String>{};

  final pickupLatitude = Rxn<double>();
  final pickupLongitude = Rxn<double>();
  final pickupPlaceId = ''.obs;
  final pickupAddressText = ''.obs;
  final pickupSuggestions = <PlaceSuggestion>[].obs;
  final mapPickerTarget = Rxn<PackageMapTarget>();
  final mapPickerDropIndex = 0.obs;
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
  bool _detailsNavigationInFlight = false;

  List<String> get packageTypes => _packageTypes.toList(growable: false);

  bool get canAddDrop =>
      packageOrderType.value != PackageOrderType.receive &&
      dropLocations.length < _maxDropCount;

  int get dropCount => dropLocations.length;

  List<MapEntry<int, DropLocationData>> get activeDropEntries => dropLocations
      .asMap()
      .entries
      .where((entry) {
        final drop = entry.value;
        return drop.controller.text.trim().isNotEmpty ||
            _hasValidCoordinates(drop.latitude.value, drop.longitude.value);
      })
      .toList(growable: false);

  List<DropLocationData> get activeDropLocations =>
      activeDropEntries.map((entry) => entry.value).toList(growable: false);

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
      : 'Confirm Drop Location #${mapPickerDropIndex.value + 1}';

  String get mapPickerFallbackText =>
      mapPickerTarget.value == PackageMapTarget.pickup
      ? 'Move the pin on map to set exact pickup location'
      : 'Move the pin on map to set exact drop location';

  bool get canMoveFromPickup =>
      pickupController.text.trim().isNotEmpty &&
      _hasValidCoordinates(pickupLatitude.value, pickupLongitude.value);

  bool get canMoveFromDrop {
    return activeDropLocations.isNotEmpty;
  }

  bool get canAttemptPickup => pickupAddressText.value.trim().isNotEmpty;

  bool get canMoveFromType => selectedPackageType.value?.isNotEmpty == true;

  bool get canMoveFromContact {
    final isReceive = packageOrderType.value == PackageOrderType.receive;
    if (isReceive) {
      final name = senderNameController.text.trim();
      final phone = senderPhoneController.text.trim();
      return name.length >= 2 && _isValidPhone(phone);
    }
    final activeDrops = activeDropLocations;
    if (activeDrops.isEmpty) return false;
    return activeDrops.every((drop) {
      final name = drop.nameController.text.trim();
      final phone = drop.phoneController.text.trim();
      return name.length >= 2 && _isValidTenDigitPhone(phone);
    });
  }

  bool get canSubmitReview =>
      canMoveFromPickup &&
      canMoveFromDrop &&
      canMoveFromContact &&
      canMoveFromType &&
      agreementChecked.value &&
      _distanceMeters.value > 0 &&
      distanceKm <= _maxPackageDistanceKm.value;

  @override
  void onInit() {
    super.onInit();
    loadDeliverySettings();
    loadOrders();
  }

  void addDrop() {
    if (packageOrderType.value == PackageOrderType.receive) return;
    if (dropLocations.length >= _maxDropCount) return;
    dropLocations.add(DropLocationData());
    _clearRouteSummary();
  }

  void removeDropAt(int index) {
    if (dropLocations.length <= 1) return;
    dropLocations[index].dispose();
    dropLocations.removeAt(index);
    _clearRouteSummary();
  }

  Future<void> loadDeliverySettings({bool force = false}) async {
    try {
      final firebaseHeaders = await _firebaseAuthHeaders();
      if (firebaseHeaders == null || !Get.isRegistered<ApiService>()) return;
      final options = DefaultFirebaseOptions.firestoreRestOptions;
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
    if (mode != PackageViewMode.send) {
      closeTransientOverlays();
    }
    viewMode.value = mode;
    if (mode == PackageViewMode.orders) {
      loadOrders();
    }
  }

  void startFlow(String flowType) {
    resetDraft(keepOrders: true);
    packageOrderType.value = flowType == 'receive'
        ? PackageOrderType.receive
        : PackageOrderType.send;
    currentStep.value = packageOrderType.value == PackageOrderType.receive
        ? PackageStep.drop
        : PackageStep.pickup;
  }

  void goBackStep() {
    switch (currentStep.value) {
      case PackageStep.initial:
        return;
      case PackageStep.pickup:
        currentStep.value = packageOrderType.value == PackageOrderType.receive
            ? PackageStep.drop
            : PackageStep.initial;
        return;
      case PackageStep.drop:
        currentStep.value = packageOrderType.value == PackageOrderType.receive
            ? PackageStep.initial
            : PackageStep.pickup;
        return;
      case PackageStep.contact:
        currentStep.value = packageOrderType.value == PackageOrderType.receive
            ? PackageStep.pickup
            : PackageStep.drop;
        return;
      case PackageStep.type:
        currentStep.value = PackageStep.contact;
        return;
      case PackageStep.review:
        currentStep.value = PackageStep.type;
        return;
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
      () => _loadSuggestions(value, isPickup: true, dropIndex: null),
    );
  }

  void onDropChanged(int index, String value) {
    if (index >= dropLocations.length) return;
    final drop = dropLocations[index];
    drop.addressText.value = value;
    drop.latitude.value = null;
    drop.longitude.value = null;
    drop.placeId.value = '';
    drop.debounce?.cancel();
    if (value.trim().length < 2) {
      drop.suggestions.clear();
      return;
    }
    drop.debounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadSuggestions(value, isPickup: false, dropIndex: index),
    );
  }

  Future<void> selectPickupSuggestion(PlaceSuggestion suggestion) async {
    await _applySuggestion(suggestion, isPickup: true, dropIndex: null);
  }

  Future<void> selectDropSuggestion(
    int index,
    PlaceSuggestion suggestion,
  ) async {
    await _applySuggestion(suggestion, isPickup: false, dropIndex: index);
  }

  Future<void> continueFromPickup() async {
    final resolved = await _resolvePickupIfNeeded();
    if (resolved == null) {
      _showSnack('Pickup Required', 'Please select a valid pickup location.');
      return;
    }
    if (packageOrderType.value == PackageOrderType.receive) {
      if (!await _validateRouteRange(showErrors: true)) return;
    }
    _openMapPicker(PackageMapTarget.pickup, dropIndex: null);
  }

  Future<void> continueFromDrop() async {
    final allResolved = await _resolveAllDropsIfNeeded();
    if (allResolved == null) {
      _showSnack('Drop Required', 'Please select valid drop locations.');
      return;
    }
    if (packageOrderType.value == PackageOrderType.receive) {
      _openMapPicker(PackageMapTarget.dropIndex, dropIndex: 0);
      return;
    }
    if (!await _validateRouteRange(showErrors: true)) return;
    final firstDropIndex = _nextActiveDropIndexAfter(-1);
    if (firstDropIndex == null) {
      _showSnack('Drop Required', 'Please select valid drop locations.');
      return;
    }
    _openMapPicker(PackageMapTarget.dropIndex, dropIndex: firstDropIndex);
  }

  void selectPackageType(String value) {
    selectedPackageType.value = value;
  }

  void onContactChanged(String _) {
    currentStep.refresh();
  }

  void onSenderPhoneChanged(String value) {
    final digits = _tenDigitPhoneText(value);
    if (senderPhoneController.text != digits) {
      senderPhoneController.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }
    currentStep.refresh();
  }

  void onReceiverPhoneChanged(int index, String value) {
    if (index >= 0 && index < dropLocations.length) {
      final digits = _tenDigitPhoneText(value);
      final phoneController = dropLocations[index].phoneController;
      if (phoneController.text != digits) {
        phoneController.value = TextEditingValue(
          text: digits,
          selection: TextSelection.collapsed(offset: digits.length),
        );
      }
    }
    currentStep.refresh();
  }

  void continueFromContact() {
    if (!requireAuth()) return;
    if (!canMoveFromContact) {
      _showSnack(
        'Contact Required',
        packageOrderType.value == PackageOrderType.receive
            ? 'Please enter sender name and a valid sender phone number.'
            : 'Please enter receiver name and a 10 digit phone number for all drop locations.',
      );
      return;
    }
    currentStep.value = PackageStep.type;
  }

  Future<void> continueFromType() async {
    if (!canMoveFromType) {
      _showSnack('Package Type Required', 'Please select a package type.');
      return;
    }
    if (!await _updateRouteSummary(showErrors: true)) return;
    currentStep.value = PackageStep.review;
  }

  void toggleAgreement() {
    agreementChecked.toggle();
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

      if (target == PackageMapTarget.pickup) {
        _applyPickupLocation(
          _PackageLocation(
            address:
                address ??
                _fallbackAddress(mapDraftAddress.value, latitude, longitude),
            latitude: latitude,
            longitude: longitude,
            placeId: '',
          ),
        );
        isMapPickerVisible.value = false;
        if (packageOrderType.value == PackageOrderType.receive) {
          if (await _updateRouteSummary(showErrors: true)) {
            currentStep.value = PackageStep.contact;
          }
        } else {
          currentStep.value = PackageStep.drop;
        }
        return;
      }

      final dropIdx = mapPickerDropIndex.value;
      if (dropIdx >= 0 && dropIdx < dropLocations.length) {
        _applyDropLocation(
          dropIdx,
          _PackageLocation(
            address:
                address ??
                _fallbackAddress(mapDraftAddress.value, latitude, longitude),
            latitude: latitude,
            longitude: longitude,
            placeId: '',
          ),
        );
      }

      isMapPickerVisible.value = false;
      if (packageOrderType.value == PackageOrderType.receive) {
        currentStep.value = PackageStep.pickup;
        return;
      }
      final nextDrop = _nextActiveDropIndexAfter(dropIdx);
      if (nextDrop != null) {
        _openMapPicker(PackageMapTarget.dropIndex, dropIndex: nextDrop);
      } else if (await _updateRouteSummary(showErrors: true)) {
        currentStep.value = PackageStep.contact;
      }
    } finally {
      isMapConfirming.value = false;
    }
  }

  Future<void> submitOrder() async {
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
        'Please complete pickup, drop, package type, and valid distance details.',
      );
      return;
    }
    if (isSubmitting.value) return;

    isSubmitting.value = true;
    try {
      final authController = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : null;
      final user = authController?.currentUser;

      final activeDrops = activeDropLocations;
      final firstDrop = activeDrops.isNotEmpty ? activeDrops.first : null;
      final dropAddresses = activeDrops
          .map((d) => d.controller.text.trim())
          .toList();
      final dropLats = activeDrops.map((d) => d.latitude.value).toList();
      final dropLngs = activeDrops.map((d) => d.longitude.value).toList();
      final dropPids = activeDrops.map((d) => d.placeId.value).toList();
      final dropReceiverNames = activeDrops
          .map((d) => d.nameController.text.trim())
          .toList();
      final dropReceiverPhones = activeDrops
          .map((d) => d.phoneController.text.trim())
          .toList();

      final draft = PackageOrderModel(
        id: 'PKG${DateTime.now().millisecondsSinceEpoch}',
        customerName: user?.name ?? 'SonicKart Customer',
        customerPhone: user?.phone ?? '+91 0000000000',
        packageType: selectedPackageType.value ?? 'Package',
        packageOrderType: packageOrderType.value.apiValue,
        senderName: packageOrderType.value == PackageOrderType.receive
            ? senderNameController.text.trim()
            : user?.name ?? 'SonicKart Customer',
        senderPhone: packageOrderType.value == PackageOrderType.receive
            ? senderPhoneController.text.trim()
            : user?.phone ?? '',
        receiverName: packageOrderType.value == PackageOrderType.receive
            ? user?.name ?? 'SonicKart Customer'
            : (firstDrop?.nameController.text.trim() ?? ''),
        receiverPhone: packageOrderType.value == PackageOrderType.receive
            ? user?.phone ?? ''
            : (firstDrop?.phoneController.text.trim() ?? ''),
        pickupAddress: pickupController.text.trim(),
        pickupLatitude: pickupLatitude.value,
        pickupLongitude: pickupLongitude.value,
        pickupPlaceId: pickupPlaceId.value,
        dropAddress: dropAddresses.isNotEmpty ? dropAddresses.first : '',
        dropLatitude: dropLats.isNotEmpty ? dropLats.first : null,
        dropLongitude: dropLngs.isNotEmpty ? dropLngs.first : null,
        dropPlaceId: dropPids.isNotEmpty ? dropPids.first : '',
        dropAddresses: dropAddresses,
        dropLatitudes: dropLats,
        dropLongitudes: dropLngs,
        dropPlaceIds: dropPids,
        dropReceiverNames: dropReceiverNames,
        dropReceiverPhones: dropReceiverPhones,
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
          'Package order could not be created. Please check your connection and try again.',
        );
        return;
      }
      await _upsertOrder(order);
      selectedOrder.value = order;
      final label = order.packageOrderType == 'receive'
          ? 'Package Receive Order Placed'
          : 'Package Order Placed';
      await _notifyAction(
        label,
        'Your package order has been placed successfully.',
      );
      resetDraft(keepOrders: true);
      viewMode.value = PackageViewMode.orders;
      _openPackageDetailsSafely(order.id);
    } finally {
      isSubmitting.value = false;
    }
  }

  void openOrder(PackageOrderModel order) {
    selectedOrder.value = order;
    _openPackageDetailsSafely(order.id);
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
      final updated = await _upsertOrder(remote);
      selectedOrder.value = updated;
      return updated;
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
        : <String, dynamic>{...existing.raw, ...existing.toJson(), ...raw};
    final parsed = PackageOrderModel.fromJson(merged);
    if (parsed.id.isEmpty) return false;

    final updated = await _upsertOrder(
      parsed,
      allowCancellation: _hasExplicitCancellation(raw),
    );
    selectedOrder.value = updated;
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
        final cancelled = await _upsertOrder(updated, allowCancellation: true);
        selectedOrder.value = cancelled;
      } else {
        final cancelled = PackageOrderModel.fromJson({
          ...order.toJson(),
          'status': 'cancelled',
          'deliveryStatus': 'cancelled',
        });
        final persisted = await _upsertOrder(
          cancelled,
          allowCancellation: true,
        );
        selectedOrder.value = persisted;
      }
      _showSnack(
        'Package Cancelled',
        'Your package order has been cancelled successfully.',
      );
    } catch (error) {
      _showSnack(
        'Cancel Failed',
        'Package order could not be cancelled. Please try again.',
      );
    }
  }

  Future<void> loadOrders() async {
    isLoadingOrders.value = true;
    try {
      final restoredOrders = _restoreStoredOrders();
      if (restoredOrders.isNotEmpty) {
        orders.assignAll(restoredOrders);
      }

      final remote = await _tryFetchPackageOrders();
      if (remote.isNotEmpty) {
        orders.assignAll(remote);
        await _persistOrders();
        return;
      }
    } finally {
      isLoadingOrders.value = false;
    }
  }

  List<PackageOrderModel> _restoreStoredOrders() {
    final rawOrders = _storage.read<List<dynamic>>(_storageKey) ?? <dynamic>[];
    return rawOrders
        .whereType<Map>()
        .map(
          (item) => PackageOrderModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> useAutoDetectedPickup() async {
    await _useCurrentLocation(isPickup: true, dropIndex: null);
  }

  Future<void> useSuggestedDrop(int index) async {
    await _useCurrentLocation(isPickup: false, dropIndex: index);
  }

  void resetDraft({bool keepOrders = false}) {
    pickupController.clear();
    for (final drop in dropLocations) {
      drop.dispose();
    }
    dropLocations.clear();
    dropLocations.add(DropLocationData());
    senderNameController.clear();
    senderPhoneController.clear();

    pickupAddressText.value = '';
    _clearPickupCoordinates();
    pickupSuggestions.clear();
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

  void closeTransientOverlays() {
    _pickupDebounce?.cancel();
    pickupSuggestions.clear();
    isResolvingPickup.value = false;
    isCalculatingRoute.value = false;
    isMapPickerVisible.value = false;
    isMapConfirming.value = false;
    isDistanceExceededVisible.value = false;
    mapPickerTarget.value = null;
    mapDraftAddress.value = '';
    mapDraftLatitude.value = null;
    mapDraftLongitude.value = null;
    for (final drop in dropLocations) {
      drop.debounce?.cancel();
      drop.suggestions.clear();
      drop.isResolving.value = false;
    }
  }

  void _openPackageDetailsSafely(String orderId) {
    final id = orderId.trim();
    if (id.isEmpty || _detailsNavigationInFlight) return;
    _detailsNavigationInFlight = true;
    closeTransientOverlays();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.currentRoute != AppRoutes.packageDetails) {
        Get.toNamed(AppRoutes.packageDetails, arguments: {'orderId': id});
      }
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        _detailsNavigationInFlight = false;
      });
    });
  }

  Future<void> _loadSuggestions(
    String query, {
    required bool isPickup,
    int? dropIndex,
  }) async {
    try {
      final bias = await _suggestionBias(
        isPickup: isPickup,
        dropIndex: dropIndex,
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
      } else if (dropIndex != null && dropIndex < dropLocations.length) {
        final drop = dropLocations[dropIndex];
        if (drop.controller.text.trim() == query.trim()) {
          drop.suggestions.assignAll(suggestions);
        }
      }
    } catch (error) {
      debugPrint('PackageController._loadSuggestions failed: $error');
    }
  }

  Future<({double latitude, double longitude})?> _suggestionBias({
    required bool isPickup,
    int? dropIndex,
  }) async {
    if (isPickup) {
      final lat = pickupLatitude.value;
      final lng = pickupLongitude.value;
      if (_hasValidCoordinates(lat, lng)) {
        return (latitude: lat!, longitude: lng!);
      }
    } else if (dropIndex != null && dropIndex < dropLocations.length) {
      final drop = dropLocations[dropIndex];
      final lat = drop.latitude.value;
      final lng = drop.longitude.value;
      if (_hasValidCoordinates(lat, lng)) {
        return (latitude: lat!, longitude: lng!);
      }
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
      return null;
    }
  }

  Future<void> _applySuggestion(
    PlaceSuggestion suggestion, {
    required bool isPickup,
    int? dropIndex,
  }) async {
    final details = await _locationLookupService.getPlaceDetails(
      suggestion.placeId,
    );
    if (details == null ||
        !_hasValidCoordinates(details.latitude, details.longitude)) {
      _showSnack('Location Error', 'Could not resolve selected location.');
      return;
    }
    if (isPickup) {
      _applyPickupLocation(
        _PackageLocation(
          address: details.address.isNotEmpty
              ? details.address
              : suggestion.description,
          latitude: details.latitude!,
          longitude: details.longitude!,
          placeId: details.placeId,
        ),
      );
    } else if (dropIndex != null && dropIndex < dropLocations.length) {
      _applyDropLocation(
        dropIndex,
        _PackageLocation(
          address: details.address.isNotEmpty
              ? details.address
              : suggestion.description,
          latitude: details.latitude!,
          longitude: details.longitude!,
          placeId: details.placeId,
        ),
      );
    }
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
    return _resolveTypedAddress(isPickup: true, dropIndex: null);
  }

  Future<List<_PackageLocation>?> _resolveAllDropsIfNeeded() async {
    final results = <_PackageLocation>[];
    for (final entry in activeDropEntries) {
      final i = entry.key;
      final drop = entry.value;
      if (drop.controller.text.trim().isEmpty) continue;
      if (_hasValidCoordinates(drop.latitude.value, drop.longitude.value)) {
        results.add(
          _PackageLocation(
            address: drop.controller.text.trim(),
            latitude: drop.latitude.value!,
            longitude: drop.longitude.value!,
            placeId: drop.placeId.value,
          ),
        );
      } else {
        final resolved = await _resolveTypedAddress(
          isPickup: false,
          dropIndex: i,
        );
        if (resolved == null) return null;
        results.add(resolved);
      }
    }
    if (results.isEmpty) return null;
    return results;
  }

  Future<_PackageLocation?> _resolveTypedAddress({
    required bool isPickup,
    int? dropIndex,
  }) async {
    final controller = isPickup
        ? pickupController
        : (dropIndex != null && dropIndex < dropLocations.length
              ? dropLocations[dropIndex].controller
              : null);
    if (controller == null) return null;
    final address = controller.text.trim();
    if (address.isEmpty) return null;
    if (isPickup) {
      isResolvingPickup.value = true;
    } else if (dropIndex != null && dropIndex < dropLocations.length) {
      dropLocations[dropIndex].isResolving.value = true;
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
      if (isPickup) {
        _applyPickupLocation(location);
      } else if (dropIndex != null && dropIndex < dropLocations.length) {
        _applyDropLocation(dropIndex, location);
      }
      return location;
    } finally {
      if (isPickup) {
        isResolvingPickup.value = false;
      } else if (dropIndex != null && dropIndex < dropLocations.length) {
        dropLocations[dropIndex].isResolving.value = false;
      }
    }
  }

  void _applyPickupLocation(_PackageLocation location) {
    pickupController.text = location.address;
    pickupAddressText.value = location.address;
    pickupLatitude.value = location.latitude;
    pickupLongitude.value = location.longitude;
    pickupPlaceId.value = location.placeId;
    pickupSuggestions.clear();
    _clearRouteSummary();
  }

  void _applyDropLocation(int index, _PackageLocation location) {
    if (index >= dropLocations.length) return;
    final drop = dropLocations[index];
    drop.controller.text = location.address;
    drop.addressText.value = location.address;
    drop.latitude.value = location.latitude;
    drop.longitude.value = location.longitude;
    drop.placeId.value = location.placeId;
    drop.suggestions.clear();
    _clearRouteSummary();
  }

  void _openMapPicker(PackageMapTarget target, {int? dropIndex}) {
    if (target == PackageMapTarget.pickup) {
      if (!_hasValidCoordinates(pickupLatitude.value, pickupLongitude.value)) {
        _showSnack(
          'Location Required',
          'Please select a valid location first.',
        );
        return;
      }
      mapPickerTarget.value = target;
      mapDraftLatitude.value = pickupLatitude.value;
      mapDraftLongitude.value = pickupLongitude.value;
      mapDraftAddress.value = pickupController.text.trim();
      isMapPickerVisible.value = true;
      return;
    }

    final idx = dropIndex ?? 0;
    mapPickerDropIndex.value = idx;
    if (idx >= dropLocations.length) return;
    final drop = dropLocations[idx];
    if (!_hasValidCoordinates(drop.latitude.value, drop.longitude.value)) {
      _showSnack('Location Required', 'Please select a valid location first.');
      return;
    }
    mapPickerTarget.value = target;
    mapDraftLatitude.value = drop.latitude.value;
    mapDraftLongitude.value = drop.longitude.value;
    mapDraftAddress.value = drop.controller.text.trim();
    isMapPickerVisible.value = true;
  }

  int? _nextActiveDropIndexAfter(int index) {
    for (final entry in activeDropEntries) {
      if (entry.key > index) return entry.key;
    }
    return null;
  }

  Future<bool> _validateRouteRange({required bool showErrors}) async {
    final pickup = await _resolvePickupIfNeeded();
    final drops = await _resolveAllDropsIfNeeded();
    if (pickup == null || drops == null || drops.isEmpty) return false;

    final allPoints = [pickup, ...drops];
    for (var i = 0; i < allPoints.length - 1; i++) {
      final km = _calculateDistanceKm(
        allPoints[i].latitude,
        allPoints[i].longitude,
        allPoints[i + 1].latitude,
        allPoints[i + 1].longitude,
      );
      if (km > _maxPackageDistanceKm.value) {
        if (showErrors) _showDistanceExceeded(km);
        return false;
      }
    }
    return true;
  }

  Future<bool> _updateRouteSummary({required bool showErrors}) async {
    final pickup = await _resolvePickupIfNeeded();
    final drops = await _resolveAllDropsIfNeeded();
    if (pickup == null || drops == null || drops.isEmpty) {
      if (showErrors) {
        _showSnack(
          'Location Required',
          'Please select valid pickup and drop locations.',
        );
      }
      return false;
    }

    final allPoints = [pickup, ...drops];

    for (var i = 0; i < allPoints.length - 1; i++) {
      final same =
          (allPoints[i].latitude - allPoints[i + 1].latitude).abs() < 0.0001 &&
          (allPoints[i].longitude - allPoints[i + 1].longitude).abs() < 0.0001;
      if (same) {
        if (showErrors) {
          _showSnack(
            'Invalid Route',
            'Consecutive locations cannot be the same.',
          );
        }
        return false;
      }
    }

    isCalculatingRoute.value = true;
    try {
      var totalMeters = 0.0;
      var totalSeconds = 0;
      final segments = <String>[];

      for (var i = 0; i < allPoints.length - 1; i++) {
        final matrix = await _locationLookupService.getDistanceMatrix(
          originLatitude: allPoints[i].latitude,
          originLongitude: allPoints[i].longitude,
          destinationLatitude: allPoints[i + 1].latitude,
          destinationLongitude: allPoints[i + 1].longitude,
        );
        if (matrix == null) {
          final km = _calculateDistanceKm(
            allPoints[i].latitude,
            allPoints[i].longitude,
            allPoints[i + 1].latitude,
            allPoints[i + 1].longitude,
          );
          totalMeters += km * 1000;
          totalSeconds += (km / 0.35).round() * 60;
          segments.add('${km.toStringAsFixed(1)} km');
        } else {
          totalMeters += matrix.distanceMeters;
          totalSeconds += matrix.durationSeconds;
          segments.add(matrix.distanceText);
        }
      }

      final totalKm = totalMeters / 1000;
      if (totalKm > _maxPackageDistanceKm.value) {
        if (showErrors) _showDistanceExceeded(totalKm);
        return false;
      }

      _distanceMeters.value = totalMeters;
      _distanceText.value = segments.join(' → ');
      _durationSeconds.value = totalSeconds;
      _durationText.value = totalSeconds >= 3600
          ? '${(totalSeconds / 3600).floor()}h ${((totalSeconds % 3600) / 60).round()}m'
          : '${max(1, (totalSeconds / 60).round())} mins';
      return true;
    } finally {
      isCalculatingRoute.value = false;
    }
  }

  Future<void> _useCurrentLocation({
    required bool isPickup,
    int? dropIndex,
  }) async {
    if (!_locationLookupService.isConfigured) {
      _showSnack('Location Error', 'Google location lookup is not configured.');
      return;
    }
    if (!await _ensureLocationPermission()) return;
    if (isPickup) {
      isResolvingPickup.value = true;
    } else if (dropIndex != null && dropIndex < dropLocations.length) {
      dropLocations[dropIndex].isResolving.value = true;
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
      final location = _PackageLocation(
        address:
            address ??
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
        latitude: position.latitude,
        longitude: position.longitude,
        placeId: '',
      );
      if (isPickup) {
        _applyPickupLocation(location);
      } else if (dropIndex != null && dropIndex < dropLocations.length) {
        _applyDropLocation(dropIndex, location);
      }
    } finally {
      if (isPickup) {
        isResolvingPickup.value = false;
      } else if (dropIndex != null && dropIndex < dropLocations.length) {
        dropLocations[dropIndex].isResolving.value = false;
      }
    }
  }

  Future<void> _persistOrders() async {
    final payload = orders.map((order) => order.toJson()).toList();
    await _storage.write(_storageKey, payload);
  }

  Future<PackageOrderModel> _upsertOrder(
    PackageOrderModel order, {
    bool allowCancellation = false,
  }) async {
    final incomingIds = _orderIdentifiers(order).map(_normalizeId).toSet();
    final index = orders.indexWhere(
      (item) =>
          _orderIdentifiers(item).map(_normalizeId).any(incomingIds.contains),
    );
    final existing = index >= 0 ? orders[index] : null;
    final nextOrder = index >= 0
        ? _protectStatusRegression(
            orders[index],
            order,
            allowCancellation: allowCancellation,
          )
        : order;
    if (index >= 0) {
      orders[index] = nextOrder;
    } else {
      orders.insert(0, nextOrder);
    }
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _persistOrders();
    _notifyPackageStatusChange(existing, nextOrder);
    return nextOrder;
  }

  void _notifyPackageStatusChange(
    PackageOrderModel? existing,
    PackageOrderModel nextOrder,
  ) {
    final status = _normalizeStatus(nextOrder.status);
    if (!_shouldNotifyPackageStatus(status)) return;
    if (existing == null) return;
    final previousStatus = _normalizeStatus(existing.status);
    if (previousStatus == status) return;

    if (Get.isRegistered<LocalNotificationService>()) {
      final title = 'Package ${_statusTitle(status)}';
      final message =
          'Your package order ${nextOrder.id} is ${_statusTitle(status).toLowerCase()}.';
      Get.find<LocalNotificationService>().show(
        title: title,
        body: message,
        channelId: 'sonickart_package_updates',
        channelName: 'Package updates',
        channelDescription: 'Package order status notifications',
      );
    }

    final wasDelivered =
        previousStatus == 'delivered' || previousStatus == 'completed';
    if (!wasDelivered &&
        (status == 'delivered' || status == 'completed') &&
        !_ratedOrderIds.contains(nextOrder.id) &&
        !_ratedOrderIds.containsAll(_orderIdentifiers(nextOrder))) {
      needsRatingForOrder.value = nextOrder;
    }
  }

  bool _shouldNotifyPackageStatus(String status) {
    return const {
      'placed',
      'pending',
      'sent',
      'send',
      'confirmed',
      'accepted',
      'assigned',
      'picked',
      'picked_up',
      'arriving',
      'out_for_delivery',
      'delivered',
      'completed',
      'cancelled',
      'prepared',
      'ready',
    }.contains(status);
  }

  String _statusTitle(String status) {
    final normalized = status == 'picked' ? 'picked_up' : status;
    return normalized
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  PackageOrderModel _protectStatusRegression(
    PackageOrderModel existing,
    PackageOrderModel incoming, {
    required bool allowCancellation,
  }) {
    final existingStatus = _normalizeStatus(existing.status);
    final incomingStatus = _normalizeStatus(incoming.status);
    final existingIsDone =
        existingStatus == 'delivered' || existingStatus == 'completed';
    final incomingIsCancel =
        incomingStatus == 'cancel' ||
        incomingStatus == 'canceled' ||
        incomingStatus == 'cancelled';
    final existingIsActive =
        existingStatus.isNotEmpty &&
        existingStatus != 'cancelled' &&
        existingStatus != 'delivered' &&
        existingStatus != 'completed';
    if (existingIsActive && incomingIsCancel && !allowCancellation) {
      return PackageOrderModel.fromJson({
        ...incoming.raw,
        ...incoming.toJson(),
        'status': existing.status,
        'deliveryStatus': existing.status,
      });
    }
    if (!existingIsDone || !incomingIsCancel) return incoming;
    return PackageOrderModel.fromJson({
      ...incoming.raw,
      ...incoming.toJson(),
      'status': existing.status,
      'deliveryStatus': existing.status,
    });
  }

  Future<PackageOrderModel?> _tryCreatePackageOrder(
    PackageOrderModel draft,
  ) async {
    if (!Get.isRegistered<ApiService>()) return null;
    try {
      final dropLocationsPayload = <Map<String, dynamic>>[];
      final receiverContacts = <Map<String, dynamic>>[];
      final dropAddrList = <String>[];
      final dropLatList = <double?>[];
      final dropLngList = <double?>[];
      final dropPidList = <String>[];
      final dropReceiverNames = <String>[];
      final dropReceiverPhones = <String>[];
      final dropPaymentAmounts = <double>[];
      final dropPaymentStatuses = <String>[];
      final dropStatuses = <String>[];
      final activeDrops = activeDropLocations;
      for (var index = 0; index < activeDrops.length; index++) {
        final drop = activeDrops[index];
        final addr = drop.controller.text.trim();
        final rName = drop.nameController.text.trim();
        final rPhone = drop.phoneController.text.trim();
        final isFinalDrop = index == activeDrops.length - 1;
        final paymentAmount = isFinalDrop
            ? draft.deliveryCharge.roundToDouble()
            : 0.0;
        final paymentStatus = paymentAmount > 0 ? 'pending' : 'not_required';
        dropAddrList.add(addr);
        dropLatList.add(drop.latitude.value);
        dropLngList.add(drop.longitude.value);
        dropPidList.add(drop.placeId.value);
        dropReceiverNames.add(rName);
        dropReceiverPhones.add(rPhone);
        dropPaymentAmounts.add(paymentAmount);
        dropPaymentStatuses.add(paymentStatus);
        dropStatuses.add('pending');
        dropLocationsPayload.add({
          'sequence': index + 1,
          'dropNumber': index + 1,
          'drop_number': index + 1,
          if (addr.isNotEmpty) 'address': addr,
          if (_hasValidCoordinates(drop.latitude.value, drop.longitude.value))
            'latitude': drop.latitude.value,
          if (_hasValidCoordinates(drop.latitude.value, drop.longitude.value))
            'longitude': drop.longitude.value,
          if (drop.placeId.value.isNotEmpty) 'placeId': drop.placeId.value,
          if (drop.placeId.value.isNotEmpty) 'place_id': drop.placeId.value,
          if (rName.isNotEmpty) 'receiverName': rName,
          if (rName.isNotEmpty) 'receiver_name': rName,
          if (rPhone.isNotEmpty) 'receiverPhone': rPhone,
          if (rPhone.isNotEmpty) 'receiver_phone': rPhone,
          'paymentAmount': paymentAmount,
          'payment_amount': paymentAmount,
          'amountToCollect': paymentAmount,
          'amount_to_collect': paymentAmount,
          'paymentStatus': paymentStatus,
          'payment_status': paymentStatus,
          'status': 'pending',
          'dropStatus': 'pending',
          'drop_status': 'pending',
        });
        receiverContacts.add({
          'sequence': index + 1,
          'dropNumber': index + 1,
          'drop_number': index + 1,
          'name': rName,
          'receiverName': rName,
          'receiver_name': rName,
          'phone': rPhone,
          'receiverPhone': rPhone,
          'receiver_phone': rPhone,
          'paymentAmount': paymentAmount,
          'payment_amount': paymentAmount,
          'amountToCollect': paymentAmount,
          'amount_to_collect': paymentAmount,
          'paymentStatus': paymentStatus,
          'payment_status': paymentStatus,
        });
      }

      final payload = {
        'pickupLocation': {
          'address': draft.pickupAddress,
          'latitude': draft.pickupLatitude,
          'longitude': draft.pickupLongitude,
          if (draft.pickupPlaceId.isNotEmpty) 'placeId': draft.pickupPlaceId,
        },
        'dropLocation': dropLocationsPayload.isNotEmpty
            ? dropLocationsPayload.first
            : null,
        'dropAddresses': dropAddrList,
        'dropLatitudes': dropLatList,
        'dropLongitudes': dropLngList,
        'dropPlaceIds': dropPidList,
        'dropReceiverNames': dropReceiverNames,
        'dropReceiverPhones': dropReceiverPhones,
        'dropPaymentAmounts': dropPaymentAmounts,
        'dropPaymentStatuses': dropPaymentStatuses,
        'dropStatuses': dropStatuses,
        'dropLocations': dropLocationsPayload,
        'drop_locations': dropLocationsPayload,
        'drops': dropLocationsPayload,
        'locations': dropLocationsPayload,
        'activeDrops': dropLocationsPayload,
        'active_drops': dropLocationsPayload,
        'drop_addresses': dropAddrList,
        'drop_latitudes': dropLatList,
        'drop_longitudes': dropLngList,
        'drop_place_ids': dropPidList,
        'drop_receiver_names': dropReceiverNames,
        'drop_receiver_phones': dropReceiverPhones,
        'drop_payment_amounts': dropPaymentAmounts,
        'drop_payment_statuses': dropPaymentStatuses,
        'drop_statuses': dropStatuses,
        'receiverContacts': receiverContacts,
        'receiver_contacts': receiverContacts,
        'totalDrops': dropLocationsPayload.length,
        'total_drops': dropLocationsPayload.length,
        'numberOfDrops': dropLocationsPayload.length,
        'number_of_drops': dropLocationsPayload.length,
        'dropCount': dropLocationsPayload.length,
        'drop_count': dropLocationsPayload.length,
        'currentDropIndex': 0,
        'current_drop_index': 0,
        'packageType': draft.packageType,
        'distance': (draft.distanceKm * 1000).round(),
        'distanceText': draft.distanceText,
        'duration': draft.durationSeconds,
        'durationText': draft.durationText,
        'deliveryCharge': draft.deliveryCharge,
        'customerName': draft.customerName,
        'customerPhone': draft.customerPhone,
        'senderName': draft.senderName,
        'senderPhone': draft.senderPhone,
        'receiverName': draft.receiverName,
        'receiverPhone': draft.receiverPhone,
        'sender': {'name': draft.senderName, 'phone': draft.senderPhone},
        'receiver': {'name': draft.receiverName, 'phone': draft.receiverPhone},
        'orderType': 'package',
        'packageOrderType': draft.packageOrderType,
        'status': 'pending',
        'deliveryStatus': 'pending',
        'delivery_status': 'pending',
        'packageStatus': 'pending',
        'package_status': 'pending',
        'agreement': agreementChecked.value,
      };
      debugPrint(
        'PackageController.createPackage drops=${dropLocationsPayload.length} '
        'addresses=${dropAddrList.length} contacts=${receiverContacts.length}',
      );
      debugPrint('PackageController.createPackage payload=$payload');
      final response = await Get.find<ApiService>().post(
        endpoint: ApiConstants.packageOrder,
        data: payload,
      );
      final raw = _extractObject(response);
      final parsed = PackageOrderModel.fromJson(raw);
      return parsed.id.isEmpty ? null : parsed;
    } catch (error) {
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

  String _normalizeStatus(String status) {
    final normalized = status.trim().toLowerCase().replaceAll(
      RegExp(r'[-\s]+'),
      '_',
    );
    if (normalized == 'cancel' || normalized == 'canceled') return 'cancelled';
    return normalized;
  }

  bool _hasExplicitCancellation(Map<String, dynamic> raw) {
    final status = _normalizeStatus(raw['status']?.toString() ?? '');
    if (status == 'cancelled') return true;
    if (raw['isCancelled'] == true || raw['isCanceled'] == true) return true;
    return [
      raw['cancelledAt'],
      raw['canceledAt'],
      raw['cancelled_at'],
      raw['canceled_at'],
      raw['cancellationReason'],
      raw['cancellation_reason'],
      raw['cancelReason'],
      raw['cancelledBy'],
      raw['canceledBy'],
    ].any((value) => value?.toString().trim().isNotEmpty == true);
  }

  bool _isTerminalStatus(String status) {
    final normalized = _normalizeStatus(status);
    return normalized == 'delivered' ||
        normalized == 'completed' ||
        normalized == 'cancelled';
  }

  bool _isValidPhone(String value) {
    return _isValidTenDigitPhone(value);
  }

  bool _isValidTenDigitPhone(String value) {
    final digits = _tenDigitPhoneText(value);
    return digits.length == 10;
  }

  String _tenDigitPhoneText(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length <= 10 ? digits : digits.substring(0, 10);
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
    AppSnackBar.show(title, message, snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> _notifyAction(String title, String message) async {
    _showSnack(title, message);
    if (Get.isRegistered<NotificationService>()) {
      await Get.find<NotificationService>().record(
        title: title,
        message: message,
        category: 'package',
      );
    }
    if (Get.isRegistered<LocalNotificationService>()) {
      await Get.find<LocalNotificationService>().show(
        title: title,
        body: message,
        channelId: 'sonickart_package_updates',
        channelName: 'Package updates',
        channelDescription: 'Package order notifications',
      );
    }
  }

  void _showDistanceExceeded(double distanceKm) {
    exceedingDistanceKm.value = distanceKm;
    isDistanceExceededVisible.value = true;
  }

  Future<void> submitDeliveryRating({
    required String orderId,
    required int rating,
    String feedback = '',
  }) async {
    if (!Get.isRegistered<ApiService>()) return;
    final normalizedRating = rating.clamp(1, 5).toInt();
    final trimmedFeedback = feedback.trim();
    try {
      final response = await Get.find<ApiService>().post(
        endpoint: ApiConstants.packageOrderRating(orderId),
        data: {
          'orderId': orderId,
          'rating': normalizedRating,
          if (trimmedFeedback.isNotEmpty) 'feedback': trimmedFeedback,
        },
      );
      final responseObject = _extractObject(response);
      final submittedRating =
          _ratingFromResponse(responseObject) ?? normalizedRating;
      final submittedFeedback =
          _firstNonEmpty([
            responseObject['feedback'],
            responseObject['ratingFeedback'],
            responseObject['rating_feedback'],
            responseObject['deliveryFeedback'],
            responseObject['delivery_feedback'],
          ]) ??
          trimmedFeedback;
      final updatedOrder = await _markOrderRated(
        orderId: orderId,
        rating: submittedRating,
        feedback: submittedFeedback,
        response: responseObject,
      );
      _ratedOrderIds.addAll(
        updatedOrder == null ? [orderId] : _orderIdentifiers(updatedOrder),
      );
      needsRatingForOrder.value = null;
    } catch (error) {
      debugPrint('PackageController.submitDeliveryRating failed: $error');
      final message = error is ApiException ? error.message : error.toString();
      if (message.toLowerCase().contains('already') &&
          message.toLowerCase().contains('rated')) {
        _ratedOrderIds.add(orderId);
        needsRatingForOrder.value = null;
        return;
      }
      rethrow;
    }
  }

  Future<PackageOrderModel?> _markOrderRated({
    required String orderId,
    required int rating,
    required String feedback,
    required Map<String, dynamic> response,
  }) async {
    final localOrder = findOrderById(orderId) ?? selectedOrder.value;
    if (localOrder == null) return null;

    final now = DateTime.now().toIso8601String();
    final merged = <String, dynamic>{
      ...localOrder.raw,
      ...localOrder.toJson(),
      ...response,
      'rating': rating,
      'ratingFeedback': feedback,
      'rating_feedback': feedback,
      'deliveryRating': rating,
      'delivery_rating': rating,
      'deliveryFeedback': feedback,
      'delivery_feedback': feedback,
      'ratedAt': response['ratedAt'] ?? response['rated_at'] ?? now,
      'rated_at': response['rated_at'] ?? response['ratedAt'] ?? now,
    };
    final updated = await _upsertOrder(PackageOrderModel.fromJson(merged));
    if (_orderIdentifiers(
      updated,
    ).map(_normalizeId).contains(_normalizeId(orderId))) {
      selectedOrder.value = updated;
    }
    return updated;
  }

  int? _ratingFromResponse(Map<String, dynamic> response) {
    for (final key in ['rating', 'deliveryRating', 'delivery_rating']) {
      final value = response[key];
      final parsed = value is num
          ? value.toInt()
          : int.tryParse(value?.toString() ?? '');
      if (parsed != null && parsed >= 1 && parsed <= 5) return parsed;
    }
    return null;
  }

  String deliveryPartnerNameFor(PackageOrderModel order) {
    final partner = order.raw['deliveryPartner'] is Map
        ? Map<String, dynamic>.from(order.raw['deliveryPartner'] as Map)
        : const <String, dynamic>{};
    return _firstNonEmpty([
          partner['name'],
          partner['fullName'],
          order.raw['deliveryPersonName'],
          order.raw['riderName'],
          order.raw['driverName'],
          order.raw['deliveryPartnerName'],
        ]) ??
        '';
  }

  @override
  void onClose() {
    _pickupDebounce?.cancel();
    for (final drop in dropLocations) {
      drop.dispose();
    }
    pickupController.dispose();
    senderNameController.dispose();
    senderPhoneController.dispose();

    super.onClose();
  }

  String? _firstNonEmpty(Iterable<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
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
