import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../data/models/product_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'cart/controllers/cart_controller.dart';
import 'dashboard/controllers/dashboard_controller.dart';

class ProductDetailView extends StatelessWidget {
  ProductDetailView({super.key});

  ProductModel? _resolveProduct() {
    final value = Get.arguments?['product'];
    if (value is ProductModel) return value;
    if (value is Map)
      return ProductModel.fromJson(Map<String, dynamic>.from(value));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final product = _resolveProduct();
    if (product == null) {
      debugPrint(
        '[PRODUCT][ERROR] ProductDetailView opened without product arguments',
      );
      return Scaffold(body: Center(child: Text('Product not found')));
    }
    debugPrint(
      '[PRODUCT][OPEN] id=${product.id} name="${product.name}" price=${product.price} mrp=${product.mrp}',
    );
    debugPrint(
      '[IMAGE][PRODUCT] raw="${product.imageUrl}" resolved="${product.resolvedImageUrl}" featured="${product.resolvedFeaturedImageUrl}"',
    );
    debugPrint(
      '[PRODUCT][META] category=${product.categoryId} vendor=${product.vendorId} branch=${product.branchId}',
    );
    final cart = Get.find<CartController>();
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(product.name.isEmpty ? 'Product Detail' : product.name),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.rpx),
        children: [
          Container(
            height: 280.hpx,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18.rpx),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
            child: product.resolvedImageUrl.isNotEmpty
                ? Image.network(
                    product.resolvedImageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        _FallbackProductArt(product: product, size: 120),
                  )
                : _FallbackProductArt(product: product, size: 120),
          ),
          SizedBox(height: 20.hpx),
          Text(
            product.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12.hpx),
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.hpx),
          Text(
            product.description.isEmpty
                ? 'No description available for this product.'
                : product.description,
            style: TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
          SizedBox(height: 18.hpx),
          Row(
            children: [
              Text(
                'Rs ${product.price}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 12.wpx),
              if (product.mrp.isNotEmpty)
                Text(
                  'Rs ${product.mrp}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.hpx),
          Text(
            product.unit,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.rpx),
          child: Obx(() {
            final quantity = cart.items
                .where((item) => item.product.id == product.id)
                .fold<int>(0, (sum, item) => sum + item.quantity);
            return _DetailCartActions(
              product: product,
              cart: cart,
              quantity: quantity,
            );
          }),
        ),
      ),
    );
  }
}

class _DetailCartActions extends StatelessWidget {
  _DetailCartActions({
    required this.product,
    required this.cart,
    required this.quantity,
  });

  final ProductModel product;
  final CartController cart;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    if (quantity == 0) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _addToCart(showFeedback: true),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: AppColors.primary),
              ),
              child: Text(
                'Add to Cart',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          SizedBox(width: 12.wpx),
          Expanded(
            child: FilledButton(
              onPressed: _buyNow,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'Buy Now',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.wpx, vertical: 8.hpx),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16.rpx),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () async {
                  debugPrint(
                    '[CART][REMOVE] ProductDetail remove tapped id=${product.id}',
                  );
                  await cart.removeItem(product.id);
                  debugPrint(
                    '[CART][REMOVE_DONE] id=${product.id} quantity=${cart.getItemCount(product.id)} totalItems=${cart.totalItems}',
                  );
                },
                icon: Icon(Icons.remove_rounded),
                color: AppColors.primary,
              ),
              Expanded(
                child: Text(
                  '$quantity in cart',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _addToCart(showFeedback: false),
                icon: Icon(Icons.add_rounded),
                color: AppColors.primary,
              ),
            ],
          ),
        ),
        SizedBox(height: 10.hpx),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => openDashboardTab(2),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppColors.primary),
                ),
                child: Text(
                  'View Cart',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            SizedBox(width: 12.wpx),
            Expanded(
              child: FilledButton(
                onPressed: () => Get.toNamed(AppRoutes.checkout),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Checkout',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addToCart({required bool showFeedback}) async {
    debugPrint(
      '[CART][ADD] ProductDetail add tapped id=${product.id} name="${product.name}"',
    );
    await cart.addItem(product);
    debugPrint(
      '[CART][ADD_DONE] id=${product.id} quantity=${cart.getItemCount(product.id)} totalItems=${cart.totalItems}',
    );
    if (showFeedback) {
      Get.snackbar(
        'Added to Cart',
        '${product.name.trim()} added successfully.',
        snackPosition: SnackPosition.BOTTOM,
        mainButton: TextButton(
          onPressed: () => openDashboardTab(2),
          child: Text('View Cart'),
        ),
      );
    }
  }

  Future<void> _buyNow() async {
    debugPrint(
      '[CART][BUY_NOW] ProductDetail buy now tapped id=${product.id} name="${product.name}"',
    );
    await cart.addItem(product);
    debugPrint(
      '[CART][BUY_NOW_DONE] id=${product.id} quantity=${cart.getItemCount(product.id)} totalItems=${cart.totalItems} -> checkout',
    );
    Get.toNamed(AppRoutes.checkout);
  }
}

class _FallbackProductArt extends StatelessWidget {
  _FallbackProductArt({required this.product, required this.size});

  final ProductModel product;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24.rpx),
      ),
      child: Text(
        product.emoji.isEmpty
            ? (product.name.isEmpty
                  ? 'P'
                  : product.name.characters.first.toUpperCase())
            : product.emoji,
        style: TextStyle(
          fontSize: size / 2.8,
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
