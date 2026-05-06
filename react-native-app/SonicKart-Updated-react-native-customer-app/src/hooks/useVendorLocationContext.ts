import { useEffect, useMemo, useState } from 'react';
import { PermissionsAndroid, Platform } from 'react-native';
import Geolocation from '@react-native-community/geolocation';
import { resolveVendorByCoordinates, type ResolvedVendor } from '@service/addressService';
import { useAuthStore } from '@state/authStore';
import { useDeliverySettingsStore } from '@state/deliverySettingsStore';
import { useLocationStore } from '@state/locationStore';
import { normalizeCoordinate } from '@utils/locationUtils';

const normalizeVendorToken = (value: unknown) => String(value ?? '').trim();

const uniqueVendorTokens = (values: string[]) =>
  [...new Set(values.map((value) => normalizeVendorToken(value)).filter(Boolean))];

const parseVendorIds = (value: string | null | undefined) =>
  uniqueVendorTokens(String(value ?? '').split(','));

type Coordinate = { latitude: number; longitude: number };

const resolveVendorIdString = (resolved: ResolvedVendor | null): string | null => {
  if (!resolved) {
    return null;
  }

  const vendorIds = uniqueVendorTokens(
    Array.isArray(resolved.vendorIds)
      ? resolved.vendorIds
      : []
  );

  if (vendorIds.length > 0) {
    return vendorIds.join(',');
  }

  const fallbackVendorId = normalizeVendorToken(resolved.vendorId);
  return fallbackVendorId || null;
};

const resolveUserCoordinate = (
  user: Record<string, any> | null
) => {
  const coordinateCandidates = [
    user?.liveLocation,
    user?.location,
    {
      latitude: user?.latitude ?? user?.lat,
      longitude: user?.longitude ?? user?.lng ?? user?.lon,
    },
  ];

  for (const candidate of coordinateCandidates) {
    const normalized = normalizeCoordinate(candidate);
    if (normalized) {
      return normalized;
    }
  }

  return null;
};

const requestDeviceLocationPermission = async () => {
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

const readDeviceCoordinate = async (): Promise<Coordinate | null> =>
  new Promise((resolve) => {
    Geolocation.getCurrentPosition(
      (position) => {
        const normalized = normalizeCoordinate({
          latitude: position?.coords?.latitude,
          longitude: position?.coords?.longitude,
        });
        resolve(normalized);
      },
      () => resolve(null),
      {
        enableHighAccuracy: false,
        timeout: 12000,
        maximumAge: 300000,
      }
    );
  });

/**
 * Keeps vendor context synced with selected address, then falls back to user live location.
 */
export const useVendorLocationContext = () => {
  const user = useAuthStore((state) => state.user);
  const selectedAddress = useLocationStore((state) => state.selectedAddress);
  const selectedVendorId = useLocationStore((state) => state.selectedVendorId);
  const setSelectedVendorId = useLocationStore((state) => state.setSelectedVendorId);
  const productRadiusKm = useDeliverySettingsStore(
    (state) => state.settings.productRadiusKm
  );
  const [vendorResolving, setVendorResolving] = useState(false);
  const [deviceCoordinate, setDeviceCoordinate] = useState<Coordinate | null>(null);
  const [deviceCoordinateLoading, setDeviceCoordinateLoading] = useState(false);

  const selectedAddressCoordinate = useMemo(
    () =>
      normalizeCoordinate({
        latitude: selectedAddress?.latitude,
        longitude: selectedAddress?.longitude,
      }),
    [selectedAddress?.latitude, selectedAddress?.longitude]
  );

  const userCoordinate = useMemo(
    () => resolveUserCoordinate(user),
    [user]
  );

  useEffect(() => {
    if (selectedAddressCoordinate) {
      setDeviceCoordinate(null);
      setDeviceCoordinateLoading(false);
      return;
    }

    let cancelled = false;

    const resolveFromDevice = async () => {
      setDeviceCoordinateLoading(true);
      try {
        const hasPermission = await requestDeviceLocationPermission();
        if (!hasPermission) {
          if (!cancelled) {
            setDeviceCoordinate(null);
          }
          return;
        }

        const currentCoordinate = await readDeviceCoordinate();
        if (!cancelled) {
          setDeviceCoordinate(currentCoordinate);
        }
      } finally {
        if (!cancelled) {
          setDeviceCoordinateLoading(false);
        }
      }
    };

    resolveFromDevice();

    return () => {
      cancelled = true;
    };
  }, [selectedAddressCoordinate]);

  const scopedCoordinate = useMemo(
    () => selectedAddressCoordinate ?? deviceCoordinate ?? userCoordinate ?? null,
    [selectedAddressCoordinate, userCoordinate, deviceCoordinate]
  );

  useEffect(() => {
    let cancelled = false;

    const syncVendorContext = async () => {
      if (!scopedCoordinate) {
        setSelectedVendorId(null);
        setVendorResolving(false);
        return;
      }

      try {
        setVendorResolving(true);
        const resolved = await resolveVendorByCoordinates(
          scopedCoordinate.latitude,
          scopedCoordinate.longitude,
          { radiusKm: productRadiusKm }
        );
        if (cancelled) {
          return;
        }
        setSelectedVendorId(resolveVendorIdString(resolved));
      } catch (error) {
        if (cancelled) {
          return;
        }
        console.log('Error resolving vendor context', error);
        setSelectedVendorId(null);
      } finally {
        if (!cancelled) {
          setVendorResolving(false);
        }
      }
    };

    syncVendorContext();

    return () => {
      cancelled = true;
    };
  }, [
    productRadiusKm,
    scopedCoordinate,
    setSelectedVendorId,
  ]);

  const vendorIds = useMemo(
    () => parseVendorIds(selectedVendorId),
    [selectedVendorId]
  );

  return {
    scopedCoordinate,
    vendorIds,
    vendorResolving: vendorResolving || deviceCoordinateLoading,
  };
};
