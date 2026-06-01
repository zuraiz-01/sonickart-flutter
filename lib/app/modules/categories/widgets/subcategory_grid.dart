import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';

import '../../../data/models/product_subcategory_model.dart';
import '../../../theme/app_colors.dart';

class SubcategoryGrid extends StatelessWidget {
  const SubcategoryGrid({
    super.key,
    required this.subcategories,
    required this.onTap,
  });

  final List<ProductSubcategoryModel> subcategories;
  final ValueChanged<ProductSubcategoryModel> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(8.wpx, 10.hpx, 8.wpx, 112.hpx),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8.wpx,
        mainAxisSpacing: 8.hpx,
        childAspectRatio: 0.95,
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

class BackToSubcategoriesCard extends StatelessWidget {
  const BackToSubcategoriesCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.rpx),
      child: Container(
        padding: EdgeInsets.all(8.rpx),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10.rpx),
          border: Border.all(color: AppColors.accent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42.rpx,
              height: 42.rpx,
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
                size: 22.spx,
              ),
            ),
            SizedBox(height: 8.hpx),
            Text(
              'Subcategories',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 11.spx,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubcategoryCard extends StatelessWidget {
  const _SubcategoryCard({required this.subcategory, required this.onTap});

  final ProductSubcategoryModel subcategory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOtherProducts = subcategory.isMixed;
    final isDark = AppColors.isDarkMode;
    final cardColor = isDark ? const Color(0xFF06225B) : AppColors.card;
    final borderColor = isDark ? AppColors.accent : AppColors.border;
    final textColor = isDark ? AppColors.accent : AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.rpx),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.wpx, vertical: 8.hpx),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14.rpx),
          border: Border.all(color: borderColor, width: 1.2.rpx),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 4.rpx,
              offset: Offset(0, 2.hpx),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SubcategoryThumb(subcategory: subcategory),
            SizedBox(height: 6.hpx),
            Text(
              subcategory.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 11.spx,
                fontWeight: FontWeight.w900,
                height: 1.12,
              ),
            ),
            if (isOtherProducts || isDark) ...[
              SizedBox(height: 4.hpx),
              Container(
                width: 34.wpx,
                height: 3.hpx,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2.rpx),
                ),
              ),
            ],
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
    if (subcategory.isMixed) {
      return OtherProductsLogo(size: 62.rpx);
    }

    final imageUrl = subcategory.resolvedImageUrl;
    return Container(
      width: 62.rpx,
      height: 62.rpx,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.productImageFill,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.isDarkMode
              ? AppColors.accent
              : AppColors.primary.withValues(alpha: 0.08),
          width: 1.rpx,
        ),
      ),
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: 56.rpx,
              height: 56.rpx,
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
        fontSize: 20.spx,
      ),
    );
  }
}

class OtherProductsLogo extends StatelessWidget {
  const OtherProductsLogo({super.key, this.size = 54});

  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final tile = size * 0.23;
    final gap = size * 0.07;
    final boardSize = (tile * 2) + gap;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF001033) : AppColors.productImageFill,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark
                ? AppColors.accent
                : AppColors.primary.withValues(alpha: 0.08),
            width: isDark ? size * 0.055 : 1.rpx,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: Stack(
              children: [
                _LogoTile(
                  left: 0,
                  top: 0,
                  size: tile,
                  color: const Color(0xFF2EA7FF),
                ),
                _LogoTile(
                  left: tile + gap,
                  top: 0,
                  size: tile,
                  color: AppColors.accent,
                ),
                _LogoTile(
                  left: 0,
                  top: tile + gap,
                  size: tile,
                  color: const Color(0xFF63D447),
                ),
                _LogoTile(
                  left: tile + gap,
                  top: tile + gap,
                  size: tile,
                  color: const Color(0xFF8248F4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile({
    required this.left,
    required this.top,
    required this.size,
    required this.color,
  });

  final double left;
  final double top;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
      ),
    );
  }
}
