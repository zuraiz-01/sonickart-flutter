import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/product_subcategory_model.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_controller.dart';
import '../../cart/widgets/cart_summary_bar.dart';
import '../../cart/widgets/universal_add.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../controllers/categories_controller.dart';

class CategoriesView extends GetView<CategoriesController> {
  const CategoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<AppThemeController>();
    return Obx(() {
      themeController.isDarkMode.value;
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: Text(
            'Categories',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 22.spx,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            onPressed: Get.back,
            icon: Icon(Icons.chevron_left_rounded),
          ),
          actions: [
            IconButton(
              onPressed: () => Get.toNamed(AppRoutes.search),
              icon: Icon(Icons.search_rounded),
            ),
          ],
        ),
        body: Stack(
          children: [
            Obx(
              () => Row(
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width * 0.30,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border(
                        right: BorderSide(color: AppColors.border, width: 0.8),
                      ),
                    ),
                    child:
                        controller.isCategoriesLoading.value &&
                            controller.categories.isEmpty
                        ? Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            controller: controller.categoryListScrollController,
                            itemExtent:
                                CategoriesController.categoryListItemExtent,
                            itemCount: controller.categories.length,
                            itemBuilder: (context, index) {
                              final category = controller.categories[index];
                              final isSelected =
                                  controller.selectedCategory.value?.id ==
                                  category.id;
                              return InkWell(
                                onTap: () {
                                  if (controller.shouldIgnoreCategoryTap(
                                    category,
                                  )) {
                                    return;
                                  }
                                  controller.selectCategory(category);
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 18,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withValues(
                                            alpha: 0.08,
                                          )
                                        : Colors.transparent,
                                    border: Border(
                                      right: BorderSide(
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        width: 4.wpx,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      _CategoryThumb(category: category),
                                      SizedBox(height: 6.hpx),
                                      Text(
                                        category.name,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w700,
                                          fontSize: 12.spx,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Expanded(
                    child: Container(
                      color: AppColors.surface,
                      child: controller.shouldShowSubcategoryOptions
                          ? _SubcategoryGrid(
                              subcategories:
                                  controller.visibleSubcategoryOptions,
                              onTap: controller.selectSubcategory,
                            )
                          : controller.isProductsLoading.value ||
                                controller.isSubcategoriesLoading.value
                          ? Center(child: CircularProgressIndicator())
                          : controller.products.isEmpty
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(20.rpx),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      controller.selectedSubcategory.value ==
                                              null
                                          ? 'New categories will be available soon.'
                                          : 'No products found in this subcategory.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (controller.selectedSubcategory.value !=
                                            null &&
                                        controller
                                            .visibleSubcategoryOptions
                                            .isNotEmpty) ...[
                                      SizedBox(height: 14.hpx),
                                      TextButton.icon(
                                        onPressed:
                                            controller.showSubcategoryOptions,
                                        icon: Icon(
                                          Icons.apps_rounded,
                                          size: 18.spx,
                                        ),
                                        label: Text(
                                          'Subcategories',
                                          style: TextStyle(
                                            fontSize: 12.spx,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          : GridView.builder(
                              controller:
                                  controller.productGridScrollController,
                              padding: EdgeInsets.fromLTRB(
                                8.wpx,
                                8.hpx,
                                8.wpx,
                                112.hpx,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 0.50,
                                  ),
                              itemCount:
                                  controller.products.length +
                                  (controller.selectedSubcategory.value !=
                                              null &&
                                          controller
                                              .visibleSubcategoryOptions
                                              .isNotEmpty
                                      ? 1
                                      : 0),
                              itemBuilder: (context, index) {
                                final hasBackCard =
                                    controller.selectedSubcategory.value !=
                                        null &&
                                    controller
                                        .visibleSubcategoryOptions
                                        .isNotEmpty;
                                if (hasBackCard && index == 0) {
                                  return _BackToSubcategoriesCard(
                                    onTap: controller.showSubcategoryOptions,
                                  );
                                }
                                final product = controller
                                    .products[hasBackCard ? index - 1 : index];
                                return InkWell(
                                  onTap: () => Get.toNamed(
                                    AppRoutes.productDetail,
                                    arguments: {'product': product},
                                  ),
                                  borderRadius: BorderRadius.circular(10.rpx),
                                  child: Container(
                                    padding: EdgeInsets.all(8.rpx),
                                    decoration: BoxDecoration(
                                      color: AppColors.card,
                                      borderRadius: BorderRadius.circular(
                                        10.rpx,
                                      ),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.cardShadow,
                                          blurRadius: 3,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _ProductImageBox(product: product),
                                        SizedBox(height: 8.hpx),
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
                                        SizedBox(height: 2),
                                        Expanded(
                                          child: Text(
                                            product.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 9.spx,
                                              color: AppColors.primary,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 4.hpx),
                                        Text(
                                          '₹${product.displayPrice}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.spx,
                                            color: AppColors.price,
                                          ),
                                        ),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                product.unit == '1 pc'
                                                    ? ' '
                                                    : product.unit,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 10.spx,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                            if (product.displayMrp.isNotEmpty)
                                              Text(
                                                '₹${product.displayMrp}',
                                                style: TextStyle(
                                                  fontSize: 10.spx,
                                                  color:
                                                      AppColors.textSecondary,
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                ),
                                              ),
                                          ],
                                        ),
                                        SizedBox(height: 6.hpx),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: SizedBox(
                                            width: 58.wpx,
                                            child: UniversalAdd(
                                              product: product,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: CartSummaryBar()),
          ],
        ),
        bottomNavigationBar: _CategoriesBottomNav(),
      );
    });
  }
}

class _CategoriesBottomNav extends StatelessWidget {
  const _CategoriesBottomNav();

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
                  color: AppColors.activeNav,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(22.rpx),
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.navBg,
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
                  final active = i == 1;
                  return Expanded(
                    child: _CategoriesNavItem(
                      label: tabs[i].$1,
                      icon: tabs[i].$2,
                      activeIcon: tabs[i].$3,
                      active: active,
                      onTap: () {
                        if (i == 1) return;
                        if (i == 0) {
                          openDashboardTab(0);
                          return;
                        }
                        if (i == 2) {
                          openDashboardTab(2);
                          return;
                        }
                        if (i == 3) {
                          openDashboardTab(3);
                          return;
                        }
                        if (i == 4) {
                          openDashboardTab(4);
                          return;
                        }
                        AppSnackBar.show(
                          tabs[i].$1,
                          '${tabs[i].$1} tab abhi pending hai.',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
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

class _CategoriesNavItem extends StatelessWidget {
  const _CategoriesNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 72.hpx,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                child: active ? _activeIcon() : _inactiveIcon(),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 18.hpx,
                  child: Center(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: active
                            ? AppColors.activeNav
                            : AppColors.textSecondary,
                        fontSize: 10.spx,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeIcon() {
    return Container(
      width: 46.wpx,
      height: 46.hpx,
      decoration: BoxDecoration(
        color: AppColors.activeNav,
        borderRadius: BorderRadius.circular(23.rpx),
        boxShadow: const [
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
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(activeIcon, size: 18.spx, color: AppColors.activeNav),
        ),
      ),
    );
  }

  Widget _inactiveIcon() {
    return SizedBox(
      width: 46.wpx,
      height: 46.hpx,
      child: Center(
        child: Icon(icon, size: 19.spx, color: AppColors.textSecondary),
      ),
    );
  }
}

class _BackToSubcategoriesCard extends StatelessWidget {
  const _BackToSubcategoriesCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.rpx),
      child: Container(
        padding: EdgeInsets.all(10.rpx),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10.rpx),
          border: Border.all(color: AppColors.accent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48.rpx,
              height: 48.rpx,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Icon(
                Icons.apps_rounded,
                color: AppColors.primary,
                size: 24.spx,
              ),
            ),
            SizedBox(height: 10.hpx),
            Text(
              'Subcategories',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 12.spx,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubcategoryGrid extends StatelessWidget {
  const _SubcategoryGrid({required this.subcategories, required this.onTap});

  final List<ProductSubcategoryModel> subcategories;
  final ValueChanged<ProductSubcategoryModel> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(10.wpx, 14.hpx, 10.wpx, 112.hpx),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10.wpx,
        mainAxisSpacing: 12.hpx,
        childAspectRatio: 0.78,
      ),
      itemCount: subcategories.length,
      itemBuilder: (context, index) {
        final subcategory = subcategories[index];
        return _SubcategoryCard(
          subcategory: subcategory,
          onTap: () => onTap(subcategory),
        );
      },
    );
  }
}

class _SubcategoryCard extends StatelessWidget {
  const _SubcategoryCard({required this.subcategory, required this.onTap});

  final ProductSubcategoryModel subcategory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.rpx),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.wpx, vertical: 12.hpx),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18.rpx),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 5.rpx,
              offset: Offset(0, 3.hpx),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SubcategoryThumb(subcategory: subcategory),
            SizedBox(height: 10.hpx),
            Text(
              subcategory.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12.spx,
                fontWeight: FontWeight.w900,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubcategoryThumb extends StatelessWidget {
  const _SubcategoryThumb({required this.subcategory});

  final ProductSubcategoryModel subcategory;

  @override
  Widget build(BuildContext context) {
    final imageUrl = subcategory.resolvedImageUrl;
    return Container(
      width: 66.rpx,
      height: 66.rpx,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: subcategory.isMixed
            ? AppColors.accent.withValues(alpha: 0.22)
            : AppColors.productImageFill,
        shape: BoxShape.circle,
        border: Border.all(
          color: subcategory.isMixed
              ? AppColors.accent
              : AppColors.primary.withValues(alpha: 0.08),
          width: 1.2.rpx,
        ),
      ),
      child: subcategory.isMixed
          ? Icon(
              Icons.inventory_2_rounded,
              color: AppColors.primary,
              size: 30.spx,
            )
          : imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: 66.rpx,
              height: 66.rpx,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    return Text(
      subcategory.name.isEmpty
          ? 'S'
          : subcategory.name.characters.first.toUpperCase(),
      style: TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w900,
        fontSize: 24.spx,
      ),
    );
  }
}

class _CategoryThumb extends StatelessWidget {
  const _CategoryThumb({required this.category});

  final CategoryModel category;

  @override
  Widget build(BuildContext context) {
    final imageUrl = category.resolvedImageUrl;
    return Container(
      width: 46.wpx,
      height: 46.hpx,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.productImageFill,
        borderRadius: BorderRadius.circular(14.rpx),
      ),
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: 46.wpx,
              height: 46.hpx,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _categoryFallback(),
            )
          : _categoryFallback(),
    );
  }

  Widget _categoryFallback() {
    return Text(
      category.emoji.isEmpty
          ? (category.name.isEmpty
                ? 'C'
                : category.name.characters.first.toUpperCase())
          : category.emoji,
      style: TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
        fontSize: 20.spx,
      ),
    );
  }
}

class _ProductImageBox extends StatelessWidget {
  const _ProductImageBox({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.resolvedImageUrl.toString();
    return Container(
      height: 82.hpx,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.productImageFill,
        borderRadius: BorderRadius.circular(8.rpx),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: double.infinity,
              height: 82.hpx,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _fallback(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Center(
                  child: SizedBox(
                    width: 18.wpx,
                    height: 18.hpx,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    final emoji = product.emoji.toString();
    final name = product.name.toString();
    return Text(
      emoji.isEmpty
          ? (name.isEmpty ? 'P' : name.characters.first.toUpperCase())
          : emoji,
      style: TextStyle(
        fontSize: 42.spx,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
      ),
    );
  }
}
