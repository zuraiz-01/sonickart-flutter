import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../data/models/address_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../package/controllers/package_controller.dart';

class ProfileController extends GetxController {
  ProfileController(this._storage);

  static const _addressStorageKey = 'saved_addresses';
  static const _currentUserStorageKey = 'currentUser';

  final GetStorage _storage;

  final isEditModalVisible = false.obs;
  final activeInfoModal = RxnString();
  final isSavingProfile = false.obs;
  final addresses = <AddressModel>[].obs;
  final statusMessage = RxnString();
  final selectedAddressId = RxnString();
  final editingAddress = Rxn<AddressModel>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();

  final addressNameController = TextEditingController();
  final addressPhoneController = TextEditingController();
  final addressLineController = TextEditingController();

  UserModel? get currentUser {
    final rawUser = _storage.read(_currentUserStorageKey);
    if (rawUser is Map) {
      return UserModel.fromJson(Map<String, dynamic>.from(rawUser));
    }
    return null;
  }

  String get initials {
    final seed = currentUser?.name.isNotEmpty == true
        ? currentUser!.name
        : (currentUser?.phone.isNotEmpty == true ? currentUser!.phone : 'Guest');
    final parts = seed.trim().split(' ').where((part) => part.isNotEmpty).toList();
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
    _syncProfileForm();
    loadAddresses();
  }

