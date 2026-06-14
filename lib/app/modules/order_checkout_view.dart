import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';

import '../core/utils/auth_guard.dart';
import '../data/models/app_ad_model.dart';
import '../data/models/address_model.dart';
import '../data/models/cart_item_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'ads/widgets/ad_placement.dart';
import 'cart/controllers/cart_controller.dart';
import 'order_controller.dart';
import 'profile/controllers/profile_controller.dart';

enum _AddressSheetResult { cancelled, keptCurrent, changed }

class OrderCheckoutView extends StatefulWidget {
  const OrderCheckoutView({super.key});

  @override
  State<OrderCheckoutView> createState() => _OrderCheckoutViewState();
}

class _OrderCheckoutViewState extends State<OrderCheckoutView> {
  late final OrderController controller = Get.find<OrderController>();
  late final CartController cartController = Get.find<CartController>();
  bool _showingAddressConfirmation = false;
  bool _showingPaymentOptions = false;

  @override
  void initState() {
    super.initState();
    unawaited(controller.preloadCheckoutContext());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Checkout',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 17.spx,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        toolbarHeight: 40.hpx,
        iconTheme: IconThemeData(color: AppColors.price, size: 17.spx),
      ),
      body: SafeArea(
        top: false,
        child: Obx(() {
          final items = cartController.items
              .where((item) => item.quantity > 0)
              .toList(growable: false);
          final totals = controller.calculateCheckoutTotals(items);
          final freeLeft = controller.freeDeliveryAmountLeft(items);
          final selectedCoupon = controller.selectedCoupon.value;
          final shouldLeaveCheckout =
              !cartController.isSyncingCart.value &&
              !controller.isPlacingOrder.value &&
              !controller.isValidatingCartAvailability.value &&
              !controller.isHandlingUnavailableCart.value &&
              items.isEmpty;
          if (shouldLeaveCheckout) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Get.currentRoute == AppRoutes.checkout) {
                Get.offNamed(AppRoutes.dashboard);
              }
            });
            return const SizedBox.shrink();
          }
          if (selectedCoupon != null) {
            final couponError = controller.couponEligibilityMessage(
              selectedCoupon,
              items,
            );
            if (couponError != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (controller.selectedCoupon.value?.id == selectedCoupon.id) {
                  controller.clearInvalidCoupon(couponError);
                }
              });
            }
          }

          return Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(8.wpx, 8.hpx, 8.wpx, 92.hpx),
                children: [
                  if (freeLeft > 0) ...[
                    _FreeDeliveryHint(amountLeft: freeLeft),
                    SizedBox(height: 10.hpx),
                  ],
                  _AddressCard(controller: controller),
                  SizedBox(height: 10.hpx),
                  if (items.isNotEmpty) ...[
                    _OrderListCard(items: items, cart: cartController),
                    SizedBox(height: 10.hpx),
                  ],
                  _CouponRow(controller: controller, totals: totals),
                  SizedBox(height: 10.hpx),
                  _BillDetails(totals: totals),
                  SizedBox(height: 10.hpx),
                  _DeliveryNoteBox(controller: controller),
                  SizedBox(height: 10.hpx),
                  const AdPlacement(placement: AppAdPlacement.checkout),
                ],
              ),
              Positioned(
                left: 16.wpx,
                right: 16.wpx,
                bottom: 10.hpx,
                child: _CheckoutFooter(
                  loading:
                      controller.isPlacingOrder.value ||
                      controller.isValidatingCartAvailability.value,
                  disabled:
                      items.isEmpty ||
                      totals.grandTotal <= 0 ||
                      controller.isHandlingUnavailableCart.value,
                  onPressed: () => unawaited(_showAddressConfirmation()),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _showAddressConfirmation() async {
    if (!requireAuth()) return;
    if (_showingAddressConfirmation ||
        _showingPaymentOptions ||
        controller.isPlacingOrder.value ||
        controller.isValidatingCartAvailability.value ||
        controller.isHandlingUnavailableCart.value ||
        Get.isDialogOpen == true) {
      return;
    }

    _showingAddressConfirmation = true;
    await Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: 24.wpx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.rpx),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(18.wpx, 20.hpx, 18.wpx, 16.hpx),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50.rpx,
                height: 50.rpx,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: AppColors.price,
                  size: 25.spx,
                ),
              ),
              SizedBox(height: 12.hpx),
              Text(
                'Confirm Delivery Address',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18.spx,
                ),
              ),
              SizedBox(height: 8.hpx),
              _ConfirmationAddressCard(
                recipient: controller.deliveryRecipient,
                address: controller.deliveryAddressPreview,
              ),
              SizedBox(height: 18.hpx),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => unawaited(
                        _handleAddressChangeFromConfirmation(context),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.22),
                        ),
                        minimumSize: Size(0, 44.hpx),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9.rpx),
                        ),
                        textStyle: TextStyle(
                          fontSize: 14.spx,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('Change'),
                    ),
                  ),
                  SizedBox(width: 10.wpx),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        _showingAddressConfirmation = false;
                        Get.back();
                        Future<void>.delayed(
                          const Duration(milliseconds: 90),
                          () {
                            if (mounted) {
                              unawaited(_showPaymentOptions());
                            }
                          },
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.buttonFill,
                        foregroundColor: AppColors.onButtonFill,
                        minimumSize: Size(0, 44.hpx),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9.rpx),
                        ),
                        textStyle: TextStyle(
                          fontSize: 14.spx,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierColor: AppColors.black.withValues(alpha: 0.45),
    );
    _showingAddressConfirmation = false;
  }

  Future<void> _handleAddressChangeFromConfirmation(
    BuildContext context,
  ) async {
    Get.back<void>();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!context.mounted) return;

    final result = await _showCheckoutAddressSheet(
      context,
      controller: controller,
    );
    if (result == _AddressSheetResult.cancelled) return;
    if (!context.mounted || Get.currentRoute != AppRoutes.checkout) return;
    if (controller.isHandlingUnavailableCart.value ||
        controller.isValidatingCartAvailability.value ||
        controller.isPlacingOrder.value) {
      return;
    }

    final cartController = Get.find<CartController>();
    final hasCheckoutItems = cartController.items.any(
      (item) => item.quantity > 0,
    );
    if (!hasCheckoutItems) return;

    unawaited(_showPaymentOptions());
  }

  Future<void> _showPaymentOptions() async {
    if (_showingPaymentOptions ||
        controller.isPlacingOrder.value ||
        controller.isValidatingCartAvailability.value ||
        controller.isHandlingUnavailableCart.value ||
        Get.isDialogOpen == true) {
      return;
    }

    _showingPaymentOptions = true;
    await Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: 28.wpx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.rpx),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(18.wpx, 20.hpx, 18.wpx, 16.hpx),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Payment\nMethod',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18.spx,
                  height: 1.25,
                ),
              ),
              SizedBox(height: 18.hpx),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: Get.back,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.22),
                        ),
                        minimumSize: Size(0, 44.hpx),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9.rpx),
                        ),
                        textStyle: TextStyle(
                          fontSize: 14.spx,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 10.wpx),
                  Expanded(
                    child: FilledButton(
                      onPressed: controller.isPlacingOrder.value
                          ? null
                          : () {
                              controller.selectPaymentMode('COD');
                              Get.back();
                              unawaited(controller.placeOrder());
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.buttonFill,
                        foregroundColor: AppColors.onButtonFill,
                        minimumSize: Size(0, 44.hpx),
                        padding: EdgeInsets.symmetric(horizontal: 8.wpx),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9.rpx),
                        ),
                        textStyle: TextStyle(
                          fontSize: 13.spx,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: const Text(
                        'Cash On Delivery',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierColor: AppColors.black.withValues(alpha: 0.45),
    );
    _showingPaymentOptions = false;
  }
}

