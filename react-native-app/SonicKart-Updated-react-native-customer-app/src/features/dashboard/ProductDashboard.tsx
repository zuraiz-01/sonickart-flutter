import {
  Platform,
  StyleSheet,
  TouchableOpacity,
  View,
} from 'react-native';
import React, { FC, useCallback, useMemo, useRef } from 'react';
import { useFocusEffect } from '@react-navigation/native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { screenHeight } from '@utils/Scaling';
import Visuals from './Visuals';
import {
  CollapsibleContainer,
  CollapsibleHeaderContainer,
  CollapsibleScrollView,
  useCollapsibleContext,
  withCollapsibleContext,
} from '@r0b0t3d/react-native-collapsible';
import AnimatedHeader from './AnimatedHeader';
import StickSearchBar from './StickSearchBar';
import Content from '@components/dashboard/Content';
import CustomText from '@components/ui/CustomText';
import { RFValue } from 'react-native-responsive-fontsize';
import { Fonts } from '@utils/Constants';
import Animated, {
  useAnimatedStyle,
  withTiming,
} from 'react-native-reanimated';
import Icon from 'react-native-vector-icons/Ionicons';
import withCart from '@features/cart/WithCart';
import withLiveStatus from '@features/map/withLiveStatus';
import { fetchCustomerOrders, getOrderById } from '@service/orderService';
import { useAuthStore } from '@state/authStore';
import { useCartStore } from '@state/cartStore';
import { navigate } from '@utils/NavigationUtils';
import { resolveOrderItemCount } from '@utils/orderItems';
import colors from '../../theme/colors';
import BottomTabBar from '@components/ui/BottomTabBar';

const resolveOrderStatus = (order: any) =>
  String(order?.deliveryStatus ?? order?.delivery_status ?? order?.status ?? '')
    .trim()
    .toLowerCase();

const isProductOrder = (order: any) =>
  Boolean(order) && order?.orderType !== 'package' && !order?.packageType;

const isInactiveOrderStatus = (status: string) =>
  status === 'delivered' || status === 'completed' || status === 'cancelled';

const CART_SUMMARY_BOTTOM_OFFSET = 120;
const ACTIVE_ORDER_BOTTOM_OFFSET = Platform.OS === 'ios' ? 112 : 104;
const CART_SUMMARY_ESTIMATED_HEIGHT = 62;
const ACTIVE_ORDER_GAP_ABOVE_CART = 16;

const resolveOrderIdentifiers = (order: any) => {
  const candidates = [
    order?.id,
    order?._id,
    order?.orderId,
    order?.orderNumber,
  ]
    .map((value) => (value === null || value === undefined ? '' : String(value).trim()))
    .filter(Boolean);

  return [...new Set(candidates)];
};

const getActiveOrderCopy = (status: string) => {
  if (status === 'pending') {
    return {
      title: 'Preparing your order',
      subtitle: 'We are getting everything ready.',
    };
  }

  if (status === 'confirmed' || status === 'accepted' || status === 'assigned') {
    return {
      title: 'Your order is confirmed',
      subtitle: 'Tap to open live tracking.',
    };
  }

  if (status === 'picked' || status === 'arriving' || status === 'out_for_delivery') {
    return {
      title: 'Your order is on the way',
      subtitle: 'Tap to track the delivery live.',
    };
  }

  return {
    title: 'Your order is active',
    subtitle: 'Tap to view the latest status.',
  };
};

/**
 * Customer home dashboard with collapsible header and product-category entry points.
 */
