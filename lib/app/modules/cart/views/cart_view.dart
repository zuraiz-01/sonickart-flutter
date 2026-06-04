import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';

import '../../../data/models/app_ad_model.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../ads/widgets/ad_placement.dart';
import '../controllers/cart_controller.dart';
import '../../dashboard/controllers/dashboard_controller.dart';

class CartView extends GetView<CartController> {
  const CartView({super.key, this.showScaffold = false});

  final bool showScaffold;

  @override
  Widget build(BuildContext context) {
    final cartContent = Obx(() {
      if (controller.isEmpty) {
        return _CartEmptyState(isSyncing: controller.isSyncingCart.value);
      }

      return ListView(
        padding: EdgeInsets.fromLTRB(16.wpx, 16.hpx, 16.wpx, 110.hpx),
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
          SizedBox(height: 12.hpx),
          const AdPlacement(placement: AppAdPlacement.cart),
        ],
      );
    });

    final content = ColoredBox(
      color: AppColors.surface,
      child: Column(
        children: [
          _CartHeader(showBackToHome: !showScaffold),
          Expanded(child: cartContent),
        ],
      ),
    );

    if (!showScaffold) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(child: content),
    );
  }
}

class _CartHeader extends StatelessWidget {
  const _CartHeader({required this.showBackToHome});

  final bool showBackToHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60.hpx,
      padding: EdgeInsets.all(10.rpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44.wpx,
            height: 44.hpx,
            child: IconButton(
              onPressed: () {
                if (showBackToHome && Get.isRegistered<DashboardController>()) {
                  openDashboardTab(0);
                  return;
                }
                if (Get.key.currentState?.canPop() ?? false) {
                  Get.back<void>();
                  return;
                }
                openDashboardTab(0);
              },
              icon: Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textPrimary,
                size: 24.rpx,
              ),
              padding: EdgeInsets.zero,
              tooltip: 'Go back',
            ),
          ),
          Expanded(
            child: Text(
              'Cart',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 17.spx,
              ),
            ),
          ),
          SizedBox(width: 44.wpx, height: 44.hpx),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totalItems, required this.isSyncing});

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
  const _ItemsCard({required this.controller});

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
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: AppColors.inputFill,
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
              imageUrl: item.product.resolvedImageUrl,
              name: item.product.name,
              quantity: item.quantity,
              unitPrice: item.product.numericPrice,
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
  const _CartItemRow({
    required this.itemId,
    required this.imageUrl,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.onAdd,
    required this.onRemove,
  });

  final String itemId;
  final String imageUrl;
  final String name;
  final int quantity;
  final double unitPrice;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    debugPrint('CartView._CartItemRow: item=$itemId imageUrl=$imageUrl');
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.symmetric(horizontal: 14.wpx, vertical: 16.hpx),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 70.wpx,
            height: 70.hpx,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(18.rpx),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.10),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 46.wpx,
                    height: 46.hpx,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const _ProductImageFallback(text: '!'),
                  )
                : const _ProductImageFallback(text: '?'),
          ),
          SizedBox(width: 14.wpx),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15.spx,
                  ),
                ),
                if (unitPrice > 0) ...[
                  SizedBox(height: 4.hpx),
                  Text(
                    '\u20B9${unitPrice.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13.5.spx,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 12.wpx),
          Container(
            constraints: BoxConstraints(minWidth: 104.wpx),
            padding: EdgeInsets.symmetric(horizontal: 8.wpx, vertical: 6.hpx),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(999.rpx),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QuantityButton(icon: Icons.remove_rounded, onTap: onRemove),
                Container(
                  width: 28.wpx,
                  alignment: Alignment.center,
                  child: Text(
                    '$quantity',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16.spx,
                    ),
                  ),
                ),
                _QuantityButton(icon: Icons.add_rounded, onTap: onAdd),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.rpx),
      child: Ink(
        width: 32.wpx,
        height: 32.hpx,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16.rpx),
          border: Border.all(color: AppColors.primary),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary.withValues(alpha: 0.7),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.subtotal, required this.total});

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
            color: AppColors.black.withValues(alpha: 0.05),
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
  const _PriceRow({
    required this.label,
    required this.value,
    this.isStrong = false,
  });

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
          '\u20B9${value.toStringAsFixed(0)}',
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
  const _ActionSection({required this.controller});

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
              backgroundColor: AppColors.muted,
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              padding: EdgeInsets.symmetric(vertical: 14.hpx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.rpx),
              ),
            ),
            child: Text(
              controller.isClearingCart.value
                  ? 'Removing...'
                  : 'Remove all items',
              style: const TextStyle(fontWeight: FontWeight.w800),
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
                    if (!requireAuth()) return;
                    debugPrint(
                      'CartView.checkout: checkout tapped with ${controller.totalItems} items',
                    );
                    Get.toNamed(AppRoutes.checkout);
                  },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.buttonFill,
              foregroundColor: AppColors.onButtonFill,
              padding: EdgeInsets.symmetric(vertical: 14.hpx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.rpx),
              ),
            ),
            child: const Text(
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
    final confirmed = await Get.bottomSheet<bool>(
      SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16.wpx, 16.hpx, 16.wpx, 18.hpx),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.rpx)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Remove all items?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(result: false),
                    icon: Icon(Icons.close_rounded, color: AppColors.primary),
                    tooltip: 'Close',
                  ),
                ],
              ),
              SizedBox(height: 6.hpx),
              Text(
                "This action clears your entire cart. You can't undo it.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              SizedBox(height: 18.hpx),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Get.back(result: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.border),
                    padding: EdgeInsets.symmetric(vertical: 14.hpx),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.rpx),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              SizedBox(height: 10.hpx),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Get.back(result: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.buttonFill,
                    foregroundColor: AppColors.onButtonFill,
                    padding: EdgeInsets.symmetric(vertical: 14.hpx),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.rpx),
                    ),
                  ),
                  child: Text(
                    controller.isClearingCart.value
                        ? 'Removing...'
                        : 'Remove everything',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );

    if (confirmed == true) {
      await controller.clearCart();
    }
  }
}

class _CartEmptyState extends StatelessWidget {
  const _CartEmptyState({required this.isSyncing});

  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 32.wpx, vertical: 24.hpx),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 140.wpx,
              height: 140.hpx,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28.rpx),
                child: Image.asset(
                  'assets/images/sonickart1.jpg',
                  fit: BoxFit.contain,
                  opacity: const AlwaysStoppedAnimation(0.8),
                  errorBuilder: (_, _, _) => Icon(
                    Icons.shopping_cart_checkout_rounded,
                    size: 62,
                    color: AppColors.primary,
                  ),
                ),
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
                backgroundColor: AppColors.buttonFill,
                foregroundColor: AppColors.onButtonFill,
                padding: EdgeInsets.symmetric(
                  horizontal: 22.wpx,
                  vertical: 14.hpx,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999.rpx),
                ),
              ),
              child: const Text(
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
