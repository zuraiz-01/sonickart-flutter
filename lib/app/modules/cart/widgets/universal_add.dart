import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../../../data/models/product_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../controllers/cart_controller.dart';

class UniversalAdd extends StatelessWidget {
  UniversalAdd({
    required this.product,
    this.width,
    this.showOptionsOnInitialAdd = true,
    super.key,
  });

  final ProductModel product;
  final double? width;
  final bool showOptionsOnInitialAdd;

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();
    return Obx(() {
      final count = cart.items
          .where((item) => item.product.id == product.id)
          .fold<int>(0, (sum, item) => sum + item.quantity);
      return AnimatedContainer(
        duration: Duration(milliseconds: 180),
        width: width ?? double.infinity,
        constraints: BoxConstraints(minHeight: 40.hpx),
        decoration: BoxDecoration(
          color: count == 0 ? AppColors.accent : AppColors.secondaryBlue,
          borderRadius: BorderRadius.circular(8.rpx),
        ),
        child: count == 0
            ? InkWell(
                onTap: () {
                  if (showOptionsOnInitialAdd) {
                    _showAddOptions(context, cart);
                    return;
                  }
                  cart.addItem(product);
                },
                borderRadius: BorderRadius.circular(8.rpx),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.wpx,
                      vertical: 10.hpx,
                    ),
                    child: Text(
                      'ADD',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.spx,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              )
            : Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 4.wpx,
                  vertical: 5.hpx,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CounterTap(
                      icon: Icons.remove_rounded,
                      onTap: () => cart.removeItem(product.id),
                    ),
                    Text(
                      '$count',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 13.spx,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _CounterTap(
                      icon: Icons.add_rounded,
                      onTap: () => cart.addItem(product),
                    ),
                  ],
                ),
              ),
      );
    });
  }

  Future<void> _showAddOptions(
    BuildContext context,
    CartController cart,
  ) async {
    await Get.bottomSheet<void>(
      SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(20.wpx, 18.hpx, 20.wpx, 20.hpx),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22.rpx)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose An Option',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8.hpx),
              Text(
                'How would you like to proceed with ${product.name.trim().isEmpty ? 'this item' : product.name.trim()}?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 18.hpx),
              FilledButton(
                onPressed: () async {
                  Get.back<void>();
                  await cart.addItem(product);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.rpx),
                  ),
                ),
                child: Text(
                  'Add to Cart',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              SizedBox(height: 10.hpx),
              OutlinedButton(
                onPressed: () async {
                  Get.back<void>();
                  await cart.addItem(product);
                  Get.toNamed(AppRoutes.checkout);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.rpx),
                  ),
                ),
                child: Text(
                  'Buy Now',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(onPressed: Get.back, child: Text('Cancel')),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

class _CounterTap extends StatelessWidget {
  _CounterTap({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.rpx),
      child: Padding(
        padding: EdgeInsets.all(6.rpx),
        child: Icon(icon, color: AppColors.white, size: 16),
      ),
    );
  }
}
