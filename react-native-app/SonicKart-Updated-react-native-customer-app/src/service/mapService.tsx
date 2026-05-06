import axios from 'axios';
import { GOOGLE_MAP_API } from './config';
import { updateUserLocation } from './authService';
import { getDeliverySettingsSnapshot } from './deliverySettingsService';

/**
 * Google Maps utility service.
 * Provides geocoding, place autocomplete/details, distance matrix, and directions.
 */
const GEOCODE_BASE_URL = 'https://maps.googleapis.com/maps/api/geocode/json';
const PLACE_AUTOCOMPLETE_URL =
  'https://maps.googleapis.com/maps/api/place/autocomplete/json';

const PLACE_DETAILS_URL =
  'https://maps.googleapis.com/maps/api/place/details/json';

const isGoogleMapsApiEnabled = () =>
  typeof GOOGLE_MAP_API === 'string' && GOOGLE_MAP_API.trim().length > 0;

const logGeocodeWarning = (status?: string, errorMessage?: string) => {
  const normalizedStatus = typeof status === 'string' ? status : 'UNKNOWN_ERROR';

  if (normalizedStatus === 'ZERO_RESULTS') {
    return;
  }

  if (normalizedStatus === 'REQUEST_DENIED') {
    console.warn(
      `Reverse geocoding unavailable (${normalizedStatus}). ${errorMessage || 'Enable Geocoding API for this Google project.'}`
    );
    return;
  }

  console.warn(
    `Reverse geocoding failed (${normalizedStatus}). ${errorMessage || 'Please try again later.'}`
  );
};

export const reverseGeocode = async (
  latitude: number,
  longitude: number,
  setUser: any
) => {
  try {
    const address = await reverseGeocodeToAddress(latitude, longitude);
    const payload: any = { liveLocation: { latitude, longitude } };
    if (address) {
      payload.address = address;
    }
    await updateUserLocation(payload, setUser);
  } catch (error) {
    console.warn('Geo Code Failed', error);
  }
};

export const reverseGeocodeToAddress = async (
  latitude: number,
  longitude: number
): Promise<string | null> => {
  try {
    if (!isGoogleMapsApiEnabled()) {
      logGeocodeWarning('REQUEST_DENIED', 'Google Maps API key is missing.');
      return null;
    }

    const response = await axios.get(GEOCODE_BASE_URL, {
      params: {
        latlng: `${latitude},${longitude}`,
        key: GOOGLE_MAP_API,
      },
    });

    const status = response.data?.status;
    const errorMessage = response.data?.error_message;

    if (status === 'OK' && response.data.results?.length) {
      return response.data.results[0].formatted_address;
    }
    logGeocodeWarning(status, errorMessage);
    return null;
  } catch (error: any) {
    console.warn('Geo Code Failed', error?.message || error);
    return null;
  }
};

/**
 * Geocode an address to get latitude and longitude
 * @param address - The address string to geocode
 * @returns Object with address, latitude, and longitude, or null if geocoding fails
 */
export const geocodeAddress = async (
  address: string
): Promise<{ address: string; latitude: number; longitude: number } | null> => {
  try {
    if (!address || typeof address !== 'string' || address.trim().length === 0) {
      throw new Error('Invalid address provided');
    }

    if (!isGoogleMapsApiEnabled()) {
      logGeocodeWarning('REQUEST_DENIED', 'Google Maps API key is missing.');
      return null;
    }

    const response = await axios.get(GEOCODE_BASE_URL, {
      params: {
        address: address.trim(),
        key: GOOGLE_MAP_API,
      },
    });

    const status = response.data?.status;
    const errorMessage = response.data?.error_message;

    if (status === 'OK' && response.data.results?.length) {
      const result = response.data.results[0];
      const location = result.geometry?.location;

      if (typeof location?.lat === 'number' && typeof location?.lng === 'number') {
        return {
          address: result.formatted_address,
          latitude: location.lat,
          longitude: location.lng,
        };
      }
    }

    logGeocodeWarning(status, errorMessage);
    return null;
  } catch (error: any) {
    console.warn('Geocoding Failed', error?.message || error);
    return null;
  }
};

interface PlaceSuggestionBias {
  latitude?: number | null;
  longitude?: number | null;
  radiusMeters?: number;
  strictBounds?: boolean;
}

export const getPlaceSuggestions = async (
  query: string,
  sessionToken?: string,
  bias?: PlaceSuggestionBias
) => {
  try {
    const params: Record<string, string> = {
      input: query,
      key: GOOGLE_MAP_API,
      language: 'en',
      components: 'country:IN',
    };

    if (sessionToken) {
      params.sessiontoken = sessionToken;
    }

    if (
      bias?.latitude !== undefined &&
      bias?.longitude !== undefined &&
      bias?.latitude !== null &&
      bias?.longitude !== null
    ) {
      params.location = `${bias.latitude},${bias.longitude}`;
      params.radius = String(
        bias.radiusMeters ?? getDeliverySettingsSnapshot().packageMapRadiusMeters
      );
      if (bias.strictBounds) {
        params.strictbounds = 'true';
      }
    }

    const response = await axios.get(PLACE_AUTOCOMPLETE_URL, { params });

    if (response.data.status === 'OK' && response.data.predictions) {
      return response.data.predictions;
    }
    return [];
  } catch (error) {
    console.warn('Place autocomplete failed', error);
    return [];
  }
};

