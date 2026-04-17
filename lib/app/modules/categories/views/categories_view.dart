import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../cart/widgets/cart_summary_bar.dart';
import '../../cart/widgets/universal_add.dart';
import '../controllers/categories_controller.dart';

class CategoriesView extends GetView<CategoriesController> {
  const CategoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Obx(
          () => Text(
            controller.selectedCategory.value?.name ?? 'Categories',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: Get.back,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        actions: [
          IconButton(
            onPressed: () => Get.toNamed(AppRoutes.search),
            icon: const Icon(Icons.search_rounded),
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
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(
                  right: BorderSide(color: AppColors.border, width: 0.8),
                ),
              ),
              child: controller.isCategoriesLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: controller.categories.length,
                      itemBuilder: (context, index) {
                        final category = controller.categories[index];
                        final isSelected =
                            controller.selectedCategory.value?.id == category.id;
                        return InkWell(
                          onTap: () => controller.selectCategory(category),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              border: Border(
                                right: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                _CategoryThumb(category: category),
                                const SizedBox(height: 6),
                                Text(
                                  category.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight:
                                        isSelected ? FontWeight.w800 : FontWeight.w700,
                                    fontSize: 12,
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
                    ? const Center(child: CircularProgressIndicator())
                    : controller.products.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
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
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 112),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
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
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x1A000000),
                                          blurRadius: 3,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _ProductImageBox(product: product),
                                        const SizedBox(height: 8),
                                        Text(
                                          product.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Expanded(
                                          child: Text(
                                            product.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: AppColors.primary,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Rs ${product.price}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
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
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                            if (product.mrp.isNotEmpty)
                                              Text(
                                                'Rs ${product.mrp}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.textSecondary,
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: SizedBox(
                                            width: 58,
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
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CartSummaryBar(),
          ),
        ],
      ),
      bottomNavigationBar: const _CategoriesBottomNav(),
    );
  }
}

class _CategoriesBottomNav extends StatelessWidget {
  const _CategoriesBottomNav();

  @override
  Widget build(BuildContext context) {
    const tabs = [
      ('Home', Icons.home_outlined, Icons.home_rounded),
      ('Categories', Icons.category_outlined, Icons.category_rounded),
      ('Cart', Icons.shopping_cart_outlined, Icons.shopping_cart_rounded),
      ('Package', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
      ('Profile', Icons.person_outline_rounded, Icons.person_rounded),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.only(
                top: 8,
                left: 8,
                right: 8,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
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
                          Get.offNamed(AppRoutes.dashboard);
                          return;
                        }
                        if (i == 2) {
                          Get.offNamed(
                            AppRoutes.dashboard,
                            arguments: {'tabIndex': 2},
                          );
                          return;
                        }
                        if (i == 3) {
                          Get.offNamed(
                            AppRoutes.dashboard,
                            arguments: {'tabIndex': 3},
                          );
                          return;
                        }
                        if (i == 4) {
                          Get.offNamed(
                            AppRoutes.dashboard,
                            arguments: {'tabIndex': 4},
                          );
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
                                  offset: const Offset(0, -20),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 2),
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(23),
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
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: AppColors.white,
                                          borderRadius: BorderRadius.circular(17),
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
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: active
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    fontSize: 10,
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
  const _CategoryThumb({required this.category});

  final CategoryModel category;

  @override
  Widget build(BuildContext context) {
    final imageUrl = category.resolvedImageUrl;
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: 46,
              height: 46,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _categoryFallback(),
            )
          : _categoryFallback(),
    );
  }

  Widget _categoryFallback() {
    return Text(
      category.emoji.isEmpty
          ? (category.name.isEmpty ? 'C' : category.name.characters.first.toUpperCase())
          : category.emoji,
      style: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
        fontSize: 20,
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
      height: 82,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: double.infinity,
              height: 82,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _fallback(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
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
      emoji.isEmpty ? (name.isEmpty ? 'P' : name.characters.first.toUpperCase()) : emoji,
      style: const TextStyle(
        fontSize: 42,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
      ),
    );
  }
}
