import React, { FC, useCallback, useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Linking,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  View,
} from 'react-native';
import { RouteProp, useRoute } from '@react-navigation/native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import { RFValue } from 'react-native-responsive-fontsize';

import CustomHeader from '@components/ui/CustomHeader';
import CustomText from '@components/ui/CustomText';
import LiveMap from '@features/map/LiveMap';
import PackageBillDetails from '@features/order/PackageBillDetails';
import withLiveStatus from '@features/map/withLiveStatus';
import { useAuthStore } from '@state/authStore';
import { getPackageOrderById } from '@service/packageService';
import { formatISOToCustom } from '@utils/DateUtils';
import { Fonts, Colors } from '@utils/Constants';
import colors from '../../theme/colors';

/**
 * Package order detail/tracking page.
 * Fetches latest package order state and renders live map + billing summary.
 */
type PackageOrderRouteParams = {
  orderId?: string | number;
  order?: any;
};

const statusColorMap: Record<string, string> = {
  pending: colors.accentYellow,
  assigned: colors.primaryBlue,
  confirmed: colors.primaryBlue,
  picked: colors.success,
  picked_up: colors.success,
  delivered: colors.cyan,
  cancelled: colors.cancelled,
};

const resolveDialablePhone = (phone: unknown) => {
  const rawPhone = String(phone ?? '').trim();
  if (!rawPhone) {
    return '';
  }

  const sanitized = rawPhone.replace(/[^\d+]/g, '');
  if (!sanitized) {
    return '';
  }

  if (sanitized.startsWith('+')) {
    return `+${sanitized.slice(1).replace(/\+/g, '')}`;
  }

  return sanitized.replace(/\+/g, '');
};