export const getPlaceDetails = async (placeId: string, sessionToken?: string) => {
  try {
    const params: Record<string, string> = {
      place_id: placeId,
      key: GOOGLE_MAP_API,
      language: 'en',
      fields: 'formatted_address,geometry,place_id',
    };

    if (sessionToken) {
      params.sessiontoken = sessionToken;
    }

    const response = await axios.get(PLACE_DETAILS_URL, { params });

    if (response.data.status === 'OK' && response.data.result) {
      const { formatted_address, geometry, place_id: resolvedPlaceId } = response.data.result;
      const location = geometry?.location;
      return {
        address: formatted_address || '',
        latitude: location?.lat ?? null,
        longitude: location?.lng ?? null,
        placeId: resolvedPlaceId || placeId,
      };
    }
    return null;
  } catch (error) {
    console.warn('Place details failed', error);
    return null;
  }
};

const DISTANCE_MATRIX_URL = 'https://maps.googleapis.com/maps/api/distancematrix/json';
const DIRECTIONS_URL = 'https://maps.googleapis.com/maps/api/directions/json';

export interface DistanceMatrixResult {
  distance: {
    text: string;
    value: number; // in meters
  };
  duration: {
    text: string;
    value: number; // in seconds
  };
  status: string;
}

export const getDistanceMatrix = async (
  origin: { latitude: number; longitude: number },
  destination: { latitude: number; longitude: number },
  retryCount = 0
): Promise<DistanceMatrixResult | null> => {
  const MAX_RETRIES = 2;

  try {
    // Validate coordinates
    if (
      !origin.latitude ||
      !origin.longitude ||
      !destination.latitude ||
      !destination.longitude
    ) {
      throw new Error('Invalid coordinates provided');
    }

    const params = {
      origins: `${origin.latitude},${origin.longitude}`,
      destinations: `${destination.latitude},${destination.longitude}`,
      key: GOOGLE_MAP_API,
      units: 'metric',
    };

    const response = await axios.get(DISTANCE_MATRIX_URL, {
      params,
      timeout: 10000, // 10 second timeout
    });

    if (response.data.status === 'OK' && response.data.rows?.[0]?.elements?.[0]) {
      const element = response.data.rows[0].elements[0];
      if (element.status === 'OK') {
        return {
          distance: element.distance,
          duration: element.duration,
          status: element.status,
        };
      } else if (element.status === 'ZERO_RESULTS') {
        throw new Error('No route found between the locations');
      } else if (element.status === 'NOT_FOUND') {
        throw new Error('One or both locations could not be found');
      }
    } else if (response.data.status === 'OVER_QUERY_LIMIT') {
      throw new Error('API quota exceeded. Please try again later.');
    } else if (response.data.status === 'REQUEST_DENIED') {
      throw new Error('API request denied. Please check API key.');
    }

    return null;
  } catch (error: any) {
    console.warn('Distance Matrix API failed', error);

    // Retry on network errors or timeouts
    if (
      retryCount < MAX_RETRIES &&
      (error.code === 'ECONNABORTED' ||
       error.code === 'ETIMEDOUT' ||
       error.code === 'ENOTFOUND' ||
       error.response?.status >= 500)
    ) {
      console.log(`Retrying Distance Matrix API (attempt ${retryCount + 1}/${MAX_RETRIES})...`);
      await new Promise((resolve) => setTimeout(resolve, 1000 * (retryCount + 1)));
      return getDistanceMatrix(origin, destination, retryCount + 1);
    }

    throw error;
  }
};

export interface DirectionsResult {
  routes: any[];
  status: string;
  polylinePoints?: Array<{ latitude: number; longitude: number }>;
}

export const getDirections = async (
  origin: { latitude: number; longitude: number },
  destination: { latitude: number; longitude: number }
): Promise<DirectionsResult | null> => {
  try {
    const params = {
      origin: `${origin.latitude},${origin.longitude}`,
      destination: `${destination.latitude},${destination.longitude}`,
      key: GOOGLE_MAP_API,
      mode: 'driving',
    };

    const response = await axios.get(DIRECTIONS_URL, { params });

    if (response.data.status === 'OK' && response.data.routes?.length > 0) {
      return {
        routes: response.data.routes,
        status: response.data.status,
      };
    }
    return null;
  } catch (error) {
    console.warn('Directions API failed', error);
    return null;
  }
};
