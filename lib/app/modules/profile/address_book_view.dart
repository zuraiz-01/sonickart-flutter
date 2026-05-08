import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';
import 'controllers/profile_controller.dart';

class AddressBookView extends GetView<ProfileController> {
  const AddressBookView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          surfaceTintColor: AppColors.white,
          elevation: 0,
          title: Text(
            'Address Book',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 15.spx,
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 12.wpx),
              child: FilledButton.icon(
                onPressed: controller.requiresAddressRelogin.value
                    ? controller.logout
                    : controller.isLoadingAddresses.value
                    ? null
                    : () {
                        final canOpen = controller.startAddAddress();
                        if (!canOpen) return;
                        if (!context.mounted) return;
                        _showAddressSheet(context);
                      },
                icon: Icon(
                  controller.requiresAddressRelogin.value
                      ? Icons.login_rounded
                      : Icons.add_circle_outline_rounded,
                  size: 13.spx,
                ),
                label: Text(
                  controller.requiresAddressRelogin.value
                      ? 'Login'
                      : 'Add Address',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  minimumSize: Size(0, 32.hpx),
                  padding: EdgeInsets.symmetric(
                    horizontal: 11.wpx,
                    vertical: 7.hpx,
                  ),
                  textStyle: TextStyle(
                    fontSize: 14.spx,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.rpx),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(12.wpx, 18.hpx, 12.wpx, 24.hpx),
          children: [
            if (controller.isLoadingAddresses.value)
              _AddressStateCard(
                child: Column(
                  children: [
                    SizedBox(
                      width: 28.wpx,
                      height: 28.hpx,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 14.hpx),
                    Text(
                      'Addresses load ho rahe hain...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              )
            else if (controller.addresses.isEmpty &&
                (controller.addressLoadError.value ?? '').isNotEmpty)
              _AddressStateCard(
                child: Column(
                  children: [
                    Icon(
                      controller.requiresAddressRelogin.value
                          ? Icons.lock_clock_outlined
                          : Icons.cloud_off_rounded,
                      size: 56,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 12.hpx),
                    Text(
                      controller.requiresAddressRelogin.value
                          ? 'Login required'
                          : 'Addresses unavailable',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8.hpx),
                    Text(
                      controller.addressLoadError.value!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: 16.hpx),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: controller.requiresAddressRelogin.value
                            ? controller.logout
                            : controller.loadAddresses,
                        child: Text(
                          controller.requiresAddressRelogin.value
                              ? 'Login Again'
                              : 'Retry',
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (controller.addresses.isEmpty)
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
            if (controller.addresses.isNotEmpty &&
                (controller.addressLoadError.value ?? '').isNotEmpty)
              Container(
                margin: EdgeInsets.only(bottom: 16.hpx),
                padding: EdgeInsets.all(14.rpx),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14.rpx),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.requiresAddressRelogin.value
                          ? 'Session issue'
                          : 'Sync issue',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.hpx),
                    Text(
                      controller.addressLoadError.value!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 10.hpx),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: controller.requiresAddressRelogin.value
                            ? controller.logout
                            : controller.loadAddresses,
                        child: Text(
                          controller.requiresAddressRelogin.value
                              ? 'Login Again'
                              : 'Retry Sync',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ...controller.addresses.map((address) {
              final active = address.isSelected;
              return Padding(
                padding: EdgeInsets.only(bottom: 12.hpx),
                child: Container(
                  padding: EdgeInsets.fromLTRB(13.wpx, 13.hpx, 13.wpx, 12.hpx),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x0F092774),
                        blurRadius: 5,
                        offset: Offset(0, 2),
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
                            size: 18.spx,
                          ),
                          SizedBox(width: 8.wpx),
                          Expanded(
                            child: Text(
                              address.fullName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.spx,
                                  ),
                            ),
                          ),
                          if (active)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
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
                                  fontSize: 15.spx,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 7.hpx),
                      Text(
                        address.address,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontSize: 15.spx,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: 7.hpx),
                      Text(
                        address.contactNumber,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 15.spx,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 3.hpx),
                      Text(
                        'Lat: ${address.latitude?.toStringAsFixed(6) ?? '-'}, Lng: ${address.longitude?.toStringAsFixed(6) ?? '-'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.75,
                          ),
                          fontSize: 14.spx,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 12.hpx),
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: _AddressActionButton(
                              onPressed: () => controller.useAddress(address),
                              icon: active
                                  ? Icons.check_circle_rounded
                                  : Icons.check_circle_outline_rounded,
                              label: active ? 'Selected' : 'Use this address',
                              filled: true,
                            ),
                          ),
                          SizedBox(width: 8.wpx),
                          Expanded(
                            flex: 3,
                            child: Tooltip(
                              message: 'Edit Address',
                              child: _AddressActionButton(
                                onPressed: () {
                                  controller.startEditAddress(address);
                                  _showAddressSheet(context);
                                },
                                icon: Icons.edit_outlined,
                                label: 'Edit',
                                filled: true,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.wpx),
                          Expanded(
                            flex: 3,
                            child: Tooltip(
                              message: 'Delete Address',
                              child: _AddressActionButton(
                                onPressed: () {
                                  controller.deleteAddress(address);
                                },
                                icon: Icons.delete_outline_rounded,
                                label: 'Delete',
                              ),
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
        return Obx(() {
          final editing = controller.editingAddress.value;
          final locationPreview = editing?.address.isNotEmpty == true
              ? editing!.address
              : controller.liveLocationAddress.value.trim().isNotEmpty
              ? controller.liveLocationAddress.value.trim()
              : controller.dashboardAddressLabel;

          return Padding(
            padding: EdgeInsets.only(
              left: 16.wpx,
              right: 16.wpx,
              top: 34.hpx,
              bottom: MediaQuery.of(context).viewInsets.bottom + 26.hpx,
            ),
            child: Container(
              padding: EdgeInsets.fromLTRB(24.wpx, 26.hpx, 24.wpx, 24.hpx),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20.rpx),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              editing == null
                                  ? 'Add New Address'
                                  : 'Edit Address',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          InkWell(
                            onTap: Get.back,
                            borderRadius: BorderRadius.circular(18.rpx),
                            child: Container(
                              width: 36.wpx,
                              height: 36.hpx,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(18.rpx),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 28.hpx),
                      Container(
                        padding: EdgeInsets.all(14.rpx),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14.rpx),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40.wpx,
                              height: 40.hpx,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(20.rpx),
                              ),
                              child: controller.isResolvingLocation.value
                                  ? Padding(
                                      padding: EdgeInsets.all(10.rpx),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : Icon(
                                      Icons.my_location_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                            ),
                            SizedBox(width: 12.wpx),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Delivery location',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => controller
                                            .resolveCurrentLocationForDraft(
                                              forceAddressFill: true,
                                            ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        icon: Icon(
                                          Icons.refresh_rounded,
                                          size: 16,
                                        ),
                                        label: Text('Refresh'),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.hpx),
                                  Text(
                                    locationPreview,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                          height: 1.4,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 28.hpx),
                      _AddressFieldLabel(text: 'Full Name'),
                      SizedBox(height: 8.hpx),
                      TextField(
                        controller: controller.addressNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Enter Customer Name',
                        ),
                      ),
                      SizedBox(height: 20.hpx),
                      _AddressFieldLabel(text: 'Contact Number'),
                      SizedBox(height: 8.hpx),
                      TextField(
                        controller: controller.addressPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Enter Mobile Number',
                        ),
                      ),
                      SizedBox(height: 20.hpx),
                      _AddressFieldLabel(text: 'Address'),
                      SizedBox(height: 8.hpx),
                      TextField(
                        controller: controller.addressLineController,
                        maxLines: 3,
                        minLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: controller.onAddressInputChanged,
                        decoration: InputDecoration(
                          hintText: 'House / Flat / Area / Landmark',
                          alignLabelWithHint: true,
                        ),
                      ),
                      if (controller.isResolvingSuggestions.value)
                        Padding(
                          padding: EdgeInsets.only(top: 10.hpx),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16.wpx,
                                height: 16.hpx,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(width: 10.wpx),
                              Text(
                                'Finding nearby matches...',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      if (controller.placeSuggestions.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(top: 10.hpx),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(14.rpx),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            children: controller.placeSuggestions
                                .map(
                                  (suggestion) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12.wpx,
                                      vertical: 2.hpx,
                                    ),
                                    leading: Icon(
                                      Icons.location_on_outlined,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                    title: Text(
                                      suggestion.primaryText.isNotEmpty
                                          ? suggestion.primaryText
                                          : suggestion.description,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    subtitle:
                                        suggestion.secondaryText.isNotEmpty
                                        ? Text(
                                            suggestion.secondaryText,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          )
                                        : null,
                                    onTap: () => controller
                                        .selectAddressSuggestion(suggestion),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      SizedBox(height: 24.hpx),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: Get.back,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: EdgeInsets.symmetric(vertical: 14.hpx),
                                side: BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.rpx),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.wpx),
                          Expanded(
                            child: FilledButton(
                              onPressed: controller.saveAddress,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.white,
                                padding: EdgeInsets.symmetric(vertical: 14.hpx),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.rpx),
                                ),
                              ),
                              child: Text(
                                editing == null
                                    ? 'Save Address'
                                    : 'Update Address',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }
}

class _AddressStateCard extends StatelessWidget {
  const _AddressStateCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.rpx),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(16.rpx),
      ),
      child: child,
    );
  }
}

class _AddressActionButton extends StatelessWidget {
  const _AddressActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.filled = false,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final background = filled ? AppColors.primary : AppColors.white;
    final foreground = filled ? AppColors.white : AppColors.primary;

    return SizedBox(
      height: 34.hpx,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 13.spx),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(fontSize: 14.spx, fontWeight: FontWeight.w800),
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: AppColors.primary, width: 1),
          padding: EdgeInsets.symmetric(horizontal: 8.wpx),
          iconColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7.rpx),
          ),
        ),
      ),
    );
  }
}

class _AddressFieldLabel extends StatelessWidget {
  const _AddressFieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