const ProductDashboard: FC = () => {
  const { scrollY, expand } = useCollapsibleContext();
  const insets = useSafeAreaInsets();
  const { currentOrder, setCurrentOrder, user } = useAuthStore();
  const cartCount = useCartStore((state) =>
    state.cart.reduce((total, cartItem) => total + (cartItem?.count || 0), 0)
  );
  const previousScroll = useRef<number>(0);

  const backToTopStyle = useAnimatedStyle(() => {
    const isScrollingUp =
      scrollY.value < previousScroll.current && scrollY.value > 150;
    const opacity = withTiming(isScrollingUp ? 1 : 0, { duration: 300 });
    const translateY = withTiming(isScrollingUp ? 0 : 10, { duration: 300 });

    previousScroll.current = scrollY.value;

    return {
      opacity,
      transform: [{ translateY }],
    };
  });

  const activeProductOrder = useMemo(() => {
    if (!isProductOrder(currentOrder)) {
      return null;
    }

    const status = resolveOrderStatus(currentOrder);
    return isInactiveOrderStatus(status) ? null : currentOrder;
  }, [currentOrder]);

  const activeOrderItemCount = useMemo(() => {
    return resolveOrderItemCount(activeProductOrder);
  }, [activeProductOrder]);

  const activeOrderCopy = useMemo(
    () => getActiveOrderCopy(resolveOrderStatus(activeProductOrder)),
    [activeProductOrder]
  );

  const syncActiveProductOrder = useCallback(async () => {
    const userId = user?.id || user?._id;
    if (!userId) {
      return;
    }

    try {
      const orders = await fetchCustomerOrders(String(userId));
      if (!Array.isArray(orders)) {
        return;
      }

      const latestActiveProductOrder = [...orders]
        .filter(isProductOrder)
        .sort((left: any, right: any) => {
          const leftTime = new Date(left?.createdAt || 0).getTime();
          const rightTime = new Date(right?.createdAt || 0).getTime();
          return rightTime - leftTime;
        })
        .find((order: any) => !isInactiveOrderStatus(resolveOrderStatus(order)));

      if (latestActiveProductOrder) {
        let resolvedActiveOrder = latestActiveProductOrder;
        const activeOrderIds = resolveOrderIdentifiers(latestActiveProductOrder);

        if (activeOrderIds.length > 0 && resolveOrderItemCount(latestActiveProductOrder) === 0) {
          for (const activeOrderId of activeOrderIds) {
            const detailedOrder = await getOrderById(activeOrderId);
            if (detailedOrder) {
              resolvedActiveOrder = detailedOrder;
              break;
            }
          }
        }

        setCurrentOrder(resolvedActiveOrder);
        return;
      }

      if (isProductOrder(currentOrder)) {
        setCurrentOrder(null);
      }
    } catch (error) {
      console.log('ProductDashboard active order sync error', error);
    }
  }, [currentOrder, setCurrentOrder, user?._id, user?.id]);

  useFocusEffect(
    useCallback(() => {
      syncActiveProductOrder();
    }, [syncActiveProductOrder])
  );

  const handleOpenTracking = useCallback(() => {
    if (!activeProductOrder) {
      return;
    }

    setCurrentOrder(activeProductOrder);
    navigate('LiveTracking');
  }, [activeProductOrder, setCurrentOrder]);

  const activeOrderId =
    activeProductOrder?.orderId ||
    activeProductOrder?.id ||
    activeProductOrder?._id ||
    '--';
  const hasCartSummary = cartCount > 0;
  const activeOrderBottomOffset =
    insets.bottom + (hasCartSummary
      ? CART_SUMMARY_BOTTOM_OFFSET + CART_SUMMARY_ESTIMATED_HEIGHT + ACTIVE_ORDER_GAP_ABOVE_CART
      : ACTIVE_ORDER_BOTTOM_OFFSET);
  const contentBottomPadding = insets.bottom + (hasCartSummary || activeProductOrder ? 280 : 16);

  return (
    <SafeAreaView style={styles.safeArea} edges={['top']}>
      <Visuals />

      <Animated.View style={[styles.backToTopButton, backToTopStyle]}>
        <TouchableOpacity
          onPress={() => {
            scrollY.value = 0;
            expand();
          }}
          style={styles.backToTopContent}
        >
          <Icon
            name="arrow-up-circle-outline"
            color={colors.white}
            size={RFValue(16)}
          />
          <CustomText
            variant="h9"
            style={styles.backToTopText}
            fontFamily={Fonts.SemiBold}
          >
            Back to top
          </CustomText>
        </TouchableOpacity>
      </Animated.View>

      <CollapsibleContainer style={styles.panelContainer}>
        <CollapsibleHeaderContainer containerStyle={styles.transparent}>
          <AnimatedHeader />
          <StickSearchBar />
        </CollapsibleHeaderContainer>

        <CollapsibleScrollView
          nestedScrollEnabled
          style={styles.panelContainer}
          showsVerticalScrollIndicator={false}
          contentContainerStyle={{ paddingBottom: contentBottomPadding }}
        >
          <Content />

          <View style={styles.taglineContainer}>
            <CustomText
              fontSize={RFValue(16)}
              fontFamily={Fonts.Bold}
              style={styles.tagline}
            >
              Your City, Your Cart in Minutes ⚡
            </CustomText>
          </View>
        </CollapsibleScrollView>
      </CollapsibleContainer>
      {activeProductOrder ? (
        <View
          pointerEvents="box-none"
          style={[styles.activeOrderWrap, { bottom: activeOrderBottomOffset }]}
        >
          <TouchableOpacity
            activeOpacity={0.92}
            style={styles.activeOrderCard}
            onPress={handleOpenTracking}
          >
            <View style={styles.activeOrderIconWrap}>
              <Icon name="bag-handle-outline" size={RFValue(18)} color={colors.primaryBlue} />
            </View>
            <View style={styles.activeOrderCopyWrap}>
              <CustomText
                variant="h8"
                fontFamily={Fonts.Bold}
                style={styles.activeOrderTitle}
              >
                {activeOrderCopy.title}
              </CustomText>
              <CustomText
                variant="h9"
                fontFamily={Fonts.Medium}
                style={styles.activeOrderSubtitle}
              >
                {`#${activeOrderId} | ${activeOrderItemCount} item${activeOrderItemCount === 1 ? '' : 's'}`}
              </CustomText>
              <CustomText
                variant="h9"
                fontFamily={Fonts.Medium}
                style={styles.activeOrderHint}
              >
                {activeOrderCopy.subtitle}
              </CustomText>
            </View>
            <View style={styles.activeOrderCta}>
              <CustomText
                variant="h9"
                fontFamily={Fonts.Bold}
                style={styles.activeOrderCtaText}
              >
                Track
              </CustomText>
              <Icon name="chevron-forward" size={RFValue(16)} color={colors.primaryBlue} />
            </View>
          </TouchableOpacity>
        </View>
      ) : null}
      <BottomTabBar />
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#F3F7FF',
  },
  panelContainer: {
    flex: 1,
  },
  transparent: {
    backgroundColor: 'transparent',
  },
  backToTopButton: {
    position: 'absolute',
    alignSelf: 'center',
    top: Platform.OS === 'ios' ? screenHeight * 0.18 : 100,
    zIndex: 999,
  },
  backToTopContent: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.primaryBlue,
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 8,
    gap: 6,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.22,
    shadowRadius: 4,
    elevation: 6,
  },
  backToTopText: {
    color: colors.white,
  },
  taglineContainer: {
    alignItems: 'center',
    marginTop: 10,
    marginBottom: 6,
    paddingBottom: 0,
  },
  tagline: {
    textAlign: 'center',
    color: colors.primaryBlue,
    fontWeight: '700',
    backgroundColor: '#F3F7FF',
    paddingHorizontal: 18,
    paddingVertical: 12,
    borderRadius: 999,
    overflow: 'hidden',
  },
  activeOrderWrap: {
    position: 'absolute',
    left: 16,
    right: 16,
    zIndex: 998,
  },
  activeOrderCard: {
    backgroundColor: colors.white,
    borderRadius: 22,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
    paddingHorizontal: 14,
    paddingVertical: 14,
    flexDirection: 'row',
    alignItems: 'center',
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.1,
    shadowRadius: 14,
    elevation: 6,
  },
  activeOrderIconWrap: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#EEF4FF',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  activeOrderCopyWrap: {
    flex: 1,
  },
  activeOrderTitle: {
    color: colors.primaryBlue,
  },
  activeOrderSubtitle: {
    color: colors.primaryBlue,
    marginTop: 2,
  },
  activeOrderHint: {
    color: colors.greyText,
    marginTop: 4,
  },
  activeOrderCta: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
    marginLeft: 10,
  },
  activeOrderCtaText: {
    color: colors.primaryBlue,
  },
});

export default withLiveStatus(
  withCart(withCollapsibleContext(ProductDashboard))
);
