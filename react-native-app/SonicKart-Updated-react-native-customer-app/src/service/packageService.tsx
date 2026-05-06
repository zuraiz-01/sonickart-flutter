import { appAxios } from './apiInterceptors';
import { retryWithBackoff } from '@utils/apiRetry';

/**
 * Package-order focused API helpers.
 * Used by customer package booking and package detail refresh flows.
 */
export interface PackageOrderData {
  pickupLocation: {
    address: string;
    latitude: number;
    longitude: number;
    placeId?: string;
  };
  dropLocation: {
    address: string;
    latitude: number;
    longitude: number;
    placeId?: string;
  };
  packageType: string;
  distance: number; // in meters
  distanceText: string;
  duration: number; // in seconds
  durationText: string;
  deliveryCharge: number;
  customerName?: string;
  customerPhone?: string;
  specialInstructions?: string;
  orderType?: 'send' | 'receive'; // Package order type: send or receive
  agreement?: boolean; // Agreement to terms and conditions
}

export const createPackageOrder = async (
  packageData: PackageOrderData,
  retryOptions = { maxRetries: 2 }
) => {
  try {
    const response = await retryWithBackoff(
      () =>
        appAxios.post('/order/package', {
          pickupLocation: packageData.pickupLocation,
          dropLocation: packageData.dropLocation,
          packageType: packageData.packageType,
          distance: packageData.distance,
          distanceText: packageData.distanceText,
          duration: packageData.duration,
          durationText: packageData.durationText,
          deliveryCharge: packageData.deliveryCharge,
          customerName: packageData.customerName,
          customerPhone: packageData.customerPhone,
          specialInstructions: packageData.specialInstructions,
          orderType: 'package', // For delivery_orders table
          packageOrderType: packageData.orderType || 'send', // For package_orders table: send or receive
          agreement: packageData.agreement, // Agreement status
        }),
      retryOptions
    );
    return response.data;
  } catch (error: any) {
    console.error('Create Package Order Error', error);

    // Provide user-friendly error messages
    if (error.response) {
      const status = error.response.status;
      const message = error.response.data?.message || 'Failed to create package order';

      if (status === 400) {
        throw new Error(`Invalid request: ${message}`);
      } else if (status === 401) {
        throw new Error('Please login again to continue');
      } else if (status === 403) {
        throw new Error('You do not have permission to create orders');
      } else if (status === 429) {
        throw new Error('Too many requests. Please try again in a moment.');
      } else if (status >= 500) {
        throw new Error('Server error. Please try again later.');
      } else {
        throw new Error(message);
      }
    } else if (error.request) {
      throw new Error('Network error. Please check your internet connection and try again.');
    } else {
      throw new Error('An unexpected error occurred. Please try again.');
    }
  }
};

export const getPackageOrderById = async (id: string) => {
  const rawId = String(id);
  const normalizedId = rawId.replace(/^PKG/i, '');

  const tryFetch = async (targetId: string) => {
    const response = await appAxios.get(`/order/package/${targetId}`);
    return response.data;
  };

  try {
    return await tryFetch(normalizedId);
  } catch (error: any) {
    // If normalized lookup fails with 404, retry once with the raw id
    const status = error?.response?.status;
    if (status === 404 && normalizedId !== rawId) {
      try {
        return await tryFetch(rawId);
      } catch (fallbackError) {
        console.log('Fetch Package Order Error (fallback)', fallbackError);
        return null;
      }
    }

    console.log('Fetch Package Order Error', error);
    return null;
  }
};

