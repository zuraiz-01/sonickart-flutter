import {
  View,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
  Modal,
  TouchableWithoutFeedback,
  Image,
  Linking,
} from 'react-native';
import React, { FC, useEffect, useMemo, useState } from 'react';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAuthStore } from '@state/authStore';
import { getOrderById, cancelOrderItems /* , cancelPackageOrder */ } from '@service/orderService'; // Commented out package order cancellation
// import { getPackageOrderById } from '@service/packageService' // Commented out package service
import { Colors, Fonts } from '@utils/Constants';
import LiveHeader from './LiveHeader';
import LiveMap from './LiveMap';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import IonIcon from 'react-native-vector-icons/Ionicons';
import { RFValue } from 'react-native-responsive-fontsize';
import CustomText from '@components/ui/CustomText';
import DeliveryDetails from './DeliveryDetails';
import OrderSummary from './OrderSummary';
import BillDetails from '@features/order/BillDetails';
// import PackageBillDetails from '@features/order/PackageBillDetails' // Commented out package bill details
import colors from '../../theme/colors';
import withLiveStatus from './withLiveStatus';
import CancellationReasonModal from '@components/ui/CancellationReasonModal';
import { normalizeImageUrl } from '@utils/imageUtils';
import { normalizeCoordinate, type Coordinate } from '@utils/locationUtils';
import {
  formatCurrencyValue,
  resolveDisplayMrpWithGst,
  resolveDisplayPriceWithGst,
} from '@utils/productPricing';

/**
 * Main customer live-tracking screen for regular product orders.
 * Shows map, status/ETA, partner details, order summary, and cancellation flow.
 */
// OrderItemRow component for better state management - Using CartScreen approach
const OrderItemRow: FC<{ cartItem: any }> = ({ cartItem }) => {
  const [imageError, setImageError] = useState(false);

  // Use the image URL directly from the backend with proper normalization
  // The backend maps product_images to item.image in the order structure
  const rawImageData = cartItem?.item?.image;
  const imageUrl = normalizeImageUrl(rawImageData);

  // Debug log to see what we're getting
  console.log(`🖼️ LiveTracking Item: ${cartItem?.item?.name}`, {
    rawImageData,
    imageUrl,
    hasImage: !!imageUrl,
    imageError,
    fullCartItemKeys: Object.keys(cartItem || {}),
    fullItemKeys: Object.keys(cartItem?.item || {}),
  });

  return (
    <View style={styles.orderedItem}>
      <View style={styles.itemImageContainer}>
        {imageUrl && !imageError ? (
          <Image
            source={{ uri: imageUrl }}
            style={styles.itemImage}
            onError={(error) => {
              console.log(`❌ Image error for ${cartItem?.item?.name}:`, {
                url: imageUrl,
                rawImageData,
                error: error.nativeEvent.error,
              });
              setImageError(true);
            }}
            onLoad={() => {
              console.log(`✅ Image loaded for ${cartItem?.item?.name}: ${imageUrl}`);
            }}
            resizeMode="contain"
          />
        ) : (
          <View style={styles.placeholderImage}>
            <Icon name="image-outline" size={20} color={Colors.disabled} />
            {/* Debug text to show why image failed */}
            {!imageUrl && (
              <CustomText fontSize={6} style={styles.placeholderText}>
                No URL
              </CustomText>
            )}
            {imageUrl && imageError && (
              <CustomText fontSize={6} style={styles.placeholderText}>
                Failed
              </CustomText>
            )}
          </View>
        )}
      </View>

      <View style={styles.itemDetails}>
        <CustomText
          variant="h8"
          fontFamily={Fonts.SemiBold}
          numberOfLines={2}
          style={styles.itemName}
        >
          {cartItem?.item?.name || cartItem?.product_name || cartItem?.productName || 'Item'}
        </CustomText>

        <View style={styles.itemPriceRow}>
          <CustomText variant="h9" fontFamily={Fonts.Medium} style={styles.itemPrice}>
            ₹{formatCurrencyValue(resolveDisplayPriceWithGst(cartItem))}
          </CustomText>
          {resolveDisplayMrpWithGst(cartItem) &&
          resolveDisplayMrpWithGst(cartItem)! > resolveDisplayPriceWithGst(cartItem) && (
            <CustomText variant="h9" style={styles.originalPrice}>
              ₹{formatCurrencyValue(resolveDisplayMrpWithGst(cartItem))}
            </CustomText>
          )}
        </View>
      </View>

      <View style={styles.quantityContainer}>
        <View style={styles.quantityBadge}>
          <CustomText variant="h8" fontFamily={Fonts.SemiBold} style={styles.quantityText}>
            {cartItem?.count || cartItem?.quantity || 1}
          </CustomText>
        </View>
        <CustomText variant="h9" fontFamily={Fonts.Medium} style={styles.quantityLabel}>
          Qty
        </CustomText>
      </View>
    </View>
  );
};

