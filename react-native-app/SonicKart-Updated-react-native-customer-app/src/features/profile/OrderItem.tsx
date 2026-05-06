import { View, StyleSheet, TouchableOpacity } from 'react-native';
import React, { FC, useMemo } from 'react';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import CustomText from '@components/ui/CustomText';
import { Fonts } from '@utils/Constants';
import { formatISOToCustom } from '@utils/DateUtils';
import { navigate } from '@utils/NavigationUtils';
import { useAuthStore } from '@state/authStore';
import {
  resolveOrderItemCount,
  resolveOrderItemPreviewLines,
  resolveOrderItems,
} from '@utils/orderItems';
import colors from '../../theme/colors';

interface CartItem {
  _id: string | number;
  item: any;
  count: number;
}

interface Order {
  orderId?: string | number;
  id?: string | number;
  _id?: string | number;
  items?: CartItem[];
  orderItems?: CartItem[] | Record<string, unknown>;
  order_items?: CartItem[] | Record<string, unknown>;
  products?: CartItem[] | Record<string, unknown>;
  productItems?: CartItem[] | Record<string, unknown>;
  product_items?: CartItem[] | Record<string, unknown>;
  lineItems?: CartItem[] | Record<string, unknown>;
  line_items?: CartItem[] | Record<string, unknown>;
  cartItems?: CartItem[] | Record<string, unknown>;
  cart_items?: CartItem[] | Record<string, unknown>;
  data?: {
    items?: CartItem[] | Record<string, unknown>;
  };
  order?: {
    items?: CartItem[] | Record<string, unknown>;
  };
  totalPrice?: number;
  createdAt?: string;
  status?: string;
  deliveryStatus?: string;
  delivery_status?: string;
}

const getNormalizedStatus = (order: Order) =>
  String(order?.deliveryStatus ?? order?.delivery_status ?? order?.status ?? 'pending')
    .trim()
    .toLowerCase();

const getStatusPresentation = (status: string) => {
  if (status === 'delivered' || status === 'completed') {
    return {
      label: 'Delivered',
      icon: 'check-decagram',
      backgroundColor: '#EAF8EF',
      color: colors.success,
    };
  }

  if (status === 'cancelled') {
    return {
      label: 'Cancelled',
      icon: 'close-octagon',
      backgroundColor: '#FDECEC',
      color: colors.danger,
    };
  }

  if (status === 'confirmed' || status === 'assigned' || status === 'accepted') {
    return {
      label: 'In Progress',
      icon: 'truck-fast-outline',
      backgroundColor: '#EAF1FF',
      color: colors.primaryBlue,
    };
  }

  return {
    label: 'Preparing',
    icon: 'progress-clock',
    backgroundColor: '#FFF5DE',
    color: colors.warning,
  };
};

const formatPrice = (value: number | string | undefined) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed.toFixed(2) : '0.00';
};

