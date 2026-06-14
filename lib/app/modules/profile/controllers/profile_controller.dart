import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/location_lookup_service.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/models/address_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../core/services/app_session_scope.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../routes/app_routes.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../categories/controllers/categories_controller.dart';
import '../../dashboard/controllers/dashboard_controller.dart';

class ProfileController extends GetxController {
  ProfileController(this._storage);

  static const _addressStorageKey = 'saved_addresses';
  static const _currentUserStorageKey = 'currentUser';
  static const _selectedAddressStorageKey = 'selectedAddress';
  static const _selectedVendorIdStorageKey = 'selectedVendorId';
  static const _selectedLocationServiceableStorageKey =
      'selectedLocationServiceable';
  static const _selectedServiceLocationSessionStorageKey =
      AppSessionScope.selectedServiceLocationSessionKey;
  static const _transientLocationAddressIds = {
    'live-location',
    'service-location',
    'blocked-service-location',
  };

  final GetStorage _storage;
  final LocationLookupService _locationLookupService = LocationLookupService();

  final isEditModalVisible = false.obs;
  final activeInfoModal = RxnString();
  final isSavingProfile = false.obs;
  final isLoadingAddresses = false.obs;
  final isResolvingLocation = false.obs;
  final isResolvingSuggestions = false.obs;
  final addresses = <AddressModel>[].obs;
  final placeSuggestions = <PlaceSuggestion>[].obs;
  final addressLoadError = RxnString();
  final requiresAddressRelogin = false.obs;
  final statusMessage = RxnString();
  final selectedAddressId = RxnString();
  final editingAddress = Rxn<AddressModel>();
  final liveLocationAddress = ''.obs;
  final draftLatitude = Rxn<double>();
  final draftLongitude = Rxn<double>();
  final draftPlaceId = RxnString();
  final walletBalance = 0.0.obs;
  final rewardPoints = 0.obs;
  final refundCount = 0.obs;
  final giftCardCount = 0.obs;
  final notificationsEnabled = false.obs;
  final isUpdatingNotifications = false.obs;
  final isDeletingAccount = false.obs;
  final _profileRevision = 0.obs;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressNameController = TextEditingController();
  final addressPhoneController = TextEditingController();
  final addressLineController = TextEditingController();
  Timer? _addressSuggestionDebounce;

  UserModel? get currentUser {
    final rawUser = _storage.read(_currentUserStorageKey);
    if (rawUser is Map) {
      return UserModel.fromJson(Map<String, dynamic>.from(rawUser));
    }
    return null;
  }

  bool get hasBackendSession {
    final token = _storage.read<String>('accessToken');
    return token != null && token.trim().isNotEmpty;
  }

  AddressModel? get activeAddress {
    final selectedId = selectedAddressId.value?.trim();
    final stored = _storedSelectedAddress;
    if (selectedId != null && selectedId.isNotEmpty) {
      final selectedFromList = addresses.firstWhereOrNull(
        (item) => item.id == selectedId,
      );
      if (selectedFromList != null) {
        return selectedFromList;
      }
      if (stored != null && stored.id == selectedId) {
        return stored;
      }
    }

    final selectedByFlag = addresses.firstWhereOrNull(
      (item) => item.isSelected,
    );
    if (selectedByFlag != null) {
      return selectedByFlag;
    }
    if (stored != null && !_isTransientLocationAddress(stored)) {
      return stored;
    }
    if (selectedId == null || selectedId.isEmpty) {
      return null;
    }
    return addresses.firstWhereOrNull((item) => item.id == selectedId);
  }

  String get dashboardPrimaryLabel {
    _profileRevision.value;
    if (hasBackendSession || _storage.read('isLoggedIn') == true) {
      final displayName = _customerDisplayName(currentUser);
      if (displayName.isNotEmpty) {
        return 'Hi, $displayName';
      }
    }
    return 'Hi, Customer';
  }

  String get dashboardAddressLabel {
    final selectedAddress = activeAddress?.address.trim() ?? '';
    if (selectedAddress.isNotEmpty) {
      return selectedAddress;
    }
    final liveAddress = liveLocationAddress.value.trim();
    if (liveAddress.isNotEmpty) {
      return liveAddress;
    }
    return 'Select delivery address';
  }

  String _customerDisplayName(UserModel? user) {
    final name = user?.name.trim() ?? '';
    if (name.isNotEmpty && !_isGenericCustomerName(name)) {
      return name;
    }
    final phone = user?.phone.trim() ?? '';
    if (phone.isNotEmpty) {
      return phone;
    }
    return name.isNotEmpty ? name : '';
  }

  bool _isGenericCustomerName(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    return const {
      'customer',
      'guest',
      'guest user',
      'sonickart customer',
      'sonic kart customer',
    }.contains(normalized);
  }

