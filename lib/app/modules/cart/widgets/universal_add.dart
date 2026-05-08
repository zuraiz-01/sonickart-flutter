import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../../../data/models/product_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../controllers/cart_controller.dart';

class UniversalAdd extends StatelessWidget {
  const UniversalAdd({
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
                        fontSize: 14.spx,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 56;
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.wpx,
                      vertical: 5.hpx,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _CounterTap(
                          icon: Icons.remove_rounded,
                          compact: isCompact,
                          onTap: () => cart.removeItem(product.id),
                        ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$count',
                              maxLines: 1,
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 15.spx,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        _CounterTap(
                          icon: Icons.add_rounded,
                          compact: isCompact,
                          onTap: () => cart.addItem(product),
                        ),
                      ],
                    ),
                  );
                },
              ),
      );
    });
  }

  Future<void> _showAddOptions(
    BuildContext context,
    CartController cart,
  ) async {
    final productName = product.name.trim().isEmpty
        ? 'this item'
        : product.name.trim().toUpperCase();
    await Get.bottomSheet<void>(
      SafeArea(
        minimum: EdgeInsets.fromLTRB(22.wpx, 0, 22.wpx, 50.hpx),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: 430.wpx),
            padding: EdgeInsets.fromLTRB(20.wpx, 24.hpx, 20.wpx, 20.hpx),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(13.rpx),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.75),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.20),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose An Option',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16.spx,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: 8.hpx),
                Text(
                  'How would you like to proceed with\n$productName ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 15.spx,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: 22.hpx),
                FilledButton(
                  onPressed: () async {
                    Get.back<void>();
                    await cart.addItem(product);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    minimumSize: Size(double.infinity, 52.hpx),
                    padding: EdgeInsets.symmetric(vertical: 14.hpx),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9.rpx),
                    ),
                  ),
                  child: Text(
                    'Add to cart',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.spx,
                    ),
                  ),
                ),
                SizedBox(height: 12.hpx),
                OutlinedButton(
                  onPressed: () async {
                    Get.back<void>();
                    await cart.addItem(product);
                    Get.toNamed(AppRoutes.checkout);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary, width: 1.3),
                    minimumSize: Size(double.infinity, 50.hpx),
                    padding: EdgeInsets.symmetric(vertical: 13.hpx),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9.rpx),
                    ),
                  ),
                  child: Text(
                    'Buy now',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.spx,
                    ),
                  ),
                ),
                SizedBox(height: 12.hpx),
                TextButton(
                  onPressed: Get.back,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    minimumSize: Size(double.infinity, 42.hpx),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.spx,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.primary.withValues(alpha: 0.35),
    );
  }
}

class _CounterTap extends StatelessWidget {
  const _CounterTap({
    required this.icon,
    required this.onTap,
    required this.compact,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.rpx),
      child: SizedBox(
        width: compact ? 14.wpx : 18.wpx,
        height: 30.hpx,
        child: Icon(icon, color: AppColors.white, size: 13.spx),
      ),
    );
  }
}
