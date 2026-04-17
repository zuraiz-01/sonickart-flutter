import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../controllers/cart_controller.dart';

class CartSummaryBar extends StatelessWidget {
  const CartSummaryBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();
    return Obx(() {
      final cartItems = cart.items.toList(growable: false);
      final totalItems = cartItems.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );
      if (totalItems <= 0) return const SizedBox.shrink();
      final firstImage = cartItems.isEmpty
          ? ''
          : cartItems.first.product.resolvedImageUrl;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Material(
          color: AppColors.white,
          elevation: 10,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Get.offNamed(
                    AppRoutes.dashboard,
                    arguments: {'tabIndex': 2},
                  ),
                  borderRadius: BorderRadius.circular(18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: firstImage.isEmpty
                            ? Container(
                                width: 42,
                                height: 42,
                                color: AppColors.surface,
                                child: const Icon(
                                  Icons.shopping_basket_outlined,
                                  color: AppColors.primary,
                                ),
                              )
                            : Image.network(
                                firstImage,
                                width: 42,
                                height: 42,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 42,
                                  height: 42,
                                  color: AppColors.surface,
                                  child: const Icon(
                                    Icons.shopping_basket_outlined,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$totalItems Item${totalItems > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Get.toNamed(AppRoutes.checkout),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondaryBlue,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Next', style: TextStyle(fontWeight: FontWeight.w800)),
                      SizedBox(width: 8),
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