  AddressModel? get _storedSelectedAddress {
    final raw = _storage.read(_selectedAddressStorageKey);
    if (raw is Map) {
      return AddressModel.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  String? get _storedSelectedVendorId {
    final value = _storage.read(_selectedVendorIdStorageKey);
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  AddressModel? get _storedServiceableServiceLocation {
    if (_storage.read(_selectedLocationServiceableStorageKey) != true) {
      return null;
    }
    if (!AppSessionScope.isCurrentSession(
      _storage.read(_selectedServiceLocationSessionStorageKey),
    )) {
      return null;
    }
    final stored = _storedSelectedAddress;
    if (stored == null || stored.id.trim() != 'service-location') {
      return null;
    }
    if (stored.address.trim().isEmpty || !_hasValidCoordinates(stored)) {
      return null;
    }
    return stored;
  }

  String get initials {
    final seed = currentUser?.name.isNotEmpty == true
        ? currentUser!.name
        : (currentUser?.phone.isNotEmpty == true
              ? currentUser!.phone
              : 'Guest');
    final parts = seed
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'G';
    }
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return '${parts.first.characters.first}${parts[1].characters.first}'
        .toUpperCase();
  }

  @override
  void onInit() {
    super.onInit();
    debugPrint('ProfileController.onInit: profile flow started');
    unawaited(_bootstrapProfile());
  }

  Future<void> _bootstrapProfile() async {
    _syncProfileForm();
    unawaited(syncNotificationPreference());
    if (!hasBackendSession) {
      _restoreGuestCatalogContext();
      await loadAddresses();
      await _resolveHomeLocationPreview(forceRefresh: true);
      return;
    }

    await loadAddresses();
    await loadProfileSummary();
  }

  Future<void> refreshForAuthenticatedSession() async {
    debugPrint(
      'ProfileController.refreshForAuthenticatedSession: refreshing profile session',
    );
    final serviceLocationToKeep = _storedServiceableServiceLocation;
    statusMessage.value = null;
    addressLoadError.value = null;
    requiresAddressRelogin.value = false;
    _syncProfileForm();
    unawaited(syncNotificationPreference());
    await loadProfileSummary();
    await loadAddresses();
    if (serviceLocationToKeep != null) {
      await _restoreAuthenticatedServiceAreaLocation(serviceLocationToKeep);
      return;
    }
    if (activeAddress == null) {
      await _resolveHomeLocationPreview(forceRefresh: true);
    }
  }

  void clearSessionState() {
    debugPrint('ProfileController.clearSessionState: clearing session state');
    clearTransientOverlays();
    addresses.clear();
    placeSuggestions.clear();
    addressLoadError.value = null;
    requiresAddressRelogin.value = false;
    statusMessage.value = null;
    selectedAddressId.value = null;
    editingAddress.value = null;
    liveLocationAddress.value = '';
    draftLatitude.value = null;
    draftLongitude.value = null;
    draftPlaceId.value = null;
    addressNameController.clear();
    addressPhoneController.clear();
    addressLineController.clear();
    _syncProfileForm();
  }

  void openEditProfile() {
    debugPrint('ProfileController.openEditProfile: opening edit modal');
    _syncProfileForm();
    activeInfoModal.value = null;
    isEditModalVisible.value = true;
  }

  void closeEditProfile() {
    debugPrint('ProfileController.closeEditProfile: closing edit modal');
    isEditModalVisible.value = false;
  }

  Future<void> saveProfile() async {
    final trimmedPhone = phoneController.text.trim();
    final trimmedName = nameController.text.trim();
    if (trimmedPhone.length < 10) {
      AppSnackBar.show(
        'Phone Required',
        'Enter a valid 10-digit phone number.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    isSavingProfile.value = true;
    try {
      final localUser = UserModel(
        id: currentUser?.id ?? 'usr-local',
        name: trimmedName.isEmpty ? 'SonicKart Customer' : trimmedName,
        email: currentUser?.email ?? '',
        phone: trimmedPhone,
      );
      final user = await _tryUpdateProfileRemote(localUser) ?? localUser;
      await _storage.write(_currentUserStorageKey, user.toJson());
      _profileRevision.value++;
      debugPrint(
        'ProfileController.saveProfile: saved profile name=${user.name} phone=${user.phone}',
      );
      closeEditProfile();
      statusMessage.value = 'Profile updated successfully.';
      _notifyAction(
        'Profile Updated',
        'Your profile information was updated.',
        category: 'profile',
      );
    } finally {
      isSavingProfile.value = false;
    }
  }

  Future<void> loadProfileSummary() async {
    if (!Get.isRegistered<ApiService>() || !hasBackendSession) return;
    try {
      final response = await Get.find<ApiService>().get(
        endpoint: ApiConstants.user,
      );
      final raw = _extractObject(response);
      final userRaw = raw['user'] is Map
          ? Map<String, dynamic>.from(raw['user'] as Map)
          : raw['customer'] is Map
          ? Map<String, dynamic>.from(raw['customer'] as Map)
          : raw;
      final user = UserModel.fromJson(userRaw);
      if (user.id.isNotEmpty || user.phone.isNotEmpty) {
        await _storage.write(_currentUserStorageKey, user.toJson());
        _profileRevision.value++;
        _syncProfileForm();
      }
      walletBalance.value =
          _numberFrom(
            raw['walletBalance'] ??
                raw['wallet_balance'] ??
                userRaw['walletBalance'] ??
                userRaw['wallet_balance'],
          ) ??
          walletBalance.value;
      rewardPoints.value =
          (_numberFrom(
                    raw['rewardPoints'] ??
                        raw['reward_points'] ??
                        userRaw['rewardPoints'] ??
                        userRaw['reward_points'],
                  ) ??
                  rewardPoints.value)
              .round();
      refundCount.value =
          (_numberFrom(raw['refundCount'] ?? raw['refund_count']) ??
                  refundCount.value)
              .round();
      giftCardCount.value =
          (_numberFrom(raw['giftCardCount'] ?? raw['gift_card_count']) ??
                  giftCardCount.value)
              .round();
    } catch (error) {
      debugPrint('ProfileController.loadProfileSummary failed: $error');
    }
  }

  (String, String) infoModalContent(String key) {
    return switch (key) {
      'wallet' => (
        'Wallet',
        'Available balance: ₹${walletBalance.value.toStringAsFixed(0)}. Wallet top-up is available from supported payment channels.',
      ),
      'rewards' => (
        'Rewards',
        'Earn points on every order. Feature coming soon!',
      ),
      'refunds' => (
        'Refunds',
        'View and manage your refund requests. Feature coming soon!',
      ),
      'giftcards' => (
        'Gift Cards',
        'Purchase and send gift cards to your loved ones. Feature coming soon!',
      ),
      'notifications' => (
        'Notifications',
        'Use the notification switch in Profile to control order and package update alerts.',
      ),
      'suggest' => (
        'Suggest Products',
        "Have a product suggestion? We'd love to hear from you! Feature coming soon!",
      ),
      'about' => (
        'About',
        'SonicKart customer app is connected with live catalog, orders, package delivery and address flows.',
      ),
      _ => ('Coming Soon', 'This section will be available shortly.'),
    };
  }

  void openInfoModal(String key) {
    debugPrint('ProfileController.openInfoModal: opening modal $key');
    isEditModalVisible.value = false;
    activeInfoModal.value = key;
  }

  void closeInfoModal() {
    debugPrint('ProfileController.closeInfoModal: closing info modal');
    activeInfoModal.value = null;
  }

  void clearTransientOverlays() {
    isEditModalVisible.value = false;
    activeInfoModal.value = null;
    isSavingProfile.value = false;
  }

  void openOrders() {
    debugPrint('ProfileController.openOrders: redirecting to customer orders');
    clearTransientOverlays();
    Get.toNamed(AppRoutes.customerOrders);
  }

  Future<void> openHelp() async {
    debugPrint('ProfileController.openHelp: opening email composer');
    final emailUri = Uri(
      scheme: 'mailto',
      path: 'support@sonickartnow.com',
      queryParameters: {'subject': 'Need help'},
    );
    try {
      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('ProfileController.openHelp failed: $error');
    }
  }

  Future<void> openWebsite() async {
    debugPrint('ProfileController.openWebsite: opening SonicKart website');
    clearTransientOverlays();
    final uri = Uri.parse('https://sonickartnow.com');
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (error) {
      debugPrint('ProfileController.openWebsite external failed: $error');
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (opened) return;
    } catch (error) {
      debugPrint('ProfileController.openWebsite platform failed: $error');
    }

    AppSnackBar.show(
      'Website Error',
      'Unable to open website. Please check browser app and try again.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void handleMenuAction(String action) {
    debugPrint('ProfileController.handleMenuAction: action=$action');
    switch (action) {
      case 'addresses':
        clearTransientOverlays();
        Get.toNamed(AppRoutes.addressBook);
        return;
      case 'notifications':
        clearTransientOverlays();
        Get.toNamed(AppRoutes.notifications);
        return;
      case 'edit':
        openEditProfile();
        return;
      case 'about':
        unawaited(openWebsite());
        return;
      default:
        openInfoModal(action);
    }
  }

  Future<void> logout() async {
    debugPrint('ProfileController.logout: logout requested');
    clearTransientOverlays();
    if (Get.isRegistered<CartController>()) {
      await Get.find<CartController>().clearCart();
    }
    if (Get.isRegistered<AuthController>()) {
      await Get.find<AuthController>().logout();
      return;
    }
    await _storage.erase();
    Get.offAllNamed(AppRoutes.login);
  }

  Future<void> deleteAccount() async {
    debugPrint('ProfileController.deleteAccount: delete requested');
    if (isDeletingAccount.value) return;
    if (!hasBackendSession) {
      statusMessage.value = 'Please log in again before deleting your account.';
      return;
    }
    if (!Get.isRegistered<ApiService>()) {
      statusMessage.value =
          'Account deletion is not available right now. Please try again.';
      return;
    }

    isDeletingAccount.value = true;
    statusMessage.value = null;
    try {
      await Get.find<ApiService>().delete(endpoint: ApiConstants.deleteAccount);
      await logout();
    } on ApiException catch (error) {
      debugPrint('ProfileController.deleteAccount API failed: $error');
      statusMessage.value = error.message.isNotEmpty
          ? error.message
          : 'Account deletion failed. Please try again.';
    } on TimeoutException {
      statusMessage.value =
          'Account deletion request timed out. Please try again.';
    } on http.ClientException {
      statusMessage.value =
          'Internet connection issue. Account was not deleted.';
    } catch (error) {
      debugPrint('ProfileController.deleteAccount API failed: $error');
      statusMessage.value =
          'Account deletion failed. Please try again or contact support.';
    } finally {
      isDeletingAccount.value = false;
    }
  }

  Future<void> syncNotificationPreference() async {
    try {
      if (Get.isRegistered<PushNotificationService>()) {
        notificationsEnabled.value = await Get.find<PushNotificationService>()
            .areNotificationsEnabled();
        return;
      }
      notificationsEnabled.value =
          _storage.read<bool>(
            PushNotificationService.notificationsDisabledStorageKey,
          ) !=
          true;
    } catch (error) {
      debugPrint('ProfileController.syncNotificationPreference failed: $error');
      notificationsEnabled.value = false;
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (isUpdatingNotifications.value) return;
    isUpdatingNotifications.value = true;
    statusMessage.value = null;
    try {
      final service = await _pushNotificationService();
      if (enabled) {
        final allowed = await service.enableNotifications();
        notificationsEnabled.value = allowed;
        statusMessage.value = allowed
            ? 'Order and package notifications are turned on.'
            : 'Notifications were not allowed. You can enable them from device settings.';
        return;
      }

      await service.disableNotifications();
      notificationsEnabled.value = false;
      statusMessage.value = 'Order and package notifications are turned off.';
    } finally {
      isUpdatingNotifications.value = false;
    }
  }

  Future<PushNotificationService> _pushNotificationService() async {
    if (Get.isRegistered<PushNotificationService>()) {
      return Get.find<PushNotificationService>();
    }
    final service = Get.put(PushNotificationService(), permanent: true);
    await service.init();
    return service;
  }

  Future<void> loadAddresses() async {
    debugPrint('ProfileController.loadAddresses: loading saved addresses');
    isLoadingAddresses.value = true;
    addressLoadError.value = null;
    requiresAddressRelogin.value = false;

    if (!hasBackendSession) {
      addresses.clear();
      addressLoadError.value =
          'Login session is missing. Please log in again to view your saved addresses.';
      requiresAddressRelogin.value = true;
      isLoadingAddresses.value = false;
      return;
    }

    try {
      final remote = await _tryFetchAddresses();
      addresses.assignAll(_applySelectedState(remote));
      await _persistAddresses();
      debugPrint(
        'ProfileController.loadAddresses: fetched ${addresses.length} addresses from API',
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        _markAddressSessionExpired();
      } else {
        _restoreLocalAddresses();
        addressLoadError.value = error.message.isNotEmpty
            ? error.message
            : 'Addresses are not loading right now. Please try again.';
      }
    } on http.ClientException {
      _restoreLocalAddresses();
      addressLoadError.value =
          'Addresses could not be synced because of an internet issue.';
    } on TimeoutException {
      _restoreLocalAddresses();
      addressLoadError.value = 'Address request timed out. Please try again.';
    } catch (error) {
      debugPrint('ProfileController.loadAddresses failed: $error');
      _restoreLocalAddresses();
      addressLoadError.value =
          'Addresses could not be loaded right now. Please try again.';
    } finally {
      isLoadingAddresses.value = false;
    }
  }

  void _restoreGuestCatalogContext() {
    final stored = _storedSelectedAddress;
    if (stored == null) return;
    if (_isTransientLocationAddress(stored)) {
      selectedAddressId.value = null;
      return;
    }
    selectedAddressId.value = stored.id;
    if (stored.address.trim().isNotEmpty) {
      liveLocationAddress.value = stored.address.trim();
    }
  }

  bool startAddAddress() {
    if (!_ensureAddressSession()) return false;
    debugPrint('ProfileController.startAddAddress: opening add address flow');
    editingAddress.value = null;
    addressNameController.clear();
    addressPhoneController.clear();
    addressLineController.clear();
    draftLatitude.value = null;
    draftLongitude.value = null;
    draftPlaceId.value = null;
    placeSuggestions.clear();
    liveLocationAddress.value = '';
    unawaited(resolveCurrentLocationForDraft(forceAddressFill: true));
    return true;
  }

  void startEditAddress(AddressModel address) {
    if (!_ensureAddressSession()) return;
    debugPrint('ProfileController.startEditAddress: editing ${address.id}');
    editingAddress.value = address;
    addressNameController.text = address.fullName;
    addressPhoneController.text = address.contactNumber;
    addressLineController.text = address.address;
    draftLatitude.value = address.latitude;
    draftLongitude.value = address.longitude;
    draftPlaceId.value = address.placeId.isEmpty ? null : address.placeId;
    placeSuggestions.clear();
    if (address.address.trim().isNotEmpty) {
      liveLocationAddress.value = address.address.trim();
    }
  }

  Future<void> saveAddress() async {
    if (!_ensureAddressSession()) return;
    final fullName = addressNameController.text.trim();
    final phone = addressPhoneController.text.trim();
    var addressLine = addressLineController.text.trim();
    if (fullName.isEmpty || phone.length < 10 || addressLine.isEmpty) {
      statusMessage.value =
          'Enter a name, a valid phone number, and an address.';
      return;
    }

    if (draftLatitude.value == null || draftLongitude.value == null) {
      final geocoded = await _locationLookupService.geocodeAddress(addressLine);
      if (geocoded != null) {
        addressLine = geocoded.address;
        addressLineController.text = geocoded.address;
        draftLatitude.value = geocoded.latitude;
        draftLongitude.value = geocoded.longitude;
        draftPlaceId.value = geocoded.placeId.isEmpty ? null : geocoded.placeId;
      }
    }

    try {
      final existing = editingAddress.value;
      if (existing == null) {
        final savedAddress = await _saveAddressRemote(
          AddressModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            fullName: fullName,
            contactNumber: phone,
            address: addressLine,
            latitude: draftLatitude.value,
            longitude: draftLongitude.value,
            placeId: draftPlaceId.value ?? '',
            isSelected: true,
          ),
        );
        final selectedAddress = savedAddress.copyWith(isSelected: true);
        addresses.assignAll([
          selectedAddress,
          ...addresses.map((item) => item.copyWith(isSelected: false)),
        ]);
        await _applySelectedAddressContext(selectedAddress);
        debugPrint(
          'ProfileController.saveAddress: created ${selectedAddress.id}',
        );
        _notifyAction(
          'Address Added',
          'New delivery address was saved.',
          category: 'address',
        );
      } else {
        final index = addresses.indexWhere((item) => item.id == existing.id);
        if (index >= 0) {
          final savedAddress = await _saveAddressRemote(
            existing.copyWith(
              fullName: fullName,
              contactNumber: phone,
              address: addressLine,
              latitude: draftLatitude.value,
              longitude: draftLongitude.value,
              placeId: draftPlaceId.value ?? '',
              isSelected: true,
            ),
          );
          final selectedAddress = savedAddress.copyWith(isSelected: true);
          addresses.assignAll(
            addresses.map((item) {
              if (item.id == selectedAddress.id) return selectedAddress;
              return item.copyWith(isSelected: false);
            }),
          );
          await _applySelectedAddressContext(selectedAddress);
          debugPrint('ProfileController.saveAddress: updated ${existing.id}');
          _notifyAction(
            'Address Updated',
            'Delivery Address was updated.',
            category: 'address',
          );
        }
      }

      await _persistAddresses();
      statusMessage.value = 'Address saved successfully.';
      editingAddress.value = null;
      addressNameController.clear();
      addressPhoneController.clear();
      addressLineController.clear();
      draftLatitude.value = null;
      draftLongitude.value = null;
      draftPlaceId.value = null;
      placeSuggestions.clear();
      Get.back<void>();
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        _markAddressSessionExpired();
      }
      statusMessage.value = error.message.isNotEmpty
          ? error.message
          : 'Address could not be saved. Please try again.';
    } on http.ClientException {
      statusMessage.value =
          'Address could not be saved because of an internet issue.';
    } on TimeoutException {
      statusMessage.value = 'Address save request timed out. Please try again.';
    } catch (error) {
      debugPrint('ProfileController.saveAddress failed: $error');
      statusMessage.value = 'Address could not be saved. Please try again.';
    }
  }

  Future<void> useAddress(AddressModel address) async {
    if (!_ensureAddressSession()) return;
    debugPrint('ProfileController.useAddress: selecting ${address.id}');

    if (!_hasValidCoordinates(address)) {
      statusMessage.value =
          'Selected address does not have valid map coordinates. Please update this address and try again.';
      return;
    }

    final updated = addresses.map((item) {
      if (item.id != address.id) {
        return item.copyWith(isSelected: false);
      }
      return address.copyWith(
        fullName: address.fullName.trim().isNotEmpty
            ? address.fullName.trim()
            : item.fullName,
        contactNumber: address.contactNumber.trim().isNotEmpty
            ? address.contactNumber.trim()
            : item.contactNumber,
        address: address.address.trim().isNotEmpty
            ? address.address.trim()
            : item.address,
        latitude: address.latitude ?? item.latitude,
        longitude: address.longitude ?? item.longitude,
        placeId: address.placeId.trim().isNotEmpty
            ? address.placeId
            : item.placeId,
        vendorId: address.vendorId.trim().isNotEmpty
            ? address.vendorId
            : item.vendorId,
        isSelected: true,
      );
    }).toList();
    addresses.assignAll(updated);
    final selected = updated.firstWhereOrNull((item) => item.id == address.id);
    if (selected != null) {
      await _applySelectedAddressContext(selected);
      statusMessage.value = null;
      _notifyAction(
        'Address Selected',
        'Delivery Address changed to ${selected.address}.',
        category: 'address',
      );
    }
    await _persistAddresses();
  }

  Future<void> applyServiceAreaLocation({
    required String address,
    required double latitude,
    required double longitude,
    String placeId = '',
  }) async {
    final normalizedAddress = address.trim();
    if (normalizedAddress.isEmpty ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      statusMessage.value = 'Please select a valid delivery location.';
      return;
    }

    final user = currentUser;
    final temporaryAddress = AddressModel(
      id: 'service-location',
      fullName: user?.name.trim().isNotEmpty == true
          ? user!.name.trim()
          : 'Customer',
      contactNumber: user?.phone ?? '',
      address: normalizedAddress,
      latitude: latitude,
      longitude: longitude,
      placeId: placeId.trim(),
      isSelected: true,
    );

    selectedAddressId.value = temporaryAddress.id;
    _clearSavedAddressSelection();
    await _storage.remove(_selectedVendorIdStorageKey);
    liveLocationAddress.value = normalizedAddress;
    unawaited(_updateUserLocation(temporaryAddress));
    final vendorId = await _tryResolveVendor(temporaryAddress);
    if (vendorId == null) {
      await _storage.remove(_selectedVendorIdStorageKey);
      await _storage.remove(_selectedServiceLocationSessionStorageKey);
      await _storage.remove(_selectedLocationServiceableStorageKey);
      await _persistSelectedAddress(temporaryAddress.copyWith(vendorId: ''));
    } else {
      await _storage.write(_selectedLocationServiceableStorageKey, true);
      await _storage.write(
        _selectedServiceLocationSessionStorageKey,
        AppSessionScope.id,
      );
      await _persistSelectedAddress(
        temporaryAddress.copyWith(vendorId: vendorId),
      );
    }
    unawaited(_refreshCatalogAfterAddressChange());
  }

  Future<void> applyBlockedServiceAreaLocation({
    required String address,
    required double latitude,
    required double longitude,
    String placeId = '',
  }) async {
    final normalizedAddress = address.trim().isNotEmpty
        ? address.trim()
        : '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      await _storage.remove(_selectedVendorIdStorageKey);
      await _storage.remove(_selectedServiceLocationSessionStorageKey);
      await _storage.write(_selectedLocationServiceableStorageKey, false);
      unawaited(_refreshCatalogAfterAddressChange());
      return;
    }

    final user = currentUser;
    final blockedAddress = AddressModel(
      id: 'blocked-service-location',
      fullName: user?.name.trim().isNotEmpty == true
          ? user!.name.trim()
          : 'Customer',
      contactNumber: user?.phone ?? '',
      address: normalizedAddress,
      latitude: latitude,
      longitude: longitude,
      placeId: placeId.trim(),
      isSelected: true,
    );

    selectedAddressId.value = blockedAddress.id;
    _clearSavedAddressSelection();
    liveLocationAddress.value = normalizedAddress;
    await _storage.remove(_selectedVendorIdStorageKey);
    await _storage.remove(_selectedServiceLocationSessionStorageKey);
    await _storage.write(_selectedLocationServiceableStorageKey, false);
    await _persistSelectedAddress(blockedAddress);
    unawaited(_refreshCatalogAfterAddressChange());
  }

  Future<void> _restoreAuthenticatedServiceAreaLocation(
    AddressModel address,
  ) async {
    final normalizedAddress = address.address.trim();
    final user = currentUser;
    final selectedVendorId = _storedSelectedVendorId ?? address.vendorId.trim();
    final restoredAddress = address.copyWith(
      id: address.id.trim().isNotEmpty ? address.id.trim() : 'service-location',
      fullName: user?.name.trim().isNotEmpty == true
          ? user!.name.trim()
          : (address.fullName.trim().isNotEmpty
                ? address.fullName.trim()
                : 'Customer'),
      contactNumber: user?.phone.trim().isNotEmpty == true
          ? user!.phone.trim()
          : address.contactNumber,
      address: normalizedAddress,
      vendorId: selectedVendorId,
      isSelected: true,
    );

    selectedAddressId.value = restoredAddress.id;
    _clearSavedAddressSelection();
    liveLocationAddress.value = normalizedAddress;
    await _storage.write(_selectedLocationServiceableStorageKey, true);
    await _storage.write(
      _selectedServiceLocationSessionStorageKey,
      AppSessionScope.id,
    );
    if (selectedVendorId.trim().isNotEmpty) {
      await _storage.write(_selectedVendorIdStorageKey, selectedVendorId);
      await _persistSelectedAddress(restoredAddress);
    } else {
      await _persistSelectedAddress(restoredAddress);
      final resolvedVendorId = await _tryResolveVendor(restoredAddress);
      if (resolvedVendorId != null) {
        await _persistSelectedAddress(
          restoredAddress.copyWith(vendorId: resolvedVendorId),
        );
      }
    }
    unawaited(_updateUserLocation(restoredAddress));
    await _refreshCatalogAfterAddressChange();
  }

  Future<void> deleteAddress(AddressModel address) async {
    if (!_ensureAddressSession()) return;
    debugPrint('ProfileController.deleteAddress: deleting ${address.id}');
    try {
      await _deleteAddressRemote(address.id);
      addresses.removeWhere((item) => item.id == address.id);
      if (selectedAddressId.value == address.id) {
        selectedAddressId.value = null;
        await _storage.remove(_selectedAddressStorageKey);
        await _storage.remove(_selectedVendorIdStorageKey);
        await _storage.remove(_selectedServiceLocationSessionStorageKey);
        await _storage.remove(_selectedLocationServiceableStorageKey);
        await _resolveHomeLocationPreview(forceRefresh: true);
      }
      await _persistAddresses();
      statusMessage.value = 'Address deleted successfully.';
      _notifyAction(
        'Address Deleted',
        'Saved delivery address was deleted.',
        category: 'address',
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        _markAddressSessionExpired();
      }
      statusMessage.value = error.message.isNotEmpty
          ? error.message
          : 'Address could not be deleted. Please try again.';
    } on http.ClientException {
      statusMessage.value =
          'Address could not be deleted because of an internet issue.';
    }
  }

  Future<void> resolveCurrentLocationForDraft({
    bool forceAddressFill = false,
  }) async {
    if (!_locationLookupService.isConfigured) {
      return;
    }

    isResolvingLocation.value = true;
    try {
      final granted = await _ensureLocationPermission();
      if (!granted) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );

      draftLatitude.value = position.latitude;
      draftLongitude.value = position.longitude;
      draftPlaceId.value = null;

      final resolved = await _locationLookupService.reverseGeocodeToAddress(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (resolved != null && resolved.trim().isNotEmpty) {
        liveLocationAddress.value = resolved.trim();
        if (forceAddressFill || addressLineController.text.trim().isEmpty) {
          addressLineController.text = resolved.trim();
        }
      }
    } catch (error) {
      debugPrint(
        'ProfileController.resolveCurrentLocationForDraft failed: $error',
      );
    } finally {
      isResolvingLocation.value = false;
    }
  }

  Future<void> fetchAddressSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      placeSuggestions.clear();
      isResolvingSuggestions.value = false;
      return;
    }

    if (!_locationLookupService.isConfigured) {
      placeSuggestions.clear();
      return;
    }

    isResolvingSuggestions.value = true;
    try {
      final suggestions = await _locationLookupService.getPlaceSuggestions(
        trimmed,
      );
      if (addressLineController.text.trim() == trimmed) {
        placeSuggestions.assignAll(suggestions);
      }
    } finally {
      isResolvingSuggestions.value = false;
    }
  }

  Future<void> selectAddressSuggestion(PlaceSuggestion suggestion) async {
    final details = await _locationLookupService.getPlaceDetails(
      suggestion.placeId,
    );
    if (details == null) return;

    addressLineController.text = details.address;
    draftLatitude.value = details.latitude;
    draftLongitude.value = details.longitude;
    draftPlaceId.value = details.placeId.isEmpty ? null : details.placeId;
    liveLocationAddress.value = details.address;
    placeSuggestions.clear();
  }

  void onAddressInputChanged(String value) {
    draftPlaceId.value = null;
    _addressSuggestionDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      placeSuggestions.clear();
      isResolvingSuggestions.value = false;
      return;
    }
    _addressSuggestionDebounce = Timer(const Duration(milliseconds: 350), () {
      fetchAddressSuggestions(trimmed);
    });
  }

