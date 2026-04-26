import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../cart/widgets/cart_summary_bar.dart';
import '../../cart/widgets/universal_add.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../controllers/categories_controller.dart';

class CategoriesView extends GetView<CategoriesController> {
  CategoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Obx(
          () => Text(
            controller.selectedCategory.value?.name ?? 'Categories',
            style: TextStyle(fontWeight: FontWeight.w700),
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
                    color: AppColors.white,
                    border: Border(
                      right: BorderSide(color: AppColors.border, width: 0.8),
                    ),
                  ),
                  child: controller.isCategoriesLoading.value
                      ? Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: controller.categories.length,
                          itemBuilder: (context, index) {
                            final category = controller.categories[index];
                            final isSelected =
                                controller.selectedCategory.value?.id ==
                                category.id;
                            return InkWell(
                              onTap: () => controller.selectCategory(category),
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
                    child: controller.isProductsLoading.value
                        ? Center(child: CircularProgressIndicator())
                        : controller.products.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.rpx),
                              child: Text(
                                'New categories will be available soon.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        : GridView.builder(
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
                            itemCount: controller.products.length,
                            itemBuilder: (context, index) {
                              final product = controller.products[index];
                              return InkWell(
                                onTap: () => Get.toNamed(
                                  AppRoutes.productDetail,
                                  arguments: {'product': product},
                                ),
                                borderRadius: BorderRadius.circular(10.rpx),
                                child: Container(
                                  padding: EdgeInsets.all(8.rpx),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(10.rpx),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x1A000000),
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
                                          fontWeight: FontWeight.w600,
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
                                        'Rs ${product.price}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.spx,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              product.unit,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10.spx,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                          if (product.mrp.isNotEmpty)
                                            Text(
                                              'Rs ${product.mrp}',
                                              style: TextStyle(
                                                fontSize: 10.spx,
                                                color: AppColors.textSecondary,
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 6.hpx),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: SizedBox(
                                          width: 58.wpx,
                                          child: UniversalAdd(product: product),
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
  }
}

class _CategoriesBottomNav extends StatelessWidget {
  _CategoriesBottomNav();

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
                  final active = i == 1;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
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
                        Get.snackbar(
                          tabs[i].$1,
                          '${tabs[i].$1} tab abhi pending hai.',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
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

class _CategoryThumb extends StatelessWidget {
  _CategoryThumb({required this.category});

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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.rpx),
      ),
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: 46.wpx,
              height: 46.hpx,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _categoryFallback(),
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
  _ProductImageBox({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.resolvedImageUrl.toString();
    return Container(
      height: 82.hpx,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8.rpx),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: double.infinity,
              height: 82.hpx,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _fallback(),
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