const OrderItem: FC<{ item: Order; index: number }> = ({ item }) => {
  const { setCurrentOrder } = useAuthStore();

  const normalizedStatus = useMemo(() => getNormalizedStatus(item), [item]);
  const statusMeta = useMemo(
    () => getStatusPresentation(normalizedStatus),
    [normalizedStatus]
  );
  const items = useMemo(() => resolveOrderItems(item), [item]);
  const orderNumber = item?.orderId ?? item?.id ?? item?._id ?? '--';
  const totalItems = useMemo(
    () => resolveOrderItemCount(item),
    [item]
  );
  const displayItemCount = useMemo(() => {
    if (totalItems > 0) {
      return totalItems;
    }

    if (items.length > 0) {
      return items.length;
    }

    const fallbackCollections = [
      item?.items,
      item?.orderItems,
      item?.order_items,
      item?.products,
      item?.productItems,
      item?.product_items,
      item?.lineItems,
      item?.line_items,
      item?.cartItems,
      item?.cart_items,
      item?.data?.items,
      item?.order?.items,
    ];

    for (const collection of fallbackCollections) {
      if (Array.isArray(collection) && collection.length > 0) {
        return collection.length;
      }

      if (
        collection &&
        typeof collection === 'object' &&
        !Array.isArray(collection)
      ) {
        const keys = Object.keys(collection);
        if (keys.length > 0 && keys.every((key) => /^\d+$/.test(key))) {
          return keys.length;
        }
      }
    }

    return 0;
  }, [item, items.length, totalItems]);
  const itemPreview = useMemo(() => resolveOrderItemPreviewLines(item), [item]);

  const handlePress = () => {
    setCurrentOrder(item);
    navigate('LiveTracking');
  };

  return (
    <TouchableOpacity
      style={styles.card}
      activeOpacity={0.9}
      onPress={handlePress}
    >
      <View style={styles.topRow}>
        <View style={styles.orderMeta}>
          <CustomText variant="h9" fontFamily={Fonts.Medium} style={styles.orderLabel}>
            Order ID
          </CustomText>
          <CustomText variant="h7" fontFamily={Fonts.Bold} style={styles.orderNumber}>
            #{orderNumber}
          </CustomText>
        </View>

        <View style={[styles.statusChip, { backgroundColor: statusMeta.backgroundColor }]}>
          <Icon name={statusMeta.icon} size={15} color={statusMeta.color} />
          <CustomText
            variant="h9"
            fontFamily={Fonts.SemiBold}
            style={[styles.statusText, { color: statusMeta.color }]}
          >
            {statusMeta.label}
          </CustomText>
        </View>
      </View>

      <View style={styles.infoRow}>
        <View style={styles.infoPill}>
          <Icon name="basket-outline" size={15} color={colors.primaryBlue} />
          <CustomText variant="h9" fontFamily={Fonts.Medium} style={styles.infoPillText}>
            {displayItemCount > 0
              ? `${displayItemCount} item${displayItemCount === 1 ? '' : 's'}`
              : 'Items unavailable'}
          </CustomText>
        </View>
        <View style={styles.infoPill}>
          <Icon name="calendar-month-outline" size={15} color={colors.primaryBlue} />
          <CustomText variant="h9" fontFamily={Fonts.Medium} style={styles.infoPillText}>
            {item?.createdAt ? formatISOToCustom(item.createdAt) : 'Recent order'}
          </CustomText>
        </View>
      </View>

      <View style={styles.previewCard}>
        {itemPreview.map((previewLine, previewIndex) => (
          <CustomText
            key={`${previewLine}-${previewIndex}`}
            variant="h8"
            numberOfLines={1}
            style={styles.previewLine}
          >
            {previewLine}
          </CustomText>
        ))}
      </View>

      <View style={styles.bottomRow}>
        <View>
          <CustomText variant="h9" fontFamily={Fonts.Medium} style={styles.totalLabel}>
            Total Paid
          </CustomText>
          <CustomText variant="h5" fontFamily={Fonts.Bold} style={styles.totalAmount}>
            ₹{formatPrice(item?.totalPrice)}
          </CustomText>
        </View>

        <View style={styles.ctaWrap}>
          <CustomText variant="h9" fontFamily={Fonts.SemiBold} style={styles.ctaText}>
            {normalizedStatus === 'delivered' || normalizedStatus === 'cancelled'
              ? 'View details'
              : 'Track order'}
          </CustomText>
          <Icon name="arrow-right" size={18} color={colors.primaryBlue} />
        </View>
      </View>
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.white,
    borderRadius: 24,
    padding: 16,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.06,
    shadowRadius: 18,
    elevation: 3,
  },
  topRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: 12,
  },
  orderMeta: {
    flex: 1,
  },
  orderLabel: {
    color: colors.greyText,
    marginBottom: 4,
  },
  orderNumber: {
    color: colors.primaryBlue,
  },
  statusChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 8,
    borderRadius: 14,
  },
  statusText: {
    textTransform: 'capitalize',
  },
  infoRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    marginTop: 14,
  },
  infoPill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: colors.lightBlue,
    paddingHorizontal: 10,
    paddingVertical: 8,
    borderRadius: 14,
  },
  infoPillText: {
    color: colors.primaryBlue,
  },
  previewCard: {
    marginTop: 14,
    backgroundColor: colors.primaryBlueOpacity05,
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 12,
    gap: 6,
  },
  previewLine: {
    color: colors.darkBlue,
    opacity: 0.9,
  },
  bottomRow: {
    marginTop: 16,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 12,
  },
  totalLabel: {
    color: colors.greyText,
    marginBottom: 4,
  },
  totalAmount: {
    color: colors.primaryBlue,
  },
  ctaWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  ctaText: {
    color: colors.primaryBlue,
  },
});

export default OrderItem;
