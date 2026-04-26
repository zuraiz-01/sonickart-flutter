import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../controllers/cart_controller.dart';

class CartSummaryBar extends StatelessWidget {
  CartSummaryBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();
    return Obx(() {
      final cartItems = cart.items.toList(growable: false);
      final totalItems = cartItems.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );
      if (totalItems <= 0) return SizedBox.shrink();
      final firstImage = cartItems.isEmpty
          ? ''
          : cartItems.first.product.resolvedImageUrl;
      return Padding(
        padding: EdgeInsets.fromLTRB(16.wpx, 0.hpx, 16.wpx, 12.hpx),
        child: Material(
          color: AppColors.white,
          elevation: 10,
          borderRadius: BorderRadius.circular(24.rpx),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.wpx, vertical: 8.hpx),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24.rpx),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => openDashboardTab(2),
                  borderRadius: BorderRadius.circular(18.rpx),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.rpx),
                        child: firstImage.isEmpty
                            ? Container(
                                width: 42.wpx,
                                height: 42.hpx,
                                color: AppColors.surface,
                                child: Icon(
                                  Icons.shopping_basket_outlined,
                                  color: AppColors.primary,
                                ),
                              )
                            : Image.network(
                                firstImage,
                                width: 42.wpx,
                                height: 42.hpx,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 42.wpx,
                                  height: 42.hpx,
                                  color: AppColors.surface,
                                  child: Icon(
                                    Icons.shopping_basket_outlined,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                      ),
                      SizedBox(width: 10.wpx),
                      Text(
                        '$totalItems Item${totalItems > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Spacer(),
                FilledButton(
                  onPressed: () => Get.toNamed(AppRoutes.checkout),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondaryBlue,
                    foregroundColor: AppColors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.rpx),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Next',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(width: 8.wpx),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
