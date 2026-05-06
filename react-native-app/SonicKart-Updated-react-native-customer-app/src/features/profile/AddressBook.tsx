import {
  View,
  StyleSheet,
  ScrollView,
  Alert,
  ActivityIndicator,
  TouchableOpacity,
  Modal,
  KeyboardAvoidingView,
  TouchableWithoutFeedback,
  Linking,
} from 'react-native';
import React, { FC, useCallback, useEffect, useRef, useState } from 'react';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import Geolocation from '@react-native-community/geolocation';
import { Platform, PermissionsAndroid } from 'react-native';
import CustomHeader from '@components/ui/CustomHeader';
import CustomText from '@components/ui/CustomText';
import CustomInput from '@components/ui/CustomInput';
import { Fonts } from '@utils/Constants';
import Icon from 'react-native-vector-icons/Ionicons';
import { RFValue } from 'react-native-responsive-fontsize';
import MapView, { Region } from 'react-native-maps';
import { customMapStyle } from '@utils/CustomMap';
import {
  saveAddress,
  getAddresses,
  updateAddress,
  deleteAddress,
  SavedAddress,
  resolveVendorByCoordinates,
} from '@service/addressService';
import { useAuthStore } from '@state/authStore';
import { useDeliverySettingsStore } from '@state/deliverySettingsStore';
import { useLocationStore } from '@state/locationStore';
import { updateUserLocation } from '@service/authService';
import colors from '../../theme/colors';
import {
  getPlaceDetails,
  getPlaceSuggestions,
  reverseGeocodeToAddress,
} from '@service/mapService';
import {
  buildRegionFromCoordinate,
  clampMapDelta,
  normalizeCoordinate,
} from '@utils/locationUtils';

const generatePlacesSessionToken = () =>
  `${Date.now()}-${Math.random().toString(36).slice(2, 11)}`;

const isExpectedLocationErrorCode = (code?: number) => code === 1 || code === 2 || code === 3;

// Configure Geolocation
Geolocation.setRNConfiguration({
  skipPermissionRequests: false,
  authorizationLevel: 'whenInUse',
  enableBackgroundLocationUpdates: false,
  // Prefer Android location manager to avoid Play Services provider issues on some devices.
  locationProvider: 'android',
});

/**
 * Address book management screen.
 * Handles saved-address CRUD, place suggestions, map picker, and vendor resolution.
 */
