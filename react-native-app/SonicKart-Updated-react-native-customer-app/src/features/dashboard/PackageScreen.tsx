import React, { FC, useState, useEffect, useRef, useCallback, useMemo } from 'react';
import {
  View,
  StyleSheet,
  ScrollView,
  Alert,
  ActivityIndicator,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  Modal,
} from 'react-native';
import Geolocation from '@react-native-community/geolocation';
import { Platform as RNPlatform, PermissionsAndroid, Linking } from 'react-native';
import CustomHeader from '@components/ui/CustomHeader';
import CustomText from '@components/ui/CustomText';
import CustomInput from '@components/ui/CustomInput';
import CustomButton from '@components/ui/CustomButton';
import Icon from 'react-native-vector-icons/Ionicons';
import MaterialIcons from 'react-native-vector-icons/MaterialIcons';
import { RFValue } from 'react-native-responsive-fontsize';
import { Fonts } from '@utils/Constants';
import colors from '../../theme/colors';
import MapView, { Marker, Region } from 'react-native-maps';
import MapViewDirections from 'react-native-maps-directions';
import { GOOGLE_MAP_API } from '@service/config';
import { customMapStyle } from '@utils/CustomMap';
import {
  getPlaceSuggestions,
  getPlaceDetails,
  reverseGeocodeToAddress,
  getDistanceMatrix,
} from '@service/mapService';
import { createPackageOrder } from '@service/packageService';
import { useAuthStore } from '@state/authStore';
import { validatePackageOrder } from '@utils/validation';
import { validateDeliveryDistance } from '@utils/distanceValidation';
import { fetchPackageOrders } from '@service/orderService';
import OrderItem from '@components/delivery/OrderItem';
import { FlatList, RefreshControl } from 'react-native';
import DistanceExceededModal from '@components/ui/DistanceExceededModal';
import {
  SafeAreaView,
  useSafeAreaInsets,
} from 'react-native-safe-area-context';
import BottomTabBar from '@components/ui/BottomTabBar';
import {
  clampMapDelta,
  normalizeCoordinate,
} from '@utils/locationUtils';
import { useDeliverySettingsStore } from '@state/deliverySettingsStore';

const generatePlacesSessionToken = () =>
  `${Date.now()}-${Math.random().toString(36).slice(2, 11)}`;

const resolvePackageTypeIconName = (type: string) => {
  const normalized = String(type ?? '').trim().toLowerCase();

  if (normalized.includes('document')) {
    return 'document-text-outline';
  }

  if (
    normalized.includes('food') ||
    normalized.includes('grocery') ||
    normalized.includes('grocer')
  ) {
    return 'restaurant-outline';
  }

  if (
    normalized.includes('medicine') ||
    normalized.includes('medical') ||
    normalized.includes('pharma')
  ) {
    return 'medical-outline';
  }

  return 'cube-outline';
};

// Configure Geolocation with better timeout handling
Geolocation.setRNConfiguration({
  skipPermissionRequests: false,
  authorizationLevel: 'whenInUse',
  enableBackgroundLocationUpdates: false,
  // Prefer Android location manager to avoid Play Services provider issues on some devices.
  locationProvider: 'android',
});

type Step = 'initial' | 'pickup' | 'drop' | 'type' | 'review';
type ViewMode = 'send' | 'orders';
type PackageOrderType = 'send' | 'receive';

/**
 * Package booking screen (customer side).
 * Supports:
 * - send/receive flow
 * - pickup/drop autocomplete and auto-detect
 * - distance calculation + max-range validation
 * - package order creation + package order history list
 */
