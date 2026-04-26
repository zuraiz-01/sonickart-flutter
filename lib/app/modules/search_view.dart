import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../data/models/product_model.dart';
import '../data/repositories/catalog_repository.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'cart/widgets/cart_summary_bar.dart';
import 'cart/widgets/universal_add.dart';

class SearchView extends StatefulWidget {
  SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _queryController = TextEditingController();
  final _results = <ProductModel>[].obs;
  final _loading = false.obs;
  final _hasSearched = false.obs;
  Worker? _debounceWorker;
  final _query = ''.obs;

  @override
  void initState() {
    super.initState();
    final initialQuery = Get.arguments?['query']?.toString();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      _queryController.text = initialQuery;
    }
    _queryController.addListener(() => _query.value = _queryController.text);
    _debounceWorker = debounce<String>(
      _query,
      _performSearch,
      time: Duration(milliseconds: 500),
    );
    if (_queryController.text.trim().isNotEmpty) {
      _query.value = _queryController.text;
      _performSearch(_queryController.text);
    }
  }

  Future<void> _performSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      _results.clear();
      _hasSearched.value = false;
      return;
    }
    _loading.value = true;
    _hasSearched.value = true;
    try {
      final repo = Get.find<CatalogRepository>();
      _results.assignAll(await repo.searchProducts(query));
    } finally {
      _loading.value = false;
    }
  }

  @override
  void dispose() {
    _debounceWorker?.dispose();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(title: Text('Search Products'), centerTitle: true),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: EdgeInsets.all(12.rpx),
                child: TextField(
                  controller: _queryController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search for products...',
                    prefixIcon: Icon(Icons.search, color: AppColors.primary),
                    suffixIcon: Obx(
                      () => _query.value.isEmpty
                          ? SizedBox.shrink()
                          : IconButton(
                              onPressed: _queryController.clear,
                              icon: Icon(Icons.cancel_outlined),
                            ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.rpx),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Obx(() {
                  if (_loading.value) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }
                  if (!_hasSearched.value) {
                    return _SearchState(
                      icon: Icons.search,
                      title: 'Search for products',
                      subtitle:
                          'Enter a product name to search nearby catalog.',
                    );
                  }
                  if (_results.isEmpty) {
                    return _SearchState(
                      icon: Icons.search_off,
                      title: 'No products found',
                      subtitle:
                          'Try another keyword or select a delivery address first.',
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      12.wpx,
                      4.hpx,
                      12.wpx,
                      112.hpx,
                    ),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10.hpx),
                    itemBuilder: (context, index) {
                      final product = _results[index];
                      return _ProductTile(product: product);
                    },
                  );
                }),
              ),
            ],
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: CartSummaryBar()),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  _ProductTile({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          Get.toNamed(AppRoutes.productDetail, arguments: {'product': product}),
      borderRadius: BorderRadius.circular(16.rpx),
      child: Container(
        padding: EdgeInsets.all(12.rpx),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16.rpx),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _ProductVisual(product: product, size: 62),
            SizedBox(width: 12.wpx),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4.hpx),
                  Text(
                    product.unit,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6.hpx),
                  Text(
                    'Rs ${product.price}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 58.wpx,
              child: UniversalAdd(product: product),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductVisual extends StatelessWidget {
  _ProductVisual({required this.product, required this.size});

  final ProductModel product;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (product.imageUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14.rpx),
        child: Image.network(
          product.imageUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14.rpx),
    ),
    child: Text(
      product.emoji.isEmpty
          ? (product.name.isEmpty
                ? 'P'
                : product.name.characters.first.toUpperCase())
          : product.emoji,
      style: TextStyle(
        fontSize: 26.spx,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
      ),
    ),
  );
}

class _SearchState extends StatelessWidget {
  _SearchState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.rpx),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 62, color: AppColors.primary),
            SizedBox(height: 16.hpx),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.hpx),
            Text(
              subtitle,
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
