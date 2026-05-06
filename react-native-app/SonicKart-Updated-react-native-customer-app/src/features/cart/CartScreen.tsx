import React, { FC, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Image,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  View,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import CustomHeader from '@components/ui/CustomHeader';
import CustomText from '@components/ui/CustomText';
import BottomTabBar from '@components/ui/BottomTabBar';
import CartItemRow from '@features/order/OrderItem';
import CustomButton from '@components/ui/CustomButton';
import { useCartStore } from '@state/cartStore';
import { Fonts } from '@utils/Constants';
import { navigate } from '@utils/NavigationUtils';
import colors from '../../theme/colors';
import ActionOptionsModal from '@components/ui/ActionOptionsModal';
import { formatCurrencyValue } from '@utils/productPricing';

const PRIMARY_ACTION_COLOR = '#092774';

/**
 * Full cart screen.
 * Syncs cart from backend, shows bill preview, and routes user to checkout.
 */
const CartScreen: FC = () => {
  const cart = useCartStore((state) => state.cart);
  const clearCart = useCartStore((state) => state.clearCart);
  const getTotalPrice = useCartStore((state) => state.getTotalPrice);
  const fetchCartFromServer = useCartStore((state) => state.fetchCartFromServer);
  const insets = useSafeAreaInsets();
  const [clearing, setClearing] = useState(false);
  const [syncingCart, setSyncingCart] = useState(false);
  const [clearModalVisible, setClearModalVisible] = useState(false);

  useEffect(() => {
    let isMounted = true;
    const syncCart = async () => {
      setSyncingCart(true);
      try {
        await fetchCartFromServer();
      } catch (error) {
        console.log('Failed to sync cart', error);
      } finally {
        if (isMounted) {
          setSyncingCart(false);
        }
      }
    };
    syncCart();
    return () => {
      isMounted = false;
    };
  }, [fetchCartFromServer]);

  const totalItems = useMemo(
    () => cart?.reduce((acc, current) => acc + (current?.count || 0), 0),
    [cart]
  );

  const subtotal = getTotalPrice();
  const grandTotal = subtotal;

  const handleCheckout = () => {
    if (!cart.length) {
      Alert.alert('Your cart is empty', 'Add some items before checkout.');
      return;
    }
    navigate('ProductOrder', { fromScreen: 'cart' });
  };

  const confirmClearCart = async () => {
    if (clearing) {
      return;
    }
    setClearModalVisible(false);
    setClearing(true);
    try {
      await clearCart();
    } finally {
      setClearing(false);
    }
  };

  const handleClearCart = () => {
    if (!cart.length || clearing) {
      return;
    }
    setClearModalVisible(true);
  };

  const renderEmptyState = () => (
    <View style={styles.emptyContainer}>
      <Image
        source={require('@assets/images/sonickart1.jpg')}
        style={styles.emptyImage}
        resizeMode="contain"
      />
      <CustomText
        variant="body"
        fontFamily={Fonts.Bold}
        style={styles.emptyTitle}
      >
        Your cart is waiting
      </CustomText>
      <CustomText
        variant="body"
        style={styles.emptySubtitle}
      >
        Browse categories and add your favorites to get started.
      </CustomText>
      <TouchableOpacity
        style={styles.exploreButton}
        onPress={() => navigate('ProductCategories')}
        activeOpacity={0.8}
      >
        <CustomText
          variant="body"
          fontFamily={Fonts.Bold}
          style={styles.exploreText}
        >
          Explore Categories
        </CustomText>
      </TouchableOpacity>
    </View>
  );

  return (
    <SafeAreaView style={styles.safeArea} edges={['top']}>
      <View style={styles.container}>
        <CustomHeader title="Cart" />
        {cart.length === 0 ? (
          renderEmptyState()
        ) : (
          <ScrollView
            contentContainerStyle={[
              styles.scrollContent,
              { paddingBottom: insets.bottom + 110 },
            ]}
            showsVerticalScrollIndicator={false}
          >
            <View style={styles.summaryCard}>
              <View style={styles.summaryTopRow}>
                <View style={styles.summaryCopy}>
                  <CustomText
                    variant="h7"
                    fontFamily={Fonts.Bold}
                    style={styles.summaryTitle}
                  >
                    Ready to checkout
                  </CustomText>
                  <CustomText
                    variant="body"
                    fontFamily={Fonts.Medium}
                    style={styles.summaryCaption}
                  >
                    {totalItems} {totalItems === 1 ? 'item' : 'items'} packed in your cart.
                  </CustomText>
                </View>
              </View>

              <View style={styles.summaryMetaRow}>
                <View style={styles.summaryMetaChip}>
                  <CustomText
                    variant="h9"
                    fontFamily={Fonts.Medium}
                    style={styles.summaryMetaText}
                  >
                    {syncingCart ? 'Refreshing cart...' : 'Speed you want, care you trust'}
                  </CustomText>
                </View>
              </View>
            </View>

            <View style={styles.itemsCard}>
              <View style={styles.itemsHeader}>
                <CustomText
                  variant="h8"
                  fontFamily={Fonts.Bold}
                  style={styles.itemsHeaderTitle}
                >
                  Cart items
                </CustomText>
                <CustomText
                  variant="h9"
                  fontFamily={Fonts.Medium}
                  style={styles.itemsHeaderCount}
                >
                  {totalItems} selected
                </CustomText>
              </View>
              {cart.map((cartItem) => {
                const key = cartItem?.item?.id || cartItem?.item?._id;
                return <CartItemRow key={key} item={cartItem} />;
              })}
            </View>

            <View style={styles.totalCard}>
              <CustomText
                variant="h8"
                fontFamily={Fonts.Bold}
                style={styles.billTitle}
              >
                Price details
              </CustomText>

              <View style={styles.rowBetween}>
                <CustomText
                  variant="body"
                  fontFamily={Fonts.Medium}
                  style={styles.rowLabel}
                >
                  Subtotal
                </CustomText>
                <CustomText
                  variant="body"
                  fontFamily={Fonts.Bold}
                  style={styles.rowValue}
                >
                  ₹{formatCurrencyValue(subtotal)}
                </CustomText>
              </View>

              <View style={[styles.rowBetween, styles.grandTotalRow]}>
                <CustomText
                  variant="body"
                  fontFamily={Fonts.Bold}
                  style={styles.totalLabel}
                >
                  Total
                </CustomText>
                <CustomText
                  variant="body"
                  fontFamily={Fonts.Bold}
                  style={styles.totalValue}
                >
                  ₹{formatCurrencyValue(grandTotal)}
                </CustomText>
              </View>
            </View>

            <View style={styles.actionsWrap}>
              <TouchableOpacity
                style={[
                  styles.clearButton,
                  (!cart.length || clearing) && styles.clearButtonDisabled,
                ]}
                onPress={handleClearCart}
                disabled={!cart.length || clearing}
              >
                <CustomText
                  variant="body"
                  fontFamily={Fonts.Bold}
                  style={[
                    styles.clearText,
                    (!cart.length || clearing) ? styles.clearTextDisabled : null,
                  ]}
                >
                  Remove all items
                </CustomText>
              </TouchableOpacity>

              <CustomButton
                onPress={handleCheckout}
                title="Go to Checkout"
                disabled={!cart.length}
                loading={false}
                style={styles.checkoutButton}
              />
            </View>
          </ScrollView>
        )}
        <ActionOptionsModal
          visible={clearModalVisible}
          onClose={() => setClearModalVisible(false)}
          title="Remove all items?"
          message="This action clears your entire cart. You can't undo it."
          options={[
            { label: 'Cancel', type: 'secondary', onPress: () => {} },
            {
              label: clearing ? 'Removing...' : 'Remove everything',
              type: 'primary',
              onPress: confirmClearCart,
            },
          ]}
        />
        <BottomTabBar />
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#F5F8FF',
  },
  container: {
    flex: 1,
    backgroundColor: '#F5F8FF',
  },
  scrollContent: {
    paddingTop: 16,
  },
  summaryCard: {
    marginHorizontal: 16,
    marginBottom: 16,
    alignItems: 'center',
  },
  summaryTopRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'center',
  },
  summaryCopy: {
    flex: 1,
    alignItems: 'center',
  },
  summaryTitle: {
    color: colors.primaryBlue,
    fontSize: 20,
    textAlign: 'center',
  },
  summaryCaption: {
    marginTop: 4,
    color: colors.greyText,
    fontSize: 14,
    textAlign: 'center',
  },
  summaryMetaRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    marginTop: 10,
    justifyContent: 'center',
  },
  summaryMetaChip: {
    backgroundColor: 'transparent',
    borderRadius: 999,
    paddingHorizontal: 0,
    paddingVertical: 0,
  },
  summaryMetaText: {
    color: colors.primaryBlue,
    textAlign: 'center',
    fontSize: 13,
  },
  itemsCard: {
    backgroundColor: colors.white,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: colors.blackOpacity05,
    overflow: 'hidden',
    marginHorizontal: 16,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  itemsHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 14,
    paddingTop: 14,
    paddingBottom: 6,
    backgroundColor: '#FAFBFF',
  },
  itemsHeaderTitle: {
    color: colors.primaryBlue,
  },
  itemsHeaderCount: {
    color: colors.greyText,
  },
  totalCard: {
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.blackOpacity05,
    borderRadius: 18,
    padding: 16,
    marginHorizontal: 16,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  billTitle: {
    color: colors.primaryBlue,
    marginBottom: 14,
  },
  rowBetween: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  rowLabel: {
    color: colors.primaryBlue,
  },
  rowValue: {
    color: colors.primaryBlue,
  },
  grandTotalRow: {
    borderTopWidth: 1,
    borderTopColor: colors.blackOpacity05,
    paddingTop: 12,
    marginTop: 12,
  },
  totalLabel: {
    fontWeight: '700',
    color: colors.primaryBlue,
  },
  totalValue: {
    fontWeight: '700',
    color: colors.primaryBlue,
  },
  actionsWrap: {
    paddingHorizontal: 16,
  },
  clearButton: {
    alignItems: 'center',
    padding: 12,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: PRIMARY_ACTION_COLOR,
    backgroundColor: '#DCE5FF',
    marginBottom: 16,
  },
  clearButtonDisabled: {
    backgroundColor: colors.blackOpacity05,
    borderColor: colors.blackOpacity05,
  },
  clearText: {
    color: PRIMARY_ACTION_COLOR,
  },
  clearTextDisabled: {
    color: colors.primaryBlue,
    opacity: 0.6,
  },
  checkoutButton: {
    borderRadius: 14,
    marginHorizontal: 0,
    marginTop: 0,
  },
  emptyContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 32,
    backgroundColor: '#F5F8FF',
  },
  emptyTitle: {
    textAlign: 'center',
    marginTop: 16,
    marginBottom: 8,
    color: colors.primaryBlue,
  },
  emptyImage: {
    width: 140,
    height: 140,
    opacity: 0.8,
  },
  emptySubtitle: {
    textAlign: 'center',
    opacity: 0.6,
    lineHeight: 20,
  },
  exploreButton: {
    marginTop: 20,
    paddingHorizontal: 22,
    paddingVertical: 13,
    borderRadius: 999,
    backgroundColor: colors.primaryBlue,
  },
  exploreText: {
    color: colors.white,
  },
});

export default CartScreen;
