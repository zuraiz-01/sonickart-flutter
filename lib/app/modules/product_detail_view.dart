import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../data/models/product_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'cart/controllers/cart_controller.dart';
import 'dashboard/controllers/dashboard_controller.dart';

class ProductDetailView extends StatefulWidget {
  const ProductDetailView({super.key});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  int _activeSlide = 0;

  ProductModel? _resolveProduct() {
    final value = Get.arguments?['product'];
    if (value is ProductModel) return value;
    if (value is Map) {
      return ProductModel.fromJson(Map<String, dynamic>.from(value));
    }
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
    final carouselImages = product.resolvedGalleryImageUrls;
    debugPrint('[IMAGE][GALLERY] count=${carouselImages.length}');
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
          _ProductImageCarousel(
            product: product,
            imageUrls: carouselImages,
            activeSlide: _activeSlide,
            onSlideChanged: (value) => setState(() => _activeSlide = value),
          ),
          SizedBox(height: 20.hpx),
          Text(
            product.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
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
                '₹${product.displayPrice}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 12.wpx),
              if (product.displayMrp.isNotEmpty)
                Text(
                  '₹${product.displayMrp}',
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
            product.unit == '1 pc' ? '' : product.unit,
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

class _ProductImageCarousel extends StatelessWidget {
  const _ProductImageCarousel({
    required this.product,
    required this.imageUrls,
    required this.activeSlide,
    required this.onSlideChanged,
  });

  final ProductModel product;
  final List<String> imageUrls;
  final int activeSlide;
  final ValueChanged<int> onSlideChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280.hpx,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16.rpx),
        border: Border.all(color: AppColors.surface),
      ),
      child: imageUrls.isEmpty
          ? Center(child: _FallbackProductArt(product: product, size: 120))
          : Stack(
              alignment: Alignment.center,
              children: [
                PageView.builder(
                  itemCount: imageUrls.length,
                  onPageChanged: onSlideChanged,
                  itemBuilder: (context, index) {
                    final imageUrl = imageUrls[index];
                    return Center(
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            _FallbackProductArt(product: product, size: 120),
                      ),
                    );
                  },
                ),
                if (imageUrls.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12.hpx,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(imageUrls.length, (index) {
                        final isActive = index == activeSlide;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 8.rpx,
                          height: 8.rpx,
                          margin: EdgeInsets.symmetric(horizontal: 4.wpx),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.secondaryBlue
                                : AppColors.border.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4.rpx),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
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
  const _FallbackProductArt({required this.product, required this.size});

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