const PackageScreen: FC = () => {
  const insets = useSafeAreaInsets();
  const { user } = useAuthStore();
  const {
    packageTypes,
    packageBaseFee,
    packagePerKmFee,
    maxPackageDistanceKm,
    packageMapRadiusMeters,
  } = useDeliverySettingsStore((state) => state.settings);
  const [viewMode, setViewMode] = useState<ViewMode>('send');
  const [currentStep, setCurrentStep] = useState<Step>('initial');
  const [packageOrderType, setPackageOrderType] = useState<PackageOrderType>('send');
  const [loading, setLoading] = useState(false);
  const [locationLoading, setLocationLoading] = useState(false);

  // Package Orders State
  const [packageOrders, setPackageOrders] = useState<any[]>([]);
  const [ordersLoading, setOrdersLoading] = useState(false);
  const [ordersRefreshing, setOrdersRefreshing] = useState(false);

  // Pickup Location
  const [pickupAddress, setPickupAddress] = useState('');
  const [pickupLatitude, setPickupLatitude] = useState<number | null>(null);
  const [pickupLongitude, setPickupLongitude] = useState<number | null>(null);
  const [pickupPlaceId, setPickupPlaceId] = useState<string | null>(null);
  const [pickupSuggestions, setPickupSuggestions] = useState<any[]>([]);
  const [pickupSuggestionLoading, setPickupSuggestionLoading] = useState(false);
  const [pickupSessionToken, setPickupSessionToken] = useState(() => generatePlacesSessionToken());

  // Drop Location
  const [dropAddress, setDropAddress] = useState('');
  const [dropLatitude, setDropLatitude] = useState<number | null>(null);
  const [dropLongitude, setDropLongitude] = useState<number | null>(null);
  const [dropPlaceId, setDropPlaceId] = useState<string | null>(null);
  const [dropSuggestions, setDropSuggestions] = useState<any[]>([]);
  const [dropSuggestionLoading, setDropSuggestionLoading] = useState(false);
  const [dropSessionToken, setDropSessionToken] = useState(() => generatePlacesSessionToken());

  // Package Type
  const [selectedPackageType, setSelectedPackageType] = useState<string | null>(null);

  // Distance & Charge
  const [distance, setDistance] = useState<number | null>(null);
  const [distanceText, setDistanceText] = useState('');

  // Distance validation modal
  const [distanceExceededModalVisible, setDistanceExceededModalVisible] = useState(false);
  const [exceedingDistance, setExceedingDistance] = useState<number>(0);
  const [duration, setDuration] = useState<number | null>(null);
  const [durationText, setDurationText] = useState('');
  const [deliveryCharge, setDeliveryCharge] = useState(0);
  const [calculating, setCalculating] = useState(false);

  // Agreement state
  const [agreementChecked, setAgreementChecked] = useState(false);

  // Map
  const [mapRegion, setMapRegion] = useState<Region | null>(null);
  const mapRef = useRef<MapView>(null);
  const [pickupMapPickerVisible, setPickupMapPickerVisible] = useState(false);
  const [pickupMapConfirming, setPickupMapConfirming] = useState(false);
  const [pickupDraftCoordinate, setPickupDraftCoordinate] = useState<{ latitude: number; longitude: number } | null>(null);
  const [pickupDraftAddress, setPickupDraftAddress] = useState('');
  const [pickupDraftRegion, setPickupDraftRegion] = useState<Region | null>(null);
  const [dropMapPickerVisible, setDropMapPickerVisible] = useState(false);
  const [dropMapConfirming, setDropMapConfirming] = useState(false);
  const [dropDraftCoordinate, setDropDraftCoordinate] = useState<{ latitude: number; longitude: number } | null>(null);
  const [dropDraftAddress, setDropDraftAddress] = useState('');
  const [dropDraftRegion, setDropDraftRegion] = useState<Region | null>(null);
  const pickupCoordinate = useMemo(
    () => normalizeCoordinate({ latitude: pickupLatitude, longitude: pickupLongitude }),
    [pickupLatitude, pickupLongitude]
  );
  const dropCoordinate = useMemo(
    () => normalizeCoordinate({ latitude: dropLatitude, longitude: dropLongitude }),
    [dropLatitude, dropLongitude]
  );

  const suggestionTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const isMountedRef = useRef(true);

  useEffect(() => {
    if (
      selectedPackageType &&
      !packageTypes.includes(selectedPackageType)
    ) {
      setSelectedPackageType(null);
    }
  }, [packageTypes, selectedPackageType]);

  const proceedAfterDropSelection = useCallback(
    (nextDropLatitude: number, nextDropLongitude: number) => {
      if (pickupLatitude && pickupLongitude) {
        const distanceValidation = validateDeliveryDistance(
          pickupLatitude,
          pickupLongitude,
          nextDropLatitude,
          nextDropLongitude
        );

        if (!distanceValidation.isValid) {
          setExceedingDistance(distanceValidation.distance);
          setDistanceExceededModalVisible(true);
          return;
        }
      }

      if (packageOrderType === 'receive') {
        setCurrentStep('pickup');
      } else {
        setCurrentStep('type');
      }
    },
    [packageOrderType, pickupLatitude, pickupLongitude]
  );

  const proceedAfterPickupSelection = useCallback(
    (nextPickupLatitude: number, nextPickupLongitude: number) => {
      if (dropLatitude && dropLongitude) {
        const distanceValidation = validateDeliveryDistance(
          nextPickupLatitude,
          nextPickupLongitude,
          dropLatitude,
          dropLongitude
        );

        if (!distanceValidation.isValid) {
          setExceedingDistance(distanceValidation.distance);
          setDistanceExceededModalVisible(true);
          return;
        }
      }

      if (packageOrderType === 'receive') {
        setCurrentStep('type');
      } else {
        setCurrentStep('drop');
      }
    },
    [dropLatitude, dropLongitude, packageOrderType]
  );

  const updatePickupDraftCoordinate = useCallback((coordinate: any) => {
    const normalized = normalizeCoordinate(coordinate);
    if (!normalized) {
      return;
    }

    setPickupDraftCoordinate(normalized);
    setPickupDraftRegion((previousRegion) => {
      const fallbackRegion: Region = {
        latitude: normalized.latitude,
        longitude: normalized.longitude,
        latitudeDelta: 0.01,
        longitudeDelta: 0.01,
      };

      return previousRegion
        ? {
            ...previousRegion,
            latitude: normalized.latitude,
            longitude: normalized.longitude,
          }
        : fallbackRegion;
    });
  }, []);

  const openPickupMapPicker = useCallback(() => {
    const normalizedPickupCoordinate = normalizeCoordinate({
      latitude: pickupLatitude,
      longitude: pickupLongitude,
    });

    if (!normalizedPickupCoordinate) {
      Alert.alert('Required', 'Please select a valid pickup location');
      return;
    }

    setPickupDraftCoordinate(normalizedPickupCoordinate);
    setPickupDraftAddress(pickupAddress || '');
    setPickupDraftRegion({
      latitude: normalizedPickupCoordinate.latitude,
      longitude: normalizedPickupCoordinate.longitude,
      latitudeDelta: clampMapDelta(0.01, 0.01),
      longitudeDelta: clampMapDelta(0.01, 0.01),
    });
    setPickupMapPickerVisible(true);
  }, [pickupAddress, pickupLatitude, pickupLongitude]);

  const handleConfirmPickupFromMap = useCallback(async () => {
    if (!pickupDraftCoordinate) {
      Alert.alert('Required', 'Please select a valid pickup location on map');
      return;
    }

    setPickupMapConfirming(true);
    try {
      const normalized = normalizeCoordinate(pickupDraftCoordinate);
      if (!normalized) {
        Alert.alert('Location Error', 'Selected map location is invalid');
        return;
      }

      let resolvedAddress: string | null = pickupDraftAddress?.trim() || null;
      if (!resolvedAddress) {
        resolvedAddress = await reverseGeocodeToAddress(normalized.latitude, normalized.longitude);
      }

      if (resolvedAddress) {
        setPickupAddress(resolvedAddress);
      }

      setPickupLatitude(normalized.latitude);
      setPickupLongitude(normalized.longitude);
      setPickupPlaceId(null);
      setPickupSuggestions([]);
      refreshPickupSessionToken();
      setPickupMapPickerVisible(false);

      proceedAfterPickupSelection(normalized.latitude, normalized.longitude);
    } catch (error) {
      console.error('Confirm pickup from map failed:', error);
      Alert.alert('Error', 'Unable to confirm location from map. Please try again.');
    } finally {
      setPickupMapConfirming(false);
    }
  }, [pickupDraftAddress, pickupDraftCoordinate, proceedAfterPickupSelection]);

  const updateDropDraftCoordinate = useCallback((coordinate: any) => {
    const normalized = normalizeCoordinate(coordinate);
    if (!normalized) {
      return;
    }

    setDropDraftCoordinate(normalized);
    setDropDraftRegion((previousRegion) => {
      const fallbackRegion: Region = {
        latitude: normalized.latitude,
        longitude: normalized.longitude,
        latitudeDelta: 0.01,
        longitudeDelta: 0.01,
      };

      return previousRegion
        ? {
            ...previousRegion,
            latitude: normalized.latitude,
            longitude: normalized.longitude,
          }
        : fallbackRegion;
    });
  }, []);

  const openDropMapPicker = useCallback(() => {
    const normalizedDropCoordinate = normalizeCoordinate({
      latitude: dropLatitude,
      longitude: dropLongitude,
    });

    if (!normalizedDropCoordinate) {
      Alert.alert('Required', 'Please select a valid drop location');
      return;
    }

    setDropDraftCoordinate(normalizedDropCoordinate);
    setDropDraftAddress(dropAddress || '');
    setDropDraftRegion({
      latitude: normalizedDropCoordinate.latitude,
      longitude: normalizedDropCoordinate.longitude,
      latitudeDelta: clampMapDelta(0.01, 0.01),
      longitudeDelta: clampMapDelta(0.01, 0.01),
    });
    setDropMapPickerVisible(true);
  }, [dropAddress, dropLatitude, dropLongitude]);

  const handleConfirmDropFromMap = useCallback(async () => {
    if (!dropDraftCoordinate) {
      Alert.alert('Required', 'Please select a valid drop location on map');
      return;
    }

    setDropMapConfirming(true);
    try {
      const normalized = normalizeCoordinate(dropDraftCoordinate);
      if (!normalized) {
        Alert.alert('Location Error', 'Selected map location is invalid');
        return;
      }

      let resolvedAddress: string | null = dropDraftAddress?.trim() || null;
      if (!resolvedAddress) {
        resolvedAddress = await reverseGeocodeToAddress(normalized.latitude, normalized.longitude);
      }

      if (resolvedAddress) {
        setDropAddress(resolvedAddress);
      }

      setDropLatitude(normalized.latitude);
      setDropLongitude(normalized.longitude);
      setDropPlaceId(null);
      setDropSuggestions([]);
      refreshDropSessionToken();
      setDropMapPickerVisible(false);

      proceedAfterDropSelection(normalized.latitude, normalized.longitude);
    } catch (error) {
      console.error('Confirm drop from map failed:', error);
      Alert.alert('Error', 'Unable to confirm location from map. Please try again.');
    } finally {
      setDropMapConfirming(false);
    }
  }, [dropDraftAddress, dropDraftCoordinate, proceedAfterDropSelection]);

  // Fetch package orders
  const loadPackageOrders = useCallback(async (isRefresh = false) => {
    const userId = user?.id || user?._id;
    if (!userId) {
      setPackageOrders([]);
      return;
    }

    try {
      isRefresh ? setOrdersRefreshing(true) : setOrdersLoading(true);
      // Fetch all package orders for the customer (no status filter)
      const data = await fetchPackageOrders('all', String(userId), 'customer');
      // Filter to only show package orders
      const filteredOrders = Array.isArray(data)
        ? data.filter((order: any) => order.orderType === 'package' || order.packageType)
        : [];
      setPackageOrders(filteredOrders);
    } catch (err) {
      console.log('Load package orders error', err);
      setPackageOrders([]);
    } finally {
      isRefresh ? setOrdersRefreshing(false) : setOrdersLoading(false);
    }
  }, [user]);

  // Load orders when switching to orders view
  useEffect(() => {
    if (viewMode === 'orders') {
      loadPackageOrders();
    }
  }, [viewMode, loadPackageOrders]);

  // Cleanup on unmount
  useEffect(() => {
    isMountedRef.current = true;
    return () => {
      isMountedRef.current = false;
      if (suggestionTimeoutRef.current) {
        clearTimeout(suggestionTimeoutRef.current);
      }
    };
  }, []);

  useEffect(() => {
    if (!dropMapPickerVisible || !dropDraftCoordinate) {
      return;
    }

    const timeoutId = setTimeout(async () => {
      try {
        const resolvedAddress = await reverseGeocodeToAddress(
          dropDraftCoordinate.latitude,
          dropDraftCoordinate.longitude
        );

        if (resolvedAddress && isMountedRef.current) {
          setDropDraftAddress(resolvedAddress);
        }
      } catch (error) {
        console.log('Drop map reverse geocode error', error);
      }
    }, 400);

    return () => clearTimeout(timeoutId);
  }, [dropDraftCoordinate, dropMapPickerVisible]);

  useEffect(() => {
    if (!pickupMapPickerVisible || !pickupDraftCoordinate) {
      return;
    }

    const timeoutId = setTimeout(async () => {
      try {
        const resolvedAddress = await reverseGeocodeToAddress(
          pickupDraftCoordinate.latitude,
          pickupDraftCoordinate.longitude
        );

        if (resolvedAddress && isMountedRef.current) {
          setPickupDraftAddress(resolvedAddress);
        }
      } catch (error) {
        console.log('Pickup map reverse geocode error', error);
      }
    }, 400);

    return () => clearTimeout(timeoutId);
  }, [pickupDraftCoordinate, pickupMapPickerVisible]);

  // Request location permissions
  const requestLocationPermission = async () => {
    if (RNPlatform.OS === 'android') {
      try {
        const permissions = [
          PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
          PermissionsAndroid.PERMISSIONS.ACCESS_COARSE_LOCATION,
        ];

        const alreadyGranted = await Promise.all(
          permissions.map((perm) => PermissionsAndroid.check(perm))
        );

        if (alreadyGranted.some(Boolean)) {
          return true;
        }

        const result = await PermissionsAndroid.requestMultiple(permissions);
        const isGranted =
          result[PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION] ===
            PermissionsAndroid.RESULTS.GRANTED ||
          result[PermissionsAndroid.PERMISSIONS.ACCESS_COARSE_LOCATION] ===
            PermissionsAndroid.RESULTS.GRANTED;

        if (!isGranted) {
          const deniedForever = Object.values(result).some(
            (status) => status === PermissionsAndroid.RESULTS.NEVER_ASK_AGAIN
          );

          const message = deniedForever
            ? 'Location permission is permanently denied. Please enable it from settings.'
            : 'Location permission is required to auto-detect your location.';

          Alert.alert(
            'Permission Required',
            message,
            deniedForever
              ? [
                  { text: 'Cancel', style: 'cancel' },
                  {
                    text: 'Open Settings',
                    onPress: () => Linking.openSettings(),
                  },
                ]
              : [{ text: 'OK' }]
          );
        }

        return isGranted;
      } catch (err) {
        console.warn('Permission request error:', err);
        return false;
      }
    } else {
      // For iOS, we'll rely on the getCurrentPosition call to trigger permission request
      return true;
    }
  };

  const openDeviceLocationSettings = useCallback(async () => {
    try {
      if (
        RNPlatform.OS === 'android' &&
        typeof (Linking as any).sendIntent === 'function'
      ) {
        await (Linking as any).sendIntent('android.settings.LOCATION_SOURCE_SETTINGS');
        return;
      }
      await Linking.openSettings();
    } catch (error) {
      console.warn('Failed to open location settings:', error);
    }
  }, []);

  // Get current location with retry mechanism
  const getCurrentLocation = useCallback(async () => {
    try {
      const hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        Alert.alert(
          'Location Permission',
          'Location permission is required to auto-detect your pickup location. You can still enter the address manually.',
          [{ text: 'OK' }]
        );
        return null;
      }

      setLocationLoading(true);

      // Try multiple configurations with increasing timeout and different accuracy levels
      const configs = [
        { enableHighAccuracy: false, timeout: 10000, maximumAge: 300000 }, // 5 min cache, 10s timeout, low accuracy
        { enableHighAccuracy: false, timeout: 20000, maximumAge: 600000 }, // 10 min cache, 20s timeout, low accuracy
        { enableHighAccuracy: true, timeout: 30000, maximumAge: 0 }, // No cache, 30s timeout, high accuracy
      ];

      for (let attempt = 0; attempt < configs.length; attempt++) {
        const config = configs[attempt];
        console.log(`📍 Location attempt ${attempt + 1} with config:`, config);

        try {
          const location = await new Promise<{ latitude: number; longitude: number } | null>(
            (resolve, reject) => {
              const timeoutId = setTimeout(() => {
                reject(new Error('Location request timed out'));
              }, config.timeout + 2000); // Add 2s buffer

              Geolocation.getCurrentPosition(
                (position) => {
                  clearTimeout(timeoutId);
                  try {
                    const { latitude, longitude } = position.coords;

                    // Validate coordinates
                    if (
                      typeof latitude === 'number' &&
                      typeof longitude === 'number' &&
                      !isNaN(latitude) &&
                      !isNaN(longitude) &&
                      latitude >= -90 &&
                      latitude <= 90 &&
                      longitude >= -180 &&
                      longitude <= 180
                    ) {
                      console.log('📍 Location obtained:', latitude, longitude);
                      resolve({ latitude, longitude });
                    } else {
                      reject(new Error('Invalid coordinates received'));
                    }
                  } catch (error) {
                    reject(error);
                  }
                },
                (error) => {
                  clearTimeout(timeoutId);
                  reject(error);
                },
                config
              );
            }
          );

          if (location) {
            setLocationLoading(false);
            return location;
          }
        } catch (error: any) {
          console.warn(`📍 Location attempt ${attempt + 1} failed:`, error.message);

          // If this is the last attempt, show error to user
          if (attempt === configs.length - 1) {
            setLocationLoading(false);
            if (error.code === 2) {
              Alert.alert(
                'Location Services Off',
                'Location provider unavailable. Please turn on GPS/Location and try again.',
                [
                  { text: 'Cancel', style: 'cancel' },
                  { text: 'Open Location Settings', onPress: openDeviceLocationSettings },
                  { text: 'Retry', onPress: () => getCurrentLocation() },
                ]
              );
              return null;
            }

            const errorMessage =
              error.code === 3 || error.message?.includes('timeout')
                ? 'Location request timed out. Please try again or enter the address manually.'
                : error.code === 1
                ? 'Location permission denied. Please enable location permissions in settings.'
                : 'Unable to get your location. Please enter the address manually.';

            Alert.alert('Location Error', errorMessage, [{ text: 'OK' }]);
            return null;
          }

          // Continue to next attempt
          continue;
        }
      }

      setLocationLoading(false);
      return null;
    } catch (error: any) {
      console.warn('Get location failed:', error);
      setLocationLoading(false);
      Alert.alert(
        'Location Error',
        'Unable to get your location. Please enter the address manually.',
        [{ text: 'OK' }]
      );
      return null;
    }
  }, [openDeviceLocationSettings]);

  // Auto-detect pickup location
  const handleAutoDetectPickup = useCallback(async () => {
    const location = await getCurrentLocation();
    if (location) {
      try {
        const address = await reverseGeocodeToAddress(location.latitude, location.longitude);
        if (address) {
          const normalized = normalizeCoordinate(location);
          if (!normalized) {
            Alert.alert('Location Error', 'Could not detect a valid pickup location.', [{ text: 'OK' }]);
            return;
          }
          setPickupAddress(address);
          setPickupLatitude(normalized.latitude);
          setPickupLongitude(normalized.longitude);
          setPickupPlaceId(null);
          refreshPickupSessionToken();

          // Validate distance if drop location is already selected
          if (dropLatitude && dropLongitude) {
            const distanceValidation = validateDeliveryDistance(
              location.latitude,
              location.longitude,
              dropLatitude,
              dropLongitude
            );

            if (!distanceValidation.isValid) {
              setExceedingDistance(distanceValidation.distance);
              setDistanceExceededModalVisible(true);
            }
          }
        } else {
          Alert.alert(
            'Address Not Found',
            'Could not find the address for your location. Please enter the address manually.',
            [{ text: 'OK' }]
          );
        }
      } catch (error) {
        console.error('Reverse geocoding error:', error);
        Alert.alert(
          'Address Error',
          'Could not get address for your location. Please enter the address manually.',
          [{ text: 'OK' }]
        );
      }
    }
  }, [getCurrentLocation, dropLatitude, dropLongitude]);

  // Auto-detect drop location
  const handleAutoDetectDrop = useCallback(async () => {
    const location = await getCurrentLocation();
    if (location) {
      try {
        const address = await reverseGeocodeToAddress(location.latitude, location.longitude);
        if (address) {
          const normalized = normalizeCoordinate(location);
          if (!normalized) {
            Alert.alert('Location Error', 'Could not detect a valid drop location.', [{ text: 'OK' }]);
            return;
          }
          setDropAddress(address);
          setDropLatitude(normalized.latitude);
          setDropLongitude(normalized.longitude);
          setDropPlaceId(null);
          refreshDropSessionToken();

          // Validate distance if pickup location is already selected
          if (pickupLatitude && pickupLongitude) {
            const distanceValidation = validateDeliveryDistance(
              pickupLatitude,
              pickupLongitude,
              location.latitude,
              location.longitude
            );

            if (!distanceValidation.isValid) {
              setExceedingDistance(distanceValidation.distance);
              setDistanceExceededModalVisible(true);
            }
          }
        } else {
          Alert.alert(
            'Address Not Found',
            'Could not find the address for your location. Please enter the address manually.',
            [{ text: 'OK' }]
          );
        }
      } catch (error) {
        console.error('Reverse geocoding error:', error);
        Alert.alert(
          'Address Error',
          'Could not get address for your location. Please enter the address manually.',
          [{ text: 'OK' }]
        );
      }
    }
  }, [getCurrentLocation, pickupLatitude, pickupLongitude]);

  // Fetch pickup suggestions
  const fetchPickupSuggestions = useCallback(
    async (query: string) => {
      try {
        setPickupSuggestionLoading(true);
        const currentLocation = pickupLatitude && pickupLongitude
          ? { latitude: pickupLatitude, longitude: pickupLongitude }
          : await getCurrentLocation();

        const bias = currentLocation
          ? {
              latitude: currentLocation.latitude,
              longitude: currentLocation.longitude,
              radiusMeters: packageMapRadiusMeters,
            }
          : undefined;

        const results = await getPlaceSuggestions(query, pickupSessionToken, bias);
        setPickupSuggestions(results);
      } catch (err) {
        console.log('Pickup suggestion error:', err);
        setPickupSuggestions([]);
      } finally {
        setPickupSuggestionLoading(false);
      }
    },
    [
      getCurrentLocation,
      packageMapRadiusMeters,
      pickupLatitude,
      pickupLongitude,
      pickupSessionToken,
    ]
  );

  // Handle pickup address change
  const handlePickupAddressChange = (text: string) => {
    setPickupAddress(text);
    setPickupLatitude(null);
    setPickupLongitude(null);
    setPickupPlaceId(null);

    if (suggestionTimeoutRef.current) {clearTimeout(suggestionTimeoutRef.current);}

    suggestionTimeoutRef.current = setTimeout(() => {
      if (text.trim().length >= 2) {
        fetchPickupSuggestions(text);
      } else {
        setPickupSuggestions([]);
      }
    }, 400);
  };

  // Handle pickup suggestion select
  const handlePickupSuggestionSelect = async (suggestion: any) => {
    setPickupSuggestionLoading(true);
    try {
      const details = await getPlaceDetails(suggestion.place_id, pickupSessionToken);
      const normalized = normalizeCoordinate({
        latitude: details?.latitude,
        longitude: details?.longitude,
      });
      if (details && normalized) {
        setPickupAddress(details.address);
        setPickupLatitude(normalized.latitude);
        setPickupLongitude(normalized.longitude);
        setPickupPlaceId(details.placeId);
        setPickupSuggestions([]);
        refreshPickupSessionToken();

        // Validate distance if drop location is already selected
        if (dropLatitude && dropLongitude) {
          const distanceValidation = validateDeliveryDistance(
            normalized.latitude,
            normalized.longitude,
            dropLatitude,
            dropLongitude
          );

          if (!distanceValidation.isValid) {
            setExceedingDistance(distanceValidation.distance);
            setDistanceExceededModalVisible(true);
          }
        }
      }
    } finally {
      setPickupSuggestionLoading(false);
    }
  };

  // Fetch drop suggestions
  const fetchDropSuggestions = useCallback(
    async (query: string) => {
      try {
        setDropSuggestionLoading(true);
        const currentLocation = dropLatitude && dropLongitude
          ? { latitude: dropLatitude, longitude: dropLongitude }
          : await getCurrentLocation();

        const bias = currentLocation
          ? {
              latitude: currentLocation.latitude,
              longitude: currentLocation.longitude,
              radiusMeters: packageMapRadiusMeters,
            }
          : undefined;

        const results = await getPlaceSuggestions(query, dropSessionToken, bias);
        setDropSuggestions(results);
      } catch (err) {
        console.log('Drop suggestion error:', err);
        setDropSuggestions([]);
      } finally {
        setDropSuggestionLoading(false);
      }
    },
    [
      dropLatitude,
      dropLongitude,
      dropSessionToken,
      getCurrentLocation,
      packageMapRadiusMeters,
    ]
  );

  // Handle drop address change
  const handleDropAddressChange = (text: string) => {
    setDropAddress(text);
    setDropLatitude(null);
    setDropLongitude(null);
    setDropPlaceId(null);

    if (suggestionTimeoutRef.current) {clearTimeout(suggestionTimeoutRef.current);}

    suggestionTimeoutRef.current = setTimeout(() => {
      if (text.trim().length >= 2) {
        fetchDropSuggestions(text);
      } else {
        setDropSuggestions([]);
      }
    }, 400);
  };

  // Handle drop suggestion select
  const handleDropSuggestionSelect = async (suggestion: any) => {
    setDropSuggestionLoading(true);
    try {
      const details = await getPlaceDetails(suggestion.place_id, dropSessionToken);
      const normalized = normalizeCoordinate({
        latitude: details?.latitude,
        longitude: details?.longitude,
      });
      if (details && normalized) {
        setDropAddress(details.address);
        setDropLatitude(normalized.latitude);
        setDropLongitude(normalized.longitude);
        setDropPlaceId(details.placeId);
        setDropSuggestions([]);
        refreshDropSessionToken();

        // Validate distance if pickup location is already selected
        if (pickupLatitude && pickupLongitude) {
          const distanceValidation = validateDeliveryDistance(
            pickupLatitude,
            pickupLongitude,
            normalized.latitude,
            normalized.longitude
          );

          if (!distanceValidation.isValid) {
            setExceedingDistance(distanceValidation.distance);
            setDistanceExceededModalVisible(true);
          }
        }
      }
    } finally {
      setDropSuggestionLoading(false);
    }
  };

  const refreshPickupSessionToken = () => {
    setPickupSessionToken(generatePlacesSessionToken());
  };

  const refreshDropSessionToken = () => {
    setDropSessionToken(generatePlacesSessionToken());
  };

  // Calculate distance and charge with error handling and retry
  useEffect(() => {
    let isMounted = true;
    let timeoutId: ReturnType<typeof setTimeout> | null = null;

    const calculateRoute = async () => {
      if (pickupCoordinate && dropCoordinate && currentStep === 'review') {
        setCalculating(true);
        try {
          const result = await getDistanceMatrix(
            pickupCoordinate,
            dropCoordinate
          );

          if (!isMounted) {return;}

          if (result) {
            const distanceKm = result.distance.value / 1000; // Convert meters to km

            // Validate delivery distance (30km limit)
            const distanceValidation = validateDeliveryDistance(
              pickupCoordinate.latitude,
              pickupCoordinate.longitude,
              dropCoordinate.latitude,
              dropCoordinate.longitude
            );

            if (!distanceValidation.isValid) {
              // Distance exceeds 30km limit - show modal
              setExceedingDistance(distanceValidation.distance);
              setDistanceExceededModalVisible(true);
              return;
            }

            setDistance(result.distance.value);
            setDistanceText(result.distance.text);
            setDuration(result.duration.value);
            setDurationText(result.duration.text);

            // Calculate delivery charge: Base Charge + (Distance in km × Per km charge)
            // Example: Distance = 7.4 km → Final = ₹30 + (7.4 × 8) = ₹89
            const calculatedCharge =
              packageBaseFee + (distanceKm * packagePerKmFee);
            setDeliveryCharge(Math.round(calculatedCharge));

            // Update map region to show both locations
            const minLat = Math.min(pickupCoordinate.latitude, dropCoordinate.latitude);
            const maxLat = Math.max(pickupCoordinate.latitude, dropCoordinate.latitude);
            const minLng = Math.min(pickupCoordinate.longitude, dropCoordinate.longitude);
            const maxLng = Math.max(pickupCoordinate.longitude, dropCoordinate.longitude);

            const latDelta = (maxLat - minLat) * 1.5;
            const lngDelta = (maxLng - minLng) * 1.5;

            setMapRegion({
              latitude: (minLat + maxLat) / 2,
              longitude: (minLng + maxLng) / 2,
              latitudeDelta: clampMapDelta(Math.max(latDelta, 0.01), 0.01),
              longitudeDelta: clampMapDelta(Math.max(lngDelta, 0.01), 0.01),
            });

            // Fit map to show both markers
            if (mapRef.current && isMounted) {
              timeoutId = setTimeout(() => {
                if (mapRef.current && isMounted) {
                  mapRef.current.fitToCoordinates(
                    [
                      pickupCoordinate,
                      dropCoordinate,
                    ],
                    {
                      edgePadding: { top: 50, right: 50, bottom: 50, left: 50 },
                      animated: true,
                    }
                  );
                }
              }, 100);
            }
          } else {
            if (isMounted) {
              Alert.alert(
                'Route Calculation Failed',
                'Unable to calculate route. Please check the locations and try again.',
                [{ text: 'OK' }]
              );
            }
          }
        } catch (error: any) {
          console.error('Calculate route error:', error);
          if (isMounted) {
            const errorMessage =
              error?.message ||
              'Failed to calculate route. Please check your internet connection and try again.';
            Alert.alert('Route Calculation Error', errorMessage, [{ text: 'OK' }]);
          }
        } finally {
          if (isMounted) {
            setCalculating(false);
          }
        }
      }
    };

    // Debounce calculation to avoid too many API calls
    timeoutId = setTimeout(() => {
      calculateRoute();
    }, 300);

    return () => {
      isMounted = false;
      if (timeoutId) {
        clearTimeout(timeoutId);
      }
    };
  }, [
    currentStep,
    dropCoordinate,
    packageBaseFee,
    packagePerKmFee,
    pickupCoordinate,
  ]);

  // Handle step navigation
  const handleNext = () => {
    if (currentStep === 'initial') {
      // This will be handled by handleStartSend or handleStartReceive
      return;
    } else if (currentStep === 'drop') {
      if (!dropAddress || !dropLatitude || !dropLongitude) {
        Alert.alert('Required', 'Please select a valid drop location');
        return;
      }

      // Receive flow: skip map on drop, confirm map on pickup step instead.
      if (packageOrderType === 'receive') {
        setCurrentStep('pickup');
        return;
      }

      openDropMapPicker();
    } else if (currentStep === 'pickup') {
      if (!pickupAddress || !pickupLatitude || !pickupLongitude) {
        Alert.alert('Required', 'Please select a valid pickup location');
        return;
      }

      // Validate distance if both pickup and drop locations are available
      if (pickupLatitude && pickupLongitude && dropLatitude && dropLongitude) {
        const distanceValidation = validateDeliveryDistance(
          pickupLatitude,
          pickupLongitude,
          dropLatitude,
          dropLongitude
        );

        if (!distanceValidation.isValid) {
          setExceedingDistance(distanceValidation.distance);
          setDistanceExceededModalVisible(true);
          return;
        }
      }

      if (packageOrderType === 'receive') {
        openPickupMapPicker();
        return;
      }

      setCurrentStep('drop');
    } else if (currentStep === 'type') {
      if (!selectedPackageType) {
        Alert.alert('Required', 'Please select a package type');
        return;
      }
      setCurrentStep('review');
    }
  };

  // Handle starting send package flow
  const handleStartSend = () => {
    setPackageOrderType('send');
    setCurrentStep('pickup');
  };

  // Handle starting receive package flow
  const handleStartReceive = () => {
    setPackageOrderType('receive');
    setCurrentStep('drop'); // For receive, drop location comes first
  };

  const handleBack = () => {
    if (currentStep === 'pickup') {
      // For receive flow, pickup comes after drop, so go back to drop
      // For send flow, pickup is first, so go back to initial
      if (packageOrderType === 'receive') {
        setCurrentStep('drop');
      } else {
        setCurrentStep('initial');
      }
    } else if (currentStep === 'drop') {
      // For receive flow, drop comes first, so go back to initial
      // For send flow, drop comes after pickup
      if (packageOrderType === 'receive') {
        setCurrentStep('initial');
      } else {
        setCurrentStep('pickup');
      }
    } else if (currentStep === 'type') {
      // For receive flow, type comes after pickup, so go back to pickup
      // For send flow, type comes after drop
      if (packageOrderType === 'receive') {
        setCurrentStep('pickup');
      } else {
        setCurrentStep('drop');
      }
    } else if (currentStep === 'review') {
      setCurrentStep('type');
    }
  };

  // Create package order with comprehensive validation and error handling
  const handleCreateOrder = async () => {
    // Check agreement first
    if (!agreementChecked) {
      Alert.alert(
        'Agreement Required',
        'Please confirm that your package does not contain any prohibited items before proceeding.',
        [{ text: 'OK' }]
      );
      return;
    }

    // Validate all required fields
    const validationData = {
      pickupAddress,
      pickupLatitude,
      pickupLongitude,
      dropAddress,
      dropLatitude,
      dropLongitude,
      packageType: selectedPackageType,
      distance,
      deliveryCharge,
    };

    const validation = validatePackageOrder(validationData);
    if (!validation.isValid) {
      Alert.alert(
        'Validation Error',
        validation.errors.join('\n'),
        [{ text: 'OK' }]
      );
      return;
    }

    setLoading(true);
    try {
      const orderData = await createPackageOrder({
        pickupLocation: {
          address: pickupAddress.trim(),
          latitude: pickupLatitude!,
          longitude: pickupLongitude!,
          placeId: pickupPlaceId || undefined,
        },
        dropLocation: {
          address: dropAddress.trim(),
          latitude: dropLatitude!,
          longitude: dropLongitude!,
          placeId: dropPlaceId || undefined,
        },
        packageType: selectedPackageType!,
        distance: distance!,
        distanceText: distanceText,
        duration: duration || 0,
        durationText: durationText,
        deliveryCharge: deliveryCharge,
        customerName: user?.name || undefined,
        customerPhone: user?.phone || undefined,
        orderType: packageOrderType,
        agreement: agreementChecked,
      });

      if (orderData && orderData.id) {
        // Set current order
        const { setCurrentOrder } = useAuthStore.getState();
        setCurrentOrder(orderData);

        // Reset form state
        setCurrentStep('initial');
        setPickupAddress('');
        setPickupLatitude(null);
        setPickupLongitude(null);
        setPickupPlaceId(null);
        setDropAddress('');
        setDropLatitude(null);
        setDropLongitude(null);
        setDropPlaceId(null);
        setSelectedPackageType(null);
        setDistance(null);
        setDistanceText('');
        setDuration(null);
        setDurationText('');
        setDeliveryCharge(0);
        setPackageOrderType('send');
        setAgreementChecked(false);

        // Switch to orders view and refresh the list
        setViewMode('orders');
        loadPackageOrders();
      } else {
        Alert.alert(
          'Error',
          'Failed to create package order. Please try again.',
          [
            { text: 'Cancel', style: 'cancel' },
            { text: 'Retry', onPress: handleCreateOrder },
          ]
        );
      }
    } catch (error: any) {
      console.error('Create order error:', error);

      // Show user-friendly error message
      const errorMessage =
        error?.message ||
        error?.response?.data?.message ||
        'Failed to create package order. Please check your connection and try again.';

      Alert.alert(
        'Order Creation Failed',
        errorMessage,
        [
          { text: 'OK', style: 'cancel' },
          {
            text: 'Retry',
            onPress: () => {
              // Retry after a short delay
              setTimeout(() => handleCreateOrder(), 500);
            },
          },
        ]
      );
    } finally {
      setLoading(false);
    }
  };

  const renderInitialStep = () => (
    <View style={styles.stepContainer}>
      {/* Send Package Option */}
      <View style={styles.optionCard}>
        <View style={styles.iconContainer}>
          <Icon name="send-outline" size={RFValue(48)} color={colors.primaryBlue} />
        </View>
        <CustomText
          fontFamily={Fonts.Bold}
          fontSize={18}
          style={styles.optionTitle}
        >
          Send Package
        </CustomText>
        <CustomText
          fontFamily={Fonts.Medium}
          fontSize={11}
          style={styles.optionSubtitle}
        >
          Send your package to any location
        </CustomText>
        <CustomButton
          onPress={handleStartSend}
          title="Get Started"
          disabled={false}
          loading={false}
        />
      </View>

      {/* Receive Package Option */}
      <View style={styles.optionCard}>
        <View style={styles.iconContainer}>
          <Icon name="download-outline" size={RFValue(48)} color={colors.primaryBlue} />
        </View>
        <CustomText
          fontFamily={Fonts.Bold}
          fontSize={18}
          style={styles.optionTitle}
        >
          Receive Package
        </CustomText>
        <CustomText
          fontFamily={Fonts.Medium}
          fontSize={11}
          style={styles.optionSubtitle}
        >
          Receive a package at your location
        </CustomText>
        <CustomButton
          onPress={handleStartReceive}
          title="Get Started"
          disabled={false}
          loading={false}
        />
      </View>
    </View>
  );

  const renderPickupStep = () => (
    <View style={styles.stepContainer}>
      <CustomText fontFamily={Fonts.Bold} fontSize={20} style={styles.stepTitle}>
        Pickup Location
      </CustomText>
      <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.stepSubtitle}>
        {packageOrderType === 'receive'
          ? 'Where should we pick up the package from?'
          : 'Where should we pick up your package?'}
      </CustomText>

      <View style={styles.inputContainer}>
        <CustomInput
          left={
            <View style={styles.inputIcon}>
              <Icon name="location" size={RFValue(20)} color={colors.primaryBlue} />
            </View>
          }
          placeholder="Enter pickup address"
          value={pickupAddress}
          onChangeText={handlePickupAddressChange}
          onClear={() => {
            setPickupAddress('');
            setPickupLatitude(null);
            setPickupLongitude(null);
            setPickupPlaceId(null);
            setPickupSuggestions([]);
          }}
        />

        {packageOrderType !== 'receive' && (
          <TouchableOpacity
            style={[styles.autoDetectButton, locationLoading && styles.autoDetectButtonLoading]}
            onPress={handleAutoDetectPickup}
            disabled={locationLoading}
          >
            {locationLoading ? (
              <>
                <ActivityIndicator size="small" color={colors.primaryBlue} />
                <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.autoDetectText}>
                  Detecting location...
                </CustomText>
              </>
            ) : (
              <>
                <Icon name="locate" size={RFValue(16)} color={colors.primaryBlue} />
                <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.autoDetectText}>
                  Auto Detect Location
                </CustomText>
              </>
            )}
          </TouchableOpacity>
        )}

        {pickupSuggestionLoading && (
          <View style={styles.suggestionLoading}>
            <ActivityIndicator size="small" color={colors.primaryBlue} />
          </View>
        )}

        {pickupSuggestions.length > 0 && (
          <View style={styles.suggestionsList}>
            {pickupSuggestions.map((item) => (
              <TouchableOpacity
                key={item.place_id}
                style={styles.suggestionItem}
                onPress={() => handlePickupSuggestionSelect(item)}
              >
                <Icon name="location-outline" size={RFValue(18)} color={colors.greyText} />
                <View style={styles.suggestionTextContainer}>
                  <CustomText fontFamily={Fonts.SemiBold} fontSize={14}>
                    {item.structured_formatting?.main_text || item.description}
                  </CustomText>
                  <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.suggestionSubtext}>
                    {item.structured_formatting?.secondary_text || ''}
                  </CustomText>
                </View>
              </TouchableOpacity>
            ))}
          </View>
        )}
      </View>

      <View style={styles.buttonRow}>
        <CustomButton
          onPress={handleBack}
          title="Back"
          disabled={false}
          loading={false}
          buttonColor={colors.greyText}
        />
        <CustomButton
          onPress={handleNext}
          title="Next"
          disabled={!pickupAddress || !pickupLatitude || !pickupLongitude}
          loading={false}
        />
      </View>
    </View>
  );

  const renderDropStep = () => (
    <View style={styles.stepContainer}>
      <CustomText fontFamily={Fonts.Bold} fontSize={20} style={styles.stepTitle}>
        {packageOrderType === 'receive' ? 'Drop Location' : 'Drop Location'}
      </CustomText>
      <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.stepSubtitle}>
        {packageOrderType === 'receive'
          ? 'Where should we deliver the package to you?'
          : 'Where should we deliver your package?'}
      </CustomText>

      <View style={styles.inputContainer}>
        <CustomInput
          left={
            <View style={styles.inputIcon}>
              <Icon name="location" size={RFValue(20)} color={colors.primaryBlue} />
            </View>
          }
          placeholder="Enter drop address"
          value={dropAddress}
          onChangeText={handleDropAddressChange}
          onClear={() => {
            setDropAddress('');
            setDropLatitude(null);
            setDropLongitude(null);
            setDropPlaceId(null);
            setDropSuggestions([]);
          }}
        />

        {packageOrderType === 'receive' && (
          <TouchableOpacity
            style={[styles.autoDetectButton, locationLoading && styles.autoDetectButtonLoading]}
            onPress={handleAutoDetectDrop}
            disabled={locationLoading}
          >
            {locationLoading ? (
              <>
                <ActivityIndicator size="small" color={colors.primaryBlue} />
                <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.autoDetectText}>
                  Detecting location...
                </CustomText>
              </>
            ) : (
              <>
                <Icon name="locate" size={RFValue(16)} color={colors.primaryBlue} />
                <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.autoDetectText}>
                  Auto Detect Location
                </CustomText>
              </>
            )}
          </TouchableOpacity>
        )}

        {dropSuggestionLoading && (
          <View style={styles.suggestionLoading}>
            <ActivityIndicator size="small" color={colors.primaryBlue} />
          </View>
        )}

        {dropSuggestions.length > 0 && (
          <View style={styles.suggestionsList}>
            {dropSuggestions.map((item) => (
              <TouchableOpacity
                key={item.place_id}
                style={styles.suggestionItem}
                onPress={() => handleDropSuggestionSelect(item)}
              >
                <Icon name="location-outline" size={RFValue(18)} color={colors.greyText} />
                <View style={styles.suggestionTextContainer}>
                  <CustomText fontFamily={Fonts.SemiBold} fontSize={14}>
                    {item.structured_formatting?.main_text || item.description}
                  </CustomText>
                  <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.suggestionSubtext}>
                    {item.structured_formatting?.secondary_text || ''}
                  </CustomText>
                </View>
              </TouchableOpacity>
            ))}
          </View>
        )}
      </View>

      <View style={styles.buttonRow}>
        <CustomButton
          onPress={handleBack}
          title="Back"
          disabled={false}
          loading={false}
          buttonColor={colors.greyText}
        />
        <CustomButton
          onPress={handleNext}
          title="Next"
          disabled={!dropAddress || !dropLatitude || !dropLongitude}
          loading={false}
        />
      </View>
    </View>
  );

  const renderTypeStep = () => (
    <View style={styles.stepContainer}>
      <CustomText fontFamily={Fonts.Bold} fontSize={20} style={styles.stepTitle}>
        Package Type
      </CustomText>
      <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.stepSubtitle}>
        Select the type of package you're sending
      </CustomText>

      <View style={styles.packageTypeContainer}>
        {packageTypes.map((type) => (
          <TouchableOpacity
            key={type}
            style={[
              styles.packageTypeCard,
              selectedPackageType === type && styles.packageTypeCardSelected,
            ]}
            onPress={() => setSelectedPackageType(type)}
          >
            <Icon
              name={resolvePackageTypeIconName(type)}
              size={RFValue(32)}
              color={selectedPackageType === type ? colors.white : colors.primaryBlue}
            />
            <CustomText
              fontFamily={Fonts.SemiBold}
              fontSize={14}
              style={[
                styles.packageTypeText,
                ...(selectedPackageType === type ? [styles.packageTypeTextSelected] : []),
              ]}
            >
              {type}
            </CustomText>
          </TouchableOpacity>
        ))}
      </View>

      <CustomText
        fontFamily={Fonts.Medium}
        fontSize={12}
        style={styles.packageTypeSafetyNote}
      >
        Please ensure items are suitable for safe delivery.
      </CustomText>

      <View style={styles.buttonRow}>
        <CustomButton
          onPress={handleBack}
          title="Back"
          disabled={false}
          loading={false}
          buttonColor={colors.greyText}
        />
        <CustomButton
          onPress={handleNext}
          title="Next"
          disabled={!selectedPackageType}
          loading={false}
        />
      </View>
    </View>
  );

  const renderReviewStep = () => (
    <View style={styles.stepContainer}>
      <CustomText fontFamily={Fonts.Bold} fontSize={20} style={styles.stepTitle}>
        Review & Confirm
      </CustomText>

      {/* Map View */}
      {mapRegion && pickupCoordinate && dropCoordinate && (
        <View style={styles.mapContainer}>
          <MapView
            ref={mapRef}
            style={styles.map}
            provider="google"
            customMapStyle={customMapStyle}
            region={mapRegion}
            onRegionChangeComplete={(region) =>
              setMapRegion({
                ...region,
                latitudeDelta: clampMapDelta(region.latitudeDelta, 0.01),
                longitudeDelta: clampMapDelta(region.longitudeDelta, 0.01),
              })
            }
            showsUserLocation={false}
            showsMyLocationButton={false}
            toolbarEnabled={false}
          >
            <Marker
              coordinate={pickupCoordinate}
              title="Pickup Location"
              pinColor={colors.accentYellow}
            />
            <Marker
              coordinate={dropCoordinate}
              title="Drop Location"
              pinColor={colors.primaryBlue}
            />
            <MapViewDirections
              origin={pickupCoordinate}
              destination={dropCoordinate}
              apikey={GOOGLE_MAP_API}
              strokeWidth={4}
              strokeColor={colors.secondaryBlue}
              onError={(error) => console.log('Directions error:', error)}
            />
          </MapView>
        </View>
      )}

      {/* Details */}
      <View style={styles.detailsContainer}>
        <View style={styles.detailRow}>
          <Icon name="location-outline" size={RFValue(18)} color={colors.primaryBlue} />
          <View style={styles.detailTextContainer}>
            <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.detailLabel}>
              Pickup
            </CustomText>
            <CustomText fontFamily={Fonts.SemiBold} fontSize={14}>
              {pickupAddress}
            </CustomText>
          </View>
        </View>

        <View style={styles.detailRow}>
          <Icon name="location" size={RFValue(18)} color={colors.primaryBlue} />
          <View style={styles.detailTextContainer}>
            <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.detailLabel}>
              Drop
            </CustomText>
            <CustomText fontFamily={Fonts.SemiBold} fontSize={14}>
              {dropAddress}
            </CustomText>
          </View>
        </View>

        <View style={styles.detailRow}>
          <Icon name="cube-outline" size={RFValue(18)} color={colors.primaryBlue} />
          <View style={styles.detailTextContainer}>
            <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.detailLabel}>
              Package Type
            </CustomText>
            <CustomText fontFamily={Fonts.SemiBold} fontSize={14}>
              {selectedPackageType}
            </CustomText>
          </View>
        </View>

        {calculating ? (
          <View style={styles.calculatingContainer}>
            <ActivityIndicator size="small" color={colors.primaryBlue} />
            <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.calculatingText}>
              Calculating route...
            </CustomText>
          </View>
        ) : (
          distance && (
            <>
              <View style={styles.detailRow}>
                <Icon name="navigate-outline" size={RFValue(18)} color={colors.primaryBlue} />
                <View style={styles.detailTextContainer}>
                  <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.detailLabel}>
                    Distance
                  </CustomText>
                  <CustomText fontFamily={Fonts.SemiBold} fontSize={14}>
                    {distanceText}
                  </CustomText>
                </View>
              </View>

              <View style={styles.detailRow}>
                <Icon name="time-outline" size={RFValue(18)} color={colors.primaryBlue} />
                <View style={styles.detailTextContainer}>
                  <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.detailLabel}>
                    Estimated Time
                  </CustomText>
                  <CustomText fontFamily={Fonts.SemiBold} fontSize={14}>
                    {durationText}
                  </CustomText>
                </View>
              </View>
            </>
          )
        )}

        <View style={styles.chargeContainer}>
          <CustomText fontFamily={Fonts.Bold} fontSize={18} style={styles.chargeLabel}>
            Delivery Charge
          </CustomText>
          <CustomText fontFamily={Fonts.Bold} fontSize={20} style={styles.chargeAmount}>
            ₹{deliveryCharge}
        </CustomText>
        </View>

        {/* Agreement Checkbox */}
        <TouchableOpacity
          style={styles.agreementContainer}
          onPress={() => setAgreementChecked(!agreementChecked)}
          activeOpacity={0.7}
        >
          <View style={[styles.agreementCheckbox, agreementChecked && styles.agreementCheckboxChecked]}>
            {agreementChecked && (
              <MaterialIcons name="check" size={16} color={colors.white} />
            )}
          </View>
          <CustomText style={styles.agreementText} variant="h8" fontFamily={Fonts.Medium}>
            I declare that this package does not contain any prohibited, illegal, or restricted items including cash, jewellery, liquor, drugs, or hazardous materials.
          </CustomText>
        </TouchableOpacity>
      </View>

      <View style={styles.buttonRow}>
        <CustomButton
          onPress={handleBack}
          title="Back"
          disabled={false}
          loading={false}
          buttonColor={colors.greyText}
        />
        <CustomButton
          onPress={handleCreateOrder}
          title={packageOrderType === 'receive' ? 'Confirm & Receive' : 'Confirm & Send'}
          disabled={!distance || calculating || loading || !agreementChecked}
          loading={loading}
        />
      </View>
    </View>
  );

  const renderPackageOrders = () => {
    const keyExtractor = (item: any, index: number) =>
      item?.orderId || item?.id || String(index);

    const renderOrder = ({ item, index }: { item: any; index: number }) => (
      <OrderItem item={item} index={index} />
    );

    if (ordersLoading && packageOrders.length === 0) {
      return (
        <View style={styles.loaderContainer}>
          <ActivityIndicator size="small" color={colors.primaryBlue} />
          <CustomText variant="h8" style={styles.loaderText}>
            Loading your package orders...
          </CustomText>
        </View>
      );
    }

    if (packageOrders.length === 0) {
      return (
        <View style={styles.emptyContainer}>
          <Icon name="cube-outline" size={RFValue(60)} color={colors.greyText} />
          <CustomText variant="h7" fontFamily={Fonts.SemiBold} style={styles.emptyTitle}>
            No Package Orders
          </CustomText>
          <CustomText variant="h9" style={styles.emptyText}>
            You haven't sent any packages yet. Start by creating a new package order.
          </CustomText>
          <CustomButton
            onPress={() => setViewMode('send')}
            title="Send Package"
            disabled={false}
            loading={false}
          />
        </View>
      );
    }

    return (
      <FlatList
        data={packageOrders}
        keyExtractor={keyExtractor}
        renderItem={renderOrder}
        refreshControl={
          <RefreshControl
            refreshing={ordersRefreshing}
            onRefresh={() => loadPackageOrders(true)}
            colors={[colors.primaryBlue]}
            tintColor={colors.primaryBlue}
          />
        }
        contentContainerStyle={[styles.ordersListContent, { paddingBottom: insets.bottom + 120 }]}
        showsVerticalScrollIndicator={false}
      />
    );
  };

  return (

    // <View style={styles.container}>
    <SafeAreaView style={{ flex: 1 }} edges={['top']}>
      <CustomHeader title="Send Package" />

      {/* Tab Switcher */}
      <View style={styles.tabContainer}>
        <TouchableOpacity
          style={[styles.tab, viewMode === 'send' && styles.tabActive]}
          onPress={() => setViewMode('send')}
        >
          <Icon
            name="add-circle-outline"
            size={RFValue(18)}
            color={viewMode === 'send' ? colors.primaryBlue : colors.greyText}
          />
          <CustomText
            fontFamily={Fonts.SemiBold}
            fontSize={14}
            style={[styles.tabText, ...(viewMode === 'send' ? [styles.tabTextActive] : [])]}
          >
            Send Package
          </CustomText>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tab, viewMode === 'orders' && styles.tabActive]}
          onPress={() => setViewMode('orders')}
        >
          <Icon
            name="cube-outline"
            size={RFValue(18)}
            color={viewMode === 'orders' ? colors.primaryBlue : colors.greyText}
          />
          <CustomText
            fontFamily={Fonts.SemiBold}
            fontSize={14}
            style={[styles.tabText, ...(viewMode === 'orders' ? [styles.tabTextActive] : [])]}
          >
            My Packages
          </CustomText>
        </TouchableOpacity>
      </View>

      {viewMode === 'orders' ? (
        <View style={styles.ordersContainer}>
          {renderPackageOrders()}
        </View>
      ) : (
        <KeyboardAvoidingView
          style={styles.keyboardView}
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          keyboardVerticalOffset={Platform.OS === 'ios' ? 0 : 20}
        >
          <ScrollView
            style={styles.scrollView}
            contentContainerStyle={[styles.scrollContent, { paddingBottom: insets.bottom + 120 }]}
            showsVerticalScrollIndicator={false}
            keyboardShouldPersistTaps="handled"
          >
            {currentStep === 'initial' && renderInitialStep()}
            {currentStep === 'pickup' && renderPickupStep()}
            {currentStep === 'drop' && renderDropStep()}
            {currentStep === 'type' && renderTypeStep()}
            {currentStep === 'review' && renderReviewStep()}
          </ScrollView>
        </KeyboardAvoidingView>
      )}

      {/* Distance Exceeded Modal */}
      <DistanceExceededModal
        visible={distanceExceededModalVisible}
        onClose={() => setDistanceExceededModalVisible(false)}
        distance={exceedingDistance}
        maxDistance={maxPackageDistanceKm}
      />

      <Modal
        visible={pickupMapPickerVisible}
        animationType="slide"
        transparent
        onRequestClose={() => setPickupMapPickerVisible(false)}
      >
        <View style={styles.dropMapModalOverlay}>
          <View style={styles.dropMapModalCard}>
            <View style={styles.dropMapModalHeader}>
              <CustomText fontFamily={Fonts.Bold} fontSize={17} style={styles.dropMapModalTitle}>
                Confirm Pickup Location
              </CustomText>
              <TouchableOpacity
                onPress={() => setPickupMapPickerVisible(false)}
                style={styles.dropMapCloseButton}
                accessibilityRole="button"
                accessibilityLabel="Close map pickup selector"
              >
                <Icon name="close" size={RFValue(20)} color={colors.primaryBlue} />
              </TouchableOpacity>
            </View>

            <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.dropMapAddressText}>
              {pickupDraftAddress || 'Move the pin on map to set exact pickup location'}
            </CustomText>

            <View style={styles.dropMapPreviewWrap}>
              {pickupDraftRegion && pickupDraftCoordinate ? (
                <MapView
                  key={`${pickupDraftRegion.latitude}-${pickupDraftRegion.longitude}`}
                  style={styles.dropMapPreview}
                  provider="google"
                  customMapStyle={customMapStyle}
                  initialRegion={pickupDraftRegion}
                  onRegionChangeComplete={(region) => {
                    setPickupDraftRegion({
                      ...region,
                      latitudeDelta: clampMapDelta(region.latitudeDelta, 0.01),
                      longitudeDelta: clampMapDelta(region.longitudeDelta, 0.01),
                    });
                    updatePickupDraftCoordinate({
                      latitude: region.latitude,
                      longitude: region.longitude,
                    });
                  }}
                  showsUserLocation
                  showsCompass={false}
                  toolbarEnabled={false}
                />
              ) : (
                <View style={styles.dropMapLoader}>
                  <ActivityIndicator size="small" color={colors.primaryBlue} />
                </View>
              )}
              <View pointerEvents="none" style={styles.dropMapPin}>
                <View style={styles.dropMapPinHead}>
                  <View style={styles.dropMapPinHeadInner} />
                </View>
                <View style={styles.dropMapPinStick} />
              </View>
            </View>

            <TouchableOpacity
              style={[styles.dropMapConfirmButton, pickupMapConfirming && styles.autoDetectButtonLoading]}
              onPress={handleConfirmPickupFromMap}
              disabled={!pickupDraftCoordinate || pickupMapConfirming}
              activeOpacity={0.85}
            >
              {pickupMapConfirming ? (
                <ActivityIndicator size="small" color={colors.primaryBlue} />
              ) : (
                <CustomText fontFamily={Fonts.SemiBold} fontSize={14} style={styles.dropMapConfirmText}>
                  Set Location
                </CustomText>
              )}
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      <Modal
        visible={dropMapPickerVisible}
        animationType="slide"
        transparent
        onRequestClose={() => setDropMapPickerVisible(false)}
      >
        <View style={styles.dropMapModalOverlay}>
          <View style={styles.dropMapModalCard}>
            <View style={styles.dropMapModalHeader}>
              <CustomText fontFamily={Fonts.Bold} fontSize={17} style={styles.dropMapModalTitle}>
                Confirm Drop Location
              </CustomText>
              <TouchableOpacity
                onPress={() => setDropMapPickerVisible(false)}
                style={styles.dropMapCloseButton}
                accessibilityRole="button"
                accessibilityLabel="Close map location selector"
              >
                <Icon name="close" size={RFValue(20)} color={colors.primaryBlue} />
              </TouchableOpacity>
            </View>

            <CustomText fontFamily={Fonts.Medium} fontSize={12} style={styles.dropMapAddressText}>
              {dropDraftAddress || 'Move the pin on map to set exact drop location'}
            </CustomText>

            <View style={styles.dropMapPreviewWrap}>
              {dropDraftRegion && dropDraftCoordinate ? (
                <MapView
                  key={`${dropDraftRegion.latitude}-${dropDraftRegion.longitude}`}
                  style={styles.dropMapPreview}
                  provider="google"
                  customMapStyle={customMapStyle}
                  initialRegion={dropDraftRegion}
                  onRegionChangeComplete={(region) => {
                    setDropDraftRegion({
                      ...region,
                      latitudeDelta: clampMapDelta(region.latitudeDelta, 0.01),
                      longitudeDelta: clampMapDelta(region.longitudeDelta, 0.01),
                    });
                    updateDropDraftCoordinate({
                      latitude: region.latitude,
                      longitude: region.longitude,
                    });
                  }}
                  showsUserLocation
                  showsCompass={false}
                  toolbarEnabled={false}
                />
              ) : (
                <View style={styles.dropMapLoader}>
                  <ActivityIndicator size="small" color={colors.primaryBlue} />
                </View>
              )}
              <View pointerEvents="none" style={styles.dropMapPin}>
                <View style={styles.dropMapPinHead}>
                  <View style={styles.dropMapPinHeadInner} />
                </View>
                <View style={styles.dropMapPinStick} />
              </View>
            </View>

            <TouchableOpacity
              style={[styles.dropMapConfirmButton, dropMapConfirming && styles.autoDetectButtonLoading]}
              onPress={handleConfirmDropFromMap}
              disabled={!dropDraftCoordinate || dropMapConfirming}
              activeOpacity={0.85}
            >
              {dropMapConfirming ? (
                <ActivityIndicator size="small" color={colors.primaryBlue} />
              ) : (
                <CustomText fontFamily={Fonts.SemiBold} fontSize={14} style={styles.dropMapConfirmText}>
                  Set Location
                </CustomText>
              )}
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      <BottomTabBar />
    </SafeAreaView>

  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F8FF',
  },
  tabContainer: {
    flexDirection: 'row',
    backgroundColor: colors.white,
    marginHorizontal: 16,
    marginTop: 12,
    marginBottom: 8,
    borderRadius: 18,
    paddingHorizontal: 8,
    paddingVertical: 8,
    borderWidth: 1,
    borderColor: colors.blackOpacity05,
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.06,
    shadowRadius: 12,
    elevation: 3,
  },
  tab: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    gap: 8,
    borderRadius: 14,
  },
  tabActive: {
    backgroundColor: '#EEF4FF',
  },
  tabText: {
    color: colors.greyText,
  },
  tabTextActive: {
    color: colors.primaryBlue,
  },
  ordersContainer: {
    flex: 1,
    backgroundColor: '#F5F8FF',
  },
  ordersListContent: {
    padding: 16,
  },
  loaderContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 50,
  },
  loaderText: {
    marginTop: 10,
    color: colors.greyText,
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 30,
    paddingTop: 100,
    marginHorizontal: 16,
  },
  emptyTitle: {
    marginTop: 20,
    marginBottom: 10,
    color: colors.greyText,
  },
  emptyText: {
    textAlign: 'center',
    color: colors.greyText,
    marginBottom: 30,
    lineHeight: 20,
  },
  keyboardView: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: 10,
  },
  stepContainer: {
    padding: 18,
    marginHorizontal: 16,
    marginTop: 10,
    marginBottom: 12,
    backgroundColor: colors.white,
    borderRadius: 22,
    borderWidth: 1,
    borderColor: colors.blackOpacity05,
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.06,
    shadowRadius: 14,
    elevation: 4,
  },
  iconContainer: {
    alignItems: 'center',
    marginBottom: 18,
    marginTop: 8,
  },
  stepTitle: {
    color: colors.primaryBlue,
    marginBottom: 8,
    textAlign: 'center',
  },
  stepSubtitle: {
    color: colors.greyText,
    textAlign: 'center',
    marginBottom: 30,
  },
  inputContainer: {
    marginBottom: 20,
  },
  inputIcon: {
    paddingLeft: 15,
    justifyContent: 'center',
    alignItems: 'center',
  },
  autoDetectButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    paddingHorizontal: 15,
    backgroundColor: '#EEF4FF',
    borderRadius: 12,
    marginTop: 10,
    gap: 8,
    minHeight: 44,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
  },
  autoDetectButtonLoading: {
    opacity: 0.7,
  },
  autoDetectText: {
    color: colors.primaryBlue,
  },
  suggestionLoading: {
    padding: 10,
    alignItems: 'center',
  },
  suggestionsList: {
    maxHeight: 200,
    marginTop: 10,
    backgroundColor: colors.white,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
    overflow: 'hidden',
  },
  suggestionItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    borderBottomWidth: 1,
    borderBottomColor: colors.blackOpacity05,
    gap: 12,
  },
  suggestionTextContainer: {
    flex: 1,
  },
  suggestionSubtext: {
    color: colors.greyText,
    marginTop: 2,
  },
  packageTypeContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    marginBottom: 20,
  },
  packageTypeCard: {
    width: '48%',
    backgroundColor: '#F4F8FF',
    borderRadius: 16,
    padding: 20,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 15,
    borderWidth: 2,
    borderColor: colors.primaryBlueOpacity10,
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 2,
  },
  packageTypeCardSelected: {
    backgroundColor: colors.primaryBlue,
    borderColor: colors.primaryBlue,
  },
  packageTypeText: {
    color: colors.primaryBlue,
    marginTop: 8,
  },
  packageTypeTextSelected: {
    color: colors.white,
  },
  packageTypeSafetyNote: {
    color: colors.greyText,
    textAlign: 'center',
    marginBottom: 8,
    paddingHorizontal: 8,
  },
  buttonRow: {
    flexDirection: 'column',
    marginTop: 20,
  },
  buttonSpacer: {
    height: 10,
  },
  mapContainer: {
    height: 250,
    borderRadius: 18,
    overflow: 'hidden',
    marginBottom: 20,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
  },
  map: {
    flex: 1,
  },
  dropMapModalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(9,39,116,0.35)',
    justifyContent: 'center',
    paddingHorizontal: 18,
    paddingVertical: 26,
  },
  dropMapModalCard: {
    backgroundColor: colors.white,
    borderRadius: 20,
    padding: 16,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
  },
  dropMapModalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 8,
    gap: 8,
  },
  dropMapModalTitle: {
    color: colors.primaryBlue,
    flex: 1,
  },
  dropMapCloseButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#EEF4FF',
  },
  dropMapAddressText: {
    color: colors.greyText,
    marginBottom: 12,
    lineHeight: 18,
  },
  dropMapPreviewWrap: {
    height: 260,
    borderRadius: 16,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
    marginBottom: 14,
  },
  dropMapPreview: {
    flex: 1,
    backgroundColor: colors.white,
  },
  dropMapLoader: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#F4F8FF',
  },
  dropMapPin: {
    position: 'absolute',
    top: '50%',
    left: '50%',
    alignItems: 'center',
    justifyContent: 'center',
    transform: [{ translateX: -15 }, { translateY: -40 }],
  },
  dropMapPinHead: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: colors.primaryBlue,
    borderWidth: 4,
    borderColor: colors.white,
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 4,
    shadowColor: colors.black,
    shadowOpacity: 0.25,
    shadowRadius: 4,
    shadowOffset: { width: 0, height: 3 },
  },
  dropMapPinHeadInner: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: colors.white,
  },
  dropMapPinStick: {
    width: 6,
    height: 22,
    backgroundColor: colors.primaryBlue,
    borderBottomLeftRadius: 3,
    borderBottomRightRadius: 3,
    marginTop: -6,
  },
  dropMapConfirmButton: {
    marginTop: 4,
    borderRadius: 12,
    paddingVertical: 12,
    alignItems: 'center',
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.primaryBlue,
  },
  dropMapConfirmText: {
    color: colors.primaryBlue,
  },
  detailsContainer: {
    backgroundColor: '#EEF4FF',
    borderRadius: 18,
    padding: 16,
    marginBottom: 20,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
  },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 15,
    gap: 12,
  },
  detailTextContainer: {
    flex: 1,
  },
  detailLabel: {
    color: colors.greyText,
    marginBottom: 4,
  },
  calculatingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 15,
    gap: 10,
  },
  calculatingText: {
    color: colors.greyText,
  },
  chargeContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 10,
    paddingTop: 15,
    borderTopWidth: 1,
    borderTopColor: '#D9E6FF',
  },
  chargeLabel: {
    color: colors.primaryBlue,
  },
  chargeAmount: {
    color: colors.primaryBlue,
    fontSize: 24,
  },
  optionCard: {
    backgroundColor: '#F4F8FF',
    borderRadius: 16,
    padding: 16,
    marginBottom: 16,
    alignItems: 'center',
    borderWidth: 2,
    borderColor: colors.primaryBlueOpacity10,
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 2,
  },
  optionTitle: {
    color: colors.primaryBlue,
    marginTop: 8,
    marginBottom: 6,
    textAlign: 'center',
  },
  optionSubtitle: {
    color: colors.greyText,
    textAlign: 'center',
    marginBottom: 16,
  },
  agreementContainer: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginTop: 20,
    paddingHorizontal: 4,
    backgroundColor: colors.white,
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
  },
  agreementCheckbox: {
    width: 20,
    height: 20,
    borderWidth: 2,
    borderColor: colors.primaryBlue,
    borderRadius: 4,
    marginRight: 12,
    marginTop: 2,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: colors.white,
  },
  agreementCheckboxChecked: {
    backgroundColor: colors.primaryBlue,
  },
  agreementText: {
    flex: 1,
    color: colors.primaryBlue,
    lineHeight: 18,
    letterSpacing: 0.4,
  },
});

export default PackageScreen;
