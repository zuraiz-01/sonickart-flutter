import { View, StyleSheet, Image, TouchableOpacity } from 'react-native';
import React, { FC, useMemo, useState } from 'react';
import { Colors, Fonts } from '@utils/Constants';
import CustomText from '@components/ui/CustomText';
import { useCartStore } from '@state/cartStore';
import colors from '../../theme/colors';
import { normalizeImageUrl } from '@utils/imageUtils';
import {
  formatCurrencyValue,
  resolveDisplayPriceWithGst,
} from '@utils/productPricing';

interface OrderItemProps {
  item: any;
  onCartEmpty?: () => void;
}

const OrderItem: FC<OrderItemProps> = ({ item, onCartEmpty }) => {
  const [imageError, setImageError] = useState(false);
  const imageUrl = normalizeImageUrl(item?.item?.image);
  const addItem = useCartStore((state) => state.addItem);
  const removeItem = useCartStore((state) => state.removeItem);
  const cart = useCartStore((state) => state.cart);

  const unitPrice = useMemo(() => resolveDisplayPriceWithGst(item), [item]);

  const handleIncrement = async () => {
    await addItem(item.item);
  };

  const handleDecrement = async () => {
    const productId = item?._id || item?.item?.id || item?.item?._id;
    if (!productId) {
      return;
    }
    await removeItem(productId);

    const currentItemCount = item?.count || 0;
    if (currentItemCount <= 1 && cart.length <= 1) {
      onCartEmpty?.();
    }
  };

  return (
    <View style={styles.flexRow}>
      <View style={styles.imgContainer}>
        {imageUrl && !imageError ? (
          <Image
            source={{ uri: imageUrl }}
            style={styles.img}
            onError={() => setImageError(true)}
            resizeMode="contain"
          />
        ) : (
          <View style={styles.placeholder}>
            <CustomText fontSize={8} style={styles.placeholderText}>
              {imageError ? '!' : '?'}
            </CustomText>
          </View>
        )}
      </View>

      <View style={styles.infoBlock}>
        <CustomText
          numberOfLines={2}
          variant="h7"
          fontFamily={Fonts.Medium}
          style={styles.itemName}
        >
          {item.item.name}
        </CustomText>
        {unitPrice > 0 ? (
          <CustomText variant="h8" style={styles.itemPrice}>
            ₹{formatCurrencyValue(unitPrice)}
          </CustomText>
        ) : null}
      </View>

      <View style={styles.controlsContainer}>
        <TouchableOpacity
          style={styles.controlButton}
          onPress={handleDecrement}
          accessibilityRole="button"
          accessibilityLabel={`Decrease ${item?.item?.name}`}
        >
          <CustomText fontFamily={Fonts.Bold} style={styles.controlText}>
            -
          </CustomText>
        </TouchableOpacity>
        <CustomText fontFamily={Fonts.Bold} style={styles.countText}>
          {item.count}
        </CustomText>
        <TouchableOpacity
          style={styles.controlButton}
          onPress={handleIncrement}
          accessibilityRole="button"
          accessibilityLabel={`Increase ${item?.item?.name}`}
        >
          <CustomText fontFamily={Fonts.Bold} style={styles.controlText}>
            +
          </CustomText>
        </TouchableOpacity>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  img: {
    width: 46,
    height: 46,
  },
  imgContainer: {
    backgroundColor: '#F3F7FF',
    width: 70,
    height: 70,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
  },
  placeholder: {
    width: 46,
    height: 46,
    justifyContent: 'center',
    alignItems: 'center',
  },
  placeholderText: {
    color: Colors.disabled,
  },
  flexRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 14,
    paddingHorizontal: 14,
    paddingVertical: 16,
    backgroundColor: colors.white,
  },
  infoBlock: {
    flex: 1,
    minWidth: 0,
  },
  itemName: {
    fontSize: 15,
    color: colors.primaryBlue,
  },
  itemPrice: {
    opacity: 0.75,
    marginTop: 4,
    fontSize: 13.5,
    color: colors.greyText,
  },
  controlsContainer: {
    minWidth: 104,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-end',
    gap: 6,
    backgroundColor: '#F8FAFF',
    paddingHorizontal: 8,
    paddingVertical: 6,
    borderRadius: 999,
  },
  controlButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: colors.primaryBlue,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.white,
  },
  controlText: {
    color: colors.primaryBlue,
    fontSize: 19,
  },
  countText: {
    minWidth: 20,
    textAlign: 'center',
    color: colors.primaryBlue,
    fontSize: 16,
  },
});

export default OrderItem;
