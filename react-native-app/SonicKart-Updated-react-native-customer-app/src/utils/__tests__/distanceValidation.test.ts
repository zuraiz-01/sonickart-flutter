/**
 * Tests for distance validation utilities
 */

jest.mock('@service/deliverySettingsService', () => ({
  getDeliverySettingsSnapshot: () => ({
    maxPackageDistanceKm: 30,
  }),
}));

import { calculateDistance, validateDeliveryDistance, MAX_DELIVERY_DISTANCE_KM } from '../distanceValidation';

describe('Distance Validation', () => {
  describe('calculateDistance', () => {
    it('should calculate distance between two points correctly', () => {
      // Distance between New York and Los Angeles (approximately 3944 km)
      const nyLat = 40.7128;
      const nyLon = -74.0060;
      const laLat = 34.0522;
      const laLon = -118.2437;

      const distance = calculateDistance(nyLat, nyLon, laLat, laLon);

      // Should be approximately 3944 km (allowing for some variance due to Earth's curvature)
      expect(distance).toBeGreaterThan(3900);
      expect(distance).toBeLessThan(4000);
    });

    it('should return 0 for same coordinates', () => {
      const lat = 40.7128;
      const lon = -74.0060;

      const distance = calculateDistance(lat, lon, lat, lon);

      expect(distance).toBe(0);
    });

    it('should calculate short distances accurately', () => {
      // Two points approximately 1 km apart
      const lat1 = 40.7128;
      const lon1 = -74.0060;
      const lat2 = 40.7218; // About 1 km north
      const lon2 = -74.0060;

      const distance = calculateDistance(lat1, lon1, lat2, lon2);

      // Should be approximately 1 km
      expect(distance).toBeGreaterThan(0.9);
      expect(distance).toBeLessThan(1.1);
    });
  });

  describe('validateDeliveryDistance', () => {
    it('should validate distances within 30km as valid', () => {
      // Two points 20 km apart (within limit)
      const lat1 = 40.7128;
      const lon1 = -74.0060;
      const lat2 = 40.8928; // About 20 km north
      const lon2 = -74.0060;

      const result = validateDeliveryDistance(lat1, lon1, lat2, lon2);

      expect(result.isValid).toBe(true);
      expect(result.distance).toBeLessThan(MAX_DELIVERY_DISTANCE_KM);
      expect(result.maxDistance).toBe(MAX_DELIVERY_DISTANCE_KM);
    });

    it('should validate distances over 30km as invalid', () => {
      // Two points 50 km apart (over limit)
      const lat1 = 40.7128;
      const lon1 = -74.0060;
      const lat2 = 41.1628; // About 50 km north
      const lon2 = -74.0060;

      const result = validateDeliveryDistance(lat1, lon1, lat2, lon2);

      expect(result.isValid).toBe(false);
      expect(result.distance).toBeGreaterThan(MAX_DELIVERY_DISTANCE_KM);
      expect(result.maxDistance).toBe(MAX_DELIVERY_DISTANCE_KM);
    });

    it('should return correct distance values', () => {
      const lat1 = 40.7128;
      const lon1 = -74.0060;
      const lat2 = 40.7128;
      const lon2 = -74.0060;

      const result = validateDeliveryDistance(lat1, lon1, lat2, lon2);

      expect(result.distance).toBe(0);
      expect(result.isValid).toBe(true);
    });
  });
});
