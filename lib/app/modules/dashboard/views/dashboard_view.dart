import 'package:flutter/material.dart';
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
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final user = auth.currentUser;
    final tabs = [
      _HomeTab(user: user, controller: controller),
      const _SimpleTab(title: 'Categories', icon: Icons.grid_view_rounded),
      const CartView(),
      const PackageView(),
      const ProfileView(),
    ];

    return Obx(
      () => Scaffold(
        backgroundColor: const Color(0xFFF3F7FF),
        body: Stack(
          children: [
            Container(
              height: 220,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF36435C), Color(0xE636435C), Color(0x0036435C)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            SafeArea(child: tabs[controller.currentIndex.value]),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CartSummaryBar(),
            ),
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
  const _HomeTab({required this.user, required this.controller});
  final dynamic user;
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final name = user?.name?.toString().isNotEmpty == true ? user.name.toString() : 'Guest';
    final address = user?.phone?.toString().isNotEmpty == true
        ? '${user.phone} - Select delivery address'
        : 'Select delivery address';
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        _HeaderCard(name: name, address: address),
        const SizedBox(height: 12),
        _SearchBar(controller: controller),
        const SizedBox(height: 16),
        _PromoSection(controller: controller),
        const SizedBox(height: 16),
        _SectionTitle('Featured Products'),
        const SizedBox(height: 10),
        Obx(
          () => _ProductGrid(
            products: controller.featuredProducts,
            loading: controller.isCatalogLoading.value,
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle('Categories'),
        const SizedBox(height: 10),
        Obx(
          () => _CategoryGrid(
            categories: controller.categories,
            loading: controller.isCatalogLoading.value,
          ),
        ),
        const SizedBox(height: 16),
        _ActiveOrderCard(order: controller.activeOrder),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.name, required this.address});
  final String name;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FF),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hi, $name', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Everything you need, delivered fast', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(address, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700))),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed(AppRoutes.search),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
          boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 6))],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Obx(() => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      controller.searchHints[controller.currentSearchHintIndex.value],
                      key: ValueKey(controller.currentSearchHintIndex.value),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                  )),
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
        SizedBox(
          height: 160,
          child: Obx(() {
            final imagePath = controller.promoCards[controller.currentPromoIndex.value];
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: ClipRRect(
                key: ValueKey(controller.currentPromoIndex.value),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    boxShadow: const [
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
        const SizedBox(height: 8),
        Obx(() => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(controller.promoCards.length, (i) {
                final active = i == controller.currentPromoIndex.value;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            )),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700));
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.products,
    required this.loading,
  });

  final List<ProductModel> products;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && products.isEmpty) {
      return const SizedBox(
        height: 130,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (products.isEmpty) {
      return const Text(
        'Featured products will appear here.',
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 380;
      final width = compact ? (constraints.maxWidth - 8) / 2 : (constraints.maxWidth - 24) / 4;
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
              borderRadius: BorderRadius.circular(12),
              child: Container(
              height: 184,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Column(
                children: [
                  _DashboardImageBox(product: product),
                  const SizedBox(height: 8),
                  Expanded(child: Center(child: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)))),
                  Text(product.unit, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  Text('Rs ${product.price}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 58,
                    child: UniversalAdd(product: product),
                  ),
                ],
              ),
            )),
          );
        }).toList(),
      );
    });
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories, required this.loading});

  final List<CategoryModel> categories;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && categories.isEmpty) {
      return const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 380;
      final width = compact ? (constraints.maxWidth - 8) / 2 : (constraints.maxWidth - 24) / 4;
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
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 130,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    Container(
                      height: 62,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                      child: _CategoryImageBox(category: category),
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: Center(child: Text(category.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)))),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

class _DashboardImageBox extends StatelessWidget {
  const _DashboardImageBox({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.resolvedFeaturedImageUrl;
    return Container(
      height: 62,
      width: double.infinity,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: double.infinity,
              height: 62,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    return Text(
      product.emoji.isEmpty ? _initial(product.name) : product.emoji,
      style: const TextStyle(
        fontSize: 28,
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _CategoryImageBox extends StatelessWidget {
  const _CategoryImageBox({required this.category});

  final CategoryModel category;

  @override
  Widget build(BuildContext context) {
    final imageUrl = category.resolvedImageUrl;
    if (imageUrl.isEmpty) return _fallback();
    return Image.network(
      imageUrl,
      width: double.infinity,
      height: 62,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return Text(
      category.emoji.isEmpty ? _initial(category.name) : category.emoji,
      style: const TextStyle(
        fontSize: 28,
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

String _initial(String value) => value.trim().isEmpty
    ? 'P'
    : value.trim().characters.first.toUpperCase();

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});
  final Map<String, Object> order;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed(AppRoutes.liveTracking, arguments: {'orderId': order['id']}),
      borderRadius: BorderRadius.circular(22),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: const Color(0xFFEEF4FF), borderRadius: BorderRadius.circular(22)),
          child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(order['title'].toString(), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('#${order['id']} | ${order['items']} items', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(order['subtitle'].toString(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ])),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Track', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
          const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
        ]),
      ]),
      ),
    );
  }
}

class _SimpleTab extends StatelessWidget {
  const _SimpleTab({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(28)),
          child: Icon(icon, size: 40, color: AppColors.primary),
        ),
        const SizedBox(height: 18),
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.primary)),
      ]),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

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
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: 0, right: 0, top: 0, child: Container(height: 24, decoration: const BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.vertical(top: Radius.circular(22))))),
          Container(
            padding: const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 8),
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, -2))]),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(tabs.length, (i) {
                final active = i == index;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Padding(
                      padding: EdgeInsets.only(top: active ? 0 : 6, bottom: 4),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (active)
                          IgnorePointer(
                            child: Transform.translate(
                              offset: const Offset(0, -20),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(23), boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 10, offset: Offset(0, 6))]),
                                child: Center(child: Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(17)), child: Icon(tabs[i].$3, size: 18, color: AppColors.primary))),
                              ),
                            ),
                          )
                        else
                          Icon(tabs[i].$2, size: 19, color: AppColors.textSecondary),
                        Text(tabs[i].$1, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: active ? AppColors.primary : AppColors.textSecondary, fontSize: 10, fontWeight: active ? FontWeight.w600 : FontWeight.w500)),
                      ]),
                    ),
                  ),
                );
              }),
            ),
          ),
        ]),
      ),
    );
  }
}
