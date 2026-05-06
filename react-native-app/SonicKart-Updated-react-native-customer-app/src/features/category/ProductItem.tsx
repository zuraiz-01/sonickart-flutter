import { View, StyleSheet, Image, TouchableOpacity } from 'react-native';
import React, { FC, useEffect, useMemo, useRef, useState } from 'react';
import { screenHeight } from '@utils/Scaling';
import CustomText from '@components/ui/CustomText';
import { RFValue } from 'react-native-responsive-fontsize';
import { Colors, Fonts } from '@utils/Constants';
import UniversalAdd from '@components/ui/UniversalAdd';
import { useCartStore } from '@state/cartStore';
import { navigate } from '@utils/NavigationUtils';
import colors from '../../theme/colors';
import ActionOptionsModal from '@components/ui/ActionOptionsModal';
import { normalizeImageUrl } from '@utils/imageUtils';
import { getProductUnit } from '@utils/productUnit';
import {
  formatCurrencyValue,
  resolveDisplayMrpWithGst,
  resolveDisplayPriceWithGst,
} from '@utils/productPricing';

/**
 * Category-grid product card.
 * Handles image fallback and add-to-cart / buy-now action choices.
 */
const ProductItem: FC<{ item: any; index: number }> = ({ item }) => {
  const [imageError, setImageError] = useState(false);
  const hasLoadedImageRef = useRef(false);
  const imageUrl =
    normalizeImageUrl(item?.image) ||
    normalizeImageUrl(item?.product_images) ||
    normalizeImageUrl(item?.images);
  const safeImageUrl = imageUrl ? imageUrl.replace(/\s/g, '%20') : null;
  const imageSource = useMemo(
    () => (safeImageUrl ? { uri: safeImageUrl, cache: 'force-cache' as const } : null),
    [safeImageUrl]
  );
  const displayUnit = useMemo(() => {
    const resolvedUnit = getProductUnit(item);
    return resolvedUnit === '1 pc' ? '' : resolvedUnit;
  }, [item]);
  const displayPrice = useMemo(() => {
    const inclusivePrice = resolveDisplayPriceWithGst(item);
    return inclusivePrice > 0 ? formatCurrencyValue(inclusivePrice) : '--';
  }, [item]);
  const displayMrp = useMemo(() => {
    const inclusiveMrp = resolveDisplayMrpWithGst(item);
    return inclusiveMrp ? formatCurrencyValue(inclusiveMrp) : null;
  }, [item]);
  const productDescription = useMemo(() => {
    const descriptionCandidate = [
      item?.description,
      item?.details,
      item?.subtitle,
      item?.short_description,
      item?.shortDescription,
      item?.product_description,
    ].find(
      (value): value is string => typeof value === 'string' && value.trim().length > 0
    );

    return descriptionCandidate?.replace(/\s+/g, ' ').trim() || '';
  }, [item]);
  const addItem = useCartStore((state) => state.addItem);
  const [optionsVisible, setOptionsVisible] = useState(false);

  useEffect(() => {
    setImageError(false);
    hasLoadedImageRef.current = false;
  }, [safeImageUrl, item?.id, item?.name]);

  const handleAddToCart = async () => {
    try {
      await addItem(item);
    } catch (error) {
      console.error('Failed to add item to cart:', error);
    }
  };

  const handleBuyNow = async () => {
    try {
      await addItem(item);
      navigate('ProductOrder', { fromScreen: 'direct' });
    } catch (error) {
      console.error('Failed to add item for buy now:', error);
    }
  };

  const handleAddOptions = () => {
    setOptionsVisible(true);
  };

  const closeOptions = () => setOptionsVisible(false);

  const handleNavigateToDetails = () => {
    navigate('ProductDetail', { product: item });
  };

  return (
    <>
      <TouchableOpacity
        activeOpacity={0.9}
        onPress={handleNavigateToDetails}
        style={styles.container}
      >
        <View style={styles.imageContainer}>
          {imageSource && !imageError ? (
            <Image
              key={safeImageUrl}
              source={imageSource}
              style={styles.image}
              fadeDuration={0}
              onLoad={() => {
                hasLoadedImageRef.current = true;
                setImageError(false);
              }}
              onError={() => {
                // Some Android builds emit a late image error after successful render.
                if (hasLoadedImageRef.current) {
                  return;
                }
                setImageError(true);
              }}
              resizeMode="contain"
            />
          ) : (
            <View style={styles.placeholder}>
              <CustomText fontSize={RFValue(9)} style={styles.placeholderText}>
                {item?.name?.charAt(0)?.toUpperCase() || 'P'}
              </CustomText>
            </View>
          )}
        </View>
        <View style={styles.content}>
          {/* <View style={styles.flexRow}>
          <Image
            source={require('@assets/icons/clock.png')}
            style={styles.clockIcon}
          />
          <CustomText fontSize={RFValue(6)} fontFamily={Fonts.Medium}>
            8 MINS
          </CustomText>
        </View> */}

          <CustomText
            fontFamily={Fonts.Medium}
            fontSize={12}
            numberOfLines={2}
            style={styles.nameText}
          >
            {item.name}
          </CustomText>

          <View style={styles.bottomSection}>
            <View style={styles.descriptionSlot}>
              <CustomText
                fontFamily={Fonts.Regular}
                numberOfLines={2}
                style={[
                  styles.descriptionText,
                  !productDescription && styles.descriptionPlaceholder,
                ]}
              >
                {productDescription || ' '}
              </CustomText>
            </View>

            <View style={styles.priceContainer}>
              <View style={styles.priceInfoRow}>
                <CustomText
                  variant="h8"
                  fontFamily={Fonts.Medium}
                  numberOfLines={1}
                  style={styles.priceText}
                >
                  {`\u20B9${displayPrice}`}
                </CustomText>
                <View style={styles.metaRow}>
                  <CustomText
                    fontFamily={Fonts.Regular}
                    variant="h8"
                    numberOfLines={1}
                    style={[
                      styles.unitMetaText,
                      !displayUnit && styles.unitMetaHidden,
                    ]}
                  >
                    {displayUnit || ' '}
                  </CustomText>
                  {displayMrp && (
                    <CustomText
                      fontFamily={Fonts.Medium}
                      variant="h8"
                      style={styles.mrpText}
                      numberOfLines={1}
                    >
                      {`\u20B9${displayMrp}`}
                    </CustomText>
                  )}
                </View>
              </View>
              <View style={styles.addButtonWrap}>
                <UniversalAdd
                  item={item}
                  onInitialAdd={handleAddOptions}
                />
              </View>
            </View>
          </View>
        </View>
      </TouchableOpacity>
      <ActionOptionsModal
        visible={optionsVisible}
        onClose={closeOptions}
        title="Choose An Option"
        message={`How would you like to proceed with ${item?.name || 'this item'}?`}
        options={[
          {
            label: 'Add to Cart',
            type: 'primary',
            onPress: async () => {
              closeOptions();
              await handleAddToCart();
            },
          },
          {
            label: 'Buy Now',
            type: 'secondary',
            onPress: async () => {
              closeOptions();
              await handleBuyNow();
            },
          },
          { label: 'Cancel', type: 'ghost' },
        ]}
      />
    </>
  );
};

