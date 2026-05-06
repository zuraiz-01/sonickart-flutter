import { View, StyleSheet, Image, TouchableOpacity, Modal, TouchableWithoutFeedback, ScrollView } from 'react-native';
import React, { FC, useMemo, useState } from 'react';
import { screenWidth } from '@utils/Scaling';
import { Colors, Fonts } from '@utils/Constants';
import CustomText from '@components/ui/CustomText';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { RFValue } from 'react-native-responsive-fontsize';
import { navigate } from '@utils/NavigationUtils';
import colors from '../../theme/colors';
import {
  formatCurrencyValue,
  resolveDisplayPriceWithGst,
} from '@utils/productPricing';

interface CartItem {
  _id: string | number;
  item: any;
  count: number;
}

interface CartSummaryProps {
  cartCount: number;
  cartImage: string | null;
  cartItems: CartItem[];
}

const CartSummary: FC<CartSummaryProps> = ({ cartCount, cartImage, cartItems = [] }) => {
  const [modalVisible, setModalVisible] = useState(false);

  const cartTotal = useMemo(
    () =>
      (cartItems || []).reduce((total, cartItem) => {
        const price = resolveDisplayPriceWithGst(cartItem?.item);
        return total + price * cartItem.count;
      }, 0),
    [cartItems]
  );

  const normalizedItems = useMemo(() => cartItems || [], [cartItems]);

  const handleCartPress = () => {
    navigate('CartScreen');
  };

  const handleCartLongPress = () => {
    setModalVisible(true);
  };

  return (
    <>
      <View style={styles.container}>
        <TouchableOpacity
          style={styles.flexRowGap}
          activeOpacity={0.7}
          onPress={handleCartPress}
          onLongPress={handleCartLongPress}
          delayLongPress={250}
          accessibilityRole="button"
          accessibilityLabel="View cart items"
          accessibilityHint="Double tap to open cart. Long press to preview items."
        >
          <Image
            source={
              cartImage === null
                ? require('@assets/icons/bucket.png')
                : { uri: cartImage }
            }
            style={styles.image}
          />
          <CustomText fontFamily={Fonts.SemiBold}>
            {cartCount} Item{cartCount > 1 ? 's' : ''}
          </CustomText>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.btn}
          activeOpacity={0.7}
          onPress={() => navigate('ProductOrder', { fromScreen: 'cart' })}
          accessibilityRole="button"
          accessibilityLabel={`Proceed to checkout with ${cartCount} item${cartCount > 1 ? 's' : ''}`}
          accessibilityHint="Double tap to proceed to checkout"
        >
          <CustomText style={styles.btnText} fontFamily={Fonts.Medium}>
            Next
          </CustomText>
          <Icon name="arrow-right" color={colors.white} size={RFValue(25)} />
        </TouchableOpacity>
      </View>

      <Modal
        transparent
        animationType="slide"
        visible={modalVisible}
        onRequestClose={() => setModalVisible(false)}
      >
        <View style={styles.modalRoot}>
          <TouchableWithoutFeedback onPress={() => setModalVisible(false)}>
            <View style={styles.modalOverlay} />
          </TouchableWithoutFeedback>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <CustomText fontFamily={Fonts.SemiBold} variant="h7">
                {cartCount} item{cartCount > 1 ? 's' : ''}
              </CustomText>
              <CustomText variant="h9" style={{ opacity: 0.7 }}>
                ₹{formatCurrencyValue(cartTotal)}
              </CustomText>
              <TouchableOpacity
                onPress={() => setModalVisible(false)}
                accessibilityRole="button"
                accessibilityLabel="Close cart items list"
                style={styles.closeBtn}
              >
                <Icon name="close" size={RFValue(20)} color={Colors.text} />
              </TouchableOpacity>
            </View>

            <ScrollView style={{ maxHeight: 320 }}>
              {normalizedItems.length === 0 ? (
                <CustomText
                  variant="h8"
                  style={{ textAlign: 'center', marginVertical: 20 }}
                >
                  Your cart is empty.
                </CustomText>
              ) : (
                normalizedItems.map((cartItem) => (
                  <View style={styles.cartItemRow} key={cartItem._id}>
                    <Image
                      source={
                        cartItem?.item?.image
                          ? { uri: cartItem.item.image }
                          : require('@assets/icons/bucket.png')
                      }
                      style={styles.cartItemImage}
                    />
                    <View style={{ flex: 1 }}>
                      <CustomText
                        variant="h8"
                        numberOfLines={2}
                        fontFamily={Fonts.Medium}
                      >
                        {cartItem?.item?.name || 'Unnamed product'}
                      </CustomText>
                      {!!cartItem?.item?.quantity && (
                        <CustomText variant="h9" style={{ opacity: 0.7 }}>
                          {cartItem.item.quantity}
                        </CustomText>
                      )}
                    </View>
                    <View style={{ alignItems: 'flex-end' }}>
                      <CustomText variant="h8" fontFamily={Fonts.SemiBold}>
                        ₹{formatCurrencyValue(resolveDisplayPriceWithGst(cartItem?.item))}
                      </CustomText>
                      <CustomText variant="h9" style={{ opacity: 0.7 }}>
                        x{cartItem.count}
                      </CustomText>
                    </View>
                  </View>
                ))
              )}
            </ScrollView>
          </View>
        </View>
      </Modal>
    </>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 6,
  },
  flexRowGap: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 10,
  },
  image: {
    width: 42,
    height: 42,
    borderRadius: 12,
    borderColor: Colors.border,
    borderWidth: 1,
  },
  btn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 8,
    paddingHorizontal: 30,
    borderRadius: 20,
    backgroundColor: Colors.secondary,
    minHeight: 40,
  },
  btnText: {
    marginLeft: screenWidth * 0.02,
    color: colors.white,
  },
  modalRoot: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  modalOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: colors.blackOpacity40,
  },
  modalContent: {
    backgroundColor: colors.white,
    padding: 16,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginBottom: 12,
  },
  closeBtn: {
    marginLeft: 'auto',
    minWidth: 32,
    minHeight: 32,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cartItemRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingVertical: 10,
    borderBottomWidth: 0.7,
    borderColor: Colors.border,
  },
  cartItemImage: {
    width: 44,
    height: 44,
    borderRadius: 12,
    borderWidth: 0.7,
    borderColor: Colors.border,
  },
});
export default CartSummary;
