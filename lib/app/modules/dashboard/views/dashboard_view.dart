import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../../../data/models/category_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/product_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../core/services/service_area_gate_controller.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/service_area_gate_overlay.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../cart/widgets/cart_summary_bar.dart';
import '../../cart/views/cart_view.dart';
import '../../order_controller.dart';
import '../../package/package_view.dart';
import '../../profile/controllers/profile_controller.dart';
import '../../profile/profile_view.dart';
import '../controllers/dashboard_controller.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final profileController = Get.find<ProfileController>();
    final orderController = Get.find<OrderController>();
    final cartController = Get.find<CartController>();
    final serviceGateController = Get.find<ServiceAreaGateController>();
    unawaited(serviceGateController.ensureChecked());
    final tabs = [
      _HomeTab(
        user: auth.currentUser,
        controller: controller,
        profileController: profileController,
      ),
      _SimpleTab(title: 'Categories', icon: Icons.grid_view_rounded),
      CartView(),
      PackageView(),
      ProfileView(),
    ];

    return Obx(
      () => Scaffold(
        backgroundColor: controller.currentIndex.value == 2
            ? const Color(0xFFF5F8FF)
            : const Color(0xFFF3F7FF),
        body: Stack(
          children: [
            if (controller.currentIndex.value != 2)
              Container(
                height: 220.hpx,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF36435C),
                      Color(0xE636435C),
                      Color(0x0036435C),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            SafeArea(child: tabs[controller.currentIndex.value]),
            Obx(() {
              final activeOrder = orderController.activeProductOrder.value;
              if (controller.currentIndex.value != 0 || activeOrder == null) {
                return SizedBox.shrink();
              }
              final bottom = cartController.totalItems > 0 ? 90.hpx : 18.hpx;
              return Positioned(
                left: 16.wpx,
                right: 16.wpx,
                bottom: bottom,
                child: _ActiveOrderCard(order: activeOrder),
              );
            }),
            if (controller.currentIndex.value != 2)
              Positioned(left: 0, right: 0, bottom: 0, child: CartSummaryBar()),
            ServiceAreaGateOverlay(controller: serviceGateController),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          index: controller.currentIndex.value,
          onTap: (value) {
            if (controller.currentIndex.value == 4 && value != 4) {
              profileController.clearTransientOverlays();
            }
            if (value == 1) {
              Get.toNamed(AppRoutes.categories);
              return;
            }
            controller.changeTab(value);
          },
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.user,
    required this.controller,
    required this.profileController,
  });
  final dynamic user;
  final DashboardController controller;
  final ProfileController profileController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(8.wpx, 6.hpx, 8.wpx, 16.hpx),
      children: [
        Obx(
          () => _HeaderCard(
            primaryLabel: profileController.dashboardPrimaryLabel,
            address: profileController.dashboardAddressLabel,
          ),
        ),
        SizedBox(height: 10.hpx),
        _SearchBar(controller: controller),
        SizedBox(height: 12.hpx),
        _PromoSection(controller: controller),
        SizedBox(height: 10.hpx),
        _SectionTitle('Featured Products'),
        SizedBox(height: 7.hpx),
        Obx(
          () => _ProductGrid(
            products: controller.featuredProducts,
            loading: controller.isCatalogLoading.value,
          ),
        ),
        SizedBox(height: 12.hpx),
        _SectionTitle('Categories'),
        SizedBox(height: 7.hpx),
        Obx(
          () => _CategoryGrid(
            categories: controller.categories,
            loading: controller.isCatalogLoading.value,
          ),
        ),
        SizedBox(height: 10.hpx),
        const _HomeTagline(),
        SizedBox(height: 140.hpx),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.primaryLabel, required this.address});
  final String primaryLabel;
  final String address;

  @override
  Widget build(BuildContext context) {
    final notifications = Get.find<NotificationService>();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(10.wpx, 10.hpx, 10.wpx, 10.hpx),
      decoration: BoxDecoration(
        color: Color(0xFFF3F7FF),
        borderRadius: BorderRadius.circular(11.rpx),
        border: Border.all(color: Color(0xFFF3F7FF)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontSize: 14.spx,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2.hpx),
                    Text(
                      'Everything you need, delivered fast \u26A1',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontSize: 15.spx,
                        fontWeight: FontWeight.w800,
                        height: 1.42,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.wpx),
              _NotificationBell(controller: notifications),
            ],
          ),
          SizedBox(height: 8.hpx),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Get.toNamed(AppRoutes.addressBook),
              borderRadius: BorderRadius.circular(8.rpx),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8.wpx,
                  vertical: 7.hpx,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8.rpx),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20.wpx,
                      height: 20.hpx,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12.rpx),
                      ),
                      child: Icon(
                        Icons.location_on,
                        size: 11.spx,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 5.wpx),
                    Expanded(
                      child: Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontSize: 14.spx,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primary,
                      size: 13.spx,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.controller});

  final NotificationService controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final count = controller.unreadCount;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await controller.markAllRead();
            Get.toNamed(AppRoutes.notifications);
          },
          borderRadius: BorderRadius.circular(22.rpx),
          child: SizedBox(
            width: 44.rpx,
            height: 44.rpx,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 40.rpx,
                  height: 40.rpx,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 28.rpx,
                      height: 28.rpx,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(14.rpx),
                      ),
                      child: Icon(
                        Icons.notifications_rounded,
                        color: AppColors.primary,
                        size: 18.spx,
                      ),
                    ),
                  ),
                ),
                if (count > 0)
                  Positioned(
                    right: 1.rpx,
                    top: 0,
                    child: Container(
                      height: 17.rpx,
                      constraints: BoxConstraints(minWidth: 17.rpx),
                      padding: EdgeInsets.symmetric(horizontal: 4.wpx),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(9.rpx),
                        border: Border.all(color: AppColors.white, width: 1.5),
                      ),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 14.spx,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed(AppRoutes.search),
      borderRadius: BorderRadius.circular(10.rpx),
      child: Container(
        height: 42.hpx,
        padding: EdgeInsets.symmetric(horizontal: 11.wpx),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10.rpx),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: AppColors.primary, size: 17.spx),
            SizedBox(width: 8.wpx),
            Expanded(
              child: Obx(
                () => Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 250),
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [...previousChildren, ?currentChild],
                      );
                    },
                    child: Text(
                      controller.searchHints[controller
                          .currentSearchHintIndex
                          .value],
                      key: ValueKey(controller.currentSearchHintIndex.value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 14.spx,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoSection extends StatelessWidget {
  const _PromoSection({required this.controller});
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final sliderHeight = max(110.hpx, constraints.maxWidth * 0.46);

            return SizedBox(
              height: sliderHeight,
              child: Obx(() {
                final imagePath =
                    controller.promoCards[controller.currentPromoIndex.value];
                return AnimatedSwitcher(
                  duration: Duration(milliseconds: 350),
                  child: ClipRRect(
                    key: ValueKey(controller.currentPromoIndex.value),
                    borderRadius: BorderRadius.circular(16.rpx),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16.rpx),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
        SizedBox(height: 8.hpx),
        Obx(
          () => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(controller.promoCards.length, (i) {
              final active = i == controller.currentPromoIndex.value;
              return AnimatedContainer(
                duration: Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(horizontal: 3.wpx),
                width: active ? 16.wpx : 6.wpx,
                height: 6.hpx,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99.rpx),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w900,
      fontSize: 15.spx,
    ),
  );
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products, required this.loading});

  final List<ProductModel> products;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && products.isEmpty) {
      return SizedBox(
        height: 126.hpx,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (products.isEmpty) {
      return Text(
        'Featured products will appear here.',
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 18.wpx) / 4;
        return Wrap(
          spacing: 6.wpx,
          runSpacing: 8.hpx,
          children: products.take(8).map((product) {
            return SizedBox(
              width: width,
              child: _FeaturedProductCard(product: product),
            );
          }).toList(),
        );
      },
    );
  }
}

class _FeaturedProductCard extends StatelessWidget {
  const _FeaturedProductCard({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final unit = product.unit == '1 pc' ? '' : product.unit;
    return InkWell(
      onTap: () => Get.toNamed(
        AppRoutes.categories,
        arguments: {
          'categoryId': product.categoryId,
          'categoryName':
              product.raw['categoryName'] ?? product.raw['category_name'],
          'productId': product.id,
          'preferredVendorId': product.vendorId,
        },
      ),
      borderRadius: BorderRadius.circular(10.rpx),
      child: Container(
        height: 110.hpx,
        padding: EdgeInsets.symmetric(horizontal: 5.wpx, vertical: 5.hpx),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8.rpx),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            _DashboardImageBox(product: product, height: 48.hpx),
            SizedBox(height: 5.hpx),
            Expanded(
              child: Text(
                product.name.isEmpty ? 'Product' : product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14.spx,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(
              height: 28.hpx,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Opacity(
                    opacity: unit.isEmpty ? 0 : 1,
                    child: Text(
                      unit.isEmpty ? ' ' : unit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 7.8.spx,
                        height: 1.05,
                      ),
                    ),
                  ),
                  SizedBox(height: 2.hpx),
                  Text(
                    '₹${product.displayPrice}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.spx,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatefulWidget {
  const _CategoryGrid({required this.categories, required this.loading});

  final List<CategoryModel> categories;
  final bool loading;

  @override
  State<_CategoryGrid> createState() => _CategoryGridState();
}

class _CategoryGridState extends State<_CategoryGrid> {
  static const _maxVisibleRows = 4;
  bool _showAllRows = false;

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.categories.isEmpty) {
      return SizedBox(
        height: 110.hpx,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (widget.categories.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 20.hpx),
        child: Center(
          child: Text(
            'No categories available',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 24.wpx) / 4;
        final rowCount = (widget.categories.length / 4).ceil();
        final visibleCategories = _showAllRows
            ? widget.categories
            : widget.categories.take(_maxVisibleRows * 4).toList();
        final shouldShowToggle = rowCount > _maxVisibleRows;

        return Column(
          children: [
            Wrap(
              spacing: 8.wpx,
              runSpacing: 16.hpx,
              children: visibleCategories.map((category) {
                return SizedBox(
                  width: width,
                  child: _HomeCategoryCard(category: category),
                );
              }).toList(),
            ),
            if (shouldShowToggle) ...[
              SizedBox(height: 18.hpx),
              SizedBox(
                width: min(constraints.maxWidth * 0.6, 220),
                child: OutlinedButton(
                  onPressed: () => setState(() => _showAllRows = !_showAllRows),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: AppColors.white,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.hpx),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.rpx),
                    ),
                    elevation: 3,
                    shadowColor: Color(0x33000000),
                  ),
                  child: Text(
                    _showAllRows ? 'View less' : 'View more',
                    style: TextStyle(
                      fontSize: 15.spx,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _HomeTagline extends StatelessWidget {
  const _HomeTagline();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: min(MediaQuery.of(context).size.width * 0.86, 320),
        ),
        padding: EdgeInsets.symmetric(horizontal: 18.wpx, vertical: 12.hpx),
        decoration: BoxDecoration(
          color: Color(0xFFF3F7FF),
          borderRadius: BorderRadius.circular(999.rpx),
        ),
        child: Text(
          'Your City, Your Cart in Minutes \u26A1',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16.spx,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HomeCategoryCard extends StatelessWidget {
  const _HomeCategoryCard({required this.category});

  final CategoryModel category;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed(
        AppRoutes.categories,
        arguments: {'categoryId': category.id, 'categoryName': category.name},
      ),
      borderRadius: BorderRadius.circular(12.rpx),
      child: Container(
        height: 130.hpx,
        padding: EdgeInsets.fromLTRB(8.wpx, 8.hpx, 8.wpx, 10.hpx),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12.rpx),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 70.hpx,
              width: double.infinity,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8.rpx),
              ),
              child: _CategoryImageBox(category: category, height: 70.hpx),
            ),
            SizedBox(height: 8.hpx),
            Expanded(
              child: Text(
                category.name.isEmpty ? 'Category' : category.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11.spx,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardImageBox extends StatelessWidget {
  const _DashboardImageBox({required this.product, required this.height});

  final ProductModel product;
  final double height;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.resolvedFeaturedImageUrl;
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.rpx),
      ),
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: double.infinity,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    return Text(
      product.emoji.isEmpty ? _initial(product.name) : product.emoji,
      style: TextStyle(
        fontSize: 28.spx,
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _CategoryImageBox extends StatelessWidget {
  const _CategoryImageBox({required this.category, required this.height});

  final CategoryModel category;
  final double height;

  @override
  Widget build(BuildContext context) {
    final imageUrl = category.resolvedImageUrl;
    if (imageUrl.isEmpty) return _fallback();
    return Image.network(
      imageUrl,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    return Text(
      category.emoji.isEmpty ? _initial(category.name) : category.emoji,
      style: TextStyle(
        fontSize: 24.spx,
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

String _initial(String value) =>
    value.trim().isEmpty ? 'P' : value.trim().characters.first.toUpperCase();

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final copy = _activeOrderCopy(order.status);
    final itemCount = order.resolvedItemCount;
    final orderId = order.id.isEmpty ? '--' : order.id;
    return InkWell(
      onTap: () {
        final orderController = Get.find<OrderController>();
        orderController.selectedOrder.value = order;
        orderController.latestOrder.value = order;
        Get.toNamed(AppRoutes.liveTracking, arguments: {'orderId': order.id});
      },
      borderRadius: BorderRadius.circular(22.rpx),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.wpx, vertical: 14.hpx),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22.rpx),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44.wpx,
              height: 44.hpx,
              decoration: BoxDecoration(
                color: Color(0xFFEEF4FF),
                borderRadius: BorderRadius.circular(22.rpx),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            SizedBox(width: 12.wpx),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.primary,
                      fontSize: 14.spx,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2.hpx),
                  Text(
                    '#$orderId | $itemCount item${itemCount == 1 ? '' : 's'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontSize: 15.spx,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4.hpx),
                  Text(
                    copy.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 15.spx,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Track',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontSize: 15.spx,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

(String, String) _activeOrderCopy(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized == 'pending') {
    return ('Preparing your order', 'We are getting everything ready.');
  }
  if (normalized == 'confirmed' ||
      normalized == 'accepted' ||
      normalized == 'assigned') {
    return ('Your order is confirmed', 'Tap to open live tracking.');
  }
  if (normalized == 'picked' ||
      normalized == 'arriving' ||
      normalized == 'out_for_delivery') {
    return ('Your order is on the way', 'Tap to track the delivery live.');
  }
  return ('Your order is active', 'Tap to view the latest status.');
}

class _SimpleTab extends StatelessWidget {
  const _SimpleTab({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84.wpx,
            height: 84.hpx,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(28.rpx),
            ),
            child: Icon(icon, size: 40, color: AppColors.primary),
          ),
          SizedBox(height: 18.hpx),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('Home', Icons.home_outlined, Icons.home_rounded),
      ('Categories', Icons.category_outlined, Icons.category_rounded),
      ('Cart', Icons.shopping_cart_outlined, Icons.shopping_cart_rounded),
      ('Package', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
      ('Profile', Icons.person_outline_rounded, Icons.person_rounded),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.wpx, 6.hpx, 12.wpx, 6.hpx),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                height: 24.hpx,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(22.rpx),
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(22.rpx),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(tabs.length, (i) {
                  final active = i == index;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: SizedBox(
                        height: 62.hpx,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              height: 44.hpx,
                              child: Center(
                                child: active
                                    ? IgnorePointer(
                                        child: Transform.translate(
                                          offset: Offset(0, -14.hpx),
                                          child: Container(
                                            width: 46.wpx,
                                            height: 46.hpx,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(23.rpx),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Color(0x29000000),
                                                  blurRadius: 10,
                                                  offset: Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Container(
                                                width: 34.wpx,
                                                height: 34.hpx,
                                                decoration: BoxDecoration(
                                                  color: AppColors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(17),
                                                ),
                                                child: Icon(
                                                  tabs[i].$3,
                                                  size: 18.spx,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        tabs[i].$2,
                                        size: 19.spx,
                                        color: AppColors.textSecondary,
                                      ),
                              ),
                            ),
                            SizedBox(
                              height: 18.hpx,
                              child: Center(
                                child: Text(
                                  tabs[i].$1,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: active
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                        fontSize: 10.spx,
                                        fontWeight: active
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
