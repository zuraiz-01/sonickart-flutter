import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../controllers/cart_controller.dart';

class CartView extends GetView<CartController> {
  CartView({super.key, this.showScaffold = false});

  final bool showScaffold;

  @override
  Widget build(BuildContext context) {
    final content = Obx(() {
      if (controller.isEmpty) {
        return _CartEmptyState(isSyncing: controller.isSyncingCart.value);
      }

      return ListView(
        padding: EdgeInsets.fromLTRB(16.wpx, 16.hpx, 16.wpx, 24.hpx),
        children: [
          _SummaryCard(
            totalItems: controller.totalItems,
            isSyncing: controller.isSyncingCart.value,
          ),
          SizedBox(height: 16.hpx),
          _ItemsCard(controller: controller),
          SizedBox(height: 16.hpx),
          _PriceCard(
            subtotal: controller.subtotal,
            total: controller.grandTotal,
          ),
          SizedBox(height: 16.hpx),
          _ActionSection(controller: controller),
        ],
      );
    });

    if (!showScaffold) {
      return content;
    }

    return Scaffold(
      backgroundColor: Color(0xFFF5F8FF),
      appBar: AppBar(title: Text('Cart'), centerTitle: true),
      body: content,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  _SummaryCard({required this.totalItems, required this.isSyncing});

  final int totalItems;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Ready to checkout',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 6.hpx),
        Text(
          '$totalItems ${totalItems == 1 ? 'item' : 'items'} packed in your cart.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10.hpx),
        Text(
          isSyncing ? 'Refreshing cart...' : 'Speed you want, care you trust',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ItemsCard extends StatelessWidget {
  _ItemsCard({required this.controller});

  final CartController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14.wpx, 14.hpx, 14.wpx, 8.hpx),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Cart items',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${controller.totalItems} selected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          ...controller.items.map((item) {
            return _CartItemRow(
              itemId: item.product.id,
              emoji: item.product.emoji,
              name: item.product.name,
              description: item.product.description,
              unit: item.product.unit,
              quantity: item.quantity,
              totalPrice: item.totalPrice,
              onAdd: () => controller.addItem(item.product),
              onRemove: () => controller.removeItem(item.product.id),
            );
          }),
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  _CartItemRow({
    required this.itemId,
    required this.emoji,
    required this.name,
    required this.description,
    required this.unit,
    required this.quantity,
    required this.totalPrice,
    required this.onAdd,
    required this.onRemove,
  });

  final String itemId;
  final String emoji;
  final String name;
  final String description;
  final String unit;
  final int quantity;
  final double totalPrice;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(14.rpx),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62.wpx,
            height: 62.hpx,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14.rpx),
            ),
            child: Text(emoji, style: TextStyle(fontSize: 28.spx)),
          ),
          SizedBox(width: 12.wpx),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.hpx),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 6.hpx),
                Text(
                  unit,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10.hpx),
                Row(
                  children: [
                    _QuantityButton(
                      icon: Icons.remove_rounded,
                      onTap: onRemove,
                    ),
                    Container(
                      width: 40.wpx,
                      alignment: Alignment.center,
                      child: Text(
                        '$quantity',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _QuantityButton(icon: Icons.add_rounded, onTap: onAdd),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 10.wpx),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs ${totalPrice.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6.hpx),
              Text(
                'ID $itemId',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  _QuantityButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.rpx),
      child: Ink(
        width: 32.wpx,
        height: 32.hpx,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12.rpx),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  _PriceCard({required this.subtotal, required this.total});

  final double subtotal;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.rpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 14.hpx),
          _PriceRow(label: 'Subtotal', value: subtotal),
          SizedBox(height: 12.hpx),
          Divider(height: 1, color: AppColors.border),
          SizedBox(height: 12.hpx),
          _PriceRow(label: 'Total', value: total, isStrong: true),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  _PriceRow({required this.label, required this.value, this.isStrong = false});

  final String label;
  final double value;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    final weight = isStrong ? FontWeight.w800 : FontWeight.w600;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: weight,
            ),
          ),
        ),
        Text(
          'Rs ${value.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: weight,
          ),
        ),
      ],
    );
  }
}

class _ActionSection extends StatelessWidget {
  _ActionSection({required this.controller});

  final CartController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: controller.isEmpty || controller.isClearingCart.value
                ? null
                : () => _showClearDialog(context),
            style: OutlinedButton.styleFrom(
              backgroundColor: Color(0xFFDCE5FF),
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.rpx),
              ),
            ),
            child: Text(
              controller.isClearingCart.value
                  ? 'Removing...'
                  : 'Remove all items',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SizedBox(height: 12.hpx),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: controller.isEmpty
                ? null
                : () {
                    debugPrint(
                      'CartView.checkout: checkout tapped with ${controller.totalItems} items',
                    );
                    Get.toNamed(AppRoutes.checkout);
                  },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.rpx),
              ),
            ),
            child: Text(
              'Go to Checkout',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showClearDialog(BuildContext context) async {
    debugPrint('CartView._showClearDialog: opening clear cart confirmation');
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('Remove all items?'),
        content: Text(
          'This action clears your entire cart. You cannot undo it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: Text('Remove everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.clearCart();
    }
  }
}

class _CartEmptyState extends StatelessWidget {
  _CartEmptyState({required this.isSyncing});

  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 32.wpx, vertical: 24.hpx),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140.wpx,
              height: 140.hpx,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28.rpx),
              ),
              child: Icon(
                Icons.shopping_cart_checkout_rounded,
                size: 62,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 18.hpx),
            Text(
              'Your cart is waiting',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.hpx),
            Text(
              isSyncing
                  ? 'Refreshing your saved cart...'
                  : 'Browse categories and add your favorites to get started.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.hpx),
            FilledButton(
              onPressed: () => Get.toNamed(AppRoutes.categories),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999.rpx),
                ),
              ),
              child: Text(
                'Explore Categories',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