const PackageOrderDetails: FC = () => {
  const insets = useSafeAreaInsets();
  const route = useRoute<RouteProp<Record<string, PackageOrderRouteParams>, string>>();
  const params = route.params || {};
  const { currentOrder, setCurrentOrder } = useAuthStore();
  const [loading, setLoading] = useState(false);

  const resolvedOrder = useMemo(() => {
    if (currentOrder?.orderType === 'package') {return currentOrder;}
    return params.order || currentOrder || null;
  }, [currentOrder, params.order]);

  const orderId = useMemo(() => {
    const idCandidate =
      params.orderId ||
      resolvedOrder?.orderId ||
      resolvedOrder?.orderNumber ||
      resolvedOrder?.id ||
      resolvedOrder?._id;
    return idCandidate ? String(idCandidate) : null;
  }, [params.orderId, resolvedOrder]);

  const fetchOrderDetails = useCallback(async () => {
    if (!orderId) {return;}
    try {
      setLoading(true);
      const normalizedId = orderId.replace(/^PKG/i, '');
      const data = await getPackageOrderById(normalizedId);
      if (data) {
        setCurrentOrder(data);
      }
    } catch (error) {
      const status = (error as any)?.response?.status;
      const responseData = (error as any)?.response?.data;
      console.error('PackageOrderDetails: failed to fetch order', {
        orderId,
        normalizedId: orderId.replace(/^PKG/i, ''),
        status,
        responseData,
        error: error instanceof Error ? error.message : error,
        stack: error instanceof Error ? error.stack : undefined,
      });
    } finally {
      setLoading(false);
    }
  }, [orderId, setCurrentOrder]);

  useEffect(() => {
    if (params.order) {
      setCurrentOrder(params.order);
    }
  }, [params.order, setCurrentOrder]);

  useEffect(() => {
    fetchOrderDetails();
  }, [fetchOrderDetails]);

  const deliveryLocation = resolvedOrder?.dropLocation || resolvedOrder?.deliveryLocation;
  const pickupLocation = resolvedOrder?.pickupLocation;

  // Helper to safely parse JSON string locations if backend sends them as strings
  const parseLocationIfString = (location: any) => {
    if (!location) {return null;}
    if (typeof location === 'string') {
      try {
        return JSON.parse(location);
      } catch {
        return null;
      }
    }
    return location;
  };

  type CoordinateLike = {
    latitude?: number | string | null;
    longitude?: number | string | null;
    lat?: number | string | null;
    lng?: number | string | null;
    lon?: number | string | null;
  };

  type Coordinate = { latitude: number; longitude: number };

  const normalizeCoordinate = useCallback((coordinate?: CoordinateLike | null): Coordinate | null => {
    if (!coordinate) {
      return null;
    }

    const rawLat =
      coordinate.latitude ??
      coordinate.lat ??
      (coordinate as any)?.Latitude ??
      (coordinate as any)?.Lat;
    const rawLng =
      coordinate.longitude ??
      coordinate.lng ??
      coordinate.lon ??
      (coordinate as any)?.Longitude ??
      (coordinate as any)?.Lon;

    const lat =
      typeof rawLat === 'string' ? parseFloat(rawLat) : (rawLat as number | null | undefined);
    const lng =
      typeof rawLng === 'string' ? parseFloat(rawLng) : (rawLng as number | null | undefined);

    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return null;
    }

    return { latitude: Number(lat), longitude: Number(lng) };
  }, []);

  const statusLabel = (resolvedOrder?.status || 'pending').toString().toLowerCase();
  const normalizedStatus = statusLabel.replace(/[-\s]/g, '_');
  const displayStatus = normalizedStatus.replace(/_/g, ' ');
  const statusColor = statusColorMap[normalizedStatus] || colors.muted;

  // Show delivery partner info only after the package order is accepted/assigned in the workflow.
  const hasAssignedPartner = useMemo(() => {
    const acceptedStatuses = [
      'assigned',
      'confirmed',
      'accepted',
      'picked',
      'picked_up',
      'arriving',
      'out_for_delivery',
      'delivered',
    ];

    const acceptedByPartner =
      Boolean((resolvedOrder as any)?.acceptedAt) ||
      Boolean((resolvedOrder as any)?.accepted_at) ||
      Boolean((resolvedOrder as any)?.isAcceptedByDeliveryPartner);

    return acceptedByPartner || acceptedStatuses.includes(normalizedStatus);
  }, [normalizedStatus, resolvedOrder]);
  const hasPickedUpStatus = ['picked', 'picked_up', 'arriving', 'out_for_delivery'].includes(normalizedStatus);

  const partnerName = useMemo(() => {
    const partner = resolvedOrder?.deliveryPartner || {};
    return (
      partner?.name ||
      partner?.fullName ||
      partner?.firstName ||
      partner?.lastName ||
      resolvedOrder?.deliveryPartnerName ||
      null
    );
  }, [resolvedOrder?.deliveryPartner, resolvedOrder?.deliveryPartnerName]);

  const partnerPhone = useMemo(() => {
    const partner = resolvedOrder?.deliveryPartner || {};
    return (
      partner?.phone ||
      partner?.contactNumber ||
      partner?.mobile ||
      partner?.phoneNumber ||
      resolvedOrder?.deliveryPartnerPhone ||
      null
    );
  }, [resolvedOrder?.deliveryPartner, resolvedOrder?.deliveryPartnerPhone]);

  const totalPrice =
    resolvedOrder?.totalPrice ??
    resolvedOrder?.deliveryCharge ??
    resolvedOrder?.price ??
    0;

  const distanceKm = resolvedOrder?.distanceKm || null;
  const createdAt = resolvedOrder?.createdAt || resolvedOrder?.created_at || null;

  // Normalize delivery partner live location so the map can show their live tracing
  const normalizedDeliveryPersonLocation = useMemo(() => {
    // Prefer explicit deliveryPersonLocation if backend already populated it
    const sources = [
      resolvedOrder?.deliveryPersonLocation,
      resolvedOrder?.deliveryPartner?.liveLocation,
    ];

    for (const source of sources) {
      const parsed = parseLocationIfString(source);
      const normalized = normalizeCoordinate(parsed);
      if (normalized) {
        return normalized;
      }
    }

    return null;
  }, [normalizeCoordinate, resolvedOrder?.deliveryPersonLocation, resolvedOrder?.deliveryPartner?.liveLocation]);

  useEffect(() => {
    // Surface missing partner details in scenarios where we expect them
    if (!resolvedOrder) {return;}
    if (hasAssignedPartner && !(partnerName || partnerPhone)) {
      // Intentionally silent to avoid log noise; keep hook in case future instrumentation is needed
    }
  }, [hasAssignedPartner, normalizedStatus, orderId, partnerName, partnerPhone, resolvedOrder]);

  const handleCallPartner = useCallback(async (phone: unknown) => {
    const dialablePhone = resolveDialablePhone(phone);
    if (!dialablePhone) {
      Alert.alert('Call failed', 'Phone number is not available.');
      return;
    }

    try {
      const dialUrl = `tel:${dialablePhone}`;
      const canOpen = await Linking.canOpenURL(dialUrl);
      if (!canOpen) {
        Alert.alert('Call failed', 'Your device cannot place calls right now.');
        return;
      }
      await Linking.openURL(dialUrl);
    } catch (error) {
      console.log('Failed to open dialer', error);
      Alert.alert('Call failed', 'Unable to open phone dialer.');
    }
  }, []);

  return (
    <SafeAreaView style={{ flex: 1 }} edges={['top']}>
      <View style={styles.container}>
        <CustomHeader title="Package Order" fallbackRoute="Package" />

      <ScrollView
        style={styles.scroll}
        contentContainerStyle={[styles.scrollContent, { paddingBottom: insets.bottom + 40 }]}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.card}>
          <View style={styles.headerRow}>
            <View style={styles.headerTextContainer}>
              <CustomText variant="h6" fontFamily={Fonts.Bold}>
                Packing your package order
              </CustomText>
              <CustomText variant="h9" style={styles.subText}>
                {orderId ? `Order #${orderId}` : 'Order details'}
              </CustomText>
            </View>
            <View style={[styles.statusChip, { backgroundColor: statusColor }]}>
              <Icon name="progress-clock" size={RFValue(14)} color={colors.white} />
              <CustomText variant="h9" fontFamily={Fonts.SemiBold} style={styles.statusText}>
                {displayStatus}
              </CustomText>
            </View>
          </View>

          <View style={styles.metaRow}>
            <View style={styles.metaItem}>
              <Icon name="package-variant" size={RFValue(16)} color={colors.primaryBlue} />
              <CustomText variant="h8" fontFamily={Fonts.SemiBold} numberOfLines={1}>
                {resolvedOrder?.packageType || 'Package'}
              </CustomText>
            </View>
            {createdAt && (
              <View style={styles.metaItem}>
                <Icon name="calendar" size={RFValue(16)} color={colors.primaryBlue} />
                <CustomText variant="h8" numberOfLines={1}>
                  {formatISOToCustom(createdAt)}
                </CustomText>
              </View>
            )}
          </View>

          <View style={styles.locationRow}>
            <Icon name="map-marker" size={RFValue(16)} color={colors.success} />
            <View style={styles.locationTextContainer}>
              <CustomText variant="h8" fontFamily={Fonts.SemiBold}>
                Pickup
              </CustomText>
              <CustomText variant="h9" numberOfLines={2}>
                {pickupLocation?.address || 'N/A'}
              </CustomText>
            </View>
          </View>

          <View style={styles.locationRow}>
            <Icon name="map-marker-check" size={RFValue(16)} color={colors.danger} />
            <View style={styles.locationTextContainer}>
              <CustomText variant="h8" fontFamily={Fonts.SemiBold}>
                Drop
              </CustomText>
              <CustomText variant="h9" numberOfLines={2}>
                {deliveryLocation?.address || 'N/A'}
              </CustomText>
            </View>
          </View>

          <View style={styles.quickStats}>
            {distanceKm !== null && (
              <View style={styles.statItem}>
                <CustomText variant="h9" style={styles.statLabel}>
                  Distance
                </CustomText>
                <CustomText variant="h7" fontFamily={Fonts.SemiBold}>
                  {distanceKm} km
                </CustomText>
              </View>
            )}
            <View style={styles.statItem}>
              <CustomText variant="h9" style={styles.statLabel}>
                Delivery Charge
              </CustomText>
              <CustomText variant="h7" fontFamily={Fonts.SemiBold}>
                ₹{(resolvedOrder?.deliveryCharge ?? resolvedOrder?.price ?? 0).toFixed(2)}
              </CustomText>
            </View>
            <View style={styles.statItem}>
              <CustomText variant="h9" style={styles.statLabel}>
                Total
              </CustomText>
              <CustomText variant="h7" fontFamily={Fonts.Bold} style={styles.totalText}>
                ₹{totalPrice.toFixed(2)}
              </CustomText>
            </View>
          </View>
        </View>

        {loading && (
          <View style={styles.loaderContainer}>
            <ActivityIndicator color={colors.primaryBlue} />
            <CustomText variant="h9" style={styles.loaderText}>
              Loading latest package status...
            </CustomText>
          </View>
        )}

        {hasAssignedPartner && (partnerName || partnerPhone) && (
          <View style={styles.partnerCard}>
            <View style={styles.partnerHeader}>
              <Icon name="account-tie" size={RFValue(18)} color={colors.primaryBlue} />
              <View style={styles.partnerHeaderText}>
                <CustomText variant="h7" fontFamily={Fonts.SemiBold}>
                  Delivery Partner
                </CustomText>
                <CustomText variant="h9" style={styles.partnerStatusText}>
                  {['picked', 'picked_up'].includes(normalizedStatus) ? 'Package picked up' : 'On the way'}
                </CustomText>
              </View>
            </View>

            {partnerName && (
              <View style={styles.partnerRow}>
                <Icon name="account" size={RFValue(16)} color={colors.greyText} />
                <CustomText variant="h8" numberOfLines={1}>
                  {partnerName}
                </CustomText>
              </View>
            )}

            {partnerPhone && (
              <TouchableOpacity
                style={styles.partnerRow}
                activeOpacity={0.75}
                onPress={() => handleCallPartner(partnerPhone)}
                accessibilityRole="button"
                accessibilityLabel="Call delivery partner"
                accessibilityHint="Double tap to open phone dialer"
              >
                <Icon name="phone" size={RFValue(16)} color={colors.greyText} />
                <CustomText variant="h8" numberOfLines={1} style={styles.partnerPhoneLink}>
                  {partnerPhone}
                </CustomText>
              </TouchableOpacity>
            )}
          </View>
        )}

        <LiveMap
          iconColor={colors.primaryBlue}
          deliveryLocation={deliveryLocation}
          pickupLocation={pickupLocation}
          deliveryPersonLocation={normalizedDeliveryPersonLocation}
          hasAccepted={['assigned', 'confirmed'].includes(normalizedStatus)}
          hasPickedUp={hasPickedUpStatus}
          showDeliveryPartnerMarker={false}
        />

        <PackageBillDetails
          packageType={resolvedOrder?.packageType}
          distanceKm={distanceKm}
          deliveryCharge={resolvedOrder?.deliveryCharge ?? resolvedOrder?.price}
          totalPrice={totalPrice}
          status={resolvedOrder?.status}
        />

      </ScrollView>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.white,
  },
  scroll: {
    flex: 1,
  },
  scrollContent: {
    padding: 16,
    gap: 16,
  },
  card: {
    backgroundColor: colors.white,
    borderRadius: 12,
    padding: 14,
    borderWidth: 1,
    borderColor: Colors.border,
    gap: 12,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  headerTextContainer: {
    flex: 1,
    gap: 4,
  },
  subText: {
    color: colors.greyText,
  },
  statusChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 20,
  },
  statusText: {
    color: colors.white,
    textTransform: 'capitalize',
  },
  metaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  metaItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingVertical: 4,
  },
  locationRow: {
    flexDirection: 'row',
    gap: 10,
    alignItems: 'flex-start',
  },
  locationTextContainer: {
    flex: 1,
    gap: 4,
  },
  quickStats: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 12,
  },
  statItem: {
    flex: 1,
    padding: 10,
    backgroundColor: colors.lightBlue,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  statLabel: {
    color: colors.greyText,
    marginBottom: 4,
  },
  totalText: {
    color: colors.primaryBlue,
  },
  loaderContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    padding: 12,
    borderRadius: 10,
    backgroundColor: colors.lightBlue,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  loaderText: {
    color: colors.greyText,
  },
  partnerCard: {
    backgroundColor: colors.white,
    borderRadius: 12,
    padding: 14,
    borderWidth: 1,
    borderColor: Colors.border,
    gap: 10,
  },
  partnerHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  partnerHeaderText: {
    flex: 1,
    gap: 2,
  },
  partnerStatusText: {
    color: colors.greyText,
    textTransform: 'capitalize',
  },
  partnerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  partnerPhoneLink: {
    color: colors.primaryBlue,
    textDecorationLine: 'underline',
  },
});

export default withLiveStatus(PackageOrderDetails);
