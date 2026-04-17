import 'package:flutter/material.dart';
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
        duration: const Duration(milliseconds: 180),
        width: width ?? double.infinity,
        constraints: const BoxConstraints(minHeight: 40),
        decoration: BoxDecoration(
          color: count == 0 ? AppColors.accent : AppColors.secondaryBlue,
          borderRadius: BorderRadius.circular(8),
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
                borderRadius: BorderRadius.circular(8),
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    child: Text(
                      'ADD',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CounterTap(
                      icon: Icons.remove_rounded,
                      onTap: () => cart.removeItem(product.id),
                    ),
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 13,
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

  Future<void> _showAddOptions(BuildContext context, CartController cart) async {
    await Get.bottomSheet<void>(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
              const SizedBox(height: 8),
              Text(
                'How would you like to proceed with ${product.name.trim().isEmpty ? 'this item' : product.name.trim()}?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  Get.back<void>();
                  await cart.addItem(product);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Add to Cart',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () async {
                  Get.back<void>();
                  await cart.addItem(product);
                  Get.toNamed(AppRoutes.checkout);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Buy Now',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: Get.back,
                child: const Text('Cancel'),
              ),
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
  const _CounterTap({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: AppColors.white, size: 16),
      ),
    );
  }
}