class _DeliveryNoteBox extends StatelessWidget {
  const _DeliveryNoteBox({required this.controller});

  final OrderController controller;

  static const _quickNotes = [
    'Call on arrival',
    'Leave at door',
    'Don\u2019t ring bell',
    'Avoid calling',
    'Give to security',
  ];

  void _showQuickNotes(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.fromLTRB(20.wpx, 16.hpx, 20.wpx, 24.hpx),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.rpx)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt_rounded, color: AppColors.accent, size: 20.spx),
                SizedBox(width: 8.wpx),
                Text(
                  'Quick Notes',
                  style: TextStyle(
                    color: AppColors.price,
                    fontWeight: FontWeight.w900,
                    fontSize: 16.spx,
                  ),
                ),
                Spacer(),
                InkWell(
                  onTap: () => Get.back<void>(),
                  borderRadius: BorderRadius.circular(18.rpx),
                  child: Container(
                    width: 32.wpx,
                    height: 32.hpx,
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: AppColors.price,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.hpx),
            Text(
              'Tap to add a note',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14.spx,
              ),
            ),
            SizedBox(height: 14.hpx),
            ..._quickNotes.map(
              (note) => Padding(
                padding: EdgeInsets.only(bottom: 8.hpx),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      controller.deliveryNoteController.text = note;
                      Get.back<void>();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.price,
                      side: BorderSide(
                        color: AppColors.price.withValues(alpha: 0.2),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14.hpx),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.rpx),
                      ),
                    ),
                    child: Text(
                      note,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.spx,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.rpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sticky_note_2_outlined,
                color: AppColors.price,
                size: 18.spx,
              ),
              SizedBox(width: 8.wpx),
              Text(
                'Delivery Note',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15.spx,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.hpx),
          TextField(
            controller: controller.deliveryNoteController,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.rpx),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.rpx),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.rpx),
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          SizedBox(height: 10.hpx),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showQuickNotes(context),
              icon: Icon(Icons.bolt_rounded, size: 16.spx),
              label: Text(
                'Quick Notes',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.spx),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.4),
                ),
                padding: EdgeInsets.symmetric(vertical: 10.hpx),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.rpx),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationAddressCard extends StatelessWidget {
  const _ConfirmationAddressCard({
    required this.recipient,
    required this.address,
  });

  final String recipient;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.rpx),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.home_outlined, color: AppColors.price, size: 19.spx),
          SizedBox(width: 9.wpx),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipient,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.spx,
                  ),
                ),
                SizedBox(height: 4.hpx),
                Text(
                  address,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                    fontSize: 14.spx,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeDeliveryHint extends StatelessWidget {
  const _FreeDeliveryHint({required this.amountLeft});

  final double amountLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.wpx, vertical: 10.hpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(9.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
        boxShadow: _softShadow,
      ),
      child: Row(
        children: [
          _CircleIcon(icon: Icons.local_shipping_outlined),
          SizedBox(width: 10.wpx),
          Expanded(
            child: Text(
              'Add ₹${amountLeft.toStringAsFixed(2)} more for free delivery',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 15.spx,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.controller});

  final OrderController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final recipient = controller.deliveryRecipient;
      final address = controller.deliveryAddressPreview;
      return InkWell(
        onTap: () => _showAddressSheet(context),
        borderRadius: BorderRadius.circular(9.rpx),
        child: Container(
          padding: EdgeInsets.fromLTRB(12.wpx, 10.hpx, 10.wpx, 10.hpx),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(9.rpx),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            boxShadow: _softShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CircleIcon(icon: Icons.location_on_outlined),
              SizedBox(width: 10.wpx),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deliver to',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.spx,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: 4.hpx),
                    Text(
                      recipient,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.spx,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: 4.hpx),
                    Text(
                      address,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                        fontSize: 14.spx,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.primary, size: 18.spx),
            ],
          ),
        ),
      );
    });
  }

  void _showAddressSheet(BuildContext context) {
    unawaited(_showCheckoutAddressSheet(context, controller: controller));
  }
}

