import React, { useCallback, useMemo, useState } from 'react';
import {
  View,
  StyleSheet,
  ScrollView,
  Image,
  TouchableOpacity,
  useWindowDimensions,
  NativeSyntheticEvent,
  NativeScrollEvent,
  StatusBar,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { RFValue } from 'react-native-responsive-fontsize';
import CustomHeader from '@components/ui/CustomHeader';
import CustomText from '@components/ui/CustomText';
import { Colors, Fonts } from '@utils/Constants';
import colors from '../../theme/colors';
import { useRoute, RouteProp } from '@react-navigation/native';
import { useCartStore } from '@state/cartStore';
import { normalizeImageUrl } from '@utils/imageUtils';
import { navigate } from '@utils/NavigationUtils';
import {
  formatCurrencyValue,
  resolveDisplayMrpWithGst,
  resolveDisplayPriceWithGst,
} from '@utils/productPricing';

/**
 * Product detail page with image carousel and quick purchase actions.
 */
type ProductDetailRouteParams = {
  ProductDetail: {
    product: any;
  };
};

const ProductDetail = () => {
  const route = useRoute<RouteProp<ProductDetailRouteParams, 'ProductDetail'>>();
  const product = route?.params?.product;
  const addItem = useCartStore(state => state.addItem);
  const { width: screenWidth } = useWindowDimensions();
  const [activeSlide, setActiveSlide] = useState(0);
  const carouselWidth = Math.max(screenWidth - 32, 220);
  const insets = useSafeAreaInsets();

  const handleMomentumScrollEnd = useCallback(
    (event: NativeSyntheticEvent<NativeScrollEvent>) => {
      const { contentOffset, layoutMeasurement } = event.nativeEvent;
      if (!layoutMeasurement?.width) {
        return;
      }
      const nextIndex = Math.round(contentOffset.x / layoutMeasurement.width);
      setActiveSlide(nextIndex);
    },
    [],
  );

  const carouselImages = useMemo(() => {
    const gallery = Array.isArray(product?.images)
      ? product.images
          .map((img: unknown) => normalizeImageUrl(img))
          .filter(Boolean)
      : [];
    const mainImage = normalizeImageUrl(product?.image);

    if (mainImage && !gallery.includes(mainImage)) {
      return [mainImage, ...gallery];
    }

    if (gallery.length) {
      return gallery;
    }

    return mainImage ? [mainImage] : [];
  }, [product]);
  const displayPrice = useMemo(
    () => formatCurrencyValue(resolveDisplayPriceWithGst(product)),
    [product]
  );
  const displayMrp = useMemo(() => resolveDisplayMrpWithGst(product), [product]);

  const handleAddToCart = async () => {
    try {
      await addItem(product);
    } catch (error) {
      console.error('Failed to add product to cart:', error);
    }
  };

  const handleBuyNow = async () => {
    try {
      await addItem(product);
      navigate('ProductOrder', { fromScreen: 'direct' });
    } catch (error) {
      console.error('Failed to add product for buy now:', error);
    }
  };

  return (
    <SafeAreaView style={styles.safeArea} edges={['top']}>
      <StatusBar
        translucent={true}
        backgroundColor="transparent"
        barStyle="dark-content"
      />
      <View style={styles.container}>
        <CustomHeader
          title={product?.name || 'Product Detail'}
          fallbackRoute="ProductCategories"
        />

        <ScrollView
          contentContainerStyle={[
            styles.content,
            { paddingBottom: insets.bottom + 100 }, // Safe area + space for bottom buttons
          ]}
          showsVerticalScrollIndicator={false}
        >
          <View style={styles.imageWrapper}>
            {carouselImages.length ? (
              <>
                <ScrollView
                  horizontal
                  pagingEnabled
                  showsHorizontalScrollIndicator={false}
                  onMomentumScrollEnd={handleMomentumScrollEnd}
                  scrollEventThrottle={16}
                  contentContainerStyle={{ height: '100%' }}
                  style={{ width: carouselWidth, height: '100%' }}
                >
                  {carouselImages.map((imageUrl: string, index: number) => (
                    <View
                      key={`${imageUrl}-${index}`}
                      style={[styles.carouselSlide, { width: carouselWidth }]}
                    >
                      <Image
                        source={{ uri: imageUrl }}
                        style={[styles.image, { width: carouselWidth }]}
                        resizeMode="contain"
                      />
                    </View>
                  ))}
                </ScrollView>
                {carouselImages.length > 1 && (
                  <View style={styles.pagination}>
                    {carouselImages.map((_: string, index: number) => (
                      <View
                        key={`dot-${index}`}
                        style={[
                          styles.dot,
                          index === activeSlide && styles.activeDot,
                        ]}
                      />
                    ))}
                  </View>
                )}
              </>
            ) : (
              <View style={styles.imagePlaceholder}>
                <CustomText style={styles.placeholderText}>
                  No Image Available
                </CustomText>
              </View>
            )}
          </View>

          <View style={styles.details}>
            <CustomText
              fontFamily={Fonts.Bold}
              fontSize={18}
              style={styles.productName}
            >
              {product?.name || 'Unnamed Product'}
            </CustomText>

            <View style={styles.descriptionSection}>
              <CustomText
                fontFamily={Fonts.SemiBold}
                style={styles.sectionTitle}
              >
                Description
              </CustomText>
              <CustomText style={styles.description} variant="body">
                {product?.description?.trim() ||
                  'No description available for this product.'}
              </CustomText>
            </View>

            <View style={styles.priceSection}>
              <CustomText
                fontFamily={Fonts.Bold}
                fontSize={20}
                style={styles.price}
              >
                ₹{displayPrice || '--'}
              </CustomText>
              {displayMrp && (
                <CustomText style={styles.discountPrice}>
                  ₹{formatCurrencyValue(displayMrp)}
                </CustomText>
              )}
            </View>
          </View>
        </ScrollView>

        {/* Fixed Bottom CTA Container with proper SafeArea */}
        <View style={[styles.bottomSafeArea, { paddingBottom: insets.bottom }]}>
          <View style={styles.ctaContainer}>
            <TouchableOpacity
              style={[styles.ctaButton, styles.secondaryButton]}
              activeOpacity={0.85}
              onPress={handleAddToCart}
              hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
            >
              <CustomText
                fontFamily={Fonts.SemiBold}
                style={styles.secondaryButtonText}
              >
                Add to Cart
              </CustomText>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.ctaButton, styles.primaryButton]}
              activeOpacity={0.85}
              onPress={handleBuyNow}
              hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
            >
              <CustomText
                fontFamily={Fonts.SemiBold}
                style={styles.primaryText}
              >
                Buy Now
              </CustomText>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: colors.white,
  },
  container: {
    flex: 1,
    backgroundColor: colors.white,
  },
  content: {
    padding: 16,
    flexGrow: 1,
  },
  imageWrapper: {
    height: 280,
    borderRadius: 16,
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: Colors.backgroundSecondary,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 20,
  },
  image: {
    width: '100%',
    height: '100%',
  },
  carouselSlide: {
    height: '100%',
    justifyContent: 'center',
    alignItems: 'center',
  },
  pagination: {
    position: 'absolute',
    bottom: 12,
    left: 0,
    right: 0,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginHorizontal: 4,
    backgroundColor: Colors.border,
    opacity: 0.6,
  },
  activeDot: {
    backgroundColor: Colors.secondary,
    opacity: 1,
  },
  imagePlaceholder: {
    width: '100%',
    height: '100%',
    justifyContent: 'center',
    alignItems: 'center',
  },
  placeholderText: {
    color: Colors.text,
    fontSize: RFValue(14),
  },
  details: {
    gap: 16,
  },
  descriptionSection: {
    gap: 8,
  },
  sectionTitle: {
    color: colors.black,
  },
  productName: {
    color: colors.black,
  },
  description: {
    color: Colors.text,
    lineHeight: 20,
  },
  priceSection: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  price: {
    color: colors.darkBlue,
  },
  discountPrice: {
    textDecorationLine: 'line-through',
    color: Colors.text,
    opacity: 0.7,
  },
  bottomSafeArea: {
    backgroundColor: colors.white,
    borderTopWidth: 1,
    borderTopColor: Colors.border,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: -2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 8,
  },
  ctaContainer: {
    flexDirection: 'row',
    gap: 12,
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 8,
    backgroundColor: colors.white,
  },
  ctaButton: {
    flex: 1,
    height: 48,
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 16,
  },
  secondaryButton: {
    borderWidth: 1.5,
    borderColor: Colors.secondary,
    backgroundColor: 'transparent',
  },
  secondaryButtonText: {
    color: Colors.secondary,
    fontSize: RFValue(14),
  },
  primaryButton: {
    backgroundColor: Colors.secondary,
    shadowColor: Colors.secondary,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.2,
    shadowRadius: 4,
    elevation: 3,
  },
  primaryText: {
    color: colors.white,
    fontSize: RFValue(14),
  },
});

export default ProductDetail;
