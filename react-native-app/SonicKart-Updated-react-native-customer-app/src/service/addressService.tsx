import { appAxios } from './apiInterceptors';
import { getProductVendorRadiusKm } from '@utils/vendorRadius';

/**
 * Address book service layer.
 * Manages CRUD for saved addresses and vendor-resolution by coordinates.
 */
export interface AddressData {
  fullName: string;
  contactNumber: string;
  address: string;
  latitude: number;
  longitude: number;
  placeId?: string | null;
}

export interface SavedAddress {
  id: number;
  fullName: string;
  contactNumber: string;
  address: string;
  latitude: number;
  longitude: number;
  placeId?: string | null;
  userId: number;
  createdAt: string;
  updatedAt: string;
}

export interface ResolvedVendor {
  success: boolean;
  vendorId?: string | null; // For backward compatibility
  vendorIds?: string[]; // Nearby vendor IDs for current address.
  vendors?: Array<{
    vendorId: string | null;
    branchId?: number | string | null;
    name?: string | null;
    address?: string | null;
    distanceKm?: number;
  }>;
  count?: number;
  nearestVendor?: {
    vendorId: string | null;
    branchId?: number | string | null;
    branchName?: string | null;
    name?: string | null;
    address?: string | null;
    distanceKm?: number;
  } | null;
  branchId?: number | string | null;
  branchName?: string | null;
  address?: string | null;
  distanceKm?: number;
  message?: string;
}

const toNumber = (value: unknown): number | null => {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) {
      return null;
    }

    const directParsed = Number(trimmed);
    if (Number.isFinite(directParsed)) {
      return directParsed;
    }

    const match = trimmed.match(/-?\d+(?:\.\d+)?/);
    if (match?.[0]) {
      const fallbackParsed = Number(match[0]);
      return Number.isFinite(fallbackParsed) ? fallbackParsed : null;
    }
  }

  return null;
};

const normalizeVendorId = (value: unknown): string | null => {
  if (value === null || value === undefined) {
    return null;
  }

  const normalized = String(value).trim();
  return normalized ? normalized : null;
};

const uniqueVendorIds = (vendorIds: Array<string | null>) =>
  [...new Set(vendorIds.filter((vendorId): vendorId is string => Boolean(vendorId)))];

const resolveVendorIdentifier = (vendor: Record<string, unknown>) =>
  normalizeVendorId(vendor.vendorId ?? vendor.vendor_id ?? vendor.id);

const resolveVendorDistanceKm = (vendor: Record<string, unknown>): number | null => {
  const candidates = [
    vendor.distanceKm,
    vendor.distance_km,
    vendor.distanceKM,
    vendor.distance,
    vendor.distanceInKm,
    vendor.distance_in_km,
  ];

  for (const candidate of candidates) {
    const parsed = toNumber(candidate);
    if (parsed !== null) {
      return parsed;
    }
  }

  return null;
};

const applyRadiusFilter = (
  resolvedVendor: ResolvedVendor,
  radiusKm: number
): ResolvedVendor => {
  if (!Array.isArray(resolvedVendor?.vendors) || resolvedVendor.vendors.length === 0) {
    const nearestDistance = resolvedVendor?.nearestVendor
      ? resolveVendorDistanceKm(resolvedVendor.nearestVendor as unknown as Record<string, unknown>)
      : toNumber(
          (resolvedVendor as unknown as Record<string, unknown>).distanceKm ??
            (resolvedVendor as unknown as Record<string, unknown>).distance_km ??
            (resolvedVendor as unknown as Record<string, unknown>).distance
        );

    if (nearestDistance !== null && nearestDistance > radiusKm) {
      return {
        ...resolvedVendor,
        vendorId: null,
        vendorIds: [],
        count: 0,
        nearestVendor: null,
        message:
          resolvedVendor.message ||
          `No stores found within ${radiusKm}km of your selected address.`,
      };
    }

    return resolvedVendor;
  }

  const nearbyVendors = resolvedVendor.vendors.filter((vendor) => {
    const distance = resolveVendorDistanceKm(vendor as unknown as Record<string, unknown>);
    if (distance === null) {
      return true;
    }
    return distance <= radiusKm;
  });

  if (nearbyVendors.length === 0) {
    return {
      ...resolvedVendor,
      vendorId: null,
      vendorIds: [],
      vendors: [],
      count: 0,
      nearestVendor: null,
      message:
        resolvedVendor.message ||
        `No stores found within ${radiusKm}km of your selected address.`,
    };
  }

  const nearbyVendorIds = uniqueVendorIds(
    nearbyVendors.map((vendor) =>
      resolveVendorIdentifier(vendor as unknown as Record<string, unknown>)
    )
  );

  const nearestVendor = nearbyVendors.reduce<(typeof nearbyVendors)[number] | null>(
    (nearest, vendor) => {
      if (!nearest) {
        return vendor;
      }

      const currentDistance = resolveVendorDistanceKm(
        vendor as unknown as Record<string, unknown>
      );
      const nearestDistance = resolveVendorDistanceKm(
        nearest as unknown as Record<string, unknown>
      );

      if (nearestDistance === null) {
        return vendor;
      }

      if (currentDistance === null) {
        return nearest;
      }

      return currentDistance < nearestDistance ? vendor : nearest;
    },
    null
  );

  return {
    ...resolvedVendor,
    vendors: nearbyVendors,
    vendorIds: nearbyVendorIds,
    vendorId: nearbyVendorIds[0] ?? normalizeVendorId(resolvedVendor.vendorId),
    nearestVendor: nearestVendor ?? resolvedVendor.nearestVendor ?? null,
    count: nearbyVendors.length,
  };
};

export const saveAddress = async (data: AddressData) => {
  try {
    const response = await appAxios.post('/address/save', data);
    return response.data;
  } catch (error: any) {
    console.error('Save address error:', error);
    throw error;
  }
};

export const getAddresses = async (): Promise<SavedAddress[]> => {
  try {
    const response = await appAxios.get('/address/list');
    return response.data.data || [];
  } catch (error: any) {
    console.error('Get addresses error:', error);
    throw error;
  }
};

export const updateAddress = async (id: number, data: Partial<AddressData>) => {
  try {
    console.log('Updating address:', id, data);
    const response = await appAxios.put(`/address/${id}`, data);
    console.log('Update response:', response.data);
    return response.data;
  } catch (error: any) {
    console.error('Update address error:', error);
    console.error('Error response:', error.response?.data);
    throw error;
  }
};

export const deleteAddress = async (id: number) => {
  try {
    console.log('Deleting address:', id);
    const response = await appAxios.delete(`/address/${id}`);
    console.log('Delete response:', response.data);
    return response.data;
  } catch (error: any) {
    console.error('Delete address error:', error);
    console.error('Error response:', error.response?.data);
    throw error;
  }
};

export const resolveVendorByCoordinates = async (
  latitude: number,
  longitude: number,
  options?: { radiusKm?: number }
): Promise<ResolvedVendor | null> => {
  try {
    const radiusKm = options?.radiusKm ?? getProductVendorRadiusKm();
    const response = await appAxios.get('/address/resolve-vendor', {
      params: { latitude, longitude, radiusKm },
    });
    const resolved = response.data as ResolvedVendor | null;
    if (!resolved) {
      return null;
    }
    return applyRadiusFilter(resolved, radiusKm);
  } catch (error: any) {
    console.error('Resolve vendor error:', error?.response?.data || error?.message);
    return null;
  }
};