Future<_AddressSheetResult> _showCheckoutAddressSheet(
  BuildContext context, {
  required OrderController controller,
}) async {
  final profile = Get.isRegistered<ProfileController>()
      ? Get.find<ProfileController>()
      : null;
  if (profile != null &&
      profile.addresses.isEmpty &&
      !profile.isLoadingAddresses.value) {
    unawaited(profile.loadAddresses());
  }

  final result = await Get.bottomSheet<_AddressSheetResult>(
    SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        padding: EdgeInsets.fromLTRB(16.wpx, 12.hpx, 16.wpx, 16.hpx),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.rpx)),
        ),
        child: Obx(() {
          final addresses = profile?.addresses.toList(growable: false) ?? [];
          final isLoading = profile?.isLoadingAddresses.value == true;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (controller.isValidatingCartAvailability.value) ...[
                LinearProgressIndicator(
                  minHeight: 3.hpx,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                ),
                SizedBox(height: 10.hpx),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select delivery address',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18.spx,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back<_AddressSheetResult>(
                      result: _AddressSheetResult.cancelled,
                    ),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              SizedBox(height: 8.hpx),
              if (isLoading)
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 28.wpx,
                      height: 28.wpx,
                      child: const CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                )
              else if (addresses.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No saved addresses yet. Add one from Address Book.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.spx,
                          ),
                        ),
                        SizedBox(height: 14.hpx),
                        FilledButton.icon(
                          onPressed: () {
                            Get.back<_AddressSheetResult>(
                              result: _AddressSheetResult.cancelled,
                            );
                            Get.toNamed(AppRoutes.addressBook);
                          },
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: const Text('Add Address'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: addresses.length,
                    separatorBuilder: (_, _) => SizedBox(height: 10.hpx),
                    itemBuilder: (context, index) {
                      final address = addresses[index];
                      final selected = _isSelectedCheckoutAddress(
                        controller.selectedCheckoutAddress.value,
                        address,
                      );
                      final isSelecting =
                          controller.selectingCheckoutAddressId.value ==
                          address.id;
                      return InkWell(
                        onTap: isSelecting
                            ? null
                            : () async {
                                if (selected) {
                                  Get.back<_AddressSheetResult>(
                                    result: _AddressSheetResult.keptCurrent,
                                  );
                                  return;
                                }

                                final didSelect = await controller
                                    .selectAddress(address);
                                if (!didSelect) return;
                                if (Get.isBottomSheetOpen == true) {
                                  Get.back<_AddressSheetResult>(
                                    result: _AddressSheetResult.changed,
                                  );
                                }
                              },
                        borderRadius: BorderRadius.circular(14.rpx),
                        child: Container(
                          padding: EdgeInsets.all(14.rpx),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.muted
                                : AppColors.inputFill,
                            borderRadius: BorderRadius.circular(14.rpx),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isSelecting
                                    ? Icons.hourglass_top_rounded
                                    : selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 10.wpx),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      address.fullName,
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16.spx,
                                      ),
                                    ),
                                    SizedBox(height: 4.hpx),
                                    Text(
                                      address.address,
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.spx,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelecting)
                                SizedBox(
                                  width: 18.rpx,
                                  height: 18.rpx,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (addresses.isNotEmpty) ...[
                SizedBox(height: 12.hpx),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Get.back<_AddressSheetResult>(
                        result: _AddressSheetResult.cancelled,
                      );
                      Get.toNamed(AppRoutes.addressBook);
                    },
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Manage Addresses'),
                  ),
                ),
              ],
            ],
          );
        }),
      ),
    ),
    isScrollControlled: true,
  );

  return result ?? _AddressSheetResult.cancelled;
}