const AddressBook: FC = () => {
  const insets = useSafeAreaInsets();
  const { setUser } = useAuthStore();
  const productRadiusKm = useDeliverySettingsStore(
    (state) => state.settings.productRadiusKm
  );
  const { setSelectedAddress, setSelectedVendorId, selectedAddress } = useLocationStore();
  const [fullName, setFullName] = useState('');
  const [contactNumber, setContactNumber] = useState('');
  const [address, setAddress] = useState('');
  const [latitude, setLatitude] = useState<number | null>(null);
  const [longitude, setLongitude] = useState<number | null>(null);
  const [loading, setLoading] = useState(false);
  const [locationLoading, setLocationLoading] = useState(true);
  const [savedAddresses, setSavedAddresses] = useState<SavedAddress[]>([]);
  const [editingAddress, setEditingAddress] = useState<SavedAddress | null>(null);
  const [fetchingAddresses, setFetchingAddresses] = useState(true);
  const [addressModalVisible, setAddressModalVisible] = useState(false);
  const [modalMode, setModalMode] = useState<'add' | 'edit'>('add');
  const [deleteModalVisible, setDeleteModalVisible] = useState(false);
  const [addressToDelete, setAddressToDelete] = useState<SavedAddress | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [statusBanner, setStatusBanner] = useState<{ type: 'success' | 'error'; message: string } | null>(null);
  const [liveLocationAddress, setLiveLocationAddress] = useState('');
  const [addressSuggestions, setAddressSuggestions] = useState<any[]>([]);
  const [suggestionLoading, setSuggestionLoading] = useState(false);
  const [placeId, setPlaceId] = useState<string | null>(null);
  const [placesSessionToken, setPlacesSessionToken] = useState<string>(() => generatePlacesSessionToken());
  const [mapPickerVisible, setMapPickerVisible] = useState(false);
  const [mapRegion, setMapRegion] = useState<Region | null>(null);
  const [mapResolving, setMapResolving] = useState(false);
  const [mapAddressPreview, setMapAddressPreview] = useState('');
  const addressInputSourceRef = useRef<'auto' | 'user'>('auto');
  const suggestionTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const latestAddressRef = useRef(address);
  const MIN_SUGGESTION_QUERY = 2;
  const [selectingAddressId, setSelectingAddressId] = useState<number | null>(null);
  const refreshPlacesSessionToken = useCallback(() => {
    setPlacesSessionToken(generatePlacesSessionToken());
  }, []);

  useEffect(() => {
    latestAddressRef.current = address;
  }, [address]);

  // Request location permissions
  const requestLocationPermission = async () => {
    if (Platform.OS === 'android') {
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
          result[PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION] === PermissionsAndroid.RESULTS.GRANTED ||
          result[PermissionsAndroid.PERMISSIONS.ACCESS_COARSE_LOCATION] === PermissionsAndroid.RESULTS.GRANTED;

        if (!isGranted) {
          const deniedForever = Object.values(result).some(
            (status) => status === PermissionsAndroid.RESULTS.NEVER_ASK_AGAIN
          );

          const message = deniedForever
            ? 'Location permission is permanently denied. Please enable it from settings to auto-fill your address.'
            : 'Location permission is required to auto-fill your address.';

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
      try {
        const hasIosPermission = await new Promise<boolean>((resolve) => {
          Geolocation.requestAuthorization(
            () => resolve(true),
            () => resolve(false)
          );
        });
        return hasIosPermission;
      } catch (err) {
        console.warn('iOS permission request error:', err);
        return false;
      }
    }
  };

  const openDeviceLocationSettings = async () => {
    try {
      if (
        Platform.OS === 'android' &&
        typeof (Linking as any).sendIntent === 'function'
      ) {
        await (Linking as any).sendIntent('android.settings.LOCATION_SOURCE_SETTINGS');
        return;
      }
      await Linking.openSettings();
    } catch (error) {
      console.warn('Failed to open location settings:', error);
    }
  };

  // Get current location
  const getCurrentLocation = async (retry = false) => {
    try {
      const hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        setLocationLoading(false);
        return;
      }

      setLocationLoading(true);

      if (!Geolocation || typeof Geolocation.getCurrentPosition !== 'function') {
        setLocationLoading(false);
        if (!retry) {
          Alert.alert('Error', 'Location service is not available. You can enter the address manually.');
        }
        return;
      }

      // Try with different accuracy levels and timeouts
      const tryGetLocation = (attempt: number) => {
        const configs = [
          { enableHighAccuracy: false, timeout: 10000, maximumAge: 300000 }, // 5 min cache, 10s timeout, low accuracy
          { enableHighAccuracy: false, timeout: 15000, maximumAge: 600000 }, // 10 min cache, 15s timeout, low accuracy
          { enableHighAccuracy: true, timeout: 20000, maximumAge: 0 }, // No cache, 20s timeout, high accuracy
        ];

      const config = configs[Math.min(attempt, configs.length - 1)];
        console.log(`📍 Location attempt ${attempt + 1} with config:`, config);

        Geolocation.getCurrentPosition(
          async (position) => {
            try {
              const { latitude: lat, longitude: lng } = position.coords;
              console.log('📍 Location obtained:', lat, lng);
              setLatitude(lat);
              setLongitude(lng);

              try {
                const formattedAddress = await reverseGeocodeToAddress(lat, lng);
                setLiveLocationAddress(formattedAddress || '');
                if (formattedAddress) {
                  const hasUserTypedAddress =
                    latestAddressRef.current.trim().length > 0;
                  if (!hasUserTypedAddress) {
                    addressInputSourceRef.current = 'auto';
                    setAddress(formattedAddress);
                  }
                  setPlaceId(null);
                } else {
                  setAddress('');
                  setPlaceId(null);
                }
              } catch (error) {
                console.warn('Reverse geocoding failed:', error);
                setAddress('');
                setPlaceId(null);
              } finally {
                setLocationLoading(false);
              }
            } catch (error) {
              console.warn('Error processing location result:', error);
              setLocationLoading(false);
            }
          },
          (error) => {
            if (isExpectedLocationErrorCode(error?.code)) {
              console.warn('Location unavailable:', error.code, error.message);
            } else {
              console.error('Unexpected location error:', error?.code, error?.message);
            }

            // Try next configuration if available
            if (attempt < configs.length - 1) {
              console.log(`📍 Retrying with attempt ${attempt + 2}...`);
              setTimeout(() => tryGetLocation(attempt + 1), 500);
              return;
            }

            // All attempts failed
            setLocationLoading(false);

            // Provide specific error messages
            let errorMessage = 'Failed to get your current location. ';
            if (error.code === 1) {
              errorMessage = 'Location permission was denied. ';
            } else if (error.code === 2) {
              errorMessage = 'Location is unavailable. Please check your device settings and ensure GPS is enabled. ';
            } else if (error.code === 3) {
              errorMessage = 'Location request timed out. Please try again or enter the address manually. ';
            }
            errorMessage += 'You can enter the address manually below.';

            if (!retry) {
              if (error.code === 2) {
                Alert.alert(
                  'Location Services Off',
                  'Location provider unavailable. Please turn on GPS/Location and try again.',
                  [
                    { text: 'Cancel', style: 'cancel' },
                    { text: 'Open Location Settings', onPress: openDeviceLocationSettings },
                    { text: 'Retry', onPress: () => getCurrentLocation(true) },
                  ]
                );
                return;
              }

              Alert.alert(
                'Location Error',
                errorMessage,
                [
                  { text: 'OK' },
                  {
                    text: 'Retry',
                    onPress: () => getCurrentLocation(true),
                  },
                ]
              );
            }
          },
          config
        );
      };

      // Start with first configuration (low accuracy, cached)
      tryGetLocation(0);
    } catch (error) {
      console.warn('getCurrentLocation failed:', error);
      setLocationLoading(false);
      if (!retry) {
        Alert.alert(
          'Error',
          'An error occurred while getting location. You can enter the address manually.',
          [
            { text: 'OK' },
            {
              text: 'Retry',
              onPress: () => getCurrentLocation(true),
            },
          ]
        );
      }
    }
  };

  // Fetch saved addresses
  const fetchSavedAddresses = async () => {
    try {
      setFetchingAddresses(true);
      const addresses = await getAddresses();
      setSavedAddresses(addresses);

      // If the currently selected address was removed, clear selection/vendor
      if (
        selectedAddress &&
        !addresses.some(
          (addr) => String(addr.id) === String(selectedAddress.id)
        )
      ) {
        setSelectedAddress(null);
        setSelectedVendorId(null);
      }
    } catch (error: any) {
      console.error('Error fetching addresses:', error);
    } finally {
      setFetchingAddresses(false);
    }
  };

  // Load address for editing
  const loadAddressForEdit = (addr: SavedAddress) => {
    console.log('Loading address for edit:', addr);
    setEditingAddress(addr);
    setFullName(addr.fullName || '');
    setContactNumber(addr.contactNumber || '');
    setAddress(addr.address || '');
    setLatitude(addr.latitude ? Number(addr.latitude) : null);
    setLongitude(addr.longitude ? Number(addr.longitude) : null);
    setPlaceId(addr.placeId ?? null);
    setModalMode('edit');
    setFormError(null);
    setAddressModalVisible(true);
  };

  // Clear form
  const clearForm = (shouldRefreshLocation = true) => {
    setEditingAddress(null);
    setFullName('');
    setContactNumber('');
    setAddress('');
    setLiveLocationAddress('');
    setAddressSuggestions([]);
    setLatitude(null);
    setLongitude(null);
    setFormError(null);
    setPlaceId(null);
    setMapPickerVisible(false);
    setMapRegion(null);
    setMapAddressPreview('');
    refreshPlacesSessionToken();
    if (shouldRefreshLocation) {
    getCurrentLocation();
    }
  };

  const openAddAddressModal = () => {
    clearForm();
    setModalMode('add');
    setAddressModalVisible(true);
  };

  const closeAddressModal = () => {
    setAddressModalVisible(false);
    setFormError(null);
    setEditingAddress(null);
    setMapPickerVisible(false);
    setMapRegion(null);
    setMapAddressPreview('');
  };

  const promptDeleteAddress = (addr: SavedAddress) => {
    setAddressToDelete(addr);
    setDeleteModalVisible(true);
  };

  const cancelDeletePrompt = () => {
    setDeleteModalVisible(false);
    setAddressToDelete(null);
  };

  const confirmDeleteAddress = async () => {
    if (!addressToDelete?.id) {
      setStatusBanner({ type: 'error', message: 'Unable to find the selected address.' });
      cancelDeletePrompt();
      return;
    }

    try {
        setLoading(true);
      await deleteAddress(Number(addressToDelete.id));

      // Clear selection/vendor if the deleted address was active
      if (String(selectedAddress?.id) === String(addressToDelete.id)) {
        setSelectedAddress(null);
        setSelectedVendorId(null);
      }

      setStatusBanner({ type: 'success', message: 'Address deleted successfully.' });
      if (editingAddress?.id === addressToDelete.id) {
        clearForm(false);
      }
      await fetchSavedAddresses();
            } catch (error: any) {
              console.error('Delete address error:', error);
      const errorMessage =
        error.response?.data?.message || error.message || 'Failed to delete address. Please try again.';
      setStatusBanner({ type: 'error', message: errorMessage });
            } finally {
              setLoading(false);
      cancelDeletePrompt();
            }
  };

  // Delete address

  useEffect(() => {
    getCurrentLocation();
    fetchSavedAddresses();
    // Intentionally load-on-mount for location + address book bootstrap.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleUseAddress = async (addr: SavedAddress) => {
    if (!addr?.latitude || !addr?.longitude) {
      setStatusBanner({
        type: 'error',
        message: 'Selected address is missing coordinates. Please edit and save again.',
      });
      return;
    }

    setSelectingAddressId(addr.id);
    try {
      setSelectedAddress(addr);

      // Update user profile with chosen address + live location
      await updateUserLocation(
        {
          address: addr.address,
          liveLocation: { latitude: addr.latitude, longitude: addr.longitude },
        },
        setUser
      );

      const resolved = await resolveVendorByCoordinates(addr.latitude, addr.longitude, {
        radiusKm: productRadiusKm,
      });
      if (resolved?.vendorIds && resolved.vendorIds.length > 0) {
        // Join multiple vendor IDs with comma for the API
        const vendorIdsString = resolved.vendorIds.join(',');
        setSelectedVendorId(vendorIdsString);

        const vendorCount = resolved.count || resolved.vendorIds.length;
        const nearestStore = resolved.nearestVendor?.branchName || resolved.nearestVendor?.name || 'nearest store';

        if (vendorCount === 1) {
          setStatusBanner({
            type: 'success',
            message: `Shopping from ${nearestStore}.`,
          });
        } else {
          setStatusBanner({
            type: 'success',
            message: `Found ${vendorCount} stores within ${productRadiusKm}km.`,
          });
        }
      } else if (resolved?.vendorId) {
        // Backward compatibility: single vendorId
        setSelectedVendorId(String(resolved.vendorId));
        setStatusBanner({
          type: 'success',
          message: `Shopping from ${resolved.branchName || 'nearest store'} (${resolved.vendorId}).`,
        });
      } else {
        setSelectedVendorId(null);
        setStatusBanner({
          type: 'error',
          message:
            resolved?.message ||
            `No stores found within ${productRadiusKm}km for this address.`,
        });
      }
    } catch (error: any) {
      console.error('Apply address error:', error);
      setStatusBanner({
        type: 'error',
        message: 'Could not apply this address. Please try again.',
      });
    } finally {
      setSelectingAddressId(null);
    }
  };

  useEffect(() => {
    if (!statusBanner) {
      return;
    }
    const timer = setTimeout(() => setStatusBanner(null), 3000);
    return () => clearTimeout(timer);
  }, [statusBanner]);


  const fetchAddressSuggestions = useCallback(
    async (query: string) => {
      try {
        setSuggestionLoading(true);
        const results = await getPlaceSuggestions(query, placesSessionToken);
        setAddressSuggestions(results);
      } catch (err) {
        console.log('❌ Suggestion Error:', err);
        setAddressSuggestions([]);
      } finally {
        setSuggestionLoading(false);
      }
    },
    [placesSessionToken]
  );



  const handleAddressChange = (text: string) => {
    addressInputSourceRef.current = 'user';
    setAddress(text);
    setPlaceId(null);

    if (suggestionTimeoutRef.current) {clearTimeout(suggestionTimeoutRef.current);}

    suggestionTimeoutRef.current = setTimeout(() => {
      if (text.trim().length >= MIN_SUGGESTION_QUERY) {
        fetchAddressSuggestions(text);
      } else {
        setAddressSuggestions([]);
      }
    }, 400);
  };


  const handleSuggestionSelect = async (suggestion: any) => {
    setSuggestionLoading(true);
    try {
      const details = await getPlaceDetails(suggestion.place_id, placesSessionToken);
      if (details) {
        const normalized = normalizeCoordinate({
          latitude: details.latitude,
          longitude: details.longitude,
        });
        setAddress(details.address);
        setLatitude(normalized?.latitude ?? null);
        setLongitude(normalized?.longitude ?? null);
        setPlaceId(details.placeId);
        setAddressSuggestions([]);
        refreshPlacesSessionToken();
        if (normalized) {
          setMapRegion(buildRegionFromCoordinate(normalized, 0.01));
          setMapAddressPreview(details.address || suggestion.description || '');
          setMapPickerVisible(true);
        } else {
          setMapPickerVisible(false);
        }
      }
    } finally {
      setSuggestionLoading(false);
    }
  };


  useEffect(() => {
    const trimmed = address.trim();
    if (
      addressInputSourceRef.current !== 'user' ||
      trimmed.length < MIN_SUGGESTION_QUERY
    ) {
      setAddressSuggestions([]);
      if (suggestionTimeoutRef.current) {
        clearTimeout(suggestionTimeoutRef.current);
      }
      return;
    }

    if (suggestionTimeoutRef.current) {
      clearTimeout(suggestionTimeoutRef.current);
    }

    suggestionTimeoutRef.current = setTimeout(() => {
      fetchAddressSuggestions(trimmed);
    }, 400);

    return () => {
      if (suggestionTimeoutRef.current) {
        clearTimeout(suggestionTimeoutRef.current);
      }
    };
  }, [address, fetchAddressSuggestions]);

  const handleCloseMapPicker = () => {
    setMapPickerVisible(false);
  };

  const handleConfirmMapLocation = async () => {
    const normalized = normalizeCoordinate(mapRegion);
    if (!normalized) {
      return;
    }
    setMapResolving(true);
    try {
      const formatted = await reverseGeocodeToAddress(
        normalized.latitude,
        normalized.longitude
      );
      if (formatted) {
        setAddress(formatted);
        setMapAddressPreview(formatted);
      }
      setLatitude(normalized.latitude);
      setLongitude(normalized.longitude);
      setPlaceId(null);
      setMapPickerVisible(false);
    } catch (error) {
      console.error('Reverse geocode from map picker failed:', error);
      Alert.alert('Error', 'Unable to set location. Please try again.');
    } finally {
      setMapResolving(false);
    }
  };

  const handleSaveAddress = async () => {
    const trimmedName = fullName.trim();
    const sanitizedContact = contactNumber.replace(/\D/g, '').slice(0, 10);
    const trimmedAddress = address.trim();

    if (sanitizedContact !== contactNumber) {
      setContactNumber(sanitizedContact);
    }

    if (!trimmedName) {
      setFormError('Please enter your full name.');
      return;
    }

    if (sanitizedContact.length < 10) {
      setFormError('Enter a valid 10-digit contact number.');
      return;
    }

    if (!trimmedAddress) {
      setFormError('Please enter your address.');
      return;
    }

    const finalLatitude =
      latitude !== null && latitude !== undefined
        ? latitude
        : editingAddress?.latitude ?? 0;
    const finalLongitude =
      longitude !== null && longitude !== undefined
        ? longitude
        : editingAddress?.longitude ?? 0;
    const finalPlaceId = placeId ?? editingAddress?.placeId ?? null;

    const payload = {
      fullName: trimmedName,
      contactNumber: sanitizedContact,
      address: trimmedAddress,
      latitude: finalLatitude,
      longitude: finalLongitude,
      placeId: finalPlaceId,
    };

    setLoading(true);
    setFormError(null);

    try {
      if (modalMode === 'edit' && editingAddress?.id) {
        await updateAddress(Number(editingAddress.id), payload);
        setStatusBanner({ type: 'success', message: 'Address updated successfully.' });
      } else {
        await saveAddress(payload);
        setStatusBanner({ type: 'success', message: 'Address saved successfully.' });
      }

      setAddressModalVisible(false);
      setEditingAddress(null);
      clearForm(false);
      fetchSavedAddresses();
    } catch (error: any) {
      console.error('Save address error:', error);
      const errorMessage =
        error.response?.data?.message || error.message || 'Failed to save address. Please try again.';
      setFormError(errorMessage);
      setStatusBanner({ type: 'error', message: errorMessage });
    } finally {
      setLoading(false);
    }
  };

  const renderAddressModal = () => (
    <Modal
      visible={addressModalVisible}
      transparent
      animationType="fade"
      onRequestClose={closeAddressModal}
    >
      <TouchableWithoutFeedback onPress={closeAddressModal}>
        <View style={styles.modalOverlayBrand}>
          <TouchableWithoutFeedback onPress={() => {}}>
            <KeyboardAvoidingView
              behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
              keyboardVerticalOffset={Platform.OS === 'ios' ? 40 : 0}
              style={styles.modalCardBrand}
            >
              <ScrollView
                contentContainerStyle={styles.modalScrollContent}
                keyboardShouldPersistTaps="handled"
                showsVerticalScrollIndicator={false}
              >
                <View style={styles.modalHeaderRow}>
                  <CustomText variant="h5" fontFamily={Fonts.Bold} style={styles.modalTitle}>
                    {modalMode === 'add' ? 'Add New Address' : 'Edit Address'}
                  </CustomText>
                  <TouchableOpacity
                    onPress={closeAddressModal}
                    style={styles.modalCloseButton}
                    accessibilityLabel="Close address modal"
                  >
                    <Icon name="close" size={RFValue(20)} color={colors.primaryBlue} />
                  </TouchableOpacity>
                </View>

              <View style={styles.liveLocationCard}>
                <View style={styles.liveLocationHeader}>
                  <Icon name="navigate" size={RFValue(18)} color={colors.primaryBlue} />
                  <View style={styles.liveLocationTextWrapper}>
                    <CustomText variant="h8" fontFamily={Fonts.Bold} style={styles.liveLocationLabel}>
                      Live location
                    </CustomText>
                    <CustomText
                      variant="h9"
                      fontFamily={Fonts.Medium}
                      style={styles.liveLocationValue}
                      numberOfLines={2}
                    >
                      {liveLocationAddress ||
                        (locationLoading
                          ? 'Fetching your current location...'
                          : 'No location detected yet.')}
                    </CustomText>
                  </View>
                  <TouchableOpacity
                    style={styles.refreshButton}
                    onPress={() => getCurrentLocation(true)}
                    disabled={locationLoading}
                  >
                    <Icon
                      name="refresh"
                      size={RFValue(18)}
                      color={locationLoading ? colors.greyText : colors.primaryBlue}
                    />
                  </TouchableOpacity>
                </View>
              </View>

                {formError && (
                  <View style={styles.formErrorBox}>
                    <CustomText variant="h9" fontFamily={Fonts.Medium} style={styles.formErrorText}>
                      {formError}
                    </CustomText>
                  </View>
                )}

                <View style={styles.modalSection}>
                <CustomText variant="h8" fontFamily={Fonts.Medium} style={styles.modalLabel}>
          Full Name
        </CustomText>
        <CustomInput
          value={fullName}
          onChangeText={setFullName}
          onClear={() => setFullName('')}
          placeholder="Enter your full name"
          left={
            <Icon
              name="person-outline"
                      color={colors.primaryBlue}
              style={{ marginLeft: 10 }}
              size={RFValue(18)}
            />
          }
        />
                </View>

                <View style={styles.modalSection}>
                <CustomText variant="h8" fontFamily={Fonts.Medium} style={styles.modalLabel}>
          Contact Number
        </CustomText>
        <CustomInput
          value={contactNumber}
                  onChangeText={(text) => setContactNumber(text.replace(/\D/g, '').slice(0, 10))}
          onClear={() => setContactNumber('')}
          placeholder="Enter contact number"
          inputMode="numeric"
          left={
            <Icon
              name="call-outline"
                      color={colors.primaryBlue}
              style={{ marginLeft: 10 }}
              size={RFValue(18)}
            />
          }
        />
                </View>

                <View style={[styles.modalSection, styles.locationHeader]}>
                <CustomText variant="h8" fontFamily={Fonts.Medium} style={styles.modalLabel}>
            Location (Auto-detected)
          </CustomText>
          {locationLoading && (
                  <ActivityIndicator size="small" color={colors.primaryBlue} style={styles.loader} />
          )}
          {!locationLoading && (latitude === null || longitude === null) && (
                  <TouchableOpacity onPress={() => getCurrentLocation(true)} style={styles.retryButton}>
                    <Icon name="refresh-outline" size={RFValue(16)} color={colors.primaryBlue} />
                    <CustomText variant="h9" fontFamily={Fonts.Medium} style={styles.retryText}>
                Retry
              </CustomText>
            </TouchableOpacity>
          )}
                </View>
                {latitude !== null && longitude !== null && (
                  <CustomText variant="h9" fontFamily={Fonts.Regular} style={styles.coordinates}>
                    Lat: {latitude.toFixed(6)}, Lng: {longitude.toFixed(6)}
                  </CustomText>
                )}
                {!locationLoading && latitude === null && longitude === null && (
                  <CustomText variant="h9" fontFamily={Fonts.Regular} style={styles.helpText}>
                    Location not available. You can enter the address manually below.
                  </CustomText>
                )}

                <View style={styles.modalSection}>
                <CustomText variant="h8" fontFamily={Fonts.Medium} style={styles.modalLabel}>
          Address
        </CustomText>
        <CustomInput
          value={address}
          onChangeText={handleAddressChange}
          onFocus={() => {
            addressInputSourceRef.current = 'user';
          }}
          onClear={() => {
            setAddress('');
            setAddressSuggestions([]);
            setLatitude(null);
            setLongitude(null);
            setPlaceId(null);
          }}
          placeholder="Enter your address (auto-filled from location)"
          multiline
          numberOfLines={4}
          textAlignVertical="top"
          left={
            <Icon
              name="location-outline"
              color={colors.primaryBlue}
              style={{ marginLeft: 10, marginTop: 10 }}
              size={RFValue(18)}
            />
          }
        />

        {(suggestionLoading || addressSuggestions.length > 0) && (
          <View style={styles.suggestionCard}>
            {suggestionLoading ? (
              <ActivityIndicator size="small" color={colors.primaryBlue} />
            ) : (
              <ScrollView
                keyboardShouldPersistTaps="handled"
                contentContainerStyle={styles.suggestionScrollContent}
                style={styles.suggestionScroll}
              >
                {addressSuggestions.map((suggestion) => (
                  <TouchableOpacity
                    key={suggestion.place_id}
                    style={styles.suggestionRow}
                    onPress={() => handleSuggestionSelect(suggestion)}
                    activeOpacity={0.85}
                  >
                    <Icon name="location-sharp" size={RFValue(18)} color={colors.primaryBlue} />
                    <View style={styles.suggestionTextWrapper}>
                      <CustomText
                        variant="h8"
                        fontFamily={Fonts.Medium}
                        style={styles.suggestionPrimary}
                        numberOfLines={1}
                      >
                        {suggestion.structured_formatting?.main_text || suggestion.description}
                      </CustomText>
                      {suggestion.structured_formatting?.secondary_text && (
                        <CustomText
                          variant="h9"
                          fontFamily={Fonts.Regular}
                          style={styles.suggestionSecondary}
                          numberOfLines={1}
                        >
                          {suggestion.structured_formatting.secondary_text}
                        </CustomText>
                      )}
                    </View>
                  </TouchableOpacity>
                ))}
              </ScrollView>
            )}
          </View>
        )}

                </View>

                <View style={styles.modalActionsRow}>
                  <TouchableOpacity
                    style={styles.secondaryActionButton}
                    onPress={closeAddressModal}
                    disabled={loading}
                  >
                    <CustomText variant="h8" fontFamily={Fonts.Bold} style={styles.secondaryActionText}>
                      Cancel
                    </CustomText>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[styles.primaryActionButton, loading && styles.disabledButton]}
                    onPress={handleSaveAddress}
                    disabled={loading}
                 >
                    {loading ? (
                      <ActivityIndicator size="small" color={colors.white} />
                    ) : (
                      <CustomText variant="h8" fontFamily={Fonts.Bold} style={styles.primaryActionText}>
                        {modalMode === 'add' ? 'Save Address' : 'Update Address'}
                      </CustomText>
                    )}
                  </TouchableOpacity>
                </View>
              </ScrollView>
            </KeyboardAvoidingView>
          </TouchableWithoutFeedback>
        </View>
      </TouchableWithoutFeedback>
    </Modal>
  );

  const renderMapPickerModal = () => (
    <Modal
      visible={mapPickerVisible && !!mapRegion}
      transparent
      animationType="fade"
      onRequestClose={handleCloseMapPicker}
    >
      <TouchableWithoutFeedback onPress={handleCloseMapPicker}>
        <View style={styles.mapPickerOverlay}>
          <TouchableWithoutFeedback onPress={() => {}}>
            <View style={styles.mapPickerModal}>
              <View style={styles.mapPickerHeader}>
                <Icon name="map" size={RFValue(18)} color={colors.primaryBlue} />
                <View style={styles.mapPickerTextWrapper}>
                  <CustomText variant="h7" fontFamily={Fonts.Bold} style={styles.mapPickerTitle}>
                    Confirm exact location
                  </CustomText>
                  <CustomText
                    variant="h9"
                    fontFamily={Fonts.Regular}
                    style={styles.mapPickerSubtitle}
                    numberOfLines={2}
                  >
                    {mapAddressPreview || 'Drag the map to fine tune your address'}
                  </CustomText>
                </View>
                <TouchableOpacity onPress={handleCloseMapPicker} style={styles.mapPickerClose}>
                  <Icon name="close" size={RFValue(18)} color={colors.primaryBlue} />
                </TouchableOpacity>
              </View>
              {mapRegion && (
                <View style={styles.mapWrapper}>
                  <MapView
                    key={`${mapRegion.latitude}-${mapRegion.longitude}`}
                    style={styles.map}
                    initialRegion={mapRegion}
                    onRegionChangeComplete={(region) =>
                      setMapRegion({
                        ...region,
                        latitudeDelta: clampMapDelta(region.latitudeDelta, 0.01),
                        longitudeDelta: clampMapDelta(region.longitudeDelta, 0.01),
                      })
                    }
                    provider="google"
                    customMapStyle={customMapStyle}
                    showsUserLocation
                    showsCompass={false}
                    toolbarEnabled={false}
                  />
                  <View pointerEvents="none" style={styles.mapPin}>
                    <View style={styles.mapPinHead}>
                      <View style={styles.mapPinHeadInner} />
                    </View>
                    <View style={styles.mapPinStick} />
                  </View>
                </View>
              )}
              <TouchableOpacity
                style={[
                  styles.mapPickerConfirmButton,
                  mapResolving && styles.disabledButton,
                ]}
                onPress={handleConfirmMapLocation}
                disabled={mapResolving}
                activeOpacity={0.85}
              >
                {mapResolving ? (
                  <ActivityIndicator size="small" color={colors.primaryBlue} />
                ) : (
                  <CustomText variant="h8" fontFamily={Fonts.Bold} style={styles.mapPickerConfirmText}>
                    Set Location
                  </CustomText>
                )}
              </TouchableOpacity>
            </View>
          </TouchableWithoutFeedback>
        </View>
      </TouchableWithoutFeedback>
    </Modal>
  );

  const renderDeleteModal = () => (
    <Modal
      visible={deleteModalVisible}
      transparent
      animationType="fade"
      onRequestClose={cancelDeletePrompt}
    >
      <TouchableWithoutFeedback onPress={cancelDeletePrompt}>
        <View style={styles.modalOverlayBrand}>
          <TouchableWithoutFeedback onPress={() => {}}>
            <View style={styles.confirmCard}>
              <View style={styles.confirmIconWrapper}>
                <Icon name="trash-outline" size={RFValue(32)} color={colors.primaryBlue} />
              </View>
              <CustomText variant="h5" fontFamily={Fonts.Bold} style={styles.confirmTitle}>
                Delete address?
              </CustomText>
              <CustomText variant="h8" fontFamily={Fonts.Medium} style={styles.confirmMessage}>
                {`Are you sure you want to remove ${
                  addressToDelete?.fullName || 'this address'
                } from your saved list?`}
              </CustomText>
              <View style={styles.confirmActions}>
                <TouchableOpacity
                  style={styles.secondaryActionButton}
                  onPress={cancelDeletePrompt}
                  disabled={loading}
                >
                  <CustomText variant="h8" fontFamily={Fonts.Bold} style={styles.secondaryActionText}>
                    Cancel
                  </CustomText>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.primaryActionButton, loading && styles.disabledButton]}
                  onPress={confirmDeleteAddress}
                  disabled={loading}
                >
                  {loading ? (
                    <ActivityIndicator size="small" color={colors.white} />
                  ) : (
                    <CustomText variant="h8" fontFamily={Fonts.Bold} style={styles.primaryActionText}>
                      Delete
                    </CustomText>
                  )}
                </TouchableOpacity>
              </View>
            </View>
          </TouchableWithoutFeedback>
        </View>
      </TouchableWithoutFeedback>
    </Modal>
  );

  return (
    <SafeAreaView style={{ flex: 1 }} edges={['top']}>
      <View style={styles.container}>
        <CustomHeader title="Address Book" />
      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={[styles.scrollContent, { paddingBottom: insets.bottom + 40 }]}
        keyboardShouldPersistTaps="handled"
      >
        <View style={styles.headerActions}>
          <TouchableOpacity
            onPress={openAddAddressModal}
            style={styles.addButton}
            activeOpacity={0.85}
          >
            <Icon name="add-circle-outline" size={RFValue(18)} color={colors.white} />
            <CustomText variant="h8" fontFamily={Fonts.Bold} style={styles.addButtonText}>
              Add Address
            </CustomText>
          </TouchableOpacity>
        </View>

        {statusBanner && (
          <View
            style={[
              styles.banner,
              statusBanner.type === 'success' ? styles.bannerSuccess : styles.bannerError,
            ]}
          >
            <CustomText variant="h8" fontFamily={Fonts.Medium} style={styles.bannerText}>
              {statusBanner.message}
            </CustomText>
          </View>
        )}

        {fetchingAddresses ? (
          <ActivityIndicator size="large" color={colors.primaryBlue} style={styles.fullLoader} />
        ) : savedAddresses.length > 0 ? (
          <View style={styles.savedAddressesSection}>
            {savedAddresses.map((addr) => (
              <View key={addr.id} style={styles.addressCard}>
                <View style={styles.addressCardContent}>
                  <View style={styles.addressCardHeader}>
                    <Icon name="location" size={RFValue(20)} color={colors.primaryBlue} />
                    <CustomText variant="h6" fontFamily={Fonts.SemiBold} style={styles.addressName}>
                      {addr.fullName}
                    </CustomText>
                    {editingAddress?.id === addr.id && (
                      <View style={styles.editingBadge}>
                        <CustomText variant="h9" fontFamily={Fonts.Medium} style={styles.editingText}>
                          Active
                        </CustomText>
                      </View>
                    )}
                  </View>
                  <CustomText variant="h7" fontFamily={Fonts.Regular} style={styles.addressText}>
                    {addr.address}
                  </CustomText>
                  <CustomText variant="h8" fontFamily={Fonts.Regular} style={styles.addressContact}>
                    {addr.contactNumber}
                  </CustomText>
                  {addr.latitude !== 0 && addr.longitude !== 0 && (
                    <CustomText variant="h9" fontFamily={Fonts.Regular} style={styles.addressCoords}>
                      Lat: {Number(addr.latitude).toFixed(4)}, Lng: {Number(addr.longitude).toFixed(4)}
                    </CustomText>
                  )}
                </View>
                <View style={styles.addressCardActions}>
                  <TouchableOpacity
                    onPress={() => handleUseAddress(addr)}
                    style={[
                      styles.listPrimaryActionButton,
                      selectedAddress?.id === addr.id && styles.primaryActionActive,
                    ]}
                    activeOpacity={0.85}
                    disabled={selectingAddressId === addr.id}
                  >
                    {selectingAddressId === addr.id ? (
                      <ActivityIndicator size="small" color={colors.white} />
                    ) : (
                      <Icon name="checkmark-circle-outline" size={RFValue(18)} color={colors.white} />
                    )}
                    <CustomText
                      variant="h8"
                      fontFamily={Fonts.Medium}
                      style={styles.actionText}
                      numberOfLines={1}
                    >
                      Use this address
                    </CustomText>
                  </TouchableOpacity>
                  <TouchableOpacity
                    onPress={() => loadAddressForEdit(addr)}
                    style={styles.editButton}
                    activeOpacity={0.85}
                  >
                    <Icon name="create-outline" size={RFValue(18)} color={colors.white} />
                    <CustomText
                      variant="h8"
                      fontFamily={Fonts.Medium}
                      style={styles.actionText}
                      numberOfLines={1}
                    >
                      Edit
                    </CustomText>
                  </TouchableOpacity>
                  <TouchableOpacity
                    onPress={() => promptDeleteAddress(addr)}
                    style={styles.deleteButton}
                    activeOpacity={0.85}
                  >
                    <Icon name="trash-outline" size={RFValue(18)} color={colors.primaryBlue} />
                    <CustomText
                      variant="h8"
                      fontFamily={Fonts.Medium}
                      style={styles.deleteButtonText}
                      numberOfLines={1}
                    >
                      Delete
                    </CustomText>
                  </TouchableOpacity>
                </View>
              </View>
            ))}
          </View>
        ) : (
          <View style={styles.emptyState}>
            <Icon name="home-outline" size={RFValue(56)} color={colors.primaryBlue} />
            <CustomText variant="h5" fontFamily={Fonts.SemiBold} style={styles.emptyTitle}>
              No saved addresses yet
            </CustomText>
            <CustomText variant="h8" fontFamily={Fonts.Medium} style={styles.emptySubtitle}>
              Tap the button below to add your first delivery address.
            </CustomText>
            <TouchableOpacity
              style={styles.addInlineButton}
              onPress={openAddAddressModal}
              activeOpacity={0.9}
            >
              <CustomText variant="h7" fontFamily={Fonts.Bold} style={styles.addInlineButtonText}>
                Add Address
              </CustomText>
            </TouchableOpacity>
          </View>
        )}
      </ScrollView>
      {renderAddressModal()}
      {renderMapPickerModal()}
      {renderDeleteModal()}
    </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.white,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: 20,
  },
  headerActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginBottom: 12,
  },
  addButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: colors.primaryBlue,
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 20,
  },
  addButtonText: {
    color: colors.white,
  },
  banner: {
    padding: 12,
    borderRadius: 10,
    marginBottom: 16,
  },
  bannerSuccess: {
    backgroundColor: colors.primaryBlueOpacity10,
  },
  bannerError: {
    backgroundColor: colors.lightRed,
  },
  bannerText: {
    color: colors.primaryBlue,
  },
  loader: {
    marginLeft: 10,
  },
  fullLoader: {
    marginTop: 40,
  },
  savedAddressesSection: {
    marginTop: 10,
  },
  addressCard: {
    backgroundColor: colors.white,
    borderRadius: 16,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
    shadowColor: colors.primaryBlue,
    shadowOpacity: 0.08,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 4 },
    elevation: 2,
  },
  addressCardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
    gap: 10,
  },
  addressName: {
    flex: 1,
    color: colors.primaryBlue,
  },
  editingBadge: {
    backgroundColor: colors.primaryBlueOpacity10,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 20,
  },
  editingText: {
    color: colors.primaryBlue,
    fontSize: RFValue(9),
  },
  addressText: {
    marginBottom: 5,
    opacity: 0.85,
  },
  addressContact: {
    marginBottom: 5,
    opacity: 0.7,
  },
  addressCoords: {
    opacity: 0.6,
    marginTop: 5,
  },
  addressCardContent: {
    flex: 1,
  },
  addressCardActions: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 14,
    width: '100%',
  },
  listPrimaryActionButton: {
    flexGrow: 1.6,
    flexBasis: 0,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 8,
    paddingVertical: 10,
    borderRadius: 10,
    backgroundColor: colors.primaryBlue,
    minHeight: 44,
    marginRight: 8,
    minWidth: 0,
  },
  primaryActionActive: {
    backgroundColor: colors.darkBlue,
  },
  editButton: {
    flexGrow: 1,
    flexBasis: 0,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 8,
    paddingVertical: 10,
    borderRadius: 10,
    backgroundColor: colors.primaryBlue,
    minHeight: 44,
    marginRight: 8,
    minWidth: 0,
  },
  deleteButton: {
    flexGrow: 1,
    flexBasis: 0,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 8,
    paddingVertical: 10,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: colors.primaryBlue,
    backgroundColor: colors.white,
    minHeight: 44,
    minWidth: 0,
  },
  actionText: {
    color: colors.white,
    flexShrink: 1,
    marginLeft: 6,
    textAlign: 'center',
  },
  deleteButtonText: {
    color: colors.primaryBlue,
    flexShrink: 1,
    marginLeft: 6,
    textAlign: 'center',
  },
  emptyState: {
    marginTop: 40,
    alignItems: 'center',
    gap: 12,
    padding: 24,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
  },
  emptyTitle: {
    color: colors.primaryBlue,
  },
  emptySubtitle: {
    textAlign: 'center',
    opacity: 0.7,
  },
  addInlineButton: {
    marginTop: 10,
    backgroundColor: colors.primaryBlue,
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 25,
  },
  addInlineButtonText: {
    color: colors.white,
  },
  locationHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  coordinates: {
    marginTop: 5,
    marginBottom: 10,
    opacity: 0.6,
  },
  retryButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    paddingHorizontal: 10,
    paddingVertical: 5,
  },
  retryText: {
    color: colors.primaryBlue,
  },
  helpText: {
    marginTop: 5,
    marginBottom: 10,
    opacity: 0.7,
    fontStyle: 'italic',
  },
  liveLocationCard: {
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
    borderRadius: 14,
    padding: 12,
    marginBottom: 12,
    backgroundColor: colors.white,
  },
  liveLocationHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  liveLocationTextWrapper: {
    flex: 1,
  },
  liveLocationLabel: {
    color: colors.primaryBlue,
    marginBottom: 4,
  },
  liveLocationValue: {
    color: colors.primaryBlue,
    opacity: 0.8,
  },
  refreshButton: {
    padding: 6,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
  },
  suggestionCard: {
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
    borderRadius: 10,
    paddingVertical: 4,
    marginTop: -4,
    marginBottom: 8,
    backgroundColor: colors.white,
    maxHeight: 180,
    overflow: 'hidden',
  },
  suggestionScroll: {
    maxHeight: 172,
  },
  suggestionScrollContent: {
    paddingBottom: 4,
  },
  suggestionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  suggestionTextWrapper: {
    flex: 1,
  },
  suggestionPrimary: {
    color: colors.primaryBlue,
  },
  suggestionSecondary: {
    color: colors.greyText,
  },
  mapPickerOverlay: {
    flex: 1,
    backgroundColor: colors.blackOpacity40,
    justifyContent: 'center',
    padding: 20,
  },
  mapPickerModal: {
    borderRadius: 20,
    padding: 16,
    backgroundColor: colors.white,
    gap: 16,
  },
  mapPickerHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  mapPickerTextWrapper: {
    flex: 1,
  },
  mapPickerTitle: {
    color: colors.primaryBlue,
  },
  mapPickerSubtitle: {
    color: colors.greyText,
    marginTop: 2,
  },
  mapPickerClose: {
    padding: 4,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
  },
  mapWrapper: {
    height: 260,
    borderRadius: 12,
    overflow: 'hidden',
    backgroundColor: colors.white,
  },
  map: {
    flex: 1,
    backgroundColor: colors.white,
  },
  mapPin: {
    position: 'absolute',
    top: '50%',
    left: '50%',
    alignItems: 'center',
    justifyContent: 'center',
    transform: [{ translateX: -15 }, { translateY: -40 }],
  },
  mapPinHead: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: colors.success,
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
  mapPinHeadInner: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: colors.white,
  },
  mapPinStick: {
    width: 6,
    height: 22,
    backgroundColor: colors.success,
    borderBottomLeftRadius: 3,
    borderBottomRightRadius: 3,
    marginTop: -6,
  },
  mapPickerConfirmButton: {
    marginTop: 4,
    borderRadius: 12,
    paddingVertical: 12,
    alignItems: 'center',
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.primaryBlue,
  },
  mapPickerConfirmText: {
    color: colors.primaryBlue,
  },
  modalOverlayBrand: {
    flex: 1,
    backgroundColor: colors.blackOpacity40,
    justifyContent: 'center',
    padding: 20,
  },
  modalCardBrand: {
    backgroundColor: colors.white,
    borderRadius: 20,
    padding: 20,
    maxHeight: '90%',
  },
  modalScrollContent: {
    paddingBottom: 10,
  },
  modalHeaderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  modalTitle: {
    color: colors.primaryBlue,
    fontWeight: '700',
  },
  modalCloseButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.primaryBlueOpacity10,
  },
  formErrorBox: {
    backgroundColor: colors.lightRed,
    borderRadius: 8,
    padding: 10,
    marginBottom: 12,
  },
  formErrorText: {
    color: colors.danger,
  },
  modalSection: {
    marginBottom: 12,
  },
  modalLabel: {
    marginBottom: 6,
    color: colors.primaryBlue,
  },
  modalActionsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 12,
    marginTop: 10,
  },
  secondaryActionButton: {
    flex: 1,
    borderWidth: 1,
    borderColor: colors.primaryBlue,
    borderRadius: 12,
    paddingVertical: 12,
    alignItems: 'center',
    backgroundColor: colors.white,
  },
  secondaryActionText: {
    color: colors.primaryBlue,
  },
  primaryActionButton: {
    flex: 1,
    borderRadius: 12,
    paddingVertical: 12,
    alignItems: 'center',
    backgroundColor: colors.primaryBlue,
  },
  primaryActionText: {
    color: colors.white,
  },
  disabledButton: {
    opacity: 0.6,
  },
  confirmCard: {
    backgroundColor: colors.white,
    borderRadius: 20,
    padding: 24,
    alignItems: 'center',
  },
  confirmIconWrapper: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: colors.primaryBlueOpacity10,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
  },
  confirmTitle: {
    color: colors.primaryBlue,
    marginBottom: 8,
    fontWeight: '700',
  },
  confirmMessage: {
    textAlign: 'center',
    opacity: 0.8,
    marginBottom: 20,
  },
  confirmActions: {
    width: '100%',
    flexDirection: 'row',
    gap: 12,
  },
});

export default AddressBook;
