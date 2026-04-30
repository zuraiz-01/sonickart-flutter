import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';

import '../data/models/cart_item_model.dart';
import '../theme/app_colors.dart';
import 'cart/controllers/cart_controller.dart';
import 'order_controller.dart';
import 'profile/controllers/profile_controller.dart';

class OrderCheckoutView extends GetView<OrderController> {
  const OrderCheckoutView({super.key});

  @override
  Widget build(BuildContext context) {
    final cartController = Get.find<CartController>();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text('Checkout'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF5F8FF),
        surfaceTintColor: const Color(0xFFF5F8FF),
      ),
      body: Obx(() {
        final items = cartController.items.toList(growable: false);
        final totals = controller.calculateCheckoutTotals(items);
        final freeLeft = controller.freeDeliveryAmountLeft(items);
        final selectedCoupon = controller.selectedCoupon.value;
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
              padding: EdgeInsets.fromLTRB(16.wpx, 12.hpx, 16.wpx, 120.hpx),
              children: [
                if (freeLeft > 0) ...[
                  _FreeDeliveryHint(amountLeft: freeLeft),
                  SizedBox(height: 12.hpx),
                ],
                _AddressCard(controller: controller),
                SizedBox(height: 14.hpx),
                _OrderListCard(items: items, cart: cartController),
                SizedBox(height: 14.hpx),
                _CouponRow(controller: controller, totals: totals),
                SizedBox(height: 14.hpx),
                _BillDetails(totals: totals),
              ],
            ),
            Positioned(
              left: 16.wpx,
              right: 16.wpx,
              bottom: 16.hpx,
              child: _CheckoutFooter(
                loading: controller.isPlacingOrder.value,
                disabled: items.isEmpty || totals.grandTotal <= 0,
                onPressed: () => _showAddressConfirmation(context),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _showAddressConfirmation(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Continue with selected address?'),
        content: Text(
          'Selected address:\n${controller.deliveryAddressPreview}',
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Get.back();
              _showPaymentOptions(context);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showPaymentOptions(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Choose payment method'),
        content: const Text('How would you like to pay for this order?'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              controller.selectPaymentMode('COD');
              Get.back();
              controller.placeOrder();
            },
            child: const Text('Cash on Delivery'),
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
      padding: EdgeInsets.all(14.rpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
        boxShadow: _softShadow,
      ),
      child: Row(
        children: [
          _CircleIcon(icon: Icons.local_shipping_outlined),
          SizedBox(width: 12.wpx),
          Expanded(
            child: Text(
              'Add Rs ${amountLeft.toStringAsFixed(2)} more for free delivery',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 13.spx,
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
    return InkWell(
      onTap: () => _showAddressSheet(context),
      borderRadius: BorderRadius.circular(18.rpx),
      child: Container(
        padding: EdgeInsets.all(14.rpx),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18.rpx),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
          boxShadow: _softShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CircleIcon(icon: Icons.location_on_outlined),
            SizedBox(width: 12.wpx),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deliver to',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.spx,
                    ),
                  ),
                  SizedBox(height: 4.hpx),
                  Text(
                    controller.deliveryRecipient,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.spx,
                    ),
                  ),
                  SizedBox(height: 4.hpx),
                  Text(
                    controller.deliveryAddressPreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.spx,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  void _showAddressSheet(BuildContext context) {
    final profile = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : null;
    Get.bottomSheet(
      SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          padding: EdgeInsets.fromLTRB(16.wpx, 12.hpx, 16.wpx, 16.hpx),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.rpx)),
          ),
          child: Obx(() {
            final addresses = profile?.addresses.toList(growable: false) ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      onPressed: Get.back,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                SizedBox(height: 8.hpx),
                if (addresses.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'No saved addresses yet. Add one from Address Book.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.spx,
                        ),
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
                        final selected =
                            controller.selectedCheckoutAddress.value?.id ==
                            address.id;
                        return InkWell(
                          onTap: () async {
                            await controller.selectAddress(address);
                            Get.back();
                          },
                          borderRadius: BorderRadius.circular(14.rpx),
                          child: Container(
                            padding: EdgeInsets.all(14.rpx),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFEEF4FF)
                                  : const Color(0xFFF8FAFF),
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
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 10.wpx),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        address.fullName,
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.spx,
                                        ),
                                      ),
                                      SizedBox(height: 4.hpx),
                                      Text(
                                        address.address,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.spx,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
      isScrollControlled: true,
    );
  }
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
        borderRadius: BorderRadius.circular(22.rpx),
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
      padding: EdgeInsets.symmetric(horizontal: 14.wpx, vertical: 14.hpx),
      child: Row(
        children: [
          Container(
            width: 70.wpx,
            height: 70.wpx,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7FF),
              borderRadius: BorderRadius.circular(18.rpx),
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
          SizedBox(width: 14.wpx),
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
                SizedBox(height: 4.hpx),
                Text(
                  'Rs ${item.unitPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.spx,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.wpx),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.wpx, vertical: 6.hpx),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
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
        width: 32.wpx,
        height: 32.wpx,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18.spx),
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
      onTap: () => _showCouponSheet(context),
      borderRadius: BorderRadius.circular(18.rpx),
      child: Container(
        padding: EdgeInsets.all(16.rpx),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18.rpx),
          boxShadow: _softShadow,
        ),
        child: Row(
          children: [
            _CircleIcon(icon: Icons.confirmation_number_outlined),
            SizedBox(width: 12.wpx),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use Coupons',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16.spx,
                    ),
                  ),
                  if (totals.appliedCoupon != null) ...[
                    SizedBox(height: 4.hpx),
                    Text(
                      '${totals.appliedCoupon!.code} applied | Save Rs ${totals.couponDiscount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.spx,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (totals.appliedCoupon != null)
              TextButton(
                onPressed: controller.removeAppliedCoupon,
                child: const Text('Remove'),
              ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showCouponSheet(BuildContext context) {
    controller.openCouponSheet();
    Get.bottomSheet(
      SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          padding: EdgeInsets.fromLTRB(16.wpx, 12.hpx, 16.wpx, 16.hpx),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.rpx)),
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
                          fontSize: 18.spx,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: Get.back,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller.couponCodeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.local_activity_outlined),
                          hintText: 'Enter coupon code',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.rpx),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.wpx),
                    FilledButton(
                      onPressed: controller.isApplyingCoupon.value
                          ? null
                          : () async {
                              final applied = await controller.applyCoupon();
                              if (applied) Get.back();
                            },
                      child: controller.isApplyingCoupon.value
                          ? SizedBox(
                              width: 16.wpx,
                              height: 16.wpx,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Apply'),
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
                      fontSize: 12.spx,
                    ),
                  ),
                ],
                SizedBox(height: 12.hpx),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.rpx),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(16.rpx),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current cart total',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.spx,
                        ),
                      ),
                      SizedBox(height: 4.hpx),
                      Text(
                        'Rs ${totals.grandTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 18.spx,
                        ),
                      ),
                      if (totals.appliedCoupon != null &&
                          totals.couponDiscount > 0) ...[
                        SizedBox(height: 4.hpx),
                        Text(
                          'Applied ${totals.appliedCoupon!.code} | Saved Rs ${totals.couponDiscount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.spx,
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
                    fontSize: 15.spx,
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
                              fontSize: 13.spx,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: controller.availableCoupons.length,
                          separatorBuilder: (_, _) => SizedBox(height: 10.hpx),
                          itemBuilder: (context, index) {
                            final coupon = controller.availableCoupons[index];
                            final applied =
                                controller.selectedCoupon.value?.id ==
                                coupon.id;
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
                                if (ok) Get.back();
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          }),
        ),
      ),
      isScrollControlled: true,
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
        : 'SAVE Rs ${coupon.discountValue.toStringAsFixed(0)}';
    return Container(
      padding: EdgeInsets.all(14.rpx),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(16.rpx),
        border: Border.all(color: AppColors.border),
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
                    fontSize: 15.spx,
                  ),
                ),
                SizedBox(height: 4.hpx),
                Text(
                  coupon.title,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.spx,
                  ),
                ),
                if (coupon.description.isNotEmpty) ...[
                  SizedBox(height: 4.hpx),
                  Text(
                    coupon.description,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 12.spx,
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
                      fontSize: 11.spx,
                    ),
                  ),
                ],
                if (coupon.minimumOrderAmount > 0) ...[
                  SizedBox(height: 4.hpx),
                  Text(
                    'Min order: Rs ${coupon.minimumOrderAmount.toStringAsFixed(coupon.minimumOrderAmount == coupon.minimumOrderAmount.roundToDouble() ? 0 : 2)}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.spx,
                    ),
                  ),
                ],
                SizedBox(height: 6.hpx),
                Text(
                  eligibilityMessage == null ? 'Eligible' : eligibilityMessage!,
                  style: TextStyle(
                    color: eligible ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.spx,
                  ),
                ),
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
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10.spx,
                  ),
                ),
              ),
              SizedBox(height: 10.hpx),
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
                    fontSize: 10.spx,
                  ),
                ),
              ),
              SizedBox(height: 10.hpx),
              OutlinedButton(
                onPressed: onApply,
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
      padding: EdgeInsets.symmetric(vertical: 18.hpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18.rpx),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.wpx),
            child: Text(
              'Bill Details',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 18.spx,
              ),
            ),
          ),
          SizedBox(height: 14.hpx),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.wpx),
            child: Column(
              children: [
                _BillRow(
                  icon: Icons.article_outlined,
                  label: 'Items total (incl. GST)',
                  value: totals.totalBeforeDiscount,
                ),
                SizedBox(height: 12.hpx),
                _BillRow(
                  icon: Icons.pedal_bike_outlined,
                  label: 'Delivery charge',
                  value: totals.deliveryCharge,
                ),
                if (totals.appliedCoupon != null &&
                    totals.couponDiscount > 0) ...[
                  SizedBox(height: 12.hpx),
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
          Divider(height: 28.hpx, color: AppColors.border),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.wpx),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Grand Total',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 17.spx,
                    ),
                  ),
                ),
                Text(
                  'Rs ${totals.grandTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 17.spx,
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
        ? '-Rs ${value.abs().toStringAsFixed(2)}'
        : 'Rs ${value.toStringAsFixed(2)}';
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 18.spx),
        SizedBox(width: 8.wpx),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13.spx,
            ),
          ),
        ),
        Text(
          display,
          style: TextStyle(
            color: isDiscount ? AppColors.success : AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 13.spx,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24.rpx),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(10.rpx),
        child: FilledButton(
          onPressed: disabled || loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
            padding: EdgeInsets.symmetric(vertical: 16.hpx),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18.rpx),
            ),
          ),
          child: loading
              ? SizedBox(
                  width: 20.wpx,
                  height: 20.wpx,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: AppColors.white,
                  ),
                )
              : Text(
                  'PLACE ORDER',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.spx,
                  ),
                ),
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
      width: 38.wpx,
      height: 38.wpx,
      decoration: const BoxDecoration(
        color: Color(0xFFEEF4FF),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.primary, size: 19.spx),
    );
  }
}

final _softShadow = [
  BoxShadow(
    color: AppColors.black.withValues(alpha: 0.05),
    blurRadius: 10,
    offset: const Offset(0, 4),
  ),
];