bool _isSelectedCheckoutAddress(
  AddressModel? selected,
  AddressModel candidate,
) {
  if (selected == null) return false;
  final selectedId = selected.id.trim();
  final candidateId = candidate.id.trim();
  final selectedAddress = selected.address.trim().toLowerCase();
  final candidateAddress = candidate.address.trim().toLowerCase();
  if (selectedId.isNotEmpty && candidateId.isNotEmpty) {
    return selectedId == candidateId && selectedAddress == candidateAddress;
  }

  return selectedAddress == candidateAddress;
}

class _OrderListCard extends StatelessWidget {
  const _OrderListCard({required this.items, required this.cart});

  final List<CartItemModel> items;
  final CartController cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(9.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
        boxShadow: _softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: items.map((item) {
          return _OrderItemTile(item: item, cart: cart);
        }).toList(),
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({required this.item, required this.cart});

  final CartItemModel item;
  final CartController cart;

  @override
  Widget build(BuildContext context) {
    final image = item.product.resolvedImageUrl;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.wpx, vertical: 10.hpx),
      child: Row(
        children: [
          Container(
            width: 52.wpx,
            height: 52.wpx,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(8.rpx),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.10),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: image.isNotEmpty
                ? Image.network(
                    image,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _ProductFallback(item: item),
                  )
                : _ProductFallback(item: item),
          ),
          SizedBox(width: 10.wpx),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.spx,
                  ),
                ),
                SizedBox(height: 3.hpx),
                Text(
                  '₹${item.unitPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColors.price,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.spx,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.wpx),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 5.wpx, vertical: 4.hpx),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                _QtyButton(
                  icon: Icons.remove,
                  onTap: () => cart.removeItem(item.product.id),
                ),
                SizedBox(
                  width: 28.wpx,
                  child: Text(
                    '${item.quantity}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.spx,
                    ),
                  ),
                ),
                _QtyButton(
                  icon: Icons.add,
                  onTap: () => cart.addItem(item.product),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFallback extends StatelessWidget {
  const _ProductFallback({required this.item});

  final CartItemModel item;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        item.product.emoji.isNotEmpty ? item.product.emoji : '?',
        style: TextStyle(fontSize: 24.spx),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.rpx),
      child: Container(
        width: 25.wpx,
        height: 25.wpx,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.price),
        ),
        child: Icon(icon, color: AppColors.price, size: 14.spx),
      ),
    );
  }
}

