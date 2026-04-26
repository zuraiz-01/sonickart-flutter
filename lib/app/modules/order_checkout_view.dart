import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'cart/controllers/cart_controller.dart';
import 'order_controller.dart';

class OrderCheckoutView extends GetView<OrderController> {
  OrderCheckoutView({super.key});

  @override
  Widget build(BuildContext context) {
    final cartController = Get.find<CartController>();
    return Scaffold(
      backgroundColor: Color(0xFFF5F8FF),
      appBar: AppBar(title: Text('Checkout'), centerTitle: true),
      body: Obx(
        () => Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(16.wpx, 16.hpx, 16.wpx, 120.hpx),
              children: [
                Container(
                  padding: EdgeInsets.all(14.rpx),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38.wpx,
                        height: 38.hpx,
                        decoration: BoxDecoration(
                          color: Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(19.rpx),
                        ),
                        child: Icon(
                          Icons.location_on_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 12.wpx),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delivery Address',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            SizedBox(height: 8.hpx),
                            TextField(
                              controller: controller.deliveryAddressController,
                              minLines: 2,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Enter delivery address',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            SizedBox(height: 6.hpx),
                            TextButton(
                              onPressed: () =>
                                  Get.toNamed(AppRoutes.addressBook),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                foregroundColor: AppColors.primary,
                              ),
                              child: Text(
                                'Manage Addresses',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.hpx),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    children: cartController.items.map((item) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surface,
                          child: Text(item.product.emoji),
                        ),
                        title: Text(
                          item.product.name,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${item.quantity} x ${item.product.unit}',
                        ),
                        trailing: Text(
                          'Rs ${item.totalPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 14.hpx),
                Container(
                  padding: EdgeInsets.all(16.rpx),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Mode',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      SizedBox(height: 12.hpx),
                      _PaymentTile(
                        title: 'Cash on Delivery',
                        value: 'COD',
                        groupValue: controller.selectedPaymentMode.value,
                        onChanged: controller.selectPaymentMode,
                      ),
                      _PaymentTile(
                        title: 'Online Payment',
                        value: 'Online',
                        groupValue: controller.selectedPaymentMode.value,
                        onChanged: controller.selectPaymentMode,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.hpx),
                Container(
                  padding: EdgeInsets.all(16.rpx),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coupons',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      SizedBox(height: 12.hpx),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller.couponCodeController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                hintText: 'Try SONIC10',
                              ),
                            ),
                          ),
                          SizedBox(width: 10.wpx),
                          FilledButton(
                            onPressed: () => controller.applyCoupon(
                              cartController.grandTotal,
                            ),
                            child: Text('Apply'),
                          ),
                        ],
                      ),
                      if (controller.appliedCoupon.value != null) ...[
                        SizedBox(height: 8.hpx),
                        Text(
                          '${controller.appliedCoupon.value} applied - Rs ${controller.couponDiscount.value.toStringAsFixed(0)} saved',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 14.hpx),
                Container(
                  padding: EdgeInsets.all(16.rpx),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    children: [
                      _CheckoutRow(
                        label: 'Items total',
                        value: cartController.subtotal,
                      ),
                      if (controller.couponDiscount.value > 0) ...[
                        SizedBox(height: 10.hpx),
                        _CheckoutRow(
                          label: 'Coupon discount',
                          value: -controller.couponDiscount.value,
                        ),
                      ],
                      SizedBox(height: 10.hpx),
                      _CheckoutRow(
                        label: 'Grand total',
                        value: controller.checkoutTotal(
                          cartController.grandTotal,
                        ),
                        strong: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: FilledButton(
                onPressed: controller.placeOrder,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.rpx),
                  ),
                ),
                child: controller.isPlacingOrder.value
                    ? SizedBox(
                        width: 18.wpx,
                        height: 18.hpx,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : Text(
                        'Place Order - Rs ${controller.checkoutTotal(cartController.grandTotal).toStringAsFixed(0)}',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  _PaymentTile({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      onChanged: (next) {
        if (next != null) {
          onChanged(next);
        }
      },
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CheckoutRow extends StatelessWidget {
  _CheckoutRow({required this.label, required this.value, this.strong = false});

  final String label;
  final double value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final weight = strong ? FontWeight.w800 : FontWeight.w600;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.primary, fontWeight: weight),
          ),
        ),
        Text(
          'Rs ${value.toStringAsFixed(0)}',
          style: TextStyle(color: AppColors.primary, fontWeight: weight),
        ),
      ],
    );
  }
}