  Future<void> _persistAddresses() async {
    await _storage.write(
      _addressStorageKey,
      addresses.map((item) => item.toJson()).toList(),
    );
    debugPrint(
      'ProfileController._persistAddresses: persisted ${addresses.length} addresses',
    );
  }

  List<AddressModel> _applySelectedState(List<AddressModel> source) {
    final stored = _storedSelectedAddress;
    if (stored == null || _isTransientLocationAddress(stored)) {
      return _clearSelectedFlags(source);
    }

    selectedAddressId.value = stored.id;
    return source
        .map((item) => item.copyWith(isSelected: item.id == stored.id))
        .toList();
  }

  List<AddressModel> _clearSelectedFlags(List<AddressModel> source) {
    selectedAddressId.value = null;
    return source.map((item) => item.copyWith(isSelected: false)).toList();
  }

  void _restoreLocalAddresses() {
    final rawList =
        _storage.read<List<dynamic>>(_addressStorageKey) ?? <dynamic>[];
    final restored = rawList
        .whereType<Map>()
        .map((item) => AddressModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    addresses.assignAll(_applySelectedState(restored));
    debugPrint(
      'ProfileController._restoreLocalAddresses: restored ${addresses.length} cached addresses',
    );
  }

  Future<void> _resolveHomeLocationPreview({bool forceRefresh = false}) async {
    if ((!forceRefresh && activeAddress != null) ||
        !_locationLookupService.isConfigured) {
      return;
    }
    isResolvingLocation.value = true;
    try {
      final granted = await _ensureLocationPermission();
      if (!granted) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final resolved = await _locationLookupService.reverseGeocodeToAddress(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final locationLabel = resolved?.trim().isNotEmpty == true
          ? resolved!.trim()
          : '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      if (activeAddress != null) return;
      liveLocationAddress.value = locationLabel;
      if (hasBackendSession) {
        await _applyLiveLocationCatalogContext(
          address: locationLabel,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    } catch (error) {
      debugPrint('ProfileController._resolveHomeLocationPreview: $error');
    } finally {
      isResolvingLocation.value = false;
    }
  }

  Future<void> _applyLiveLocationCatalogContext({
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    final selected = activeAddress;
    if (selected != null && selected.id != 'live-location') return;

    final user = currentUser;
    final liveAddress = AddressModel(
      id: 'live-location',
      fullName: user?.name.trim().isNotEmpty == true
          ? user!.name.trim()
          : 'Customer',
      contactNumber: user?.phone ?? '',
      address: address,
      latitude: latitude,
      longitude: longitude,
      isSelected: true,
    );

    selectedAddressId.value = liveAddress.id;
    _clearSavedAddressSelection();
    await _storage.remove(_selectedVendorIdStorageKey);
    await _storage.remove(_selectedServiceLocationSessionStorageKey);
    await _updateUserLocation(liveAddress);
    final vendorId = await _tryResolveVendor(liveAddress);
    if (vendorId == null) {
      await _storage.remove(_selectedVendorIdStorageKey);
      await _storage.remove(_selectedLocationServiceableStorageKey);
      await _persistSelectedAddress(liveAddress.copyWith(vendorId: ''));
    } else {
      await _storage.write(_selectedLocationServiceableStorageKey, true);
      await _persistSelectedAddress(liveAddress.copyWith(vendorId: vendorId));
    }
    await _refreshCatalogAfterAddressChange();
  }

  Future<void> _persistSelectedAddress(AddressModel address) async {
    await _storage.write(_selectedAddressStorageKey, address.toJson());
  }

  bool _isTransientLocationAddress(AddressModel address) {
    return _transientLocationAddressIds.contains(address.id.trim());
  }

  void _clearSavedAddressSelection() {
    if (addresses.isEmpty) return;
    addresses.assignAll(
      addresses.map((item) => item.copyWith(isSelected: false)).toList(),
    );
  }

  Future<String?> _applySelectedAddressContext(AddressModel address) async {
    selectedAddressId.value = address.id;
    await _storage.remove(_selectedVendorIdStorageKey);
    await _storage.remove(_selectedServiceLocationSessionStorageKey);
    liveLocationAddress.value = address.address;
    await _updateUserLocation(address);

    final vendorId = await _tryResolveVendor(address);
    if (vendorId == null) {
      await _storage.remove(_selectedVendorIdStorageKey);
      await _storage.remove(_selectedLocationServiceableStorageKey);
      await _persistSelectedAddress(address.copyWith(vendorId: ''));
    } else {
      await _storage.write(_selectedLocationServiceableStorageKey, true);
      await _persistSelectedAddress(address.copyWith(vendorId: vendorId));
    }

    await _refreshCatalogAfterAddressChange();
    return vendorId;
  }

  Future<void> _updateUserLocation(AddressModel address) async {
    if (!Get.isRegistered<ApiService>()) return;
    if (!_hasValidCoordinates(address)) return;

    try {
      await Get.find<ApiService>().patch(
        endpoint: ApiConstants.user,
        data: {
          'address': address.address,
          'liveLocation': {
            'latitude': address.latitude,
            'longitude': address.longitude,
          },
        },
      );
    } catch (error) {
      debugPrint(
        'ProfileController._updateUserLocation: fallback after $error',
      );
    }
  }

  Future<UserModel?> _tryUpdateProfileRemote(UserModel user) async {
    if (!Get.isRegistered<ApiService>() || !hasBackendSession) return null;
    try {
      final response = await Get.find<ApiService>().patch(
        endpoint: ApiConstants.user,
        data: {'name': user.name, 'fullName': user.name, 'phone': user.phone},
      );
      final raw = _extractObject(response);
      final userRaw = raw['user'] is Map
          ? Map<String, dynamic>.from(raw['user'] as Map)
          : raw['customer'] is Map
          ? Map<String, dynamic>.from(raw['customer'] as Map)
          : raw;
      final parsed = UserModel.fromJson(userRaw);
      return parsed.id.isEmpty && parsed.phone.isEmpty ? user : parsed;
    } catch (error) {
      debugPrint('ProfileController._tryUpdateProfileRemote failed: $error');
      return null;
    }
  }

  Future<void> _refreshCatalogAfterAddressChange() async {
    if (Get.isRegistered<CatalogRepository>()) {
      Get.find<CatalogRepository>().invalidateProductScope();
    }
    if (Get.isRegistered<DashboardController>()) {
      await Get.find<DashboardController>().loadCatalog(force: true);
    }
    if (Get.isRegistered<CategoriesController>()) {
      await Get.find<CategoriesController>().reloadSelectedCategory(
        force: true,
      );
    }
  }

  bool _hasValidCoordinates(AddressModel address) {
    final latitude = address.latitude;
    final longitude = address.longitude;
    return latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite;
  }

  bool _ensureAddressSession() {
    if (hasBackendSession && !requiresAddressRelogin.value) {
      return true;
    }
    _markAddressSessionExpired();
    return false;
  }

  void _markAddressSessionExpired() {
    addresses.clear();
    addressLoadError.value =
        'Session expired. Please log in again to view backend addresses.';
    requiresAddressRelogin.value = true;
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      statusMessage.value =
          'Please turn on device location to auto-fill your address.';
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      statusMessage.value =
          'Location permission is needed to detect your current address.';
      return false;
    }

    return true;
  }

  Future<AddressModel> _saveAddressRemote(AddressModel address) async {
    if (!Get.isRegistered<ApiService>()) {
      throw ApiException(
        statusCode: 500,
        message: 'API service is not available.',
        response: const {},
      );
    }
    final api = Get.find<ApiService>();
    final payload = {
      'fullName': address.fullName,
      'contactNumber': address.contactNumber,
      'address': address.address,
      'latitude': address.latitude,
      'longitude': address.longitude,
      'placeId': address.placeId,
    };
    final response = editingAddress.value == null
        ? await api.post(endpoint: ApiConstants.addressSave, data: payload)
        : await api.put(
            endpoint: ApiConstants.addressById(address.id),
            data: payload,
          );
    final raw = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : response;
    final parsed = AddressModel.fromJson(raw);
    if (parsed.id.isEmpty) {
      throw ApiException(
        statusCode: 500,
        message: 'Saved Address Response Invalid Tha.',
        response: response,
      );
    }
    return _withSubmittedAddressFallback(
      parsed,
      address,
    ).copyWith(isSelected: address.isSelected);
  }

  AddressModel _withSubmittedAddressFallback(
    AddressModel saved,
    AddressModel submitted,
  ) {
    return saved.copyWith(
      fullName: saved.fullName.trim().isNotEmpty
          ? saved.fullName
          : submitted.fullName,
      contactNumber: saved.contactNumber.trim().isNotEmpty
          ? saved.contactNumber
          : submitted.contactNumber,
      address: saved.address.trim().isNotEmpty
          ? saved.address
          : submitted.address,
      latitude: saved.latitude ?? submitted.latitude,
      longitude: saved.longitude ?? submitted.longitude,
      placeId: saved.placeId.trim().isNotEmpty
          ? saved.placeId
          : submitted.placeId,
      vendorId: saved.vendorId.trim().isNotEmpty
          ? saved.vendorId
          : submitted.vendorId,
    );
  }

  Future<void> _deleteAddressRemote(String id) async {
    if (!Get.isRegistered<ApiService>()) {
      throw ApiException(
        statusCode: 500,
        message: 'API service is not available.',
        response: const {},
      );
    }
    await Get.find<ApiService>().delete(endpoint: ApiConstants.addressById(id));
  }

  Future<String?> _tryResolveVendor(AddressModel address) async {
    if (!Get.isRegistered<ApiService>()) return null;
    if (address.latitude == null || address.longitude == null) return null;
    try {
      final radiusKm = await _productRadiusKm();
      final token = _storage.read<String>('accessToken');
      final headers = (token != null && token.isNotEmpty)
          ? {'Authorization': 'Bearer $token'}
          : null;
      final response = await Get.find<ApiService>().get(
        endpoint: ApiConstants.resolveVendor,
        query: {
          'latitude': address.latitude,
          'longitude': address.longitude,
          'radiusKm': radiusKm,
        },
        authenticated: false,
        headers: headers,
      );
      final vendorIds = _resolveNearbyVendorIds(response, radiusKm);
      if (vendorIds.isNotEmpty) {
        final vendorId = vendorIds.join(',');
        await _storage.write(_selectedVendorIdStorageKey, vendorId);
        return vendorId;
      }
    } catch (error) {
      debugPrint('ProfileController._tryResolveVendor: fallback after $error');
    }
    return null;
  }

  Future<double> _productRadiusKm() async {
    if (!Get.isRegistered<CatalogRepository>()) return 5;
    try {
      final settings = await Get.find<CatalogRepository>()
          .loadDeliverySettings();
      return settings.productRadiusKm;
    } catch (_) {
      return 5;
    }
  }

  List<String> _resolveNearbyVendorIds(
    Map<String, dynamic> response,
    double radiusKm,
  ) {
    if (_explicitlyOutsideRadius(response)) {
      return const [];
    }

    final vendors = _extractVendorMaps(response);
    if (vendors.isNotEmpty) {
      final nearbyVendors = vendors.where((vendor) {
        final distance = _distanceKmFrom(vendor);
        return distance == null || distance <= radiusKm;
      }).toList();
      return _uniqueVendorIds(nearbyVendors.map(_vendorIdentifier));
    }

    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : const <String, dynamic>{};
    final result = response['result'] is Map
        ? Map<String, dynamic>.from(response['result'] as Map)
        : const <String, dynamic>{};
    final nearestVendorSource =
        response['nearestVendor'] ??
        data['nearestVendor'] ??
        result['nearestVendor'];
    final nearestVendor = nearestVendorSource is Map
        ? Map<String, dynamic>.from(nearestVendorSource)
        : const <String, dynamic>{};
    final nearestDistance =
        _distanceKmFrom(nearestVendor) ?? _distanceKmFrom(response);
    if (nearestDistance != null && nearestDistance > radiusKm) {
      return const [];
    }

    return _uniqueVendorIds([
      if (response['vendorIds'] is List) ...(response['vendorIds'] as List),
      response['vendorId'],
      response['vendor_id'],
      if (response['data'] is Map &&
          (response['data'] as Map)['vendorIds'] is List)
        ...((response['data'] as Map)['vendorIds'] as List),
      if (response['data'] is Map) (response['data'] as Map)['vendorId'],
      if (response['data'] is Map) (response['data'] as Map)['vendor_id'],
      if (response['result'] is Map &&
          (response['result'] as Map)['vendorIds'] is List)
        ...((response['result'] as Map)['vendorIds'] as List),
      if (response['result'] is Map) (response['result'] as Map)['vendorId'],
      if (response['result'] is Map) (response['result'] as Map)['vendor_id'],
      _vendorIdentifier(nearestVendor),
    ]);
  }

  bool _explicitlyOutsideRadius(Map<String, dynamic> response) {
    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : const <String, dynamic>{};
    final result = response['result'] is Map
        ? Map<String, dynamic>.from(response['result'] as Map)
        : const <String, dynamic>{};

    for (final source in [response, data, result]) {
      final within = source['withinServiceRadius'] ?? source['within_radius'];
      if (within == false || within.toString().toLowerCase() == 'false') {
        return true;
      }
      final count = _numberFrom(source['count'] ?? source['vendorCount']);
      if (count != null && count <= 0) {
        return true;
      }
    }
    return false;
  }

  List<Map<String, dynamic>> _extractVendorMaps(Map<String, dynamic> response) {
    final candidates = [
      response['vendors'],
      if (response['data'] is Map) (response['data'] as Map)['vendors'],
      if (response['result'] is Map) (response['result'] as Map)['vendors'],
      if (response['data'] is Map) (response['data'] as Map)['data'],
      if (response['result'] is Map) (response['result'] as Map)['data'],
    ];
    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return const [];
  }

  String? _vendorIdentifier(Map<String, dynamic> vendor) {
    final value =
        vendor['vendorId'] ??
        vendor['vendor_id'] ??
        vendor['id'] ??
        vendor['_id'];
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  double? _distanceKmFrom(Map<String, dynamic> source) {
    for (final key in [
      'distanceKm',
      'distance_km',
      'distanceKM',
      'distance',
      'distanceInKm',
      'distance_in_km',
    ]) {
      final parsed = _numberFrom(source[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  double? _numberFrom(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final direct = double.tryParse(raw);
    if (direct != null) return direct;
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(raw);
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  List<String> _uniqueVendorIds(Iterable<Object?> values) {
    return values
        .expand((value) => value?.toString().split(',') ?? const <String>[])
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<List<AddressModel>> _tryFetchAddresses() async {
    if (!Get.isRegistered<ApiService>()) {
      throw ApiException(
        statusCode: 500,
        message: 'API service is not available.',
        response: const {},
      );
    }
    final response = await Get.find<ApiService>().get(
      endpoint: ApiConstants.addressList,
    );
    return _extractList(response)
        .whereType<Map>()
        .map((item) => AddressModel.fromJson(Map<String, dynamic>.from(item)))
        .where((address) => address.id.isNotEmpty)
        .toList();
  }

  List _extractList(Map<String, dynamic> response) {
    final candidates = [
      response['data'],
      response['addresses'],
      response['items'],
      response['result'],
      response['results'],
    ];
    for (final value in candidates) {
      if (value is List) return value;
      if (value is Map) {
        for (final nested in [
          'data',
          'addresses',
          'items',
          'result',
          'results',
        ]) {
          final nestedValue = value[nested];
          if (nestedValue is List) return nestedValue;
        }
      }
    }
    return [];
  }

  Map<String, dynamic> _extractObject(Map<String, dynamic> response) {
    for (final value in [
      response['data'],
      response['user'],
      response['customer'],
      response['result'],
      response,
    ]) {
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return response;
  }

  void _syncProfileForm() {
    final user = currentUser;
    nameController.text = user?.name ?? '';
    phoneController.text = user?.phone ?? '';
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    addressNameController.dispose();
    addressPhoneController.dispose();
    addressLineController.dispose();
    _addressSuggestionDebounce?.cancel();
    super.onClose();
  }

  void _notifyAction(String title, String message, {required String category}) {
    if (category != 'address') {
      AppSnackBar.show(title, message, snackPosition: SnackPosition.BOTTOM);
    }
    if (!Get.isRegistered<NotificationService>()) return;
    unawaited(
      Get.find<NotificationService>().record(
        title: title,
        message: message,
        category: category,
      ),
    );
  }
}
