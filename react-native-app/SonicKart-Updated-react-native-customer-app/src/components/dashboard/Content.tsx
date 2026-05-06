import { View, StyleSheet, ActivityIndicator, Image, TouchableOpacity } from 'react-native';
import React, { FC, useEffect, useState } from 'react';
import CustomText from '@components/ui/CustomText';
import { Fonts } from '@utils/Constants';
import CategoryContainer from './CategoryContainer';
import PromoSlider from './PromoSlider';
import { getAllCategories, getProductsByCategoryId } from '@service/productService';
import { navigate } from '@utils/NavigationUtils';
import { normalizeImageUrl } from '@utils/imageUtils';
import { getProductUnit } from '@utils/productUnit';
import { formatCurrencyValue, resolveDisplayPriceWithGst } from '@utils/productPricing';
import { useDeliverySettingsStore } from '@state/deliverySettingsStore';
import { useVendorLocationContext } from '../../hooks/useVendorLocationContext';
import colors from '../../theme/colors';

function shuffleArray<T>(items: T[]) {
  const nextItems = [...items];

  for (let index = nextItems.length - 1; index > 0; index -= 1) {
    const randomIndex = Math.floor(Math.random() * (index + 1));
    [nextItems[index], nextItems[randomIndex]] = [nextItems[randomIndex], nextItems[index]];
  }

  return nextItems;
}

const attachCategoryMeta = (product: any, category: any) => ({
  ...product,
  categoryId:
    product?.categoryId || product?.category_id || category?.id,
  category_id:
    product?.category_id || product?.categoryId || category?.id,
  categoryName:
    product?.categoryName || product?.category_name || category?.name,
  category_name:
    product?.category_name || product?.categoryName || category?.name,
});

const isRemovedProduct = (product: any) => {
  if (!product) {
    return true;
  }

  const deletedAtValue = product?.deletedAt ?? product?.deleted_at;
  const hasDeletedTimestamp =
    deletedAtValue !== undefined &&
    deletedAtValue !== null &&
    String(deletedAtValue).trim().length > 0;

  if (
    product?.isDeleted === true ||
    product?.is_deleted === true ||
    product?.deleted === true ||
    hasDeletedTimestamp
  ) {
    return true;
  }

  const status = String(
    product?.status ?? product?.productStatus ?? product?.product_status ?? ''
  )
    .trim()
    .toLowerCase();

  return status === 'deleted' || status === 'removed' || status === 'archived';
};

const resolveFeaturedUnitLabel = (product: any) => {
  const isSinglePieceLabel = (value: string) => /^1\s*(pc|pcs|piece|pieces)$/i.test(value.trim());
  const isBareNumericLabel = (value: string) => /^\d+(?:\.\d+)?$/.test(value.trim());

  const directCandidates = [
    product?.displayUnit,
    product?.display_unit,
    product?.units,
    product?.quantity,
    product?.quantity_text,
    product?.quantityText,
    product?.unit,
    product?.uom,
    product?.unitDisplay,
    product?.unit_display,
    product?.unitLabel,
    product?.unit_label,
    product?.pack_size,
    product?.packSize,
    product?.size,
    product?.weight,
    product?.volume,
    product?.net_quantity,
    product?.netQuantity,
  ];

  for (const candidate of directCandidates) {
    if (candidate === undefined || candidate === null) {
      continue;
    }

    const value = String(candidate).trim();
    if (value && !isSinglePieceLabel(value) && !isBareNumericLabel(value)) {
      return value;
    }
  }

  const resolvedUnit = getProductUnit(product);
  return isSinglePieceLabel(resolvedUnit) || isBareNumericLabel(resolvedUnit) ? '' : resolvedUnit;
};