class _CouponRow extends StatelessWidget {
  const _CouponRow({required this.controller, required this.totals});

  final OrderController controller;
  final CheckoutTotals totals;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        controller.couponFeedback.value = null;
        unawaited(controller.loadCouponsForCart());
        _showCouponSheet(context);
      },
      borderRadius: BorderRadius.circular(9.rpx),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.wpx, vertical: 12.hpx),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(9.rpx),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
          boxShadow: _softShadow,
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/icons/coupon.png',
              width: 24.rpx,
              height: 24.rpx,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.confirmation_number_outlined),
            ),
            SizedBox(width: 10.wpx),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use Coupons',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.spx,
                    ),
                  ),
                  if (totals.appliedCoupon != null) ...[
                    SizedBox(height: 4.hpx),
                    Text(
                      '${totals.appliedCoupon!.code} applied | Save \u20B9${totals.couponDiscount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.spx,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (totals.appliedCoupon != null)
              TextButton(
                onPressed: () {
                  controller.removeAppliedCoupon();
                },
                child: const Text('Remove'),
              ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 17.spx,
            ),
          ],
        ),
      ),
    );
  }

  void _showCouponSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
          ),
          padding: EdgeInsets.fromLTRB(14.wpx, 14.hpx, 14.wpx, 16.hpx),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18.rpx)),
          ),
          child: Obx(() {
            final cart = Get.find<CartController>();
            final totals = controller.calculateCheckoutTotals(cart.items);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Apply coupon',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15.spx,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.primary,
                        size: 18.spx,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.hpx),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller.couponCodeController,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 15.spx,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.confirmation_number_outlined,
                            color: AppColors.primary,
                            size: 16.spx,
                          ),
                          hintText: 'Enter coupon code',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15.spx,
                            fontWeight: FontWeight.w500,
                          ),
                          filled: true,
                          fillColor: AppColors.inputFill,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.wpx,
                            vertical: 13.hpx,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.rpx),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.rpx),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.rpx),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.wpx),
                    SizedBox(
                      height: 44.hpx,
                      width: 76.wpx,
                      child: FilledButton(
                        onPressed: controller.isApplyingCoupon.value
                            ? null
                            : () async {
                                final applied = await controller.applyCoupon();
                                if (applied && sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.buttonFill,
                          foregroundColor: AppColors.onButtonFill,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.rpx),
                          ),
                          textStyle: TextStyle(
                            fontSize: 15.spx,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        child: controller.isApplyingCoupon.value
                            ? SizedBox(
                                width: 16.wpx,
                                height: 16.wpx,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onButtonFill,
                                ),
                              )
                            : const Text('Apply'),
                      ),
                    ),
                  ],
                ),
                if (controller.couponFeedback.value != null) ...[
                  SizedBox(height: 8.hpx),
                  Text(
                    controller.couponFeedback.value!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.spx,
                    ),
                  ),
                ],
                SizedBox(height: 12.hpx),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.rpx),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(8.rpx),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current cart total',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.spx,
                        ),
                      ),
                      SizedBox(height: 3.hpx),
                      Text(
                        '₹${totals.grandTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppColors.price,
                          fontWeight: FontWeight.w900,
                          fontSize: 15.spx,
                        ),
                      ),
                      if (totals.appliedCoupon != null &&
                          totals.couponDiscount > 0) ...[
                        SizedBox(height: 4.hpx),
                        Text(
                          'Applied ${totals.appliedCoupon!.code} | Saved ₹${totals.couponDiscount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.spx,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 14.hpx),
                Text(
                  'Available offers',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.spx,
                  ),
                ),
                SizedBox(height: 8.hpx),
                Expanded(
                  child: controller.isLoadingCoupons.value
                      ? const Center(child: CircularProgressIndicator())
                      : controller.availableCoupons.isEmpty
                      ? Center(
                          child: Text(
                            'No coupons available right now.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15.spx,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: controller.availableCoupons.length,
                          separatorBuilder: (_, _) => SizedBox(height: 10.hpx),
                          itemBuilder: (itemContext, index) {
                            final coupon = controller.availableCoupons[index];
                            final applied =
                                controller.selectedCoupon.value?.code ==
                                coupon.code;
                            final eligibility = controller
                                .couponEligibilityMessage(coupon, cart.items);
                            return _CouponCard(
                              coupon: coupon,
                              applied: applied,
                              eligibilityMessage: eligibility,
                              onApply: () async {
                                if (eligibility != null && !applied) {
                                  controller.couponFeedback.value = eligibility;
                                  return;
                                }
                                final ok = await controller.applyCoupon(coupon);
                                if (ok && sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          }),
        );
      },
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.coupon,
    required this.applied,
    required this.eligibilityMessage,
    required this.onApply,
  });

  final CheckoutCoupon coupon;
  final bool applied;
  final String? eligibilityMessage;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final eligible = eligibilityMessage == null;
    final value = coupon.discountType == CouponDiscountType.percentage
        ? '${coupon.discountValue.toStringAsFixed(0)}% OFF'
        : 'SAVE ₹${coupon.discountValue.toStringAsFixed(0)}';
    return Container(
      padding: EdgeInsets.all(12.rpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coupon.code,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.spx,
                  ),
                ),
                SizedBox(height: 3.hpx),
                Text(
                  coupon.title,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.spx,
                  ),
                ),
                if (coupon.description.isNotEmpty) ...[
                  SizedBox(height: 4.hpx),
                  Text(
                    coupon.description,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14.spx,
                    ),
                  ),
                ],
                if (coupon.category.isNotEmpty) ...[
                  SizedBox(height: 6.hpx),
                  Text(
                    'Category: ${coupon.category}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15.spx,
                    ),
                  ),
                ],
                if (coupon.minimumOrderAmount > 0) ...[
                  SizedBox(height: 4.hpx),
                  Text(
                    'Min order: ₹${coupon.minimumOrderAmount.toStringAsFixed(coupon.minimumOrderAmount == coupon.minimumOrderAmount.roundToDouble() ? 0 : 2)}',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 15.spx,
                    ),
                  ),
                ],
                if (!eligible) ...[
                  SizedBox(height: 6.hpx),
                  Text(
                    eligibilityMessage!,
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 15.spx,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 10.wpx),
          Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10.wpx,
                  vertical: 6.hpx,
                ),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: AppColors.price,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.spx,
                  ),
                ),
              ),
              SizedBox(height: 8.hpx),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8.wpx,
                  vertical: 4.hpx,
                ),
                decoration: BoxDecoration(
                  color: eligible
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  eligible ? 'Eligible' : 'Not eligible',
                  style: TextStyle(
                    color: eligible ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.spx,
                  ),
                ),
              ),
              SizedBox(height: 8.hpx),
              OutlinedButton(
                onPressed: onApply,
                style: OutlinedButton.styleFrom(
                  foregroundColor: applied
                      ? AppColors.white
                      : eligible
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  backgroundColor: applied
                      ? AppColors.primary
                      : AppColors.white,
                  side: BorderSide(
                    color: eligible
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.18),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 9.wpx),
                  minimumSize: Size(0, 30.hpx),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.rpx),
                  ),
                  textStyle: TextStyle(
                    fontSize: 15.spx,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(
                  applied
                      ? 'Applied'
                      : eligible
                      ? 'Apply'
                      : 'Not eligible',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BillDetails extends StatelessWidget {
  const _BillDetails({required this.totals});

  final CheckoutTotals totals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.hpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(9.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.wpx),
            child: Text(
              'Bill Details',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 15.spx,
              ),
            ),
          ),
          SizedBox(height: 12.hpx),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.wpx),
            child: Column(
              children: [
                _BillRow(
                  icon: Icons.article_outlined,
                  label: 'Items Total (Incl. GST)',
                  value: totals.totalBeforeDiscount,
                ),
                SizedBox(height: 10.hpx),
                _BillRow(
                  icon: Icons.pedal_bike_outlined,
                  label: 'Delivery Charge',
                  value: totals.deliveryCharge,
                ),
                if (totals.appliedCoupon != null &&
                    totals.couponDiscount > 0) ...[
                  SizedBox(height: 10.hpx),
                  _BillRow(
                    icon: Icons.sell_outlined,
                    label: 'Coupon (${totals.appliedCoupon!.code})',
                    value: -totals.couponDiscount,
                    isDiscount: true,
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 22.hpx, color: AppColors.border),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.wpx),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Grand Total',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.spx,
                    ),
                  ),
                ),
                Text(
                  '₹${totals.grandTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColors.price,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.spx,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isDiscount = false,
  });

  final IconData icon;
  final String label;
  final double value;
  final bool isDiscount;

  @override
  Widget build(BuildContext context) {
    final display = value < 0
        ? '-₹${value.abs().toStringAsFixed(2)}'
        : '₹${value.toStringAsFixed(2)}';
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 14.spx),
        SizedBox(width: 7.wpx),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14.spx,
            ),
          ),
        ),
        Text(
          display,
          style: TextStyle(
            color: isDiscount ? AppColors.success : AppColors.price,
            fontWeight: FontWeight.w800,
            fontSize: 15.spx,
          ),
        ),
      ],
    );
  }
}

class _CheckoutFooter extends StatelessWidget {
  const _CheckoutFooter({
    required this.loading,
    required this.disabled,
    required this.onPressed,
  });

  final bool loading;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44.hpx,
      child: FilledButton(
        onPressed: disabled || loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.buttonFill,
          foregroundColor: AppColors.onButtonFill,
          disabledBackgroundColor: AppColors.buttonFill.withValues(alpha: 0.45),
          padding: EdgeInsets.symmetric(horizontal: 16.wpx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7.rpx),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 18.wpx,
                height: 18.wpx,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.onButtonFill,
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: Text(
                      'PLACE ORDER',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.spx,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18.spx),
                ],
              ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30.wpx,
      height: 30.wpx,
      decoration: BoxDecoration(color: AppColors.muted, shape: BoxShape.circle),
      child: Icon(icon, color: AppColors.price, size: 15.spx),
    );
  }
}

final _softShadow = [
  BoxShadow(
    color: AppColors.black.withValues(alpha: 0.07),
    blurRadius: 7,
    offset: const Offset(0, 3),
  ),
];
