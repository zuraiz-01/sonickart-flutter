/**
 * Distance validation utilities for package orders
 * Validates that delivery locations are within 30km range
 */

import { getDeliverySettingsSnapshot } from '@service/deliverySettingsService';

export const getMaxDeliveryDistanceKm = () =>
  getDeliverySettingsSnapshot().maxPackageDistanceKm;

export const MAX_DELIVERY_DISTANCE_KM = getMaxDeliveryDistanceKm();

/**
 * Calculate distance between two coordinates using Haversine formula
 * @param lat1 Latitude of first point
 * @param lon1 Longitude of first point
 * @param lat2 Latitude of second point
 * @param lon2 Longitude of second point
 * @returns Distance in kilometers
 */
export const calculateDistance = (
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number => {
  const R = 6371; // Earth's radius in kilometers
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c;

  return distance;
};

const toRadians = (degrees: number): number => {
  return degrees * (Math.PI / 180);
};

/**
 * Validate if the distance between pickup and drop locations is within allowed range
 * @param pickupLat Pickup latitude
 * @param pickupLon Pickup longitude
 * @param dropLat Drop latitude
 * @param dropLon Drop longitude
 * @returns Object with validation result and distance
 */
export const validateDeliveryDistance = (
  pickupLat: number,
  pickupLon: number,
  dropLat: number,
  dropLon: number
): {
  isValid: boolean;
  distance: number;
  maxDistance: number;
} => {
  const distance = calculateDistance(pickupLat, pickupLon, dropLat, dropLon);

  return {
    isValid: distance <= getMaxDeliveryDistanceKm(),
    distance: Math.round(distance * 100) / 100, // Round to 2 decimal places
    maxDistance: getMaxDeliveryDistanceKm(),
  };
};
