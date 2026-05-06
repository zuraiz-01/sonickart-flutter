import {
  View,
  StyleSheet,
  ScrollView,
  Image,
  Platform,
  TouchableOpacity,
  Alert,
  Modal,
  ActivityIndicator,
  TouchableWithoutFeedback,
  StatusBar,
  TextInput,
} from 'react-native';
import React, { FC, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import CustomHeader from '@components/ui/CustomHeader';
import { Colors, Fonts } from '@utils/Constants';
import OrderList from './OrderList';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import CustomText from '@components/ui/CustomText';
import { useCartStore } from '@state/cartStore';
import BillDetails from './BillDetails';
import { useAuthStore } from '@state/authStore';
import ArrowButton from '@components/ui/ArrowButton';
import { navigate, resetAndNavigate } from '@utils/NavigationUtils';
import { createOrder, fetchCustomerOrders } from '@service/orderService';
import { geocodeAddress } from '@service/mapService';
import { getAddresses, SavedAddress, resolveVendorByCoordinates } from '@service/addressService';
import { updateUserLocation } from '@service/authService';
import colors from '../../theme/colors';
import Geolocation from '@react-native-community/geolocation';
import ActionOptionsModal from '@components/ui/ActionOptionsModal';
import CustomAlert from '@components/ui/CustomAlert';
import { useCustomAlert } from '../../hooks/useCustomAlert';
import { useDeliverySettingsStore } from '@state/deliverySettingsStore';
import { useLocationStore } from '@state/locationStore';
import { useFocusEffect } from '@react-navigation/native';
import { RFValue } from 'react-native-responsive-fontsize';
import { calculateOrderBreakdown } from '@utils/orderCalculations';
import {
  fetchCoupons,
  getCouponByCode,
  type CouponDocument,
  validateCouponForCart,
} from '@service/couponService';
import {
  calculateCheckoutTotals,
} from '@utils/checkoutTotals';

type ResolvedVendorOption = {
  vendorId: string | null;
  branchId: string | null;
  label?: string | null;
};

type CouponEligibilityState = {
  isEligible: boolean;
  message: string | null;
};

let lastCheckoutScrollOffset = 0;

const normalizeIdentifier = (value: any) => {
  if (value === null || value === undefined) {
    return null;
  }

  const normalized = String(value).trim();
  return normalized ? normalized : null;
};

const uniqueIdentifiers = (values: Array<string | null>) =>
  [...new Set(values.filter((value): value is string => Boolean(value)))];

const resolveVendorIdentifier = (value: any) =>
  uniqueIdentifiers([
    normalizeIdentifier(value?.vendorId),
    normalizeIdentifier(value?.vendor_id),
    normalizeIdentifier(value?.id),
    normalizeIdentifier(value?.vendor?.id),
    normalizeIdentifier(value?.vendor?.vendorId),
  ])[0] ?? null;

const resolveBranchIdentifier = (value: any) =>
  uniqueIdentifiers([
    normalizeIdentifier(value?.branchId),
    normalizeIdentifier(value?.branch_id),
    normalizeIdentifier(value?.branch?.id),
    normalizeIdentifier(value?.branch?.branchId),
    normalizeIdentifier(value?.id),
    normalizeIdentifier(value?.branch),
  ])[0] ?? null;

const collectCartVendorContext = (cartItems: any[]) => {
  const vendorIds = uniqueIdentifiers(
    cartItems.flatMap((cartItem) => {
      const product = cartItem?.item ?? {};
      const vendor = product?.vendor ?? cartItem?.vendor ?? {};

      return [
        normalizeIdentifier(product?.vendorId),
        normalizeIdentifier(product?.vendor_id),
        normalizeIdentifier(product?.vendor?.id),
        normalizeIdentifier(product?.vendor?.vendorId),
        normalizeIdentifier(vendor?.id),
        normalizeIdentifier(vendor?.vendorId),
        normalizeIdentifier(cartItem?.vendorId),
        normalizeIdentifier(cartItem?.vendor_id),
      ];
    })
  );

  const branchIds = uniqueIdentifiers(
    cartItems.flatMap((cartItem) => {
      const product = cartItem?.item ?? {};
      const branch = product?.branch ?? cartItem?.branch ?? {};

      return [
        normalizeIdentifier(product?.branchId),
        normalizeIdentifier(product?.branch_id),
        normalizeIdentifier(product?.branch?.id),
        normalizeIdentifier(product?.branch?.branchId),
        normalizeIdentifier(branch?.id),
        normalizeIdentifier(branch?.branchId),
        normalizeIdentifier(cartItem?.branchId),
        normalizeIdentifier(cartItem?.branch_id),
      ];
    })
  );

  return { vendorIds, branchIds };
};

const buildResolvedVendorOptions = (vendorResolution: any): ResolvedVendorOption[] => {
  const options: ResolvedVendorOption[] = [];

  if (Array.isArray(vendorResolution?.vendors)) {
    vendorResolution.vendors.forEach((vendor: any) => {
      options.push({
        vendorId: resolveVendorIdentifier(vendor),
        branchId: resolveBranchIdentifier(vendor),
        label: vendor?.branchName ?? vendor?.name ?? null,
      });
    });
  }

  if (
    options.length === 0 &&
    (vendorResolution?.vendorId || vendorResolution?.branchId)
  ) {
    options.push({
      vendorId: resolveVendorIdentifier(vendorResolution),
      branchId: resolveBranchIdentifier(vendorResolution),
      label: vendorResolution.branchName ?? null,
    });
  }

  if (Array.isArray(vendorResolution?.vendorIds)) {
    vendorResolution.vendorIds.forEach((vendorId: string) => {
      options.push({
        vendorId: normalizeIdentifier(vendorId),
        branchId: null,
        label: null,
      });
    });
  }

  const seen = new Set<string>();
  return options.filter((option) => {
    const key = `${option.vendorId ?? ''}|${option.branchId ?? ''}`;
    if ((!option.vendorId && !option.branchId) || seen.has(key)) {
      return false;
    }

    seen.add(key);
    return true;
  });
};

const resolveVendorIdStringFromResolution = (vendorResolution: any) => {
  const vendorIds = uniqueIdentifiers(
    buildResolvedVendorOptions(vendorResolution).map((option) => option.vendorId)
  );

  return vendorIds.length > 0 ? vendorIds.join(',') : null;
};

const resolveCartProductId = (cartItem: any) =>
  normalizeIdentifier(cartItem?._id) ||
  normalizeIdentifier(cartItem?.id) ||
  normalizeIdentifier(cartItem?.item?.id) ||
  normalizeIdentifier(cartItem?.item?._id) ||
  normalizeIdentifier(cartItem?.productId) ||
  normalizeIdentifier(cartItem?.item?.productId);

const collectCartItemVendorIds = (cartItem: any) => {
  const product = cartItem?.item ?? {};
  const vendor = product?.vendor ?? cartItem?.vendor ?? {};

  return uniqueIdentifiers([
    normalizeIdentifier(product?.vendorId),
    normalizeIdentifier(product?.vendor_id),
    normalizeIdentifier(product?.vendor?.id),
    normalizeIdentifier(product?.vendor?.vendorId),
    normalizeIdentifier(vendor?.id),
    normalizeIdentifier(vendor?.vendorId),
    normalizeIdentifier(cartItem?.vendorId),
    normalizeIdentifier(cartItem?.vendor_id),
  ]);
};

const collectCartItemBranchIds = (cartItem: any) => {
  const product = cartItem?.item ?? {};
  const branch = product?.branch ?? cartItem?.branch ?? {};

  return uniqueIdentifiers([
    normalizeIdentifier(product?.branchId),
    normalizeIdentifier(product?.branch_id),
    normalizeIdentifier(product?.branch?.id),
    normalizeIdentifier(product?.branch?.branchId),
    normalizeIdentifier(branch?.id),
    normalizeIdentifier(branch?.branchId),
    normalizeIdentifier(cartItem?.branchId),
    normalizeIdentifier(cartItem?.branch_id),
  ]);
};

const isCartItemAvailableForVendorResolution = (
  cartItem: any,
  resolvedOptions: ResolvedVendorOption[]
) => {
  if (resolvedOptions.length === 0) {
    return false;
  }

  const cartVendorIds = collectCartItemVendorIds(cartItem);
  const cartBranchIds = collectCartItemBranchIds(cartItem);

  if (cartVendorIds.length === 0 && cartBranchIds.length === 0) {
    // No vendor scope in the cart item means we cannot prove it is unavailable.
    return true;
  }

  return resolvedOptions.some((option) => {
    if (option.vendorId && cartVendorIds.includes(option.vendorId)) {
      return true;
    }

    if (option.branchId && cartBranchIds.includes(option.branchId)) {
      return true;
    }

    return false;
  });
};

const findUnavailableCartItems = (cartItems: any[], vendorResolution: any) => {
  if (!vendorResolution) {
    return [];
  }

  const resolvedOptions = buildResolvedVendorOptions(vendorResolution);

  return cartItems.filter(
    (cartItem) =>
      !isCartItemAvailableForVendorResolution(cartItem, resolvedOptions)
  );
};

const resolveCheckoutVendorContext = (cartItems: any[], vendorResolution: any) => {
  const cartContext = collectCartVendorContext(cartItems);
  const resolvedOptions = buildResolvedVendorOptions(vendorResolution);

  if (resolvedOptions.length === 0) {
    return {
      error:
        'Products in your cart are not available at this selected address. Please choose a different address or add products available near this location.',
    };
  }

  if (cartContext.vendorIds.length > 1 || cartContext.branchIds.length > 1) {
    const fallbackOption = resolvedOptions[0];
    return {
      // Allow multi-vendor carts but keep a top-level fallback vendor for backend compatibility.
      vendorId: fallbackOption?.vendorId ?? cartContext.vendorIds[0] ?? null,
      branchId: fallbackOption?.branchId ?? cartContext.branchIds[0] ?? null,
      source: 'cart-multi-vendor-fallback',
    };
  }

  const cartVendorId = cartContext.vendorIds[0] ?? null;
  const cartBranchId = cartContext.branchIds[0] ?? null;

  if (cartVendorId || cartBranchId) {
    if (resolvedOptions.length === 0) {
      return {
        vendorId: cartVendorId,
        branchId: cartBranchId,
        source: 'cart-direct',
      };
    }

    const matchedOption = resolvedOptions.find((option) => {
      if (cartVendorId && option.vendorId === cartVendorId) {
        return true;
      }

      if (cartBranchId && option.branchId === cartBranchId) {
        return true;
      }

      return false;
    });

    if (!matchedOption) {
      return {
        vendorId: cartVendorId,
        branchId: cartBranchId,
        source: 'cart-priority',
      };
    }

    return {
      vendorId: matchedOption.vendorId ?? cartVendorId,
      branchId: matchedOption.branchId ?? cartBranchId,
      source: 'cart-match',
    };
  }

  const fallbackOption = resolvedOptions[0];
  if (!fallbackOption) {
    return {
      error:
        'We could not find any vendor for your selected address. Please try a different address or location.',
    };
  }

  return {
    vendorId: fallbackOption.vendorId,
    branchId: fallbackOption.branchId,
    source: 'address-resolution',
  };
};

const buildOrderItemsPayload = (
  cartItems: any[],
  fallbackVendorId: string | null,
  fallbackBranchId: string | null
) =>
  cartItems.map((cartItem) => {
    const product = cartItem?.item ?? {};
    const vendor = product?.vendor ?? cartItem?.vendor ?? {};
    const branch = product?.branch ?? cartItem?.branch ?? {};

    const productId =
      normalizeIdentifier(cartItem?._id) ||
      normalizeIdentifier(cartItem?.id) ||
      normalizeIdentifier(product?.id) ||
      normalizeIdentifier(product?._id) ||
      normalizeIdentifier(cartItem?.productId) ||
      normalizeIdentifier(product?.productId);

    const itemVendorId =
      uniqueIdentifiers([
        normalizeIdentifier(product?.vendorId),
        normalizeIdentifier(product?.vendor_id),
        normalizeIdentifier(product?.vendor?.id),
        normalizeIdentifier(product?.vendor?.vendorId),
        normalizeIdentifier(vendor?.id),
        normalizeIdentifier(vendor?.vendorId),
        normalizeIdentifier(cartItem?.vendorId),
        normalizeIdentifier(cartItem?.vendor_id),
        fallbackVendorId,
      ])[0] ?? null;

    const itemBranchId =
      uniqueIdentifiers([
        normalizeIdentifier(product?.branchId),
        normalizeIdentifier(product?.branch_id),
        normalizeIdentifier(product?.branch?.id),
        normalizeIdentifier(product?.branch?.branchId),
        normalizeIdentifier(branch?.id),
        normalizeIdentifier(branch?.branchId),
        normalizeIdentifier(cartItem?.branchId),
        normalizeIdentifier(cartItem?.branch_id),
        fallbackBranchId,
      ])[0] ?? null;

    return {
      id: productId,
      item: productId,
      productId,
      product: productId,
      product_id: productId,
      count: cartItem?.count,
      quantity: cartItem?.count,
      vendorId: itemVendorId ?? undefined,
      vendor_id: itemVendorId ?? undefined,
      vendor: itemVendorId ?? undefined,
      branchId: itemBranchId ?? undefined,
      branch_id: itemBranchId ?? undefined,
      branch: itemBranchId ?? undefined,
    };
  });

/**
 * Checkout and order-placement screen for regular product orders.
 * Handles address context, vendor resolution, bill breakdown, COD/Online payment, and order creation.
 */
const ProductOrder: FC = () => {
  const insets = useSafeAreaInsets();
  const scrollViewRef = useRef<ScrollView | null>(null);
  const { cart, clearCart, removeItemsCompletely } = useCartStore();
  const { user, setCurrentOrder, currentOrder, setUser } = useAuthStore();
  const productRadiusKm = useDeliverySettingsStore(
    (state) => state.settings.productRadiusKm
  );
  const freeDeliveryThreshold = useDeliverySettingsStore(
    (state) => state.settings.freeDeliveryThreshold
  );
  const setSelectedVendorIdGlobal = useLocationStore((state) => state.setSelectedVendorId);
  const selectedAddress = useLocationStore((state) => state.selectedAddress);
  const setSelectedAddress = useLocationStore((state) => state.setSelectedAddress);
  const { alertConfig, isVisible: alertVisible, hideAlert, showAlert, showError } = useCustomAlert();
  const [loading, setLoading] = useState(false);
  const [deliveryAddress, setDeliveryAddress] = useState(user?.address || '');
  const [addressModalVisible, setAddressModalVisible] = useState(false);
  const [addressLoading] = useState(false);
  const [addresses, setAddresses] = useState<SavedAddress[]>([]);
  const [selectingAddressId, setSelectingAddressId] = useState<number | null>(null);
  const [initialAddressesLoaded, setInitialAddressesLoaded] = useState(false);
  const addressesInitializedRef = useRef(false);
  const [paymentOptionsVisible, setPaymentOptionsVisible] = useState(false);
  const [addressConfirmVisible, setAddressConfirmVisible] = useState(false);
  const [paymentMode, setPaymentMode] = useState<'COD' | 'Online'>('COD'); // Payment mode state
  const [footerHeight, setFooterHeight] = useState(0);
  const [orderAlertVisible, setOrderAlertVisible] = useState(false);
  const [orderBeingPlaced, setOrderBeingPlaced] = useState(false);
  const [couponModalVisible, setCouponModalVisible] = useState(false);
  const [availableCoupons, setAvailableCoupons] = useState<CouponDocument[]>([]);
  const [couponCodeInput, setCouponCodeInput] = useState('');
  const [selectedCoupon, setSelectedCoupon] = useState<CouponDocument | null>(null);
  const [couponsLoading, setCouponsLoading] = useState(false);
  const [applyingCoupon, setApplyingCoupon] = useState(false);
  const [couponFeedback, setCouponFeedback] = useState<string | null>(null);
  const suppressUnavailableCartRedirectRef = useRef(false);
  const checkoutTotals = useMemo(
    () => calculateCheckoutTotals(cart, selectedCoupon),
    [cart, selectedCoupon]
  );
  const totalItemPrice = checkoutTotals.itemsTotal;
  const couponEligibilityMap = useMemo(() => {
    const nextMap = new Map<string, CouponEligibilityState>();

    availableCoupons.forEach((coupon) => {
      const result = validateCouponForCart(coupon, {
        orderAmount: totalItemPrice,
        userRef: user,
        cartItems: cart,
      });

      nextMap.set(coupon.id, {
        isEligible: result.valid,
        message: result.valid ? null : result.message,
      });
    });

    return nextMap;
  }, [availableCoupons, cart, totalItemPrice, user]);
  const deliveryRecipient = useMemo(
    () =>
      selectedAddress?.fullName?.trim() ||
      user?.name?.trim() ||
      'Select delivery address',
    [selectedAddress?.fullName, user?.name]
  );
  const deliveryAddressPreview = useMemo(
    () =>
      selectedAddress?.address?.trim() ||
      deliveryAddress?.trim() ||
      user?.address?.trim() ||
      'Add your delivery address to continue',
    [deliveryAddress, selectedAddress?.address, user?.address]
  );
  const freeDeliveryAmountLeft = useMemo(() => {
    const remaining = freeDeliveryThreshold - checkoutTotals.totalBeforeDiscount;
    return remaining > 0 ? Number(remaining.toFixed(2)) : 0;
  }, [checkoutTotals.totalBeforeDiscount, freeDeliveryThreshold]);

  // Handle navigation when cart becomes empty
  const handleCartEmpty = useCallback(() => {
    lastCheckoutScrollOffset = 0;
    resetAndNavigate('ProductDashboard');
  }, []);

  // Check if cart is empty and navigate back to appropriate screen
  // Only redirect if cart becomes empty after initial load (user interaction)
  const [initialLoad, setInitialLoad] = useState(true);

  useEffect(() => {
    if (!initialLoad) {
      return;
    }

    // Allow some time for the cart to be populated if coming from "Buy Now"
    const timer = setTimeout(() => {
      setInitialLoad(false);
      if (cart.length === 0 || checkoutTotals.grandTotal <= 0) {
        handleCartEmpty();
      }
    }, 200);

    return () => clearTimeout(timer);
  }, [cart.length, checkoutTotals.grandTotal, handleCartEmpty, initialLoad]);

  useEffect(() => {
    if (
      !initialLoad &&
      !orderBeingPlaced &&
      (cart.length === 0 || checkoutTotals.grandTotal <= 0)
    ) {
      if (suppressUnavailableCartRedirectRef.current) {
        return;
      }
      handleCartEmpty();
    }
  }, [
    cart.length,
    checkoutTotals.grandTotal,
    handleCartEmpty,
    initialLoad,
    orderBeingPlaced,
  ]);

  useEffect(() => {
    if (selectedCoupon && checkoutTotals.couponError) {
      setSelectedCoupon(null);
      setCouponFeedback(checkoutTotals.couponError);
    }
  }, [checkoutTotals.couponError, selectedCoupon]);

  useEffect(() => {
    if (cart.length === 0) {
      setSelectedCoupon(null);
      setCouponCodeInput('');
      setAvailableCoupons([]);
      setCouponFeedback(null);
    }
  }, [cart.length]);

  // Automatically clear currentOrder if it's delivered or cancelled
  // This ensures users can place new orders immediately after delivery
  // This runs whenever currentOrder changes, so delivered orders are cleared automatically
  useEffect(() => {
    if (currentOrder !== null && currentOrder?.orderType !== 'package') {
      const orderStatus = (
        currentOrder?.deliveryStatus ||
        (currentOrder as any)?.delivery_status ||
        currentOrder?.status ||
        ''
      ).toLowerCase();

      // Automatically clear delivered or cancelled orders to allow new orders
      if (orderStatus === 'delivered' || orderStatus === 'cancelled') {
        // Use setTimeout to avoid state update conflicts
        const timer = setTimeout(() => {
          setCurrentOrder(null);
        }, 100);
        return () => clearTimeout(timer);
      }
    }
  }, [currentOrder, setCurrentOrder]);

  const toNumberOrNull = (value: any) => {
    if (value === null || value === undefined) {
      return null;
    }
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  };

  const hasValidCoordinates = (lat?: number | null, lng?: number | null) =>
    typeof lat === 'number' &&
    !Number.isNaN(lat) &&
    typeof lng === 'number' &&
    !Number.isNaN(lng);

  const deriveAddressFromUser = (): SavedAddress | null => {
    if (!user?.address) {
      return null;
    }

    const latitude = toNumberOrNull(user?.liveLocation?.latitude) ?? NaN;
    const longitude = toNumberOrNull(user?.liveLocation?.longitude) ?? NaN;

    return {
      id: -1,
      fullName: user?.name || 'Customer',
      contactNumber: user?.phone || '',
      address: user.address,
      latitude,
      longitude,
      userId: (user?.id as number) || (user?._id as number) || 0,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
  };

  const determineDefaultAddress = (list: SavedAddress[]): SavedAddress | null => {
    if (!list?.length) {
      return null;
    }

    if (user?.address) {
      const normalized = user.address.trim().toLowerCase();
      const matched = list.find(
        (addr) => addr.address?.trim()?.toLowerCase() === normalized
      );
      if (matched) {
        return matched;
      }
    }

    return list[0];
  };

  const fetchAddressesFromServer = async (): Promise<SavedAddress[]> => {
    try {
      const savedAddresses = await getAddresses();
      setAddresses(savedAddresses);
      return savedAddresses;
    } catch (error) {
      console.error('Fetch addresses error', error);
      throw error;
    }
  };

  const requestLiveCoordinates = async (): Promise<
    { latitude: number; longitude: number } | null
  > => {
    try {
      Geolocation.requestAuthorization?.();
      const currentCoords = await new Promise<{ latitude: number; longitude: number }>(
        (resolve, reject) => {
          Geolocation.getCurrentPosition(
            ({ coords }) => resolve({ latitude: coords.latitude, longitude: coords.longitude }),
            (error) => reject(error),
            { enableHighAccuracy: true, timeout: 15000, maximumAge: 5000 }
          );
        }
      );
      return currentCoords;
    } catch (error) {
      console.warn('Unable to fetch live location', error);
      return null;
    }
  };

  const ensureAddressContext = async (): Promise<SavedAddress> => {
    if (!initialAddressesLoaded) {
      try {
        await fetchAddressesFromServer();
      } catch (error) {
        console.error('Address preload failed', error);
      } finally {
        setInitialAddressesLoaded(true);
      }
    }

    let activeAddress = selectedAddress;

    if (!activeAddress && addresses.length) {
      activeAddress = determineDefaultAddress(addresses);
    }

    if (!activeAddress) {
      activeAddress = deriveAddressFromUser();
    }

    if (!activeAddress) {
      showError(
        'Add an address',
        'Please add or select a delivery address before placing the order.'
      );
      throw new Error('ADDRESS_REQUIRED');
    }

    const sanitizedAddress = activeAddress.address?.trim();
    if (!sanitizedAddress) {
      showError(
        'Add an address',
        'Please add or select a delivery address before placing the order.'
      );
      throw new Error('ADDRESS_REQUIRED');
    }

    let latitude = toNumberOrNull(activeAddress.latitude);
    let longitude = toNumberOrNull(activeAddress.longitude);

    if (!hasValidCoordinates(latitude, longitude)) {
      const liveCoords = await requestLiveCoordinates();
      if (liveCoords) {
        latitude = liveCoords.latitude;
        longitude = liveCoords.longitude;
      }
    }

    if (!hasValidCoordinates(latitude, longitude)) {
      showError(
        'Location required',
        'Please enable location services so we can deliver to the right place.'
      );
      throw new Error('LOCATION_REQUIRED');
    }

    const resolvedFullName = activeAddress.fullName?.trim() || user?.name || 'Customer';
    const resolvedPhone = activeAddress.contactNumber?.trim() || user?.phone || '';

    await updateUserLocation(
      {
        address: sanitizedAddress,
        liveLocation: {
          latitude,
          longitude,
        },
      },
      setUser
    );

    const normalizedAddress: SavedAddress = {
      ...activeAddress,
      fullName: resolvedFullName,
      contactNumber: resolvedPhone,
      address: sanitizedAddress,
      latitude: latitude!,
      longitude: longitude!,
      userId: activeAddress.userId || (user?.id as number) || (user?._id as number) || 0,
      createdAt: activeAddress.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    setSelectedAddress(normalizedAddress);
    setDeliveryAddress(sanitizedAddress);

    return normalizedAddress;
  };

  useEffect(() => {
    setDeliveryAddress(user?.address || '');
  }, [user?.address]);

  useEffect(() => {
    if (addressesInitializedRef.current) {
      return;
    }
    addressesInitializedRef.current = true;

    const initializeAddresses = async () => {
      try {
        const saved = await fetchAddressesFromServer();
        if (!selectedAddress) {
          const defaultAddress = determineDefaultAddress(saved);
          if (defaultAddress) {
            setSelectedAddress(defaultAddress);
            setDeliveryAddress(defaultAddress.address);
            return;
          }
        }

        if (!selectedAddress) {
          const fallback = deriveAddressFromUser();
          if (fallback) {
            setSelectedAddress(fallback);
            setDeliveryAddress(fallback.address);
          }
        }
      } catch (error) {
        console.error('Initial address load error', error);
      } finally {
        setInitialAddressesLoaded(true);
      }
    };

    initializeAddresses();
    // Runs once for initial address bootstrap; avoids ref churn loops from helper functions.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.address, selectedAddress]);

  const loadCouponsForCart = useCallback(async () => {
    if (totalItemPrice <= 0) {
      setAvailableCoupons([]);
      return;
    }

    setCouponsLoading(true);
    try {
      const coupons = await fetchCoupons(totalItemPrice, user, cart);
      setAvailableCoupons(coupons);
    } catch (error) {
      console.log('Coupon fetch error', error);
      setCouponFeedback(
        error instanceof Error && error.message
          ? error.message
          : 'Coupons could not be loaded right now.'
      );
      setAvailableCoupons([]);
    } finally {
      setCouponsLoading(false);
    }
  }, [cart, totalItemPrice, user]);

  const openCouponModal = useCallback(() => {
    setCouponModalVisible(true);
    setCouponFeedback(null);
    loadCouponsForCart();
  }, [loadCouponsForCart]);

  const closeCouponModal = useCallback(() => {
    setCouponModalVisible(false);
  }, []);

  const applyCouponCode = useCallback(
    async (couponCode?: string) => {
      const nextCode = String(couponCode ?? couponCodeInput).trim().toUpperCase();

      if (!nextCode) {
        setCouponFeedback('Enter a coupon code first.');
        return;
      }

      if (totalItemPrice <= 0) {
        setCouponFeedback('Add items before applying a coupon.');
        return;
      }

      setApplyingCoupon(true);
      setCouponFeedback(null);

      try {
        const result = await getCouponByCode(
          nextCode,
          totalItemPrice,
          user,
          cart
        );
        if (!result.valid) {
          setCouponFeedback(result.message);
          return;
        }

        setSelectedCoupon(result.coupon);
        setCouponCodeInput(result.coupon.code);
        setCouponFeedback(`${result.coupon.code} applied successfully.`);
        setCouponModalVisible(false);
      } catch (error) {
        console.log('Coupon apply error', error);
        setCouponFeedback(
          error instanceof Error && error.message
            ? error.message
            : 'Failed to apply this coupon right now.'
        );
      } finally {
        setApplyingCoupon(false);
      }
    },
    [cart, couponCodeInput, totalItemPrice, user]
  );

  const removeAppliedCoupon = useCallback(() => {
    setSelectedCoupon(null);
    setCouponCodeInput('');
    setCouponFeedback('Coupon removed.');
  }, []);

  const formatCouponValue = useCallback((coupon: CouponDocument) => {
    if (coupon.discountType === 'percentage') {
      return `${coupon.discountValue}% OFF`;
    }

    return `SAVE ₹${coupon.discountValue.toFixed(0)}`;
  }, []);

  const formatAmount = useCallback((value: number) => {
    return Number.isInteger(value) ? String(value) : value.toFixed(2);
  }, []);

  const handleUnavailableCartItems = useCallback(
    async (unavailableItems: any[]) => {
      const unavailableProductIds = uniqueIdentifiers(
        unavailableItems.map(resolveCartProductId)
      );

      setSelectedCoupon(null);
      setCouponCodeInput('');
      setCouponFeedback(null);
      suppressUnavailableCartRedirectRef.current = true;

      if (unavailableProductIds.length > 0) {
        await removeItemsCompletely(unavailableProductIds);
      } else {
        await clearCart();
      }

      showAlert({
        title: 'Item unavailable',
        message:
          'This item isn’t available at your location and has been removed from your cart.',
        type: 'error',
        primaryButtonText: 'OK',
        onPrimaryPress: () => {
          suppressUnavailableCartRedirectRef.current = false;
          lastCheckoutScrollOffset = 0;
          resetAndNavigate('ProductDashboard');
        },
      });
    },
    [clearCart, removeItemsCompletely, showAlert]
  );

  const basePlaceOrder = async () => {
    // Check if there's an incomplete product order
    // Package orders are always allowed, even if there's a pending product order

    // First, if currentOrder exists, fetch the latest status from server
    // This ensures we have the most up-to-date status even if socket updates weren't received
    let clearedOrderId: string | number | null = null;
    if (currentOrder !== null && currentOrder?.orderType !== 'package') {
      try {
        const orderId = currentOrder?.id || currentOrder?._id || currentOrder?.orderId || currentOrder?.orderNumber;
        if (orderId) {
          // Fetch latest order status from server to ensure we have current data
          const { getOrderById } = await import('@service/orderService');
          const latestOrder = await getOrderById(String(orderId));

          if (latestOrder) {
            // Update currentOrder with latest data
            setCurrentOrder(latestOrder);

            // Check the latest status
            const orderStatus = (
              latestOrder?.deliveryStatus ||
              (latestOrder as any)?.delivery_status ||
              latestOrder?.status ||
              ''
            ).toLowerCase();

            // If latest order is delivered or cancelled, clear it immediately
            if (orderStatus === 'delivered' || orderStatus === 'cancelled') {
              clearedOrderId = orderId;
              setCurrentOrder(null);
              // Continue - don't block, allow new order
            } else {
              // Order is incomplete (pending, confirmed, arriving, etc.) - BLOCK
              setOrderAlertVisible(true);
              return;
            }
          } else {
            // Order not found - might be deleted, clear it and allow new order
            setCurrentOrder(null);
          }
        }
      } catch (error) {
        // If fetching fails, fall back to checking currentOrder in memory
        console.log('Error fetching latest order status:', error);
        const orderStatus = (
          currentOrder?.deliveryStatus ||
          (currentOrder as any)?.delivery_status ||
          currentOrder?.status ||
          ''
        ).toLowerCase();

        if (orderStatus === 'delivered' || orderStatus === 'cancelled') {
          clearedOrderId = currentOrder?.id || currentOrder?._id || currentOrder?.orderId || currentOrder?.orderNumber || null;
          setCurrentOrder(null);
        } else {
          setOrderAlertVisible(true);
          return;
        }
      }
    }

    // Also check all customer orders to ensure no incomplete product orders exist
    // This handles the case where currentOrder might be a package order or null
    try {
      const userId = user?.id || user?._id;
      if (userId) {
        const allOrders = await fetchCustomerOrders(String(userId));
        if (Array.isArray(allOrders) && allOrders.length > 0) {
          const hasIncompleteProductOrder = allOrders.some((order: any) => {
            // Check if it's a product order (not a package order)
            const isProductOrder = order?.orderType !== 'package' && !order?.packageType;
            if (!isProductOrder) {return false;}

            // Skip if this is the order we just cleared (it was delivered/cancelled)
            const orderId = order?.id || order?._id || order?.orderId || order?.orderNumber;
            if (clearedOrderId && String(orderId) === String(clearedOrderId)) {
              return false; // Skip the cleared order, it was delivered/cancelled
            }

            // Check if it's incomplete - check both status and deliveryStatus fields
            const orderStatus = (
              order?.deliveryStatus ||
              order?.delivery_status ||
              order?.status ||
              ''
            ).toLowerCase();

            // Only block if order is truly incomplete (not delivered or cancelled)
            return orderStatus !== 'delivered' && orderStatus !== 'cancelled';
          });

          if (hasIncompleteProductOrder) {
            setOrderAlertVisible(true);
            return;
          }
        }
      }
    } catch (error) {
      // If fetching orders fails, don't block - allow order to proceed
      // This prevents network issues from blocking legitimate orders
      console.log('Error checking customer orders:', error);
    }

    if (cart.length === 0 || checkoutTotals.grandTotal <= 0) {
      showError('Add any items to place order');
      return;
    }

    setLoading(true);
    setOrderBeingPlaced(true);

    try {
      // Ensure we have a valid, up-to-date address (with coordinates)
      const addressContext = await ensureAddressContext();

      // Resolve vendors for this address on-the-fly to avoid using stale vendor IDs
      const vendorResolution = await resolveVendorByCoordinates(
        addressContext.latitude,
        addressContext.longitude,
        { radiusKm: productRadiusKm }
      );
      console.log('Resolved vendor response', vendorResolution);

      const unavailableCartItems = findUnavailableCartItems(cart, vendorResolution);
      if (unavailableCartItems.length > 0) {
        setSelectedVendorIdGlobal(
          resolveVendorIdStringFromResolution(vendorResolution)
        );
        setOrderBeingPlaced(false);
        await handleUnavailableCartItems(unavailableCartItems);
        return;
      }

      const vendorContext = resolveCheckoutVendorContext(cart, vendorResolution);
      console.log('Resolved checkout vendor context', vendorContext);

      if (vendorContext.error) {
        setSelectedVendorIdGlobal(null);
        setOrderBeingPlaced(false);
        showError(
          'No vendor available',
          vendorContext.error ||
            'We could not find any vendor for your selected address. Please try a different address or location.'
        );
        return;
      }

      // Persist the resolved vendor when available, otherwise clear stale context.
      setSelectedVendorIdGlobal(vendorContext.vendorId ?? null);

      const formattedData = buildOrderItemsPayload(
        cart,
        vendorContext.vendorId ?? null,
        vendorContext.branchId ?? null
      );

      if (formattedData.length === 0 || formattedData.some((item) => !item.id)) {
        showError(
          'Order items invalid',
          'Some cart items are missing product details. Refresh your cart and try again.'
        );
        return;
      }

      // Ensure we have coordinates - geocode if needed
      let finalLatitude = addressContext.latitude;
      let finalLongitude = addressContext.longitude;
      let finalAddress = addressContext.address;

      if (!finalLatitude || !finalLongitude) {
        console.log('📍 Geocoding address before order creation...');
        const geocodeResult = await geocodeAddress(finalAddress);
        if (geocodeResult) {
          finalLatitude = geocodeResult.latitude;
          finalLongitude = geocodeResult.longitude;
          finalAddress = geocodeResult.address;
          console.log('✅ Address geocoded:', { latitude: finalLatitude, longitude: finalLongitude });
        } else {
          console.warn('⚠️ Geocoding failed, proceeding with existing coordinates');
        }
      }

      // Calculate order breakdown for database storage
      const orderBreakdown = calculateOrderBreakdown(cart, paymentMode, selectedCoupon);

      // Create order in your system (used for COD and after successful online payment)
      const data = await createOrder(
        formattedData,
        orderBreakdown.subtotal,
        finalAddress,
        finalLatitude,
        finalLongitude,
        vendorContext.vendorId ?? undefined,
        vendorContext.branchId ?? undefined,
        orderBreakdown, // Pass the breakdown for database storage
        addressContext.fullName,
        addressContext.contactNumber
      );

      if (data != null) {
        setCurrentOrder(data);
        setSelectedCoupon(null);
        setCouponCodeInput('');
        lastCheckoutScrollOffset = 0;
        await clearCart();
        navigate('OrderSuccess', { ...data });
      } else {
        Alert.alert('There was an error creating the order');
        setOrderBeingPlaced(false);
      }
    } catch (error: any) {
      if (error?.message !== 'ADDRESS_REQUIRED' && error?.message !== 'LOCATION_REQUIRED') {
        console.error('Order creation failed', error);
        showError('Order creation failed', error?.message || 'Please try again.');
      }
      setOrderBeingPlaced(false);
    } finally {
      setLoading(false);
    }
  };

  const handlePlaceOrderCod = async () => {
    await basePlaceOrder();
  };

  const handlePaymentPrompt = () => {
    setAddressConfirmVisible(true);
  };

  const closeAddressConfirmation = useCallback(() => {
    setAddressConfirmVisible(false);
  }, []);

  const continueWithSelectedAddress = useCallback(() => {
    setAddressConfirmVisible(false);
    setPaymentOptionsVisible(true);
  }, []);

  const closePaymentOptions = () => setPaymentOptionsVisible(false);

  const handleSelectAddress = async (address: SavedAddress) => {
    try {
      setSelectingAddressId(address.id);
      const normalizedAddress = address.address?.trim();
      const normalizedName = address.fullName?.trim();
      const normalizedPhone = address.contactNumber?.trim();

      if (!normalizedAddress) {
        Alert.alert('Invalid address', 'Selected address is missing details.');
        return;
      }

      const latitude = Number(address.latitude);
      const longitude = Number(address.longitude);
      const safeName = normalizedName || user?.name || 'Customer';
      const safePhone = normalizedPhone || user?.phone || '';

      if (!hasValidCoordinates(latitude, longitude)) {
        Alert.alert(
          'Invalid address location',
          'Selected address does not have valid map coordinates. Please update this address and try again.'
        );
        return;
      }

      const nextSelectedAddress: SavedAddress = {
        ...address,
        fullName: safeName,
        contactNumber: safePhone,
        address: normalizedAddress,
        latitude,
        longitude,
      };

      await updateUserLocation(
        {
          address: normalizedAddress,
          liveLocation: {
            latitude,
            longitude,
          },
        },
        setUser
      );

      const vendorResolution = await resolveVendorByCoordinates(
        latitude,
        longitude,
        { radiusKm: productRadiusKm }
      );
      const resolvedVendorIds = resolveVendorIdStringFromResolution(vendorResolution);
      setSelectedVendorIdGlobal(resolvedVendorIds);
      setSelectedAddress(nextSelectedAddress);
      setDeliveryAddress(normalizedAddress);
      setAddressModalVisible(false);

      const unavailableCartItems = findUnavailableCartItems(cart, vendorResolution);
      if (unavailableCartItems.length > 0) {
        await handleUnavailableCartItems(unavailableCartItems);
      }
    } catch (error) {
      console.error('Select address error', error);
      Alert.alert('Failed to select address', 'Please try again.');
    } finally {
      setSelectingAddressId(null);
    }
  };

  const handleFooterLayout = useCallback(({ nativeEvent }: { nativeEvent: any }) => {
    setFooterHeight(nativeEvent.layout.height);
  }, []);

  const scrollBottomPadding = footerHeight ? footerHeight + insets.bottom + 20 : insets.bottom + 100;

  const restoreCheckoutScroll = useCallback(() => {
    if (lastCheckoutScrollOffset <= 0) {
      return;
    }

    requestAnimationFrame(() => {
      scrollViewRef.current?.scrollTo({
        y: lastCheckoutScrollOffset,
        animated: false,
      });
    });
  }, []);

  useFocusEffect(
    useCallback(() => {
      restoreCheckoutScroll();
    }, [restoreCheckoutScroll])
  );

  return (
    <SafeAreaView style={{ flex: 1 }} edges={['top']}>
      <StatusBar
        translucent={true}
        backgroundColor="transparent"
        barStyle="dark-content"
      />
      <View style={styles.container}>
        <CustomHeader title="Checkout" fallbackRoute="CartScreen" />
      <ScrollView
        ref={scrollViewRef}
        contentContainerStyle={[styles.scrollContainer, { paddingBottom: scrollBottomPadding }]}
        scrollEventThrottle={16}
        onScroll={(event) => {
          lastCheckoutScrollOffset = event.nativeEvent.contentOffset.y;
        }}
        onContentSizeChange={restoreCheckoutScroll}
      >
        <View style={styles.contentInner}>
        {freeDeliveryAmountLeft > 0 && (
          <View style={styles.freeDeliveryHintCard}>
            <View style={styles.freeDeliveryHintIconWrap}>
              <Icon
                name="truck-fast-outline"
                size={RFValue(18)}
                color={colors.primaryBlue}
              />
            </View>
            <View style={styles.freeDeliveryHintCopy}>
              <CustomText
                variant="h8"
                fontFamily={Fonts.Bold}
                style={styles.freeDeliveryHintTitle}
              >
                {`Add ₹${freeDeliveryAmountLeft.toFixed(2)} more for free delivery`}
              </CustomText>
            </View>
          </View>
        )}

        <TouchableOpacity
          style={styles.addressCard}
          onPress={() => setAddressModalVisible(true)}
          activeOpacity={0.88}
          accessibilityRole="button"
          accessibilityLabel="Select delivery address"
          accessibilityHint="Double tap to change your delivery address"
        >
          <View style={styles.addressCardIconWrap}>
            <Icon name="map-marker-outline" size={RFValue(18)} color={colors.primaryBlue} />
          </View>
          <View style={styles.addressCardCopy}>
            <CustomText variant="h9" fontFamily={Fonts.SemiBold} style={styles.addressCardLabel}>
              Deliver to
            </CustomText>
            <CustomText variant="h8" fontFamily={Fonts.Bold} style={styles.addressCardTitle}>
              {deliveryRecipient}
            </CustomText>
            <CustomText variant="h9" fontFamily={Fonts.Medium} style={styles.addressCardText}>
              {deliveryAddressPreview}
            </CustomText>
          </View>
          <Icon name="chevron-right" size={RFValue(18)} color={colors.primaryBlue} />
        </TouchableOpacity>

        <OrderList onCartEmpty={handleCartEmpty} />

        <TouchableOpacity
          style={styles.sectionRow}
          onPress={openCouponModal}
          activeOpacity={0.85}
          accessibilityRole="button"
          accessibilityLabel="Open coupons"
          accessibilityHint="Double tap to view and apply available coupons"
        >
          <View style={styles.flexRow}>
            <Image
              source={require('@assets/icons/coupon.png')}
              style={styles.couponIcon}
            />
            <View>
              <CustomText variant="h6" fontSize={17} fontFamily={Fonts.SemiBold} style={styles.couponTitle}>
                Use Coupons
              </CustomText>
              {checkoutTotals.appliedCoupon ? (
                <CustomText
                  variant="h9"
                  fontFamily={Fonts.Medium}
                  style={styles.couponAppliedText}
                >
                  {`${checkoutTotals.appliedCoupon.code} applied | Save ₹${checkoutTotals.couponDiscount.toFixed(2)}`}
                </CustomText>
              ) : null}
            </View>
          </View>
          <View style={styles.couponRowAction}>
            {checkoutTotals.appliedCoupon && (
              <TouchableOpacity
                onPress={removeAppliedCoupon}
                accessibilityRole="button"
                accessibilityLabel="Remove applied coupon"
                hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
              >
                <CustomText
                  variant="h9"
                  fontFamily={Fonts.SemiBold}
                  style={styles.removeCouponText}
                >
                  Remove
                </CustomText>
              </TouchableOpacity>
            )}
            <Icon name="chevron-right" size={RFValue(16)} color={Colors.text} />
          </View>
        </TouchableOpacity>

        <BillDetails
          totalItemPrice={totalItemPrice}
          cartItems={cart}
          largerText
          coupon={selectedCoupon}
        />
        </View>

      </ScrollView>

      <View style={[styles.checkoutFooter, { bottom: insets.bottom }]} onLayout={handleFooterLayout}>
        <View style={styles.absoluteContainer}>
        <View style={styles.paymentGateway}>
          <View style={styles.paymentButtonContainer}>
            <ArrowButton
              loading={loading}
              title="PLACE ORDER"
              onPress={handlePaymentPrompt}
              disabled={cart.length === 0 || checkoutTotals.grandTotal <= 0}
            />
          </View>
        </View>
        </View>
      </View>
      <ActionOptionsModal
        visible={addressConfirmVisible}
        onClose={closeAddressConfirmation}
        title="Continue with selected address?"
        message={`Selected address:\n${deliveryAddressPreview}`}
        options={[
          {
            label: 'Confirm',
            type: 'primary',
            onPress: continueWithSelectedAddress,
          },
          {
            label: 'Cancel',
            type: 'ghost',
            onPress: closeAddressConfirmation,
          },
        ]}
      />
      <ActionOptionsModal
        visible={paymentOptionsVisible}
        onClose={closePaymentOptions}
        title="Choose payment method"
        message="How would you like to pay for this order?"
        options={[
          // {
          //   label: 'Pay Online',
          //   type: 'primary',
          //   onPress: () => {
          //     setPaymentMode('Online');
          //     closePaymentOptions();
          //     handlePlaceOrder();
          //   }
          // },
          {
            label: 'Cash on Delivery',
            type: 'primary', // Changed from 'secondary' to 'primary' since it's now the main option
            onPress: () => {
              setPaymentMode('COD');
              closePaymentOptions();
              handlePlaceOrderCod();
            },
          },
          { label: 'Cancel', type: 'ghost', onPress: closePaymentOptions },
        ]}
      />
      <Modal
        visible={couponModalVisible}
        animationType="slide"
        transparent
        onRequestClose={closeCouponModal}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.couponModalContent}>
            <View style={styles.modalHeader}>
              <CustomText variant="h7" fontFamily={Fonts.SemiBold}>
                Apply coupon
              </CustomText>
              <TouchableOpacity
                onPress={closeCouponModal}
                accessibilityRole="button"
                accessibilityLabel="Close coupon modal"
                style={styles.closeButton}
              >
                <Icon name="close" size={RFValue(20)} color={Colors.text} />
              </TouchableOpacity>
            </View>

            <View style={styles.couponInputRow}>
              <View style={styles.couponInputContainer}>
                <Icon
                  name="ticket-percent-outline"
                  size={RFValue(18)}
                  color={colors.primaryBlue}
                />
                <TextInput
                  value={couponCodeInput}
                  onChangeText={(text) => setCouponCodeInput(text.toUpperCase())}
                  placeholder="Enter coupon code"
                  placeholderTextColor={colors.greyText}
                  autoCapitalize="characters"
                  autoCorrect={false}
                  style={styles.couponTextInput}
                />
              </View>
              <TouchableOpacity
                style={[
                  styles.applyCouponButton,
                  applyingCoupon && styles.applyCouponButtonDisabled,
                ]}
                onPress={() => {
                  applyCouponCode();
                }}
                disabled={applyingCoupon}
              >
                {applyingCoupon ? (
                  <ActivityIndicator size="small" color={colors.white} />
                ) : (
                  <CustomText
                    variant="h9"
                    fontFamily={Fonts.Bold}
                    style={styles.applyCouponButtonText}
                  >
                    Apply
                  </CustomText>
                )}
              </TouchableOpacity>
            </View>

            {couponFeedback && (
              <CustomText
                variant="h9"
                fontFamily={Fonts.Medium}
                style={styles.couponFeedbackText}
              >
                {couponFeedback}
              </CustomText>
            )}

            <View style={styles.couponSummaryCard}>
              <CustomText variant="h9" fontFamily={Fonts.Medium} style={styles.couponSummaryLabel}>
                Current cart total
              </CustomText>
              <CustomText variant="h7" fontFamily={Fonts.Bold} style={styles.couponSummaryValue}>
                {`₹${checkoutTotals.grandTotal.toFixed(2)}`}
              </CustomText>
              {checkoutTotals.appliedCoupon && (
                <CustomText variant="h9" fontFamily={Fonts.Medium} style={styles.couponSummarySavings}>
                  {`Applied ${checkoutTotals.appliedCoupon.code} | Saved ₹${checkoutTotals.couponDiscount.toFixed(2)}`}
                </CustomText>
              )}
            </View>

            <CustomText
              variant="h8"
              fontFamily={Fonts.SemiBold}
              style={styles.availableCouponsTitle}
            >
              Available offers
            </CustomText>

            {couponsLoading ? (
              <View style={styles.modalLoader}>
                <ActivityIndicator size="small" color={Colors.secondary} />
              </View>
            ) : availableCoupons.length === 0 ? (
              <View style={styles.emptyCouponContainer}>
                <CustomText
                  variant="h9"
                  fontFamily={Fonts.Medium}
                  style={styles.emptyCouponText}
                >
                  No coupons available right now.
                </CustomText>
              </View>
            ) : (
              <ScrollView style={styles.couponList} showsVerticalScrollIndicator={false}>
                {availableCoupons.map((coupon) => {
                  const isApplied = selectedCoupon?.code === coupon.code;
                  const eligibility = couponEligibilityMap.get(coupon.id);
                  const isEligible = eligibility?.isEligible ?? false;
                  const eligibilityMessage =
                    eligibility?.message ?? 'This coupon is not eligible for your cart.';

                  return (
                    <View key={coupon.id} style={styles.couponCard}>
                      <View style={styles.couponCardTop}>
                        <View style={styles.couponCopy}>
                          <CustomText
                            variant="h8"
                            fontFamily={Fonts.Bold}
                            style={styles.couponCodeText}
                          >
                            {coupon.code}
                          </CustomText>
                          <CustomText
                            variant="h9"
                            fontFamily={Fonts.Medium}
                            style={styles.couponTitleText}
                          >
                            {coupon.title}
                          </CustomText>
                          {!!coupon.description && (
                            <CustomText
                              variant="h9"
                              fontFamily={Fonts.Regular}
                              style={styles.couponDescriptionText}
                            >
                              {coupon.description}
                            </CustomText>
                          )}
                          {!!coupon.category && (
                            <CustomText
                              variant="h9"
                              fontFamily={Fonts.Medium}
                              style={styles.couponMetaText}
                            >
                              {`Category: ${coupon.category}`}
                            </CustomText>
                          )}
                          {coupon.minimumOrderAmount > 0 && (
                            <CustomText
                              variant="h9"
                              fontFamily={Fonts.Medium}
                              style={styles.couponMetaText}
                            >
                              {`Min order: Rs. ${formatAmount(coupon.minimumOrderAmount)}`}
                            </CustomText>
                          )}
                        </View>
                        <View style={styles.couponCardSide}>
                          <View style={styles.couponValueBadge}>
                            <CustomText
                              variant="h9"
                              fontFamily={Fonts.Bold}
                              style={styles.couponValueBadgeText}
                            >
                              {formatCouponValue(coupon)}
                            </CustomText>
                          </View>
                          <View
                            style={[
                              styles.couponEligibilityBadge,
                              isEligible
                                ? styles.couponEligibilityBadgeEligible
                                : styles.couponEligibilityBadgeIneligible,
                            ]}
                          >
                            <CustomText
                              variant="h10"
                              fontFamily={Fonts.SemiBold}
                              style={[
                                styles.couponEligibilityBadgeText,
                                !isEligible && styles.couponEligibilityBadgeTextIneligible,
                              ]}
                            >
                              {isEligible ? 'Eligible' : 'Not eligible'}
                            </CustomText>
                          </View>
                          <TouchableOpacity
                            style={[
                              styles.couponApplyChip,
                              isApplied && styles.couponApplyChipActive,
                              !isEligible &&
                                !isApplied &&
                                styles.couponApplyChipDisabled,
                            ]}
                            onPress={() => {
                              if (!isEligible && !isApplied) {
                                setCouponFeedback(eligibilityMessage);
                                return;
                              }
                              applyCouponCode(coupon.code);
                            }}
                          >
                            <CustomText
                              variant="h9"
                              fontFamily={Fonts.SemiBold}
                              style={[
                                styles.couponApplyChipText,
                                isApplied && styles.couponApplyChipTextActive,
                                !isEligible &&
                                  !isApplied &&
                                  styles.couponApplyChipTextDisabled,
                              ]}
                            >
                              {isApplied ? 'Applied' : isEligible ? 'Apply' : 'Not eligible'}
                            </CustomText>
                          </TouchableOpacity>
                        </View>
                      </View>
                      {!isEligible && (
                        <CustomText
                          variant="h10"
                          fontFamily={Fonts.Medium}
                          style={styles.couponIneligibleText}
                        >
                          {eligibilityMessage}
                        </CustomText>
                      )}
                    </View>
                  );
                })}
              </ScrollView>
            )}
          </View>
        </View>
      </Modal>
      <Modal
        visible={addressModalVisible}
        animationType="slide"
        transparent
        onRequestClose={() => setAddressModalVisible(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <CustomText variant="h7" fontFamily={Fonts.SemiBold}>
                Select delivery address
              </CustomText>
              <TouchableOpacity
                onPress={() => setAddressModalVisible(false)}
                accessibilityRole="button"
                accessibilityLabel="Close address selection"
                accessibilityHint="Double tap to close address selection modal"
                style={styles.closeButton}
              >
                <Icon name="close" size={RFValue(20)} color={Colors.text} />
              </TouchableOpacity>
            </View>

            {addressLoading ? (
              <View style={styles.modalLoader}>
                <ActivityIndicator size="small" color={Colors.secondary} />
              </View>
            ) : !addresses.length ? (
              <View style={styles.emptyAddressContainer}>
                <CustomText
                  variant="h8"
                  fontFamily={Fonts.Medium}
                  style={{ textAlign: 'center' }}
                >
                  No saved addresses found.
                </CustomText>
                <TouchableOpacity
                  style={styles.manageAddressButton}
                  onPress={() => {
                    setAddressModalVisible(false);
                    navigate('AddressBook');
                  }}
                  accessibilityRole="button"
                  accessibilityLabel="Add new address"
                  accessibilityHint="Double tap to add a new delivery address"
                >
                  <CustomText
                    variant="h8"
                    fontFamily={Fonts.SemiBold}
                    style={{ color: colors.white }}
                  >
                    Add Address
                  </CustomText>
                </TouchableOpacity>
              </View>
            ) : (
              <ScrollView style={{ maxHeight: 320 }}>
                {addresses.map((addr) => {
                  const isSelected = selectedAddress
                    ? selectedAddress.id === addr.id
                    : deliveryAddress &&
                      deliveryAddress.trim() === addr.address.trim();
                  return (
                    <TouchableOpacity
                      key={addr.id}
                      style={[
                        styles.addressOption,
                        isSelected && styles.addressOptionSelected,
                      ]}
                      onPress={() => handleSelectAddress(addr)}
                      disabled={selectingAddressId === addr.id}
                      accessibilityRole="button"
                      accessibilityLabel={`Select address: ${addr.fullName}, ${addr.address}`}
                      accessibilityState={{ selected: isSelected, disabled: selectingAddressId === addr.id }}
                      accessibilityHint="Double tap to select this delivery address"
                    >
                      <View style={styles.addressOptionHeader}>
                        <CustomText
                          variant="h7"
                          fontFamily={Fonts.SemiBold}
                          style={{ flex: 1 }}
                        >
                          {addr.fullName}
                        </CustomText>
                        {selectingAddressId === addr.id && (
                          <ActivityIndicator
                            size="small"
                            color={Colors.secondary}
                          />
                        )}
                      </View>
                      <CustomText
                        variant="h9"
                        fontFamily={Fonts.Regular}
                        style={{ opacity: 0.8 }}
                      >
                        {addr.address}
                      </CustomText>
                      <CustomText variant="h9" fontFamily={Fonts.Medium}>
                        {addr.contactNumber}
                      </CustomText>
                    </TouchableOpacity>
                  );
                })}
              </ScrollView>
            )}

            {!!addresses.length && (
              <TouchableOpacity
                style={[styles.manageAddressButton, { marginTop: 15 }]}
                onPress={() => {
                  setAddressModalVisible(false);
                  navigate('AddressBook');
                }}
                accessibilityRole="button"
                accessibilityLabel="Manage addresses"
                accessibilityHint="Double tap to manage your saved addresses"
              >
                <CustomText
                  variant="h8"
                  fontFamily={Fonts.SemiBold}
                  style={{ color: colors.white }}
                >
                  Manage Addresses
                </CustomText>
              </TouchableOpacity>
            )}
          </View>
        </View>
      </Modal>

      {/* Custom Order Alert Modal */}
      <Modal
        visible={orderAlertVisible}
        transparent
        animationType="fade"
        onRequestClose={() => setOrderAlertVisible(false)}
      >
        <TouchableWithoutFeedback onPress={() => setOrderAlertVisible(false)}>
          <View style={styles.orderAlertOverlay}>
            <TouchableWithoutFeedback onPress={() => {}}>
              <View style={styles.orderAlertCard}>
                <View style={styles.orderAlertIconContainer}>
                  <Icon
                    name="clock-time-four-outline"
                    size={RFValue(48)}
                    color={colors.primaryBlue}
                  />
                </View>
                <CustomText
                  variant="h5"
                  fontFamily={Fonts.Bold}
                  style={styles.orderAlertTitle}
                >
                  You can place a new order once your current order is completed.
                </CustomText>
                <TouchableOpacity
                  style={styles.orderAlertButton}
                  onPress={() => setOrderAlertVisible(false)}
                  activeOpacity={0.8}
                >
                  <CustomText
                    variant="h7"
                    fontFamily={Fonts.Bold}
                    style={styles.orderAlertButtonText}
                  >
                    OK
                  </CustomText>
                </TouchableOpacity>
              </View>
            </TouchableWithoutFeedback>
          </View>
        </TouchableWithoutFeedback>
      </Modal>

      {/* Custom Alert Modal */}
      {alertConfig && (
        <CustomAlert
          visible={alertVisible}
          title={alertConfig.title}
          message={alertConfig.message}
          type={alertConfig.type}
          primaryButtonText={alertConfig.primaryButtonText}
          secondaryButtonText={alertConfig.secondaryButtonText}
          onPrimaryPress={alertConfig.onPrimaryPress}
          onSecondaryPress={alertConfig.onSecondaryPress}
          onClose={hideAlert}
          showSecondaryButton={alertConfig.showSecondaryButton}
        />
      )}
    </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  absoluteContainer: {
    marginVertical: 8,
    marginBottom: Platform.OS === 'ios' ? 16 : 10,
  },
  container: {
    flex: 1,
    backgroundColor: '#F5F8FF',
  },
  scrollContainer: {
    backgroundColor: '#F5F8FF',
    paddingTop: 16,
  },
  contentInner: {
    paddingBottom: 10,
  },
  addressCard: {
    marginHorizontal: 16,
    marginBottom: 14,
    borderRadius: 18,
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.blackOpacity05,
    paddingHorizontal: 14,
    paddingVertical: 14,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.06,
    shadowRadius: 10,
    elevation: 3,
  },
  addressCardIconWrap: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: '#EEF4FF',
    justifyContent: 'center',
    alignItems: 'center',
  },
  addressCardCopy: {
    flex: 1,
  },
  addressCardLabel: {
    color: colors.primaryBlue,
    fontSize: 14,
    lineHeight: 19,
    opacity: 0.95,
  },
  addressCardTitle: {
    color: colors.primaryBlue,
    marginTop: 3,
    fontSize: 17,
    lineHeight: 23,
  },
  addressCardText: {
    color: colors.primaryBlue,
    marginTop: 5,
    fontSize: 14,
    lineHeight: 20,
    opacity: 0.95,
  },
  sectionRow: {
    backgroundColor: colors.white,
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 15,
    flexDirection: 'row',
    borderWidth: 1,
    borderColor: colors.blackOpacity05,
    borderRadius: 18,
    marginHorizontal: 16,
    marginTop: 14,
    marginBottom: 14,
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.06,
    shadowRadius: 10,
    elevation: 3,
  },
  couponAppliedText: {
    color: colors.green,
    marginTop: 4,
  },
  couponRowAction: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  removeCouponText: {
    color: colors.danger,
  },
  flexRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 12,
    flex: 1,
  },
  couponIcon: {
    width: 28,
    height: 28,
  },
  couponTitle: {
    color: colors.primaryBlue,
  },
  cancelText: {
    marginTop: 4,
    opacity: 0.6,
  },
  paymentGateway: {
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 10,
  },
  paymentButtonContainer: {
    width: '100%',
    alignSelf: 'center',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: colors.blackOpacity40,
    justifyContent: 'flex-end',
  },
  couponModalContent: {
    backgroundColor: colors.white,
    paddingHorizontal: 20,
    paddingTop: 20,
    paddingBottom: Platform.OS === 'ios' ? 28 : 20,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    maxHeight: '78%',
  },
  couponInputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginTop: 8,
  },
  couponInputContainer: {
    flex: 1,
    minHeight: 48,
    borderWidth: 1,
    borderColor: Colors.border,
    borderRadius: 12,
    paddingHorizontal: 12,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    backgroundColor: colors.white,
  },
  couponTextInput: {
    flex: 1,
    color: colors.primaryBlue,
    fontFamily: Fonts.SemiBold,
    fontSize: RFValue(12),
    paddingVertical: 0,
  },
  applyCouponButton: {
    minHeight: 48,
    minWidth: 88,
    borderRadius: 12,
    backgroundColor: colors.primaryBlue,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 16,
  },
  applyCouponButtonDisabled: {
    opacity: 0.65,
  },
  applyCouponButtonText: {
    color: colors.white,
  },
  couponFeedbackText: {
    marginTop: 10,
    color: colors.primaryBlue,
  },
  couponSummaryCard: {
    marginTop: 14,
    padding: 14,
    borderRadius: 14,
    backgroundColor: colors.lightBlue,
  },
  couponSummaryLabel: {
    color: colors.greyText,
  },
  couponSummaryValue: {
    color: colors.primaryBlue,
    marginTop: 4,
  },
  couponSummarySavings: {
    color: colors.green,
    marginTop: 6,
  },
  availableCouponsTitle: {
    marginTop: 18,
    marginBottom: 12,
    color: colors.primaryBlue,
  },
  emptyCouponContainer: {
    borderWidth: 1,
    borderColor: Colors.border,
    borderRadius: 14,
    padding: 18,
  },
  emptyCouponText: {
    color: colors.greyText,
    textAlign: 'center',
  },
  couponList: {
    maxHeight: 330,
  },
  couponCard: {
    borderWidth: 1,
    borderColor: Colors.border,
    borderRadius: 14,
    padding: 14,
    marginBottom: 12,
    backgroundColor: colors.white,
  },
  couponCardTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 12,
  },
  couponCopy: {
    flex: 1,
  },
  couponCardSide: {
    alignItems: 'flex-end',
    justifyContent: 'space-between',
  },
  couponCodeText: {
    color: colors.primaryBlue,
  },
  couponTitleText: {
    color: colors.primaryBlue,
    marginTop: 4,
  },
  couponDescriptionText: {
    color: colors.greyText,
    marginTop: 4,
  },
  couponMetaText: {
    color: colors.greyText,
    marginTop: 6,
  },
  couponValueBadge: {
    backgroundColor: colors.lightBlue,
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  couponValueBadgeText: {
    color: colors.primaryBlue,
  },
  couponEligibilityBadge: {
    marginTop: 10,
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 5,
  },
  couponEligibilityBadgeEligible: {
    backgroundColor: '#E5F7ED',
  },
  couponEligibilityBadgeIneligible: {
    backgroundColor: '#FDECEC',
  },
  couponEligibilityBadgeText: {
    color: '#157347',
  },
  couponEligibilityBadgeTextIneligible: {
    color: '#B42318',
  },
  couponApplyChip: {
    marginTop: 14,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: colors.primaryBlue,
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  couponApplyChipDisabled: {
    borderColor: '#C8D2E6',
    backgroundColor: '#F5F7FB',
  },
  couponApplyChipActive: {
    backgroundColor: colors.primaryBlue,
  },
  couponApplyChipText: {
    color: colors.primaryBlue,
  },
  couponApplyChipTextDisabled: {
    color: '#7B8AA6',
  },
  couponApplyChipTextActive: {
    color: colors.white,
  },
  couponIneligibleText: {
    marginTop: 10,
    color: '#B42318',
  },
  modalContent: {
    backgroundColor: colors.white,
    padding: 20,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  modalLoader: {
    paddingVertical: 30,
    alignItems: 'center',
    justifyContent: 'center',
  },
  closeButton: {
    minWidth: 44,
    minHeight: 44,
    justifyContent: 'center',
    alignItems: 'center',
  },
  addressOption: {
    borderWidth: 1,
    borderColor: Colors.border,
    borderRadius: 12,
    padding: 12,
    marginBottom: 10,
    minHeight: 44,
  },
  addressOptionSelected: {
    borderColor: Colors.secondary,
    backgroundColor: colors.warningOpacity08,
  },
  addressOptionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 6,
    gap: 8,
  },
  emptyAddressContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 20,
  },
  manageAddressButton: {
    minHeight: 44,
    backgroundColor: Colors.secondary,
    paddingVertical: 12,
    borderRadius: 10,
    alignItems: 'center',
    marginTop: 10,
  },
  checkoutFooter: {
    position: 'absolute',
    left: 16,
    right: 16,
    paddingHorizontal: 0,
    paddingTop: 0,
    paddingBottom: Platform.OS === 'ios' ? 6 : 2,
    minHeight: Platform.OS === 'ios' ? 88 : 76,
    backgroundColor: 'transparent',
  },
  freeDeliveryHintCard: {
    marginHorizontal: 16,
    marginTop: 4,
    marginBottom: 10,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#E3E8F4',
    backgroundColor: colors.white,
    paddingHorizontal: 14,
    paddingVertical: 14,
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 12,
  },
  freeDeliveryHintIconWrap: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#F3F7FF',
    alignItems: 'center',
    justifyContent: 'center',
  },
  freeDeliveryHintCopy: {
    flex: 1,
  },
  freeDeliveryHintTitle: {
    color: colors.primaryBlue,
    fontSize: 15,
    lineHeight: 21,
  },
  freeDeliveryHintText: {
    marginTop: 4,
    color: '#47628F',
    fontSize: 13,
    lineHeight: 20,
  },
  orderAlertOverlay: {
    flex: 1,
    backgroundColor: 'rgba(9,39,116,0.35)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  orderAlertCard: {
    width: '100%',
    maxWidth: 340,
    backgroundColor: colors.white,
    borderRadius: 20,
    padding: 28,
    alignItems: 'center',
    shadowColor: colors.primaryBlue,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.2,
    shadowRadius: 16,
    elevation: 12,
  },
  orderAlertIconContainer: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: colors.primaryBlueOpacity10,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 20,
  },
  orderAlertTitle: {
    color: colors.primaryBlue,
    textAlign: 'center',
    marginBottom: 24,
    lineHeight: 24,
  },
  orderAlertButton: {
    width: '100%',
    backgroundColor: colors.primaryBlue,
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  orderAlertButtonText: {
    color: colors.white,
    letterSpacing: 0.5,
  },
});

export default ProductOrder;
