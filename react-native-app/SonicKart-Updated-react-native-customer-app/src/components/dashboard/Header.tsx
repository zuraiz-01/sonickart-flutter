import {
  PermissionsAndroid,
  Platform,
  StyleSheet,
  TouchableOpacity,
  View,
} from 'react-native';
import React, { FC, useEffect, useMemo, useState } from 'react';
import CustomText from '@components/ui/CustomText';
import { Fonts } from '@utils/Constants';
import { RFValue } from 'react-native-responsive-fontsize';
import { useAuthStore } from '@state/authStore';
import { useLocationStore } from '@state/locationStore';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import { navigate } from '@utils/NavigationUtils';
import Geolocation from '@react-native-community/geolocation';
import { reverseGeocodeToAddress } from '@service/mapService';
import colors from '../../theme/colors';

const Header: FC = () => {
  const { user } = useAuthStore();
  const selectedAddress = useLocationStore((state) => state.selectedAddress);
  const [liveLocationAddress, setLiveLocationAddress] = useState('');

  useEffect(() => {
    let cancelled = false;

    const requestLocationPermission = async () => {
      if (Platform.OS !== 'android') {
        return true;
      }

      try {
        const fine = PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION;
        const coarse = PermissionsAndroid.PERMISSIONS.ACCESS_COARSE_LOCATION;
        const alreadyGranted =
          (await PermissionsAndroid.check(fine)) ||
          (await PermissionsAndroid.check(coarse));

        if (alreadyGranted) {
          return true;
        }

        const result = await PermissionsAndroid.requestMultiple([fine, coarse]);
        return (
          result[fine] === PermissionsAndroid.RESULTS.GRANTED ||
          result[coarse] === PermissionsAndroid.RESULTS.GRANTED
        );
      } catch {
        return false;
      }
    };

    const fetchLiveLocationAddress = async () => {
      if (selectedAddress?.address?.trim()) {
        return;
      }

      const granted = await requestLocationPermission();
      if (!granted || cancelled) {
        return;
      }

      Geolocation.getCurrentPosition(
        async (position) => {
          const latitude = Number(position?.coords?.latitude);
          const longitude = Number(position?.coords?.longitude);

          if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
            return;
          }

          const coordinateLabel = `${latitude.toFixed(4)}, ${longitude.toFixed(4)}`;

          try {
            const resolvedAddress = await reverseGeocodeToAddress(latitude, longitude);
            if (cancelled) {
              return;
            }

            if (resolvedAddress?.trim()) {
              setLiveLocationAddress(resolvedAddress.trim());
              return;
            }

            setLiveLocationAddress((prev) => prev || coordinateLabel);
          } catch {
            if (!cancelled) {
              setLiveLocationAddress((prev) => prev || coordinateLabel);
            }
          }
        },
        () => {
          // Keep existing fallback when device location is unavailable.
        },
        {
          enableHighAccuracy: false,
          timeout: 12000,
          maximumAge: 300000,
        }
      );
    };

    fetchLiveLocationAddress();

    return () => {
      cancelled = true;
    };
  }, [selectedAddress?.address]);

  const homeAddressLabel = useMemo(() => {
    const selected = selectedAddress?.address?.trim();
    if (selected) {
      return selected;
    }

    const live = liveLocationAddress.trim();
    if (live) {
      return live;
    }

    return 'Select delivery address';
  }, [liveLocationAddress, selectedAddress?.address]);

  const primaryLabel = selectedAddress?.fullName?.trim()
    ? `Hi, ${selectedAddress.fullName.trim()}`
    : user?.name
      ? `Hi, ${user.name}`
      : user?.phone
        ? `Hi, ${user.phone}`
        : 'Hi, Guest';

  return (
    <View style={styles.shell}>
      <View style={styles.card}>
        <TouchableOpacity
          activeOpacity={0.8}
          accessibilityRole="button"
          accessibilityLabel="Delivery information and address"
          accessibilityHint="Double tap to view delivery details"
          onPress={() => navigate('AddressBook')}
          style={styles.locationAction}
        >
          <View style={styles.topRow}>
            <CustomText
              variant="body"
              numberOfLines={1}
              fontFamily={Fonts.Bold}
              fontSize={14}
              style={styles.userNameText}
            >
              {primaryLabel}
            </CustomText>
          </View>

          <CustomText
            fontFamily={Fonts.Bold}
            variant="body"
            fontSize={12}
            numberOfLines={1}
            style={styles.deliveryTimeText}
          >
            Everything you need, delivered fast ⚡
          </CustomText>

          <View style={styles.addressRow}>
            <View style={styles.locationIconWrap}>
              <Icon name="map-marker" color={colors.primaryBlue} size={RFValue(14)} />
            </View>
            <CustomText
              variant="body"
              numberOfLines={1}
              fontFamily={Fonts.Bold}
              fontSize={12}
              style={styles.addressText}
            >
              {homeAddressLabel}
            </CustomText>
            <Icon name="chevron-down" color={colors.primaryBlue} size={RFValue(16)} />
          </View>
        </TouchableOpacity>

      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  shell: {
    paddingHorizontal: 12,
    paddingTop: Platform.OS === 'android' ? 8 : 4,
    paddingBottom: 2,
  },
  card: {
    backgroundColor: '#F3F7FF',
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 12,
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.08,
    shadowRadius: 12,
    elevation: 4,
    borderWidth: 1,
    borderColor: '#F3F7FF',
  },
  locationAction: {
    alignItems: 'flex-start',
    width: '100%',
  },
  topRow: {
    width: '100%',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-start',
    gap: 10,
  },
  userNameText: {
    color: colors.primaryBlue,
    letterSpacing: 0.2,
    fontWeight: '800',
    flexShrink: 1,
    textAlign: 'left',
    marginRight: 8,
  },
  deliveryTimeText: {
    color: colors.primaryBlue,
    marginTop: 4,
    lineHeight: 17,
    maxWidth: '100%',
  },
  addressRow: {
    justifyContent: 'flex-start',
    alignItems: 'center',
    flexDirection: 'row',
    gap: 6,
    width: '100%',
    marginTop: 10,
    backgroundColor: colors.backgroundSecondary,
    borderRadius: 12,
    paddingHorizontal: 10,
    paddingVertical: 9,
  },
  locationIconWrap: {
    width: 24,
    height: 24,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.white,
  },
  addressText: {
    color: colors.primaryBlue,
    flex: 1,
  },
});

export default Header;
