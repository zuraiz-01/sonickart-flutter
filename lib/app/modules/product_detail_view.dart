import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../core/utils/auth_guard.dart';
import '../core/widgets/app_snackbar.dart';
import '../data/models/product_model.dart';
import '../data/repositories/catalog_repository.dart';
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
  List<ProductModel> _moreProducts = [];
  bool _isLoadingMore = true;

  ProductModel? _resolveProduct() {
    final value = Get.arguments?['product'];
    if (value is ProductModel) return value;
    if (value is Map) {
      return ProductModel.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final product = _resolveProduct();
    if (product != null && product.categoryId.isNotEmpty) {
      _loadMoreProducts(product.categoryId, product.id);
    } else {
      _isLoadingMore = false;
    }
  }

  Future<void> _loadMoreProducts(String categoryId, String currentProductId) async {
    try {
      final repository = Get.find<CatalogRepository>();
      final allProducts = await repository.fetchProductsByCategory(categoryId);
      final filtered = allProducts.where((p) => p.id != currentProductId).take(8).toList();
      if (mounted) {
        setState(() {
          _moreProducts = filtered;
          _isLoadingMore = false;
        });
      }
    } catch (error) {
      debugPrint('[PRODUCT][MORE] Failed to load more products: $error');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
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
          if (!_isLoadingMore && _moreProducts.isNotEmpty)
            _MoreProductsSection(products: _moreProducts),
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
                onPressed: () {
                  if (!requireAuth()) return;
                  Get.toNamed(AppRoutes.checkout);
                },
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
    if (!requireAuth()) return;
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

class _MoreProductsSection extends StatelessWidget {
  const _MoreProductsSection({required this.products});

  final List<ProductModel> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20.hpx),
        Text(
          'More Products',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
            fontSize: 16.spx,
          ),
        ),
        SizedBox(height: 10.hpx),
        SizedBox(
          height: 190.hpx,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, _) => SizedBox(width: 10.wpx),
            itemBuilder: (context, index) {
              final product = products[index];
              return _MoreProductCard(product: product);
            },
          ),
        ),
      ],
    );
  }
}

class _MoreProductCard extends StatelessWidget {
  const _MoreProductCard({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final unit = product.unit == '1 pc' ? '' : product.unit;
    final imageUrl = product.resolvedFeaturedImageUrl;
    return GestureDetector(
      onTap: () {
        debugPrint('[PRODUCT][MORE_CARD] Tapped product id=${product.id} name="${product.name}"');
        Get.toNamed(
          AppRoutes.productDetail,
          arguments: {'product': product},
        );
      },
      child: Container(
        width: 140.wpx,
        padding: EdgeInsets.all(8.rpx),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10.rpx),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 82.hpx,
              width: double.infinity,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.productImageFill,
                borderRadius: BorderRadius.circular(8.rpx),
              ),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 82.hpx,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => _fallback(),
                    )
                  : _fallback(),
            ),
            SizedBox(height: 6.hpx),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.spx,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 4.hpx),
            Row(
              children: [
                Text(
                  '₹${product.displayPrice}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.spx,
                    color: AppColors.price,
                  ),
                ),
                if (product.displayMrp.isNotEmpty) ...[
                  SizedBox(width: 4.wpx),
                  Text(
                    '₹${product.displayMrp}',
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      fontSize: 10.spx,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            if (unit.isNotEmpty)
              Text(
                unit,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.spx,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() {
    return Text(
      product.emoji.isEmpty
          ? (product.name.isEmpty
                ? 'P'
                : product.name.characters.first.toUpperCase())
          : product.emoji,
      style: TextStyle(
        fontSize: 28.spx,
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
      ),
    );
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
