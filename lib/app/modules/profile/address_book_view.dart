import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';
import 'controllers/profile_controller.dart';

class AddressBookView extends GetView<ProfileController> {
  AddressBookView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          title: Text('Address Book'),
          centerTitle: true,
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: () {
                  controller.startAddAddress();
                  _showAddressSheet(context);
                },
                icon: Icon(Icons.add_circle_outline_rounded, size: 16),
                label: Text('Add'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.all(20.rpx),
          children: [
            if (controller.addresses.isEmpty)
              Container(
                padding: EdgeInsets.all(24.rpx),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                  borderRadius: BorderRadius.circular(16.rpx),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.home_outlined,
                      size: 56,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 12.hpx),
                    Text(
                      'No saved addresses yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8.hpx),
                    Text(
                      'Tap add to save your first delivery address.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ...controller.addresses.map((address) {
              final active = address.isSelected;
              return Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: EdgeInsets.all(16.rpx),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 10.wpx),
                          Expanded(
                            child: Text(
                              address.fullName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          if (active)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFFEAF1FF),
                                borderRadius: BorderRadius.circular(20.rpx),
                              ),
                              child: Text(
                                'Active',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.spx,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 8.hpx),
                      Text(
                        address.address,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          height: 1.45,
                        ),
                      ),
                      SizedBox(height: 6.hpx),
                      Text(
                        address.contactNumber,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 14.hpx),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: () => controller.useAddress(address),
                              icon: Icon(Icons.check_circle_outline_rounded),
                              style: FilledButton.styleFrom(
                                backgroundColor: active
                                    ? AppColors.primaryDark
                                    : AppColors.primary,
                              ),
                              label: Text('Use this address'),
                            ),
                          ),
                          SizedBox(width: 8.wpx),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                controller.startEditAddress(address);
                                _showAddressSheet(context);
                              },
                              icon: Icon(Icons.edit_outlined),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                              label: Text('Edit'),
                            ),
                          ),
                          SizedBox(width: 8.wpx),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  controller.deleteAddress(address),
                              icon: Icon(Icons.delete_outline_rounded),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                              ),
                              label: Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddressSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Container(
            padding: EdgeInsets.all(20.rpx),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20.rpx),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.editingAddress.value == null
                      ? 'Add Address'
                      : 'Edit Address',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 14.hpx),
                TextField(
                  controller: controller.addressNameController,
                  decoration: InputDecoration(labelText: 'Full Name'),
                ),
                SizedBox(height: 12.hpx),
                TextField(
                  controller: controller.addressPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: 'Contact Number'),
                ),
                SizedBox(height: 12.hpx),
                TextField(
                  controller: controller.addressLineController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: 'Address'),
                ),
                SizedBox(height: 16.hpx),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: controller.saveAddress,
                    child: Text('Save Address'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
