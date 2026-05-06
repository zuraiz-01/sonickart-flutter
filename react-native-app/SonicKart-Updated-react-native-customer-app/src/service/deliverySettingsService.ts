import { getApp } from '@react-native-firebase/app';
import {
  doc,
  getDoc,
  getFirestore,
} from '@react-native-firebase/firestore';
import {
  getApps as getWebApps,
  initializeApp as initializeWebApp,
  type FirebaseApp as WebFirebaseApp,
} from 'firebase/app';
import {
  doc as webDoc,
  getDoc as getWebDoc,
  getFirestore as getWebFirestore,
  initializeFirestore as initializeWebFirestore,
  type Firestore as WebFirestore,
} from 'firebase/firestore';

export type DeliverySettings = {
  productRadiusKm: number;
  featuredProductsLimit: number;
  freeDeliveryThreshold: number;
  productDeliveryCharge: number;
  packageTypes: string[];
  packageBaseFee: number;
  packagePerKmFee: number;
  maxPackageDistanceKm: number;
  packageMapRadiusMeters: number;
};

const COLLECTION_NAME = 'adminSettings';
const DOCUMENT_ID = 'deliveryRadius';
const WEB_APP_NAME = 'delivery-settings-fallback';

export const DEFAULT_DELIVERY_SETTINGS: DeliverySettings = {
  productRadiusKm: 5,
  featuredProductsLimit: 8,
  freeDeliveryThreshold: 200,
  productDeliveryCharge: 30,
  packageTypes: ['Documents', 'Food', 'Parcel', 'Medicine'],
  packageBaseFee: 30,
  packagePerKmFee: 8,
  maxPackageDistanceKm: 30,
  packageMapRadiusMeters: 50000,
};

const googleServices = require('../../android/app/google-services.json');

const webFirebaseConfig = {
  apiKey: googleServices?.client?.[0]?.api_key?.[0]?.current_key ?? '',
  appId: googleServices?.client?.[0]?.client_info?.mobilesdk_app_id ?? '',
  projectId: googleServices?.project_info?.project_id ?? '',
  storageBucket: googleServices?.project_info?.storage_bucket ?? '',
  messagingSenderId: googleServices?.project_info?.project_number ?? '',
};

let cachedSettings: DeliverySettings = { ...DEFAULT_DELIVERY_SETTINGS };
let hasFetchedSettings = false;
let webFirestoreInstance: WebFirestore | null = null;

const isFallbackConfigReady = () =>
  Boolean(
    webFirebaseConfig.apiKey &&
      webFirebaseConfig.appId &&
      webFirebaseConfig.projectId
  );

const toFiniteNumber = (value: unknown, fallback: number) => {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) {
      return fallback;
    }

    const parsed = Number(trimmed);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }

  return fallback;
};

const readPath = (source: Record<string, any>, path: string) => {
  const segments = path.split('.');
  let current: any = source;

  for (const segment of segments) {
    if (!current || typeof current !== 'object') {
      return undefined;
    }

    current = current[segment];
  }

  return current;
};

const pickValue = (source: Record<string, any>, paths: string[]) => {
  for (const path of paths) {
    const value = readPath(source, path);
    if (value !== undefined && value !== null) {
      return value;
    }
  }

  return undefined;
};

const uniqueValues = (values: string[]) => [...new Set(values.filter(Boolean))];

const normalizePackageTypes = (rawData: Record<string, any>) => {
  const packageTypeSource = pickValue(rawData, [
    'packageTypes',
    'package_types',
    'packages.types',
    'packages.packageTypes',
    'packages.package_types',
    'package.types',
  ]);

  const values = Array.isArray(packageTypeSource)
    ? packageTypeSource
    : String(packageTypeSource ?? '')
        .split(',')
        .map((item) => item.trim())
        .filter(Boolean);

  const normalized = uniqueValues(
    values.map((item) => String(item ?? '').trim()).filter(Boolean)
  );

  return normalized.length > 0
    ? normalized
    : [...DEFAULT_DELIVERY_SETTINGS.packageTypes];
};

