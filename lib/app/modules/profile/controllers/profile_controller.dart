import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../data/models/address_model.dart';
import '../../../data/models/user_model.dart';
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
      final address = AddressModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fullName: fullName,
        contactNumber: phone,
        address: addressLine,
        isSelected: addresses.isEmpty,
      );
      addresses.insert(0, address);
      debugPrint('ProfileController.saveAddress: created ${address.id}');
    } else {
      final index = addresses.indexWhere((item) => item.id == existing.id);
      if (index >= 0) {
        addresses[index] = existing.copyWith(
          fullName: fullName,
          contactNumber: phone,
          address: addressLine,
        );
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
    final updated = addresses
        .map((item) => item.copyWith(isSelected: item.id == address.id))
        .toList();
    addresses.assignAll(updated);
    await _persistAddresses();
    statusMessage.value = 'Shopping from selected address.';
  }

  Future<void> deleteAddress(AddressModel address) async {
    debugPrint('ProfileController.deleteAddress: deleting ${address.id}');
    addresses.removeWhere((item) => item.id == address.id);
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
