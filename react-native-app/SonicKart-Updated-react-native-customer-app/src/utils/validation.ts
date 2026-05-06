/**
 * Validation utilities for package delivery
 */

import { getDeliverySettingsSnapshot } from '@service/deliverySettingsService';
import { validateDeliveryDistance } from './distanceValidation';

export interface ValidationResult {
  isValid: boolean;
  errors: string[];
}

/**
 * Validate coordinates
 */
export const validateCoordinates = (
  latitude: number | null,
  longitude: number | null
): ValidationResult => {
  const errors: string[] = [];

  if (latitude === null || longitude === null) {
    errors.push('Coordinates are required');
    return { isValid: false, errors };
  }

  if (typeof latitude !== 'number' || typeof longitude !== 'number') {
    errors.push('Coordinates must be numbers');
    return { isValid: false, errors };
  }

  if (isNaN(latitude) || isNaN(longitude)) {
    errors.push('Coordinates must be valid numbers');
    return { isValid: false, errors };
  }

  if (latitude < -90 || latitude > 90) {
    errors.push('Latitude must be between -90 and 90');
  }

  if (longitude < -180 || longitude > 180) {
    errors.push('Longitude must be between -180 and 180');
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
};

/**
 * Validate address
 */
export const validateAddress = (address: string): ValidationResult => {
  const errors: string[] = [];

  if (!address || address.trim().length === 0) {
    errors.push('Address is required');
  } else if (address.trim().length < 10) {
    errors.push('Address must be at least 10 characters');
  } else if (address.trim().length > 500) {
    errors.push('Address must be less than 500 characters');
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
};

/**
 * Validate package type
 */
export const validatePackageType = (packageType: string | null): ValidationResult => {
  const errors: string[] = [];
  const validTypes = getDeliverySettingsSnapshot().packageTypes;

  if (!packageType) {
    errors.push('Package type is required');
  } else if (!validTypes.includes(packageType)) {
    errors.push(`Package type must be one of: ${validTypes.join(', ')}`);
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
};

/**
 * Validate distance
 * COMMENTED OUT - Distance validation disabled
 */
// export const validateDistance = (distance: number | null): ValidationResult => {
//   const errors: string[] = [];

//   if (distance === null || distance === undefined) {
//     errors.push('Distance is required');
//     return { isValid: false, errors };
//   }

//   if (typeof distance !== 'number' || isNaN(distance)) {
//     errors.push('Distance must be a valid number');
//     return { isValid: false, errors };
//   }

//   if (distance <= 0) {
//     errors.push('Distance must be greater than 0');
//   }

//   if (distance > 1000000) {
//     // More than 1000 km seems unreasonable
//     errors.push('Distance seems too large. Please check the locations.');
//   }

//   return {
//     isValid: errors.length === 0,
//     errors,
//   };
// };

// Placeholder function to maintain compatibility
export const validateDistance = (_distance: number | null): ValidationResult => {
  return { isValid: true, errors: [] };
};

/**
 * Validate complete package order data
 */
export interface PackageOrderValidationData {
  pickupAddress: string;
  pickupLatitude: number | null;
  pickupLongitude: number | null;
  dropAddress: string;
  dropLatitude: number | null;
  dropLongitude: number | null;
  packageType: string | null;
  distance: number | null;
  deliveryCharge: number;
}

export const validatePackageOrder = (
  data: PackageOrderValidationData
): ValidationResult => {
  const errors: string[] = [];

  // Validate pickup location
  const pickupAddressValidation = validateAddress(data.pickupAddress);
  if (!pickupAddressValidation.isValid) {
    errors.push(...pickupAddressValidation.errors.map((e) => `Pickup: ${e}`));
  }

  const pickupCoordsValidation = validateCoordinates(
    data.pickupLatitude,
    data.pickupLongitude
  );
  if (!pickupCoordsValidation.isValid) {
    errors.push(...pickupCoordsValidation.errors.map((e) => `Pickup: ${e}`));
  }

  // Validate drop location
  const dropAddressValidation = validateAddress(data.dropAddress);
  if (!dropAddressValidation.isValid) {
    errors.push(...dropAddressValidation.errors.map((e) => `Drop: ${e}`));
  }

  const dropCoordsValidation = validateCoordinates(
    data.dropLatitude,
    data.dropLongitude
  );
  if (!dropCoordsValidation.isValid) {
    errors.push(...dropCoordsValidation.errors.map((e) => `Drop: ${e}`));
  }

  // Validate package type
  const packageTypeValidation = validatePackageType(data.packageType);
  if (!packageTypeValidation.isValid) {
    errors.push(...packageTypeValidation.errors);
  }

  // Validate distance
  const distanceValidation = validateDistance(data.distance);
  if (!distanceValidation.isValid) {
    errors.push(...distanceValidation.errors);
  }

  // Validate delivery charge
  if (data.deliveryCharge <= 0) {
    errors.push('Delivery charge must be greater than 0');
  }

  // Check if pickup and drop are too close (same location)
  if (
    data.pickupLatitude &&
    data.pickupLongitude &&
    data.dropLatitude &&
    data.dropLongitude
  ) {
    const latDiff = Math.abs(data.pickupLatitude - data.dropLatitude);
    const lngDiff = Math.abs(data.pickupLongitude - data.dropLongitude);
    if (latDiff < 0.0001 && lngDiff < 0.0001) {
      errors.push('Pickup and drop locations cannot be the same');
    }

    // Validate delivery distance (30km limit)
    const deliveryDistanceValidation = validateDeliveryDistance(
      data.pickupLatitude,
      data.pickupLongitude,
      data.dropLatitude,
      data.dropLongitude
    );

    if (!deliveryDistanceValidation.isValid) {
      errors.push(
        `Delivery distance (${deliveryDistanceValidation.distance.toFixed(1)}km) exceeds maximum allowed distance of ${deliveryDistanceValidation.maxDistance}km`
      );
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
};