const normalizeDeliverySettings = (rawData: Record<string, any>): DeliverySettings => {
  const productRadiusKm = Math.max(
    1,
    toFiniteNumber(
      pickValue(rawData, [
        'productVisibilityRadiusKm',
        'productRadiusKm',
        'product_radius_km',
        'products.radiusKm',
        'products.visibilityRadiusKm',
        'products.productVisibilityRadiusKm',
      ]),
      DEFAULT_DELIVERY_SETTINGS.productRadiusKm
    )
  );

  const featuredProductsLimit = Math.max(
    1,
    Math.round(
      toFiniteNumber(
        pickValue(rawData, [
          'featuredProductsLimit',
          'featured_products_limit',
          'products.featuredProductsLimit',
          'products.featuredLimit',
        ]),
        DEFAULT_DELIVERY_SETTINGS.featuredProductsLimit
      )
    )
  );

  const freeDeliveryThreshold = Math.max(
    0,
    toFiniteNumber(
      pickValue(rawData, [
        'freeDeliveryThreshold',
        'free_delivery_threshold',
        'products.freeDeliveryThreshold',
        'products.freeDeliveryAmount',
      ]),
      DEFAULT_DELIVERY_SETTINGS.freeDeliveryThreshold
    )
  );

  const productDeliveryCharge = Math.max(
    0,
    toFiniteNumber(
      pickValue(rawData, [
        'deliveryCharge',
        'productDeliveryCharge',
        'products.deliveryCharge',
        'products.deliveryFee',
      ]),
      DEFAULT_DELIVERY_SETTINGS.productDeliveryCharge
    )
  );

  const packageBaseFee = Math.max(
    0,
    toFiniteNumber(
      pickValue(rawData, [
        'baseFee',
        'base_fee',
        'packages.baseFee',
        'packages.base_fee',
      ]),
      DEFAULT_DELIVERY_SETTINGS.packageBaseFee
    )
  );

  const packagePerKmFee = Math.max(
    0,
    toFiniteNumber(
      pickValue(rawData, [
        'perKmFee',
        'per_km_fee',
        'packages.perKmFee',
        'packages.per_km_fee',
      ]),
      DEFAULT_DELIVERY_SETTINGS.packagePerKmFee
    )
  );

  const maxPackageDistanceKm = Math.max(
    1,
    toFiniteNumber(
      pickValue(rawData, [
        'maxDistanceKm',
        'max_distance_km',
        'packages.maxDistanceKm',
        'packages.max_distance_km',
      ]),
      DEFAULT_DELIVERY_SETTINGS.maxPackageDistanceKm
    )
  );

  const packageMapRadiusMeters = Math.max(
    1000,
    Math.round(
      toFiniteNumber(
        pickValue(rawData, [
          'mapRadiusMeters',
          'map_radius_meters',
          'packages.mapRadiusMeters',
          'packages.map_radius_meters',
        ]),
        DEFAULT_DELIVERY_SETTINGS.packageMapRadiusMeters
      )
    )
  );

  return {
    productRadiusKm,
    featuredProductsLimit,
    freeDeliveryThreshold,
    productDeliveryCharge,
    packageTypes: normalizePackageTypes(rawData),
    packageBaseFee,
    packagePerKmFee,
    maxPackageDistanceKm,
    packageMapRadiusMeters,
  };
};

const getWebAppInstance = (): WebFirebaseApp => {
  const existingApp = getWebApps().find((app) => app.name === WEB_APP_NAME);
  if (existingApp) {
    return existingApp;
  }

  return initializeWebApp(webFirebaseConfig, WEB_APP_NAME);
};

const getWebFirestoreInstance = (): WebFirestore => {
  if (webFirestoreInstance) {
    return webFirestoreInstance;
  }

  const app = getWebAppInstance();

  try {
    webFirestoreInstance = initializeWebFirestore(app, {
      experimentalForceLongPolling: true,
    });
  } catch {
    webFirestoreInstance = getWebFirestore(app);
  }

  return webFirestoreInstance;
};

const fetchSettingsFromNativeFirestore = async () => {
  const app = getApp();
  const db = getFirestore(app);
  const snapshot = await getDoc(doc(db, COLLECTION_NAME, DOCUMENT_ID));

  if (!snapshot.exists()) {
    return { ...DEFAULT_DELIVERY_SETTINGS };
  }

  return normalizeDeliverySettings((snapshot.data() as Record<string, any>) ?? {});
};

const fetchSettingsFromWebFirestore = async () => {
  if (!isFallbackConfigReady()) {
    throw new Error('Firebase delivery settings fallback is not configured.');
  }

  const db = getWebFirestoreInstance();
  const snapshot = await getWebDoc(webDoc(db, COLLECTION_NAME, DOCUMENT_ID));

  if (!snapshot.exists()) {
    return { ...DEFAULT_DELIVERY_SETTINGS };
  }

  return normalizeDeliverySettings((snapshot.data() as Record<string, any>) ?? {});
};

export const getDeliverySettingsSnapshot = () => ({
  ...cachedSettings,
  packageTypes: [...cachedSettings.packageTypes],
});

export const setDeliverySettingsSnapshot = (settings: DeliverySettings) => {
  cachedSettings = {
    ...settings,
    packageTypes: [...settings.packageTypes],
  };
  hasFetchedSettings = true;
};

export const fetchDeliverySettings = async (
  options?: { force?: boolean }
): Promise<DeliverySettings> => {
  if (hasFetchedSettings && !options?.force) {
    return getDeliverySettingsSnapshot();
  }

  try {
    const settings = await fetchSettingsFromNativeFirestore();
    setDeliverySettingsSnapshot(settings);
    return getDeliverySettingsSnapshot();
  } catch (nativeError) {
    console.warn(
      'Delivery settings: native Firestore read failed, falling back to Web SDK.',
      nativeError
    );

    try {
      const settings = await fetchSettingsFromWebFirestore();
      setDeliverySettingsSnapshot(settings);
      return getDeliverySettingsSnapshot();
    } catch (fallbackError) {
      console.warn(
        'Delivery settings: Firestore fallback failed, using defaults.',
        fallbackError
      );
      setDeliverySettingsSnapshot(DEFAULT_DELIVERY_SETTINGS);
      return getDeliverySettingsSnapshot();
    }
  }
};
