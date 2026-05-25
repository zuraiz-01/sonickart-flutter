import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../core/widgets/app_snackbar.dart';
import '../data/models/product_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
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
    final themeController = Get.find<AppThemeController>();
    return Obx(() {
      themeController.isDarkMode.value;
      return _buildScaffold(context);
    });
  }

  Widget _buildScaffold(BuildContext context) {
    final product = _resolveProduct();
    if (product == null) {
      debugPrint(
        '[PRODUCT][ERROR] ProductDetailView opened without product arguments',
      );
      return Scaffold(body: Center(child: Text('Product Not Found')));
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          product.name.isEmpty ? 'Product Detail' : product.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 17.spx,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.card,
        surfaceTintColor: AppColors.card,
        elevation: 0,
        toolbarHeight: 40.hpx,
        iconTheme: IconThemeData(color: AppColors.primary, size: 17.spx),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(8.wpx, 8.hpx, 8.wpx, 18.hpx),
        children: [
          _ProductImageCarousel(
            product: product,
            imageUrls: carouselImages,
            activeSlide: _activeSlide,
            onSlideChanged: (value) => setState(() => _activeSlide = value),
          ),
          SizedBox(height: 14.hpx),
          Text(
            product.name.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 15.spx,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 10.hpx),
          Text(
            'Description',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 14.spx,
            ),
          ),
          SizedBox(height: 6.hpx),
          Text(
            product.description.isEmpty
                ? 'No description available for this product.'
                : product.description,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.spx,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          SizedBox(height: 12.hpx),
          Row(
            children: [
              Text(
                '\u20B9${product.displayPrice}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.price,
                  fontWeight: FontWeight.w900,
                  fontSize: 18.spx,
                ),
              ),
              SizedBox(width: 9.wpx),
              if (product.displayMrp.isNotEmpty)
                Text(
                  '\u20B9${product.displayMrp}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.spx,
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
              fontSize: 14.spx,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(8.wpx, 8.hpx, 8.wpx, 10.hpx),
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
      height: 265.hpx,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8.rpx),
        border: Border.all(color: AppColors.border),
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
                foregroundColor: AppColors.primary,
                minimumSize: Size(double.infinity, 45.hpx),
                padding: EdgeInsets.symmetric(vertical: 12.hpx),
                side: BorderSide(color: AppColors.primary, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.rpx),
                ),
              ),
              child: Text(
                'Add to Cart',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.spx),
              ),
            ),
          ),
          SizedBox(width: 10.wpx),
          Expanded(
            child: FilledButton(
              onPressed: _buyNow,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.buttonFill,
                foregroundColor: AppColors.onButtonFill,
                minimumSize: Size(double.infinity, 45.hpx),
                padding: EdgeInsets.symmetric(vertical: 12.hpx),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.rpx),
                ),
              ),
              child: Text(
                'Buy Now',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.spx),
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
          padding: EdgeInsets.symmetric(horizontal: 8.wpx, vertical: 6.hpx),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8.rpx),
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
                    fontSize: 15.spx,
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
                  foregroundColor: AppColors.primary,
                  minimumSize: Size(double.infinity, 45.hpx),
                  padding: EdgeInsets.symmetric(vertical: 12.hpx),
                  side: BorderSide(color: AppColors.primary, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.rpx),
                  ),
                ),
                child: Text(
                  'View Cart',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.spx,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.wpx),
            Expanded(
              child: FilledButton(
                onPressed: () => Get.toNamed(AppRoutes.checkout),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.buttonFill,
                  foregroundColor: AppColors.onButtonFill,
                  minimumSize: Size(double.infinity, 45.hpx),
                  padding: EdgeInsets.symmetric(vertical: 12.hpx),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.rpx),
                  ),
                ),
                child: Text(
                  'Checkout',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.spx,
                  ),
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
      AppSnackBar.show(
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
        color: AppColors.productImageFill,
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
