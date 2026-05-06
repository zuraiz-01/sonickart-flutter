import React, { FC, useCallback, useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  RefreshControl,
  StyleSheet,
  TouchableOpacity,
  View,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import CustomHeader from '@components/ui/CustomHeader';
import CustomText from '@components/ui/CustomText';
import { Fonts } from '@utils/Constants';
import { fetchCustomerOrders, getOrderById } from '@service/orderService';
import { useAuthStore } from '@state/authStore';
import OrderItem from '@features/profile/OrderItem';
import { resolveOrderItemCount } from '@utils/orderItems';
import colors from '../../theme/colors';
import BottomTabBar from '@components/ui/BottomTabBar';

/**
 * Customer order-history screen with pull-to-refresh support.
 */
const CustomerOrders: FC = () => {
  const MAX_ZERO_COUNT_ORDER_HYDRATIONS = 8;
  const { user } = useAuthStore();
  const insets = useSafeAreaInsets();
  const customerId = useMemo(() => user?.id || user?._id, [user]);

  const [orders, setOrders] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const resolveOrderIdentifiers = useCallback((order: any) => {
    const rawIds = [order?.id, order?._id, order?.orderId, order?.orderNumber]
      .map((value) => (value === null || value === undefined ? '' : String(value).trim()))
      .filter(Boolean);

    const candidates = new Set<string>();

    rawIds.forEach((rawId) => {
      const normalizedRawId = rawId.replace(/^#/, '').trim();
      if (normalizedRawId) {
        candidates.add(normalizedRawId);
      }

      const withoutPackagePrefix = normalizedRawId.replace(/^PKG/i, '').trim();
      if (withoutPackagePrefix) {
        candidates.add(withoutPackagePrefix);
      }

      const numericOnly = normalizedRawId.replace(/[^\d]/g, '').trim();
      if (numericOnly) {
        candidates.add(numericOnly);
      }
    });

    return Array.from(candidates);
  }, []);

  const normalizeOrderDetails = useCallback((payload: any) => {
    if (!payload) {
      return null;
    }

    if (Array.isArray(payload)) {
      return payload[0] ?? null;
    }

    return payload?.order ?? payload?.data ?? payload?.result ?? payload;
  }, []);

  const hydrateOrderWhenMissingItems = useCallback(
    async (order: any) => {
      if (!order || resolveOrderItemCount(order) > 0) {
        return order;
      }

      const identifiers = resolveOrderIdentifiers(order);
      let bestEffortDetailedOrder: any = null;

      for (const orderId of identifiers) {
        try {
          const detailedOrderPayload = await getOrderById(orderId);
          const detailedOrder = normalizeOrderDetails(detailedOrderPayload);

          if (!detailedOrder) {
            continue;
          }

          bestEffortDetailedOrder = { ...order, ...detailedOrder };
          if (resolveOrderItemCount(bestEffortDetailedOrder) > 0) {
            return bestEffortDetailedOrder;
          }
        } catch (hydrationError) {
          console.log('CustomerOrders detail hydration error', { orderId, error: hydrationError });
        }
      }

      return bestEffortDetailedOrder || order;
    },
    [normalizeOrderDetails, resolveOrderIdentifiers]
  );

  const loadOrders = useCallback(
    async (isRefresh = false) => {
      if (!customerId) {
        setOrders([]);
        return;
      }

      try {
        isRefresh ? setRefreshing(true) : setLoading(true);
        const data = await fetchCustomerOrders(String(customerId));
        const fetchedOrders = Array.isArray(data) ? data : [];

        const hydratedOrders = [...fetchedOrders];
        let hydrationAttempts = 0;

        for (let index = 0; index < hydratedOrders.length; index += 1) {
          const order = hydratedOrders[index];
          if (resolveOrderItemCount(order) > 0) {
            continue;
          }

          if (hydrationAttempts >= MAX_ZERO_COUNT_ORDER_HYDRATIONS) {
            break;
          }

          hydrationAttempts += 1;
          hydratedOrders[index] = await hydrateOrderWhenMissingItems(order);
        }

        setOrders(hydratedOrders);
        setError(null);
      } catch (err) {
        console.log('CustomerOrders load error', err);
        setError('Unable to load your orders right now.');
      } finally {
        isRefresh ? setRefreshing(false) : setLoading(false);
      }
    },
    [customerId, hydrateOrderWhenMissingItems]
  );

  useEffect(() => {
    loadOrders();
  }, [loadOrders]);

  const displayOrders = useMemo(() => {
    return [...orders].sort((left, right) => {
      const leftTime = new Date(left?.createdAt ?? 0).getTime();
      const rightTime = new Date(right?.createdAt ?? 0).getTime();
      return rightTime - leftTime;
    });
  }, [orders]);

  const renderOrder = ({ item, index }: { item: any; index: number }) => (
    <OrderItem item={item} index={index} />
  );

  const keyExtractor = (item: any, index: number) =>
    String(item?.orderId || item?.id || item?._id || index);

  const showEmptyState = !loading && displayOrders.length === 0;

  const listHeader = error && displayOrders.length ? (
    <View style={styles.headerContent}>
      <View style={styles.errorBanner}>
        <Icon name="alert-circle-outline" size={18} color={colors.warning} />
        <CustomText variant="h9" fontFamily={Fonts.Medium} style={styles.errorBannerText}>
          {error}
        </CustomText>
      </View>
    </View>
  ) : null;

  const emptyState = showEmptyState ? (
    <View style={styles.emptyState}>
      <View style={styles.emptyIconWrap}>
        <Icon
          name={customerId ? 'shopping-search' : 'account-lock-outline'}
          size={44}
          color={colors.primaryBlue}
        />
      </View>
      <CustomText variant="h5" fontFamily={Fonts.Bold} style={styles.emptyTitle}>
        {customerId ? 'No orders yet' : 'Login required'}
      </CustomText>
      <CustomText
        variant="h8"
        fontFamily={Fonts.Medium}
        style={styles.emptySubtitle}
      >
        {customerId
          ? 'Your confirmed, active, and delivered orders will appear here.'
          : 'Sign in to view your current and previous orders.'}
      </CustomText>
      {customerId ? (
        <TouchableOpacity
          style={styles.emptyAction}
          activeOpacity={0.85}
          onPress={() => loadOrders(true)}
        >
          <Icon name="refresh" size={18} color={colors.white} />
          <CustomText variant="h8" fontFamily={Fonts.SemiBold} style={styles.emptyActionText}>
            Refresh Orders
          </CustomText>
        </TouchableOpacity>
      ) : null}
      {error ? (
        <CustomText variant="h9" style={styles.errorText}>
          {error}
        </CustomText>
      ) : null}
    </View>
  ) : null;

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <CustomHeader title="My Orders" fallbackRoute="Profile" />

      {loading && !displayOrders.length ? (
        <View style={styles.loaderContainer}>
          <View style={styles.loaderBadge}>
            <ActivityIndicator size="small" color={colors.primaryBlue} />
          </View>
          <CustomText variant="h8" style={styles.loaderText}>
            Fetching your orders...
          </CustomText>
        </View>
      ) : (
        <FlatList
          data={displayOrders}
          keyExtractor={keyExtractor}
          renderItem={renderOrder}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={() => loadOrders(true)}
              colors={[colors.primaryBlue]}
              tintColor={colors.primaryBlue}
            />
          }
          ListHeaderComponent={listHeader}
          ListEmptyComponent={emptyState}
          ItemSeparatorComponent={() => <View style={styles.separator} />}
          contentContainerStyle={[
            displayOrders.length ? styles.listContent : styles.emptyContent,
            { paddingBottom: insets.bottom + 116 },
          ]}
          showsVerticalScrollIndicator={false}
        />
      )}
      <BottomTabBar />
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: colors.lightBlue,
  },
  listContent: {
    paddingHorizontal: 16,
    paddingTop: 14,
  },
  emptyContent: {
    flexGrow: 1,
    justifyContent: 'center',
    paddingHorizontal: 24,
    paddingTop: 24,
  },
  headerContent: {
    marginBottom: 16,
  },
  errorBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    backgroundColor: colors.lightOrange,
    borderRadius: 16,
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  errorBannerText: {
    flex: 1,
    color: colors.darkBlue,
  },
  separator: {
    height: 12,
  },
  loaderContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 16,
  },
  loaderBadge: {
    width: 58,
    height: 58,
    borderRadius: 18,
    backgroundColor: colors.white,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 14,
  },
  loaderText: {
    color: colors.primaryBlue,
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.white,
    borderRadius: 24,
    paddingHorizontal: 24,
    paddingVertical: 32,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
  },
  emptyIconWrap: {
    width: 86,
    height: 86,
    borderRadius: 28,
    backgroundColor: colors.lightBlue,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 18,
  },
  emptyTitle: {
    color: colors.primaryBlue,
    marginBottom: 8,
  },
  emptySubtitle: {
    textAlign: 'center',
    color: colors.greyText,
    lineHeight: 22,
    marginBottom: 18,
  },
  emptyAction: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: colors.primaryBlue,
    paddingHorizontal: 18,
    paddingVertical: 12,
    borderRadius: 16,
  },
  emptyActionText: {
    color: colors.white,
  },
  errorText: {
    color: colors.danger,
    textAlign: 'center',
    marginTop: 14,
  },
});

export default CustomerOrders;