const styles = StyleSheet.create({
  container: {
    width: '48%',
    borderRadius: 10,
    backgroundColor: colors.white,
    marginBottom: 10,
    overflow: 'visible',
    padding: 8,
    shadowColor: colors.black,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 3,
    elevation: 3,
  },
  imageContainer: {
    height: screenHeight * 0.14,
    width: '100%',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 8,
  },
  image: {
    height: '100%',
    width: '100%',
    aspectRatio: 1 / 1,
    resizeMode: 'contain',
  },
  placeholder: {
    height: '100%',
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.backgroundSecondary,
    borderRadius: 8,
  },
  placeholderText: {
    color: Colors.disabled,
    textAlign: 'center',
  },
  content: {
    flex: 1,
    paddingHorizontal: 0,
  },
  nameText: {
    marginTop: 4,
    marginBottom: 2,
    minHeight: 32,
    lineHeight: 16,
  },
  flexRow: {
    flexDirection: 'row',
    padding: 2,
    borderRadius: 4,
    alignItems: 'center',
    gap: 2,
    backgroundColor: Colors.backgroundSecondary,
    alignSelf: 'flex-start',
  },
  clockIcon: {
    height: 15,
    width: 15,
  },
  bottomSection: {
    marginTop: 'auto',
  },
  priceContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 6,
  },
  priceInfoRow: {
    flex: 1,
    minWidth: 0,
    paddingRight: 6,
  },
  priceText: {
    color: colors.primaryBlue,
  },
  metaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginTop: 1,
    flexWrap: 'nowrap',
    minHeight: 14,
  },
  unitMetaText: {
    color: colors.greyText || '#6B7280',
    flexShrink: 1,
  },
  unitMetaHidden: {
    opacity: 0,
  },
  mrpText: {
    opacity: 0.7,
    textDecorationLine: 'line-through',
    flexShrink: 1,
  },
  addButtonWrap: {
    alignSelf: 'flex-end',
    width: 52,
    flexShrink: 0,
  },
  descriptionSlot: {
    minHeight: 34,
    marginBottom: 2,
  },
  descriptionText: {
    color: colors.primaryBlue,
    fontSize: RFValue(9.5),
    lineHeight: 15,
  },
  descriptionPlaceholder: {
    opacity: 0,
  },
});

export default ProductItem;