const EARTH_RADIUS_KM = 6371;
const AVERAGE_SPEED_KM_PER_MIN = 0.35; // ~21 km/h

const toRadians = (value: number) => (value * Math.PI) / 180;

const getDistanceKm = (origin: Coordinate, destination: Coordinate) => {
  const dLat = toRadians(destination.latitude - origin.latitude);
  const dLon = toRadians(destination.longitude - origin.longitude);
  const lat1 = toRadians(origin.latitude);
  const lat2 = toRadians(destination.latitude);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLon / 2) * Math.sin(dLon / 2) * Math.cos(lat1) * Math.cos(lat2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return EARTH_RADIUS_KM * c;
};

const calculateEtaMinutes = (origin: Coordinate, destination: Coordinate) => {
  const distanceKm = getDistanceKm(origin, destination);
  if (!Number.isFinite(distanceKm) || distanceKm <= 0) {
    return null;
  }
  return Math.max(1, Math.round(distanceKm / AVERAGE_SPEED_KM_PER_MIN));
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

const LiveTracking: FC = () => {
  const insets = useSafeAreaInsets();
  const { currentOrder, setCurrentOrder } = useAuthStore();
  const [cancelling, setCancelling] = useState(false);
  const [cancelModalVisible, setCancelModalVisible] = useState(false);
  const [cancelSuccessVisible, setCancelSuccessVisible] = useState(false);
  const [cancellationReasonModalVisible, setCancellationReasonModalVisible] = useState(false);

  // Check if this is a package order - moved up to avoid hoisting issues
  // const isPackageOrder = useMemo(() => {
  //   return currentOrder?.orderType === 'package' ||
  //          (currentOrder?.orderId && String(currentOrder.orderId).startsWith('PKG')) ||
  //          (!currentOrder?.items || (Array.isArray(currentOrder.items) && currentOrder.items.length === 0 && currentOrder.deliveryCharge));
  // }, [currentOrder]);
  const resolveOrderId = () =>
    currentOrder?.id ||
    currentOrder?._id ||
    currentOrder?.orderId ||
    currentOrder?.orderNumber;

  const fetchOrderDetails = async () => {
    const orderId = resolveOrderId();
    if (!orderId) {
      console.warn('LiveTracking: Missing order id, skipping refresh');
      return;
    }

    // const isPackageOrder =
    //   currentOrder?.orderType === 'package' ||
    //   (orderId && String(orderId).toUpperCase().startsWith('PKG'));

    // const normalizedId = String(orderId).replace(/^PKG/i, '');

    // const data = isPackageOrder
    //   ? await getPackageOrderById(normalizedId)
    //   : await getOrderById(String(orderId));

    // Commented out package order logic - only fetch regular orders
    const data = await getOrderById(String(orderId));

    if (data) {
      setCurrentOrder(data);
    }
  };

  useEffect(() => {
    if (currentOrder) {
      fetchOrderDetails();
    }
    // Keep id-based refresh behavior to avoid effect loops on whole object updates.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentOrder?.id, currentOrder?.orderNumber]);

  // Prefer delivery_status from delivery_orders if the backend has provided it,
  // otherwise fall back to the main order.status field.
  const status = (
    currentOrder?.deliveryStatus ||
    // also support snake_case if backend sends `delivery_status`
    (currentOrder as any)?.delivery_status ||
    currentOrder?.status ||
    ''
  ).toLowerCase();
  const isPreparingOrder = status === 'pending';
  const highlightIconColor = isPreparingOrder ? '#FFC727' : Colors.disabled;

  const destinationCoordinate = useMemo(
    () =>
      normalizeCoordinate(currentOrder?.deliveryLocation) ||
      normalizeCoordinate({
        latitude: currentOrder?.customerLatitude as number | string | null,
        longitude: currentOrder?.customerLongitude as number | string | null,
      }),
    [currentOrder?.deliveryLocation, currentOrder?.customerLatitude, currentOrder?.customerLongitude]
  );

  const driverCoordinate = useMemo(
    () => normalizeCoordinate(currentOrder?.deliveryPersonLocation),
    [currentOrder?.deliveryPersonLocation]
  );

  const partnerName = useMemo(() => {
    const partner = currentOrder?.deliveryPartner || {};
    return (
      partner?.name ||
      partner?.fullName ||
      partner?.firstName ||
      partner?.lastName ||
      currentOrder?.deliveryPartnerName ||
      null
    );
  }, [currentOrder?.deliveryPartner, currentOrder?.deliveryPartnerName]);

  const partnerPhone = useMemo(() => {
    const partner = currentOrder?.deliveryPartner || {};
    return (
      partner?.phone ||
      partner?.contactNumber ||
      partner?.mobile ||
      partner?.phoneNumber ||
      currentOrder?.deliveryPartnerPhone ||
      null
    );
  }, [currentOrder?.deliveryPartner, currentOrder?.deliveryPartnerPhone]);

  const pickupCoordinate = useMemo(
    () => normalizeCoordinate(currentOrder?.pickupLocation),
    [currentOrder?.pickupLocation]
  );

  const etaMinutes = useMemo(() => {
    if (status === 'delivered' || status === 'cancelled') {
      return 0;
    }
    if (!destinationCoordinate) {
      return null;
    }
    const origin =
      driverCoordinate ||
      ((status === 'confirmed' || status === 'accepted' || status === 'assigned') ? pickupCoordinate : null);

    if (!origin) {
      return null;
    }

    return calculateEtaMinutes(origin, destinationCoordinate);
  }, [destinationCoordinate, driverCoordinate, pickupCoordinate, status]);

  // Calculate real-time distance for package orders
  const liveDistance = useMemo(() => {
    if (!driverCoordinate || !destinationCoordinate) {
      return null;
    }
    const distance = getDistanceKm(driverCoordinate, destinationCoordinate);
    return distance;
  }, [driverCoordinate, destinationCoordinate]);

  let msg = 'Packing your order';
  if (status === 'cancelled') {
    // msg = isPackageOrder ? 'Package Cancelled' : 'Order Cancelled';
    msg = 'Order Cancelled'; // Commented out package order specific message
  } else if (status === 'confirmed' || status === 'accepted') {
    msg = 'Arriving Soon';
  } else if (status === 'arriving' || status === 'out_for_delivery') {
    msg = 'Order Picked Up';
  } else if (status === 'delivered') {
    msg = 'Order Delivered';
  }

  const time = useMemo(() => {
    if (status === 'cancelled') {
      return 'Cancelled';
    }
    if (status === 'delivered') {
      return 'Fastest Delivery ⚡️';
    }
    if (etaMinutes === null) {
      return status === 'pending' ? 'Getting things ready' : 'Tracking live';
    }
    if (etaMinutes <= 1) {
      return 'Arriving any moment';
    }
    return `Arriving in ${etaMinutes} ${etaMinutes === 1 ? 'minute' : 'minutes'}`;
  }, [etaMinutes, status]);

  const deliveryDetails = useMemo(() => {
    const location = currentOrder?.deliveryLocation;
    const customer = currentOrder?.customer || {};
    return {
      addressLabel:
        location?.label ||
        location?.tag ||
        (location?.address ? 'Delivery Address' : customer?.address ? 'Delivery at Home' : undefined),
      address:
        location?.address ||
        customer?.address ||
        currentOrder?.customerAddress ||
        currentOrder?.shippingAddress ||
        null,
      name:
        location?.fullName ||
        location?.name ||
        customer?.name ||
        currentOrder?.customerName ||
        null,
      phone:
        location?.contactNumber ||
        customer?.phone ||
        currentOrder?.customerPhone ||
        null,
      partnerName: partnerName,
      partnerPhone: partnerPhone,
    };
  }, [currentOrder, partnerName, partnerPhone]);

  const handleCancelOrder = async () => {
    if (!currentOrder) {
      // Show error modal instead of Alert.alert
      Alert.alert('No Order', 'There is no order to cancel.');
      return;
    }

    const orderStatus = (currentOrder?.status || '').toLowerCase();
    if (orderStatus === 'delivered' || orderStatus === 'cancelled') {
      // Show error modal instead of Alert.alert
      Alert.alert('Cannot Cancel', 'This order cannot be cancelled.');
      return;
    }

    // Show cancellation reason modal for product orders only
    // if (!isPackageOrder) {
    //   setCancellationReasonModalVisible(true);
    // } else {
    //   // For package orders, show regular confirmation modal
    //   setCancelModalVisible(true);
    // }

    // Commented out package order logic - only handle regular orders
    setCancellationReasonModalVisible(true);
  };

  const handleCallPartner = async (phone: unknown) => {
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
  };

  const handleCancellationReasonSelect = async (reason: string) => {
    setCancellationReasonModalVisible(false);
    try {
      setCancelling(true);
      const orderId = currentOrder?.id || currentOrder?._id || currentOrder?.orderId || currentOrder?.orderNumber;
      if (!orderId) {
        Alert.alert('Error', 'Order ID not found');
        return;
      }

      // Cancel regular order with reason
      await cancelOrderItems(String(orderId), reason);

      // Refresh order details
      await fetchOrderDetails();

      // Show success modal
      setCancelSuccessVisible(true);
    } catch (error: any) {
      console.error('Cancel order error:', error);
      Alert.alert(
        'Error',
        error?.response?.data?.message || 'Failed to cancel order. Please try again.'
      );
    } finally {
      setCancelling(false);
    }
  };

  const handleConfirmCancel = async () => {
    setCancelModalVisible(false);
    try {
      setCancelling(true);
      const orderId = currentOrder?.id || currentOrder?._id || currentOrder?.orderId || currentOrder?.orderNumber;
      if (!orderId) {
        Alert.alert('Error', 'Order ID not found');
        return;
      }

      // Check if this is a package order
      // if (isPackageOrder) {
      //   // Cancel package order (no reason needed for package orders)
      //   await cancelPackageOrder(String(orderId));
      // } else {
      //   // This shouldn't happen as product orders go through reason modal
      //   await cancelOrderItems(String(orderId));
      // }

      // Commented out package order logic - only handle regular orders
      await cancelOrderItems(String(orderId));

      // Refresh order details
      await fetchOrderDetails();

      // Show success modal
      setCancelSuccessVisible(true);
    } catch (error: any) {
      console.error('Cancel order error:', error);
      Alert.alert(
        'Error',
        error?.response?.data?.message || 'Failed to cancel order. Please try again.'
      );
    } finally {
      setCancelling(false);
    }
  };

  // Check if order can be cancelled
  const canCancel = useMemo(() => {
    if (!currentOrder) {return false;}
    const orderStatus = (currentOrder?.status || '').toLowerCase();
    return orderStatus !== 'delivered' && orderStatus !== 'cancelled';
  }, [currentOrder]);

  // Prepare cart items and total price for BillDetails (same logic as OrderSummary)
  const billCartItems = useMemo(() => {
    const items = currentOrder?.items ?? [];
    if (!Array.isArray(items)) {return [];}

    return items.map((item: any) => {
      const gstValue = item?.item_gst ??
                     item?.gst_items ??
                     item?.item?.gstSlab ??
                     item?.item?.gst_slab ??
                     item?.item?.gstRate ??
                     item?.item?.gst_rate ??
                     item?.item?.gst ??
                     0;

      const numericGst = Number(gstValue) || 0;
      const originalItem = item?.item;

      return {
        ...item,
        _id: item?._id ?? item?.id ?? item?.product_id,
        count: item?.count ?? item?.quantity ?? 1,
        item_gst: item?.item_gst ?? null,
        gst_items: item?.gst_items ?? null,
        item: {
          ...originalItem,
          name: originalItem?.name ?? item?.product_name ?? item?.productName ?? 'Item',
          price: Number(originalItem?.price ?? item?.unit_price ?? item?.unitPrice ?? 0),
          discountPrice: originalItem?.discountPrice ?? originalItem?.discount_price ?? null,
          image: originalItem?.image ?? originalItem?.product_images ?? null,
          gstSlab: numericGst,
          gst_slab: numericGst,
          gstRate: numericGst,
          gst_rate: numericGst,
          gst: numericGst,
        },
      };
    });
  }, [currentOrder?.items]);

  // Calculate items total (without GST and delivery charges) for BillDetails component
  const billTotalPrice = useMemo(() => {
    if (!Array.isArray(billCartItems) || billCartItems.length === 0) {
      return 0;
    }

    // Always calculate items total from cart items for consistent display
    return billCartItems.reduce((total: number, cartItem: any) => {
      const quantity = cartItem?.count ??
                     cartItem?.quantity ??
                     0;
      const linePrice = resolveDisplayPriceWithGst(cartItem) * Number(quantity);
      return total + linePrice;
    }, 0);
  }, [billCartItems]);

  // Helper to parse JSON string locations if needed
  const parseLocationIfString = (location: any) => {
    if (!location) {return null;}
    if (typeof location === 'string') {
      try {
        return JSON.parse(location);
      } catch {
        return location;
      }
    }
    return location;
  };

  // Normalize locations for map display
  const normalizedDeliveryLocation = useMemo(() => {
    // const location = currentOrder?.deliveryLocation || (isPackageOrder ? currentOrder?.dropLocation : null);
    const location = currentOrder?.deliveryLocation; // Commented out package order dropLocation
    const parsedLocation = parseLocationIfString(location);
    const normalized = normalizeCoordinate(parsedLocation) || normalizeCoordinate({
      latitude: currentOrder?.customerLatitude as number | string | null,
      longitude: currentOrder?.customerLongitude as number | string | null,
    });

    // Suppress warning when location data is missing (common for cancelled orders)
    // Only warn if we have location data but couldn't normalize it for active orders
    const hasLocationData = !!(currentOrder?.deliveryLocation ||
                                currentOrder?.customerLatitude ||
                                currentOrder?.customerLongitude);
    const isOrderInactive = status === 'cancelled' || status === 'delivered' || !status || status.trim() === '';

    // Only warn if:
    // 1. We couldn't normalize the location
    // 2. Location data exists (we expected to normalize it)
    // 3. Order is active (not cancelled/delivered/empty status)
    if (!normalized && hasLocationData && !isOrderInactive) {
      console.warn('⚠️ LiveTracking: Could not normalize delivery location', {
        deliveryLocation: currentOrder?.deliveryLocation,
        // dropLocation: currentOrder?.dropLocation, // Commented out
        customerLatitude: currentOrder?.customerLatitude,
        customerLongitude: currentOrder?.customerLongitude,
        orderStatus: status,
      });
    }
    // No warning if location data is missing - this is expected for cancelled/incomplete orders

    return normalized;
  }, [currentOrder?.deliveryLocation, /* currentOrder?.dropLocation, */ currentOrder?.customerLatitude, currentOrder?.customerLongitude, status /* , isPackageOrder */]); // Commented out package order dependencies

  const normalizedPickupLocation = useMemo(() => {
    const parsedLocation = parseLocationIfString(currentOrder?.pickupLocation);
    const normalized = normalizeCoordinate(parsedLocation);

    if (!normalized && currentOrder?.pickupLocation) {
      console.warn('⚠️ LiveTracking: Could not normalize pickup location', currentOrder?.pickupLocation);
    }

    return normalized;
  }, [currentOrder?.pickupLocation]);

  const normalizedDeliveryPersonLocation = useMemo(() => {
    // Try multiple possible sources for delivery person location
    const sources = [
      currentOrder?.deliveryPersonLocation,
      currentOrder?.deliveryPartner?.liveLocation,
    ];

    for (const source of sources) {
      const parsedLocation = parseLocationIfString(source);
      const normalized = normalizeCoordinate(parsedLocation);
      if (normalized) {
        return normalized;
      }
    }

    // If no valid location is available, log once for debugging and return null.
    return null;
  }, [currentOrder?.deliveryPersonLocation, currentOrder?.deliveryPartner?.liveLocation]);

  return (
    <SafeAreaView style={{ flex: 1 }} edges={['top']}>
      <View style={styles.container}>
        <LiveHeader type="Customer" title={msg} secondTitle={time} />
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={[styles.scrollContent, { paddingBottom: insets.bottom + 150 }]}>

        <LiveMap
          iconColor={highlightIconColor}
          deliveryLocation={normalizedDeliveryLocation}
          pickupLocation={normalizedPickupLocation}
          deliveryPersonLocation={normalizedDeliveryPersonLocation}
          hasAccepted={currentOrder?.status === 'confirmed' || currentOrder?.status === 'assigned'}
          hasPickedUp={currentOrder?.status === 'arriving' || currentOrder?.status === 'picked'}
        />

        {/* Live Status Card - Show ETA, Distance, and Status for all orders */}
        {status !== 'cancelled' && status !== 'delivered' && (
          <View style={styles.liveStatusCard}>
            <View style={styles.liveStatusHeader}>
              <Icon name="map-marker-path" size={RFValue(18)} color={colors.primaryBlue} />
              <CustomText variant="h7" fontFamily={Fonts.Bold} style={styles.liveStatusTitle}>
                Live Tracking
              </CustomText>
            </View>
            <View style={styles.liveStatusContent}>
              {etaMinutes !== null && (
                <View style={styles.liveStatusItem}>
                  <Icon name="clock-outline" size={RFValue(16)} color={colors.accentYellow} />
                  <View style={styles.liveStatusTextContainer}>
                    <CustomText variant="h9" fontFamily={Fonts.Medium} style={styles.liveStatusLabel}>
                      ETA
                    </CustomText>
                    <CustomText variant="h8" fontFamily={Fonts.SemiBold}>
                      {etaMinutes === 0 ? 'Arriving now' : `${etaMinutes} ${etaMinutes === 1 ? 'min' : 'mins'}`}
                    </CustomText>
                  </View>
                </View>
              )}
              {liveDistance !== null && driverCoordinate && destinationCoordinate && (
                <View style={styles.liveStatusItem}>
                  <Icon name="map-marker-distance" size={RFValue(16)} color={colors.accentYellow} />
                  <View style={styles.liveStatusTextContainer}>
                    <CustomText variant="h9" fontFamily={Fonts.Medium} style={styles.liveStatusLabel}>
                      Distance
                    </CustomText>
                    <CustomText variant="h8" fontFamily={Fonts.SemiBold}>
                      {liveDistance.toFixed(2)} km
                    </CustomText>
                  </View>
                </View>
              )}
              <View style={styles.liveStatusItem}>
                <Icon name="information-outline" size={RFValue(16)} color={colors.accentYellow} />
                <View style={styles.liveStatusTextContainer}>
                  <CustomText variant="h9" fontFamily={Fonts.Medium} style={styles.liveStatusLabel}>
                    Status
                  </CustomText>
                  <CustomText variant="h8" fontFamily={Fonts.SemiBold}>
                    {status === 'pending' ? 'Waiting for pickup' :
                     status === 'assigned' ? 'On the way to pickup' :
                     status === 'picked' ? 'On the way to delivery' :
                     status === 'confirmed' ? 'On the way' :
                     status === 'out_for_delivery' ? 'Out for delivery' :
                     status === 'prepared' ? 'Preparing order' :
                     status === 'ready' ? 'Ready for pickup' :
                     status.charAt(0).toUpperCase() + status.slice(1)}
                  </CustomText>
                </View>
              </View>
            </View>
          </View>
        )}

        <View style={styles.flexRow}>
          <View style={styles.iconContainer}>
            <Icon
              name={currentOrder?.deliveryPartner ? 'phone' : 'shopping'}
              color={highlightIconColor}
              size={RFValue(20)}
            />
          </View>
          <View style={{ width: '82%' }}>

            <CustomText numberOfLines={1} variant="h7" fontFamily={Fonts.SemiBold}>
              {partnerName || 'We will soon assign delivery partner'}
            </CustomText>

            {partnerPhone && (
              <TouchableOpacity
                activeOpacity={0.75}
                onPress={() => handleCallPartner(partnerPhone)}
                accessibilityRole="button"
                accessibilityLabel="Call delivery partner"
                accessibilityHint="Double tap to open phone dialer"
              >
                <CustomText variant="h7" fontFamily={Fonts.Medium} style={styles.partnerPhoneLink}>
                  {partnerPhone}
                </CustomText>
              </TouchableOpacity>
            )}

            <CustomText variant="h9" fontFamily={Fonts.Medium}>
              {partnerName ? 'For Delivery instructions you can contact here' : msg}
            </CustomText>
          </View>
        </View>

        {/* Order Summary Section - Moved up */}
        <OrderSummary order={currentOrder} iconColor={highlightIconColor} />

        {/* Ordered Items Section - Moved up */}
        {billCartItems && billCartItems.length > 0 && (
          <View style={styles.orderedItemsContainer}>
            <View style={styles.orderedItemsHeader}>
              <View style={styles.iconContainer}>
                <Icon name="shopping" color={highlightIconColor} size={RFValue(20)} />
              </View>
              <View style={{ flex: 1 }}>
                <CustomText variant="h7" fontFamily={Fonts.SemiBold}>
                  Ordered Items ({billCartItems.length})
                </CustomText>
                <CustomText variant="h9" fontFamily={Fonts.Medium}>
                  Items in your order
                </CustomText>
              </View>
            </View>

            {billCartItems.map((cartItem: any, index: number) => {
              // Use the exact same approach as CartScreen - simple and direct
              const key = cartItem?.item?.id || cartItem?.item?._id || index;
              return (
                <OrderItemRow
                  key={key}
                  cartItem={cartItem}
                />
              );
            })}
          </View>
        )}

        <DeliveryDetails details={deliveryDetails} iconColor={highlightIconColor} />

        {/* Bill Details Section */}
        <BillDetails totalItemPrice={billTotalPrice} cartItems={billCartItems} />

        {/* Cancel Order Button - At the end */}
        {canCancel && (
          <View style={styles.cancelButtonContainer}>
            <TouchableOpacity
              style={[
                styles.cancelButton,
                styles.cancelButtonProduct,
              ]}
              onPress={handleCancelOrder}
              disabled={cancelling}
            >
              <Icon name="close-circle" size={RFValue(20)} color="#FFFFFF" />
              <CustomText
                variant="h7"
                fontFamily={Fonts.SemiBold}
                style={styles.cancelButtonText}
              >
                {cancelling ? 'Cancelling...' : 'Cancel Order'}
              </CustomText>
            </TouchableOpacity>
          </View>
        )}

      </ScrollView>

      {/* Cancellation Reason Modal - Only for Product Orders */}
      <CancellationReasonModal
        visible={cancellationReasonModalVisible}
        onClose={() => setCancellationReasonModalVisible(false)}
        onSelectReason={handleCancellationReasonSelect}
        loading={cancelling}
      />

      {/* Cancel Confirmation Modal - Only for Package Orders */}
      <Modal
        visible={cancelModalVisible}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setCancelModalVisible(false)}
      >
        <TouchableWithoutFeedback onPress={() => setCancelModalVisible(false)}>
          <View style={styles.modalOverlay}>
            <TouchableWithoutFeedback onPress={() => {}}>
              <View style={styles.cancelConfirmCard}>
                <View style={styles.cancelIconWrapper}>
                  <IonIcon name="warning-outline" size={RFValue(32)} color={colors.primaryBlue} />
                </View>
                <CustomText variant="h5" fontFamily={Fonts.Bold} style={styles.cancelTitle}>
                  Cancel Order
                </CustomText>
                <CustomText variant="h7" style={styles.cancelMessage}>
                  Are you sure you want to cancel this order.
                </CustomText>
                <View style={styles.cancelActions}>
                  <TouchableOpacity
                    style={[styles.cancelActionButton, styles.cancelSecondaryButton]}
                    onPress={() => setCancelModalVisible(false)}
                  >
                    <CustomText variant="h7" fontFamily={Fonts.Medium} style={styles.cancelSecondaryText}>
                      No, Keep Order
                    </CustomText>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[styles.cancelActionButton, styles.cancelPrimaryButton]}
                    onPress={handleConfirmCancel}
                    disabled={cancelling}
                  >
                    <CustomText variant="h7" fontFamily={Fonts.Medium} style={styles.cancelPrimaryText}>
                      {cancelling ? 'Cancelling...' : 'Yes, Cancel'}
                    </CustomText>
                  </TouchableOpacity>
                </View>
              </View>
            </TouchableWithoutFeedback>
          </View>
        </TouchableWithoutFeedback>
      </Modal>

      {/* Cancel Success Modal */}
      <Modal
        visible={cancelSuccessVisible}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setCancelSuccessVisible(false)}
      >
        <TouchableWithoutFeedback onPress={() => setCancelSuccessVisible(false)}>
          <View style={styles.modalOverlay}>
            <TouchableWithoutFeedback onPress={() => {}}>
              <View style={styles.cancelSuccessCard}>
                <View style={styles.successIconWrapper}>
                  <IonIcon name="checkmark-circle-outline" size={RFValue(32)} color={colors.primaryBlue} />
                </View>
                <CustomText variant="h5" fontFamily={Fonts.Bold} style={styles.successTitle}>
                  Order Cancelled
                </CustomText>
                <CustomText variant="h7" style={styles.successMessage}>
                  Your order has been cancelled successfully.
                </CustomText>
                <TouchableOpacity
                  style={styles.successButton}
                  onPress={() => setCancelSuccessVisible(false)}
                >
                  <CustomText variant="h7" fontFamily={Fonts.Medium} style={styles.successButtonText}>
                    Got it
                  </CustomText>
                </TouchableOpacity>
              </View>
            </TouchableWithoutFeedback>
          </View>
        </TouchableWithoutFeedback>
      </Modal>
    </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.secondary,
  },
  scrollContent: {
    backgroundColor: colors.white,
    padding: 15,
  },
  flexRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    width: '100%',
    borderRadius: 15,
    marginTop: 15,
    paddingVertical: 10,
    backgroundColor: colors.white,
    padding: 10,
    borderBottomWidth: 0.7,
    borderColor: Colors.border,
  },
  partnerPhoneLink: {
    color: colors.primaryBlue,
    textDecorationLine: 'underline',
  },
  iconContainer: {
    backgroundColor: Colors.backgroundSecondary,
    borderRadius: 100,
    padding: 10,
    justifyContent: 'center',
    alignItems: 'center',
  },
  cancelButtonContainer: {
    marginVertical: 16,
    marginHorizontal: 0,
  },
  cancelButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 8,
    gap: 8,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  cancelButtonPackage: {
    backgroundColor: colors.primaryBlue,
  },
  cancelButtonProduct: {
    backgroundColor: colors.accentYellow,
  },
  cancelButtonText: {
    color: '#FFFFFF',
    fontWeight: '600',
  },
  liveStatusCard: {
    backgroundColor: colors.white,
    borderRadius: 15,
    padding: 15,
    marginVertical: 10,
    borderWidth: 1,
    borderColor: Colors.border,
    shadowColor: colors.black,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  liveStatusHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 10,
    paddingBottom: 10,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  liveStatusTitle: {
    color: colors.primaryBlue,
  },
  liveStatusContent: {
    gap: 8,
  },
  liveStatusItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  liveStatusTextContainer: {
    flex: 1,
  },
  liveStatusLabel: {
    opacity: 0.7,
    marginBottom: 1,
  },
  // Ordered Items Styles
  orderedItemsContainer: {
    backgroundColor: colors.white,
    borderRadius: 15,
    marginTop: 5, // Reduced from 15 to 5
    marginBottom: 15,
    paddingVertical: 10,
    borderBottomWidth: 0.7,
    borderColor: Colors.border,
  },
  orderedItemsHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    padding: 10,
    borderBottomWidth: 0.7,
    borderColor: Colors.border,
    marginBottom: 10,
  },
  orderedItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 10,
    marginHorizontal: 10,
    marginVertical: 5,
    backgroundColor: colors.white,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: Colors.border,
    shadowColor: colors.black,
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  itemImageContainer: {
    backgroundColor: Colors.backgroundSecondary,
    padding: 10,
    borderRadius: 15,
    width: 60, // Fixed width like CartScreen
    height: 60, // Fixed height like CartScreen
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
    overflow: 'hidden', // Ensure images don't overflow the container
  },
  itemImage: {
    width: 40, // Same as CartScreen
    height: 40, // Same as CartScreen
    borderRadius: 8, // Add slight border radius for better appearance
  },
  placeholderImage: {
    width: 40, // Same as CartScreen
    height: 40, // Same as CartScreen
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: Colors.backgroundSecondary,
    borderRadius: 8,
  },
  placeholderText: {
    fontSize: 8, // Same as CartScreen
    opacity: 0.6,
    color: Colors.disabled,
    textAlign: 'center',
    marginTop: 2,
  },
  itemDetails: {
    flex: 1,
    marginRight: 12,
  },
  itemName: {
    marginBottom: 4,
    lineHeight: 20,
  },
  itemPriceRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  itemPrice: {
    color: colors.primaryBlue,
    fontWeight: '600',
  },
  originalPrice: {
    textDecorationLine: 'line-through',
    opacity: 0.6,
  },
  quantityContainer: {
    alignItems: 'center',
    minWidth: 50,
  },
  quantityBadge: {
    backgroundColor: colors.accentYellow,
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 6,
    marginBottom: 4,
  },
  quantityText: {
    color: colors.white,
    fontSize: RFValue(12),
  },
  quantityLabel: {
    opacity: 0.7,
    fontSize: RFValue(10),
  },
  // Cancel Modal Styles
  modalOverlay: {
    flex: 1,
    backgroundColor: colors.blackOpacity40,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  cancelConfirmCard: {
    backgroundColor: colors.white,
    borderRadius: 20,
    padding: 24,
    alignItems: 'center',
    width: '100%',
    maxWidth: 340,
    alignSelf: 'center',
    shadowColor: colors.black,
    shadowOffset: {
      width: 0,
      height: 10,
    },
    shadowOpacity: 0.25,
    shadowRadius: 20,
    elevation: 10,
  },
  cancelIconWrapper: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: colors.primaryBlueOpacity10,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
  },
  cancelTitle: {
    color: colors.primaryBlue,
    marginBottom: 8,
    textAlign: 'center',
  },
  cancelMessage: {
    textAlign: 'center',
    opacity: 0.8,
    marginBottom: 24,
    lineHeight: 22,
  },
  cancelActions: {
    width: '100%',
    flexDirection: 'row',
    gap: 12,
  },
  cancelActionButton: {
    flex: 1,
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cancelSecondaryButton: {
    backgroundColor: colors.lightBlue,
    borderWidth: 1,
    borderColor: colors.primaryBlue,
  },
  cancelPrimaryButton: {
    backgroundColor: colors.primaryBlue,
  },
  cancelSecondaryText: {
    color: colors.primaryBlue,
  },
  cancelPrimaryText: {
    color: colors.white,
  },
  // Success Modal Styles
  cancelSuccessCard: {
    backgroundColor: colors.white,
    borderRadius: 20,
    padding: 24,
    alignItems: 'center',
    width: '100%',
    maxWidth: 340,
    alignSelf: 'center',
    shadowColor: colors.black,
    shadowOffset: {
      width: 0,
      height: 10,
    },
    shadowOpacity: 0.25,
    shadowRadius: 20,
    elevation: 10,
  },
  successIconWrapper: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: colors.primaryBlueOpacity10,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
  },
  successTitle: {
    color: colors.primaryBlue,
    marginBottom: 8,
    textAlign: 'center',
  },
  successMessage: {
    textAlign: 'center',
    opacity: 0.8,
    marginBottom: 24,
    lineHeight: 22,
  },
  successButton: {
    width: '100%',
    backgroundColor: colors.primaryBlue,
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  successButtonText: {
    color: colors.white,
  },
});

export default withLiveStatus(LiveTracking);
