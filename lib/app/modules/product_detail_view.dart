import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/product_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'cart/controllers/cart_controller.dart';

class ProductDetailView extends StatelessWidget {
  const ProductDetailView({super.key});

  ProductModel? _resolveProduct() {
    final value = Get.arguments?['product'];
    if (value is ProductModel) return value;
    if (value is Map) return ProductModel.fromJson(Map<String, dynamic>.from(value));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final product = _resolveProduct();
    if (product == null) {
      debugPrint('[PRODUCT][ERROR] ProductDetailView opened without product arguments');
      return const Scaffold(body: Center(child: Text('Product not found')));
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
      appBar: AppBar(title: Text(product.name.isEmpty ? 'Product Detail' : product.name), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 280,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
            ),
            child: product.resolvedImageUrl.isNotEmpty
                ? Image.network(product.resolvedImageUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _FallbackProductArt(product: product, size: 120))
                : _FallbackProductArt(product: product, size: 120),
          ),
          const SizedBox(height: 20),
          Text(product.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text('Description', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(product.description.isEmpty ? 'No description available for this product.' : product.description, style: const TextStyle(color: AppColors.textSecondary, height: 1.45)),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('Rs ${product.price}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w900)),
              const SizedBox(width: 12),
              if (product.mrp.isNotEmpty)
                Text('Rs ${product.mrp}', style: const TextStyle(color: AppColors.textSecondary, decoration: TextDecoration.lineThrough, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(product.unit, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(
            () {
              final quantity = cart.items
                  .where((item) => item.product.id == product.id)
                  .fold<int>(0, (sum, item) => sum + item.quantity);
              return _DetailCartActions(
                product: product,
                cart: cart,
                quantity: quantity,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DetailCartActions extends StatelessWidget {
  const _DetailCartActions({
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
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Text(
                'Add to Cart',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _buyNow,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () async {
                  debugPrint('[CART][REMOVE] ProductDetail remove tapped id=${product.id}');
                  await cart.removeItem(product.id);
                  debugPrint(
                    '[CART][REMOVE_DONE] id=${product.id} quantity=${cart.getItemCount(product.id)} totalItems=${cart.totalItems}',
                  );
                },
                icon: const Icon(Icons.remove_rounded),
                color: AppColors.primary,
              ),
              Expanded(
                child: Text(
                  '$quantity in cart',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _addToCart(showFeedback: false),
                icon: const Icon(Icons.add_rounded),
                color: AppColors.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Get.offNamed(
                  AppRoutes.dashboard,
                  arguments: {'tabIndex': 2},
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: const Text(
                  'View Cart',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Get.toNamed(AppRoutes.checkout),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
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
          onPressed: () => Get.offNamed(
            AppRoutes.dashboard,
            arguments: {'tabIndex': 2},
          ),
          child: const Text('View Cart'),
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
  const _FallbackProductArt({required this.product, required this.size});

  final ProductModel product;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
      child: Text(
        product.emoji.isEmpty ? (product.name.isEmpty ? 'P' : product.name.characters.first.toUpperCase()) : product.emoji,
        style: TextStyle(fontSize: size / 2.8, color: AppColors.primary, fontWeight: FontWeight.w900),
      ),
    );
  }
}
