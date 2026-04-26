import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../cart/widgets/cart_summary_bar.dart';
import '../../cart/widgets/universal_add.dart';
import '../../cart/views/cart_view.dart';
import '../../package/package_view.dart';
import '../../profile/profile_view.dart';
import '../controllers/dashboard_controller.dart';

class DashboardView extends GetView<DashboardController> {
  DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final user = auth.currentUser;
    final tabs = [
      _HomeTab(user: user, controller: controller),
      _SimpleTab(title: 'Categories', icon: Icons.grid_view_rounded),
      CartView(),
      PackageView(),
      ProfileView(),
    ];

    return Obx(
      () => Scaffold(
        backgroundColor: Color(0xFFF3F7FF),
        body: Stack(
          children: [
            Container(
              height: 220.hpx,
              decoration: BoxDecoration(
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
            Positioned(left: 0, right: 0, bottom: 0, child: CartSummaryBar()),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          index: controller.currentIndex.value,
          onTap: (value) {
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
  _HomeTab({required this.user, required this.controller});
  final dynamic user;
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final name = user?.name?.toString().isNotEmpty == true
        ? user.name.toString()
        : 'Guest';
    final address = user?.phone?.toString().isNotEmpty == true
        ? '${user.phone} - Select delivery address'
        : 'Select delivery address';
    return ListView(
      padding: EdgeInsets.fromLTRB(12.wpx, 8.hpx, 12.wpx, 16.hpx),
      children: [
        _HeaderCard(name: name, address: address),
        SizedBox(height: 12.hpx),
        _SearchBar(controller: controller),
        SizedBox(height: 16.hpx),
        _PromoSection(controller: controller),
        SizedBox(height: 16.hpx),
        _SectionTitle('Featured Products'),
        SizedBox(height: 10.hpx),
        Obx(
          () => _ProductGrid(
            products: controller.featuredProducts,
            loading: controller.isCatalogLoading.value,
          ),
        ),
        SizedBox(height: 16.hpx),
        _SectionTitle('Categories'),
        SizedBox(height: 10.hpx),
        Obx(
          () => _CategoryGrid(
            categories: controller.categories,
            loading: controller.isCatalogLoading.value,
          ),
        ),
        SizedBox(height: 16.hpx),
        _ActiveOrderCard(order: controller.activeOrder),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  _HeaderCard({required this.name, required this.address});
  final String name;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.rpx),
      decoration: BoxDecoration(
        color: Color(0xFFF3F7FF),
        borderRadius: BorderRadius.circular(18.rpx),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hi, $name',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4.hpx),
          Text(
            'Everything you need, delivered fast',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10.hpx),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.wpx, vertical: 9.hpx),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12.rpx),
            ),
            child: Row(
              children: [
                Container(
                  width: 24.wpx,
                  height: 24.hpx,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.rpx),
                  ),
                  child: Icon(
                    Icons.location_on,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 8.wpx),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  _SearchBar({required this.controller});
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed(AppRoutes.search),
      borderRadius: BorderRadius.circular(18.rpx),
      child: Container(
        height: 52.hpx,
        padding: EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18.rpx),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
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
            Icon(Icons.search, color: AppColors.primary),
            SizedBox(width: 10.wpx),
            Expanded(
              child: Obx(
                () => AnimatedSwitcher(
                  duration: Duration(milliseconds: 250),
                  child: Text(
                    controller.searchHints[controller
                        .currentSearchHintIndex
                        .value],
                    key: ValueKey(controller.currentSearchHintIndex.value),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
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
  _PromoSection({required this.controller});
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160.hpx,
          child: Obx(() {
            final imagePath =
                controller.promoCards[controller.currentPromoIndex.value];
            return AnimatedSwitcher(
              duration: Duration(milliseconds: 350),
              child: ClipRRect(
                key: ValueKey(controller.currentPromoIndex.value),
                borderRadius: BorderRadius.circular(16.rpx),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 8.hpx),
        Obx(
          () => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(controller.promoCards.length, (i) {
              final active = i == controller.currentPromoIndex.value;
              return AnimatedContainer(
                duration: Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 6,
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
  _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _ProductGrid extends StatelessWidget {
  _ProductGrid({required this.products, required this.loading});

  final List<ProductModel> products;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && products.isEmpty) {
      return SizedBox(
        height: 130.hpx,
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
        final compact = constraints.maxWidth < 380;
        final width = compact
            ? (constraints.maxWidth - 8) / 2
            : (constraints.maxWidth - 24) / 4;
        return Wrap(
          spacing: 8,
          runSpacing: 10,
          children: products.map((product) {
            return SizedBox(
              width: width,
              child: InkWell(
                onTap: () => Get.toNamed(
                  AppRoutes.productDetail,
                  arguments: {'product': product},
                ),
                borderRadius: BorderRadius.circular(12.rpx),
                child: Container(
                  height: 184.hpx,
                  padding: EdgeInsets.all(8.rpx),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _DashboardImageBox(product: product),
                      SizedBox(height: 8.hpx),
                      Expanded(
                        child: Center(
                          child: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 11.spx,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                      Text(
                        product.unit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Rs ${product.price}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6.hpx),
                      SizedBox(
                        width: 58.wpx,
                        child: UniversalAdd(product: product),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  _CategoryGrid({required this.categories, required this.loading});

  final List<CategoryModel> categories;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && categories.isEmpty) {
      return SizedBox(
        height: 110.hpx,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final width = compact
            ? (constraints.maxWidth - 8) / 2
            : (constraints.maxWidth - 24) / 4;
        return Wrap(
          spacing: 8,
          runSpacing: 10,
          children: categories.map((category) {
            return SizedBox(
              width: width,
              child: InkWell(
                onTap: () => Get.toNamed(
                  AppRoutes.categories,
                  arguments: {'categoryId': category.id},
                ),
                borderRadius: BorderRadius.circular(12.rpx),
                child: Container(
                  height: 130.hpx,
                  padding: EdgeInsets.all(8.rpx),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 62.hpx,
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8.rpx),
                        ),
                        child: _CategoryImageBox(category: category),
                      ),
                      SizedBox(height: 8.hpx),
                      Expanded(
                        child: Center(
                          child: Text(
                            category.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 11.spx,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _DashboardImageBox extends StatelessWidget {
  _DashboardImageBox({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.resolvedFeaturedImageUrl;
    return Container(
      height: 62.hpx,
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
              height: 62.hpx,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _fallback(),
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
  _CategoryImageBox({required this.category});

  final CategoryModel category;

  @override
  Widget build(BuildContext context) {
    final imageUrl = category.resolvedImageUrl;
    if (imageUrl.isEmpty) return _fallback();
    return Image.network(
      imageUrl,
      width: double.infinity,
      height: 62.hpx,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return Text(
      category.emoji.isEmpty ? _initial(category.name) : category.emoji,
      style: TextStyle(
        fontSize: 28.spx,
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

String _initial(String value) =>
    value.trim().isEmpty ? 'P' : value.trim().characters.first.toUpperCase();

class _ActiveOrderCard extends StatelessWidget {
  _ActiveOrderCard({required this.order});
  final Map<String, Object> order;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed(
        AppRoutes.liveTracking,
        arguments: {'orderId': order['id']},
      ),
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
              ),
            ),
            SizedBox(width: 12.wpx),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order['title'].toString(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '#${order['id']} | ${order['items']} items',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.hpx),
                  Text(
                    order['subtitle'].toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleTab extends StatelessWidget {
  _SimpleTab({required this.title, required this.icon});
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
  _BottomNav({required this.index, required this.onTap});
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
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(tabs.length, (i) {
                  final active = i == index;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: active ? 0 : 6,
                          bottom: 4,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (active)
                              IgnorePointer(
                                child: Transform.translate(
                                  offset: Offset(0, -20),
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: 2),
                                    width: 46.wpx,
                                    height: 46.hpx,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(
                                        23.rpx,
                                      ),
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
                                          borderRadius: BorderRadius.circular(
                                            17,
                                          ),
                                        ),
                                        child: Icon(
                                          tabs[i].$3,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Icon(
                                tabs[i].$2,
                                size: 19,
                                color: AppColors.textSecondary,
                              ),
                            Text(
                              tabs[i].$1,
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
