type Primitive = string | number | null | undefined;

export type Coordinate = {
  latitude: number;
  longitude: number;
};

export type CoordinateLike = {
  latitude?: Primitive;
  longitude?: Primitive;
  lat?: Primitive;
  lng?: Primitive;
  lon?: Primitive;
  Latitude?: Primitive;
  Longitude?: Primitive;
  Lat?: Primitive;
  Lon?: Primitive;
  location?: unknown;
  coordinates?: unknown;
};

const INDIA_LAT_MIN = 6;
const INDIA_LAT_MAX = 38;
const INDIA_LNG_MIN = 68;
const INDIA_LNG_MAX = 98;

const isFiniteNumber = (value: unknown): value is number =>
  typeof value === 'number' && Number.isFinite(value);

export const toNumber = (value: Primitive): number | null => {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value === 'number') {
    return Number.isFinite(value) ? value : null;
  }

  const cleaned = value.trim().replace(',', '.');
  if (!cleaned) {
    return null;
  }

  const parsed = Number(cleaned);
  return Number.isFinite(parsed) ? parsed : null;
};

const inLatRange = (value: number) => value >= -90 && value <= 90;
const inLngRange = (value: number) => value >= -180 && value <= 180;

const isLikelyIndia = (coord: Coordinate) =>
  coord.latitude >= INDIA_LAT_MIN &&
  coord.latitude <= INDIA_LAT_MAX &&
  coord.longitude >= INDIA_LNG_MIN &&
  coord.longitude <= INDIA_LNG_MAX;

const parseCoordinateText = (value: string): Coordinate | null => {
  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }

  // "lat,lng"
  if (trimmed.includes(',')) {
    const [first, second] = trimmed.split(',').map((part) => toNumber(part as string));
    if (first !== null && second !== null && inLatRange(first) && inLngRange(second)) {
      return { latitude: first, longitude: second };
    }
    if (first !== null && second !== null && inLngRange(first) && inLatRange(second)) {
      const swapped = { latitude: second, longitude: first };
      if (isLikelyIndia(swapped)) {
        return swapped;
      }
    }
  }

  try {
    const parsed = JSON.parse(trimmed);
    return normalizeCoordinate(parsed);
  } catch {
    return null;
  }
};

const normalizeFromArray = (value: unknown[]): Coordinate | null => {
  if (value.length < 2) {
    return null;
  }

  const first = toNumber(value[0] as Primitive);
  const second = toNumber(value[1] as Primitive);
  if (first === null || second === null) {
    return null;
  }

  // Standard [lat, lng]
  if (inLatRange(first) && inLngRange(second)) {
    return { latitude: first, longitude: second };
  }

  // GeoJSON [lng, lat]
  if (inLngRange(first) && inLatRange(second)) {
    const swapped = { latitude: second, longitude: first };
    return swapped;
  }

  return null;
};

export const normalizeCoordinate = (value: unknown): Coordinate | null => {
  if (!value) {
    return null;
  }

  if (typeof value === 'string') {
    return parseCoordinateText(value);
  }

  if (Array.isArray(value)) {
    return normalizeFromArray(value);
  }

  const input = value as CoordinateLike;

  if (input.location) {
    const fromLocation = normalizeCoordinate(input.location);
    if (fromLocation) {
      return fromLocation;
    }
  }

  if (input.coordinates) {
    const fromCoordinates = normalizeCoordinate(input.coordinates);
    if (fromCoordinates) {
      return fromCoordinates;
    }
  }

  const lat = toNumber(
    input.latitude ?? input.lat ?? input.Latitude ?? input.Lat
  );
  const lng = toNumber(
    input.longitude ?? input.lng ?? input.lon ?? input.Longitude ?? input.Lon
  );

  if (lat === null || lng === null || !inLatRange(lat) || !inLngRange(lng)) {
    return null;
  }

  const direct = { latitude: lat, longitude: lng };
  if (isLikelyIndia(direct)) {
    return direct;
  }

  // If the direct value is not in India, try swapped. This app operates in India.
  if (inLatRange(lng) && inLngRange(lat)) {
    const swapped = { latitude: lng, longitude: lat };
    if (isLikelyIndia(swapped)) {
      return swapped;
    }
  }

  return direct;
};

export const clampMapDelta = (value: unknown, fallback = 0.01): number => {
  if (!isFiniteNumber(value)) {
    return fallback;
  }
  if (value <= 0) {
    return fallback;
  }
  return Math.min(Math.max(value, 0.005), 45);
};

export const buildRegionFromCoordinate = (
  coordinate: Coordinate,
  delta = 0.01
) => ({
  latitude: coordinate.latitude,
  longitude: coordinate.longitude,
  latitudeDelta: clampMapDelta(delta, 0.01),
  longitudeDelta: clampMapDelta(delta, 0.01),
});