  void openEditProfile() {
    debugPrint('ProfileController.openEditProfile: opening edit modal');
    _syncProfileForm();
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
      Get.snackbar(
        'Phone Required',
        'Enter a valid 10-digit phone number.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    isSavingProfile.value = true;
    try {
      final user = UserModel(
        id: currentUser?.id ?? 'usr-local',
        name: trimmedName.isEmpty ? 'SonicKart Customer' : trimmedName,
        email: emailController.text.trim(),
        phone: trimmedPhone,
      );
      await _storage.write(_currentUserStorageKey, user.toJson());
      debugPrint(
        'ProfileController.saveProfile: saved profile name=${user.name} phone=${user.phone}',
      );
      closeEditProfile();
      statusMessage.value = 'Profile updated successfully.';
    } finally {
      isSavingProfile.value = false;
    }
  }

  void openInfoModal(String key) {
    debugPrint('ProfileController.openInfoModal: opening modal $key');
    activeInfoModal.value = key;
  }

  void closeInfoModal() {
    debugPrint('ProfileController.closeInfoModal: closing info modal');
    activeInfoModal.value = null;
  }

  void openOrders() {
    debugPrint('ProfileController.openOrders: redirecting to customer orders');
    Get.toNamed(AppRoutes.customerOrders);
  }

  void openHelp() {
    debugPrint('ProfileController.openHelp: showing help snackbar');
    Get.snackbar(
      'Help',
      'Support email: support@sonickartnow.com',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void handleMenuAction(String action) {
    debugPrint('ProfileController.handleMenuAction: action=$action');
    switch (action) {
      case 'addresses':
        Get.toNamed(AppRoutes.addressBook);
        return;
      case 'edit':
        openEditProfile();
        return;
      case 'about':
        openInfoModal('about');
        return;
      default:
        openInfoModal(action);
    }
  }

  Future<void> logout() async {
    debugPrint('ProfileController.logout: logout requested');
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

  Future<void> loadAddresses() async {
    debugPrint('ProfileController.loadAddresses: loading saved addresses');
    final remote = await _tryFetchAddresses();
    if (remote.isNotEmpty) {
      addresses.assignAll(remote);
      await _persistAddresses();
      debugPrint(
        'ProfileController.loadAddresses: fetched ${addresses.length} addresses from API',
      );
      return;
    }

    final rawList = _storage.read<List<dynamic>>(_addressStorageKey) ?? <dynamic>[];
    final restored = rawList
        .map((item) => AddressModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    addresses.assignAll(restored);
    debugPrint(
      'ProfileController.loadAddresses: restored ${addresses.length} addresses',
    );
  }

  void startAddAddress() {
    debugPrint('ProfileController.startAddAddress: opening add address flow');
    editingAddress.value = null;
    addressNameController.clear();
    addressPhoneController.clear();
    addressLineController.clear();
  }

  void startEditAddress(AddressModel address) {
    debugPrint('ProfileController.startEditAddress: editing ${address.id}');
    editingAddress.value = address;
    addressNameController.text = address.fullName;
    addressPhoneController.text = address.contactNumber;
    addressLineController.text = address.address;
  }

  Future<void> saveAddress() async {
    final fullName = addressNameController.text.trim();
    final phone = addressPhoneController.text.trim();
    final addressLine = addressLineController.text.trim();
    if (fullName.isEmpty || phone.length < 10 || addressLine.isEmpty) {
      Get.snackbar(
        'Address Incomplete',
        'Name, valid phone aur address zaroor enter karo.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final existing = editingAddress.value;
    if (existing == null) {
      var address = AddressModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fullName: fullName,
        contactNumber: phone,
        address: addressLine,
        isSelected: addresses.isEmpty,
      );
      address = await _trySaveAddress(address) ?? address;
      addresses.insert(0, address);
      debugPrint('ProfileController.saveAddress: created ${address.id}');
    } else {
      final index = addresses.indexWhere((item) => item.id == existing.id);
      if (index >= 0) {
        var updatedAddress = existing.copyWith(
          fullName: fullName,
          contactNumber: phone,
          address: addressLine,
        );
        updatedAddress = await _trySaveAddress(updatedAddress) ?? updatedAddress;
        addresses[index] = updatedAddress;
        debugPrint('ProfileController.saveAddress: updated ${existing.id}');
      }
    }

    await _persistAddresses();
    statusMessage.value = 'Address saved successfully.';
    editingAddress.value = null;
    addressNameController.clear();
    addressPhoneController.clear();
    addressLineController.clear();
    Get.back<void>();
  }

  Future<void> useAddress(AddressModel address) async {
    debugPrint('ProfileController.useAddress: selecting ${address.id}');
    selectedAddressId.value = address.id;
    final vendorId = await _tryResolveVendor(address);
    final updated = addresses
        .map((item) => item.copyWith(isSelected: item.id == address.id))
        .toList();
    addresses.assignAll(updated);
    await _persistAddresses();
    statusMessage.value = vendorId == null
        ? 'Shopping from selected address.'
        : 'Shopping from vendor $vendorId.';
  }

  Future<void> deleteAddress(AddressModel address) async {
    debugPrint('ProfileController.deleteAddress: deleting ${address.id}');
    addresses.removeWhere((item) => item.id == address.id);
    await _tryDeleteAddress(address.id);
    if (selectedAddressId.value == address.id) {
      selectedAddressId.value = null;
    }
    await _persistAddresses();
    statusMessage.value = 'Address deleted successfully.';
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

  Future<AddressModel?> _trySaveAddress(AddressModel address) async {
    if (!Get.isRegistered<ApiService>()) return null;
    try {
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
          : await api.put(endpoint: ApiConstants.addressById(address.id), data: payload);
      final raw = response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : response;
      final parsed = AddressModel.fromJson(raw);
      return parsed.id.isEmpty ? null : parsed.copyWith(isSelected: address.isSelected);
    } catch (error) {
      debugPrint('ProfileController._trySaveAddress: local fallback after $error');
      return null;
    }
  }

  Future<void> _tryDeleteAddress(String id) async {
    if (!Get.isRegistered<ApiService>()) return;
    try {
      await Get.find<ApiService>().delete(endpoint: ApiConstants.addressById(id));
    } catch (error) {
      debugPrint('ProfileController._tryDeleteAddress: local fallback after $error');
    }
  }

  Future<String?> _tryResolveVendor(AddressModel address) async {
    if (!Get.isRegistered<ApiService>()) return null;
    if (address.latitude == null || address.longitude == null) return null;
    try {
      final response = await Get.find<ApiService>().get(
        endpoint: ApiConstants.resolveVendor,
        query: {
          'latitude': address.latitude,
          'longitude': address.longitude,
          'radiusKm': 30,
        },
      );
      final vendorId = response['vendorId'] ??
          response['vendor_id'] ??
          (response['nearestVendor'] is Map
              ? (response['nearestVendor']['vendorId'] ??
                  response['nearestVendor']['vendor_id'])
              : null) ??
          (response['vendorIds'] is List && (response['vendorIds'] as List).isNotEmpty
              ? (response['vendorIds'] as List).first
              : null);
      if (vendorId != null) {
        await _storage.write('selectedVendorId', vendorId.toString());
        return vendorId.toString();
      }
    } catch (error) {
      debugPrint('ProfileController._tryResolveVendor: fallback after $error');
    }
    return null;
  }

  Future<List<AddressModel>> _tryFetchAddresses() async {
    if (!Get.isRegistered<ApiService>()) return const <AddressModel>[];
    try {
      final response = await Get.find<ApiService>().get(endpoint: ApiConstants.addressList);
      final list = _extractList(response)
          .map((item) => AddressModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .where((address) => address.id.isNotEmpty)
          .toList();
      return list;
    } catch (error) {
      debugPrint('ProfileController._tryFetchAddresses: local fallback after $error');
      return const <AddressModel>[];
    }
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
        for (final nested in ['data', 'addresses', 'items', 'result', 'results']) {
          final nestedValue = value[nested];
          if (nestedValue is List) return nestedValue;
        }
      }
    }
    return const [];
  }

  void _syncProfileForm() {
    final user = currentUser;
    nameController.text = user?.name ?? '';
    phoneController.text = user?.phone ?? '';
    emailController.text = user?.email ?? '';
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressNameController.dispose();
    addressPhoneController.dispose();
    addressLineController.dispose();
    super.onClose();
  }
}