const Content: FC = () => {
  const [categories, setCategories] = useState<any[]>([]);
  const [featuredProducts, setFeaturedProducts] = useState<any[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [featuredLoading, setFeaturedLoading] = useState<boolean>(true);
  const productRadiusKm = useDeliverySettingsStore(
    (state) => state.settings.productRadiusKm
  );
  const featuredProductsLimit = useDeliverySettingsStore(
    (state) => state.settings.featuredProductsLimit
  );
  const { vendorIds, scopedCoordinate, vendorResolving } = useVendorLocationContext();

  useEffect(() => {
    const fetchCategories = async () => {
      try {
        setLoading(true);
        const data = await getAllCategories();
        setCategories(Array.isArray(data) ? data : []);
      } catch (error) {
        console.log('Error loading categories for home', error);
        setCategories([]);
      } finally {
        setLoading(false);
      }
    };

    fetchCategories();
  }, []);

  useEffect(() => {
    let isMounted = true;

    const fetchFeaturedProducts = async () => {
      if (!categories.length) {
        setFeaturedProducts([]);
        setFeaturedLoading(false);
        return;
      }

      try {
        setFeaturedLoading(true);
        if (vendorResolving) {
          return;
        }

        if (!vendorIds.length) {
          if (isMounted) {
            setFeaturedProducts([]);
          }
          return;
        }

        const randomizedCategories = shuffleArray(categories);
        const featuredProductTarget = Math.max(1, featuredProductsLimit);
        const balancedCategories = randomizedCategories.slice(
          0,
          Math.min(
            randomizedCategories.length,
            featuredProductTarget
          )
        );

        const uniqueProductMap = new Map<string, any>();

        const fetchVendorScopedProductsForCategory = async (category: any) => {
          const categoryId = String(category?.id ?? '').trim();
          if (!categoryId) {
            return [];
          }

          if (vendorIds.length > 1) {
            const vendorResults = await Promise.all(
              vendorIds.map(async (vendorId) => {
                const vendorProducts = await getProductsByCategoryId(categoryId, {
                  vendorId,
                  latitude: scopedCoordinate?.latitude,
                  longitude: scopedCoordinate?.longitude,
                  radiusKm: productRadiusKm,
                });

                return vendorProducts.map((product: any) => ({
                  ...product,
                  vendorId: product?.vendorId || product?.vendor_id || vendorId,
                  vendor_id: product?.vendor_id || product?.vendorId || vendorId,
                }));
              })
            );

            return vendorResults.flat();
          }

          return getProductsByCategoryId(categoryId, {
            vendorId: vendorIds[0],
            latitude: scopedCoordinate?.latitude,
            longitude: scopedCoordinate?.longitude,
            radiusKm: productRadiusKm,
          });
        };

        const appendUniqueProducts = (products: any[], category: any) => {
          const normalizedProducts = shuffleArray(
            (Array.isArray(products) ? products : []).map((product) =>
              attachCategoryMeta(product, category)
            )
          );

          let addedCount = 0;
          for (const product of normalizedProducts) {
            const productId = String(product?.id ?? product?._id ?? '').trim();
            if (
              !productId ||
              uniqueProductMap.has(productId) ||
              isRemovedProduct(product)
            ) {
              continue;
            }
            uniqueProductMap.set(productId, product);
            addedCount += 1;

            if (uniqueProductMap.size >= featuredProductTarget) {
              break;
            }
          }

          return addedCount;
        };

        // Pass-1: balance across random categories while avoiding duplicates.
        for (
          let categoryIndex = 0;
          categoryIndex < balancedCategories.length &&
          uniqueProductMap.size < featuredProductTarget;
          categoryIndex += 1
        ) {
          const category = balancedCategories[categoryIndex];
          const categoryProducts = await fetchVendorScopedProductsForCategory(category);
          appendUniqueProducts(categoryProducts, category);
        }

        // Pass-2: top-up from any category/vendor combination until we hit 8.
        if (uniqueProductMap.size < featuredProductTarget) {
          const fallbackCategories = shuffleArray(categories);

          for (const category of fallbackCategories) {
            if (uniqueProductMap.size >= featuredProductTarget) {
              break;
            }

            const categoryProducts = await fetchVendorScopedProductsForCategory(
              category
            );
            appendUniqueProducts(categoryProducts, category);
          }
        }

        const randomProducts = shuffleArray(Array.from(uniqueProductMap.values())).slice(
          0,
          featuredProductTarget
        );

        if (isMounted) {
          setFeaturedProducts(randomProducts);
        }
      } catch (error) {
        console.log('Error loading featured products for home', error);
        if (isMounted) {
          setFeaturedProducts([]);
        }
      } finally {
        if (isMounted) {
          setFeaturedLoading(false);
        }
      }
    };

    fetchFeaturedProducts();

    return () => {
      isMounted = false;
    };
  }, [
    categories,
    featuredProductsLimit,
    productRadiusKm,
    scopedCoordinate?.latitude,
    scopedCoordinate?.longitude,
    vendorIds,
    vendorResolving,
  ]);

  return (
    <View style={styles.container}>
      <PromoSlider />

      <View style={styles.featuredHeader}>
        <View>
          <CustomText
            fontFamily={Fonts.Bold}
            fontSize={18}
            style={styles.featuredTitle}
          >
            Featured Products
          </CustomText>
        </View>
      </View>

      {featuredLoading && !featuredProducts.length ? (
        <ActivityIndicator
          size="small"
          color={colors.primaryBlue}
          style={styles.featuredLoader}
        />
      ) : (
        <>
          {featuredLoading ? (
            <ActivityIndicator
              size="small"
              color={colors.primaryBlue}
              style={styles.featuredInlineLoader}
            />
          ) : null}
          <View style={styles.featuredGrid}>
            {featuredProducts.map((product, index) => {
              const productImage =
                normalizeImageUrl(product?.image) ||
                normalizeImageUrl(product?.product_images) ||
                normalizeImageUrl(product?.images);
              const displayUnit = resolveFeaturedUnitLabel(product);
              const productPrice = formatCurrencyValue(resolveDisplayPriceWithGst(product));

              return (
                <TouchableOpacity
                  key={`${String(product?.id ?? product?._id ?? 'featured-product')}-${index}`}
                  activeOpacity={0.88}
                  style={styles.featuredCardWrap}
                  onPress={() =>
                    navigate('ProductCategories', {
                      categoryId: product?.categoryId || product?.category_id,
                      categoryName:
                        product?.categoryName || product?.category_name,
                      productId: product?.id || product?._id,
                      preferredVendorId:
                        product?.vendorId || product?.vendor_id,
                    })
                  }
                >
                  <View style={styles.featuredCard}>
                    {productImage ? (
                      <View style={styles.featuredImageContainer}>
                        <Image
                          source={{ uri: productImage }}
                          style={styles.featuredImage}
                          resizeMode="contain"
                        />
                      </View>
                    ) : (
                      <View style={styles.featuredPlaceholder}>
                        <CustomText
                          fontFamily={Fonts.Medium}
                          fontSize={10}
                          style={styles.featuredPlaceholderText}
                        >
                          {product?.name?.charAt(0)?.toUpperCase() || 'P'}
                        </CustomText>
                      </View>
                    )}
                    <View style={styles.featuredCopy}>
                      <CustomText
                        fontFamily={Fonts.Medium}
                        numberOfLines={2}
                        style={styles.featuredCardText}
                      >
                        {product?.name || 'Product'}
                      </CustomText>
                      <View style={styles.featuredMeta}>
                        <CustomText
                          fontFamily={Fonts.Regular}
                          numberOfLines={1}
                          style={[
                            styles.featuredUnit,
                            !displayUnit ? styles.featuredUnitHidden : null,
                          ]}
                        >
                          {displayUnit || ' '}
                        </CustomText>
                        <CustomText
                          fontFamily={Fonts.Bold}
                          numberOfLines={1}
                          style={styles.featuredPrice}
                        >
                          {productPrice ? `\u20B9${productPrice}` : 'View'}
                        </CustomText>
                      </View>
                    </View>
                  </View>
                </TouchableOpacity>
              );
            })}
          </View>
          {!featuredProducts.length ? (
            <CustomText fontFamily={Fonts.Medium} style={styles.featuredEmptyText}>
              Featured products are loading.
            </CustomText>
          ) : null}
        </>
      )}

      <View style={styles.categoryHeadingRow}>
        <CustomText
          fontFamily={Fonts.Bold}
          fontSize={15}
          style={styles.categoryHeading}
        >
          Categories
        </CustomText>
      </View>

      {loading ? (
        <ActivityIndicator
          size="small"
          color={colors.primaryBlue}
          style={styles.loader}
        />
      ) : (
        <CategoryContainer data={categories} />
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 20,
    paddingTop: 10,
    paddingBottom: 6,
  },
  featuredHeader: {
    marginTop: 4,
    marginBottom: 8,
  },
  featuredTitle: {
    color: colors.primaryBlue,
    fontWeight: '700',
  },
  featuredLoader: {
    marginTop: 20,
    marginBottom: 12,
  },
  featuredInlineLoader: {
    marginBottom: 8,
  },
  featuredGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    alignItems: 'stretch',
    marginBottom: 8,
  },
  featuredEmptyText: {
    color: colors.greyText,
    textAlign: 'center',
    marginTop: 6,
    marginBottom: 10,
  },
  featuredCardWrap: {
    width: '22.8%',
    marginBottom: 10,
  },
  featuredCard: {
    flex: 1,
    backgroundColor: colors.white,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
    paddingVertical: 6,
    paddingHorizontal: 6,
    alignItems: 'center',
    justifyContent: 'flex-start',
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 3,
    elevation: 3,
    minHeight: 126,
  },
  featuredImageContainer: {
    width: '100%',
    height: 56,
    marginBottom: 6,
    borderRadius: 7,
    overflow: 'hidden',
    backgroundColor: colors.primaryBlueOpacity10,
  },
  featuredImage: {
    width: '100%',
    height: '100%',
  },
  featuredPlaceholder: {
    width: '100%',
    height: 56,
    marginBottom: 6,
    borderRadius: 7,
    backgroundColor: colors.primaryBlueOpacity10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  featuredPlaceholderText: {
    color: colors.primaryBlue,
    fontSize: 24,
  },
  featuredCardText: {
    textAlign: 'center',
    color: colors.primaryBlue,
    fontSize: 10,
    minHeight: 26,
    lineHeight: 13,
  },
  featuredCopy: {
    flex: 1,
    width: '100%',
    justifyContent: 'space-between',
  },
  featuredMeta: {
    marginTop: 4,
    alignItems: 'center',
    justifyContent: 'flex-end',
    minHeight: 28,
    width: '100%',
  },
  featuredPrice: {
    marginTop: 2,
    color: colors.greyText,
    fontSize: 10,
    textAlign: 'center',
  },
  featuredUnit: {
    color: colors.greyText,
    fontSize: 9,
    textAlign: 'center',
    minHeight: 11,
  },
  featuredUnitHidden: {
    opacity: 0,
  },
  categoryHeadingRow: {
    marginTop: 8,
    marginBottom: 4,
  },
  categoryHeading: {
    color: colors.primaryBlue,
    fontWeight: '700',
  },
  loader: {
    marginTop: 28,
    marginBottom: 16,
  },
});
export default Content;
