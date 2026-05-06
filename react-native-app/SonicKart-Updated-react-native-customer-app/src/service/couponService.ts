import { getApp } from '@react-native-firebase/app';
import {
  collection,
  getDocs,
  getFirestore,
} from '@react-native-firebase/firestore';
import {
  getApps as getWebApps,
  initializeApp as initializeWebApp,
  type FirebaseApp as WebFirebaseApp,
} from 'firebase/app';
import {
  collection as webCollection,
  getDocs as getWebDocs,
  getFirestore as getWebFirestore,
  initializeFirestore as initializeWebFirestore,
  type Firestore as WebFirestore,
} from 'firebase/firestore';

export type CouponDiscountType = 'percentage' | 'fixed';
export type CouponStatus = 'Scheduled' | 'Active' | 'Expired';

type CouponValidationContext = {
  orderAmount: number;
  userRef?: any;
  cartItems?: any[];
};

type CouponSnapshotDocument = {
  id: string;
  data(): unknown;
};

export type CouponDocument = {
  id: string;
  code: string;
  title: string;
  description: string;
  category: string;
  discountType: CouponDiscountType;
  discountValue: number;
  minimumOrderAmount: number;
  targetUser: string;
  targetUserKeys: string[];
  matchKeys: string[];
  startAt: Date;
  endAt: Date;
  status: CouponStatus;
  isActive: boolean;
  raw?: Record<string, any>;
};

export type CouponValidationResult =
  | { valid: true; coupon: CouponDocument }
  | { valid: false; message: string };

const COLLECTION_NAME = 'adminCoupons';
const WEB_COUPON_APP_NAME = 'coupon-fallback';
const googleServices = require('../../android/app/google-services.json');

const webFirebaseConfig = {
  apiKey: googleServices?.client?.[0]?.api_key?.[0]?.current_key ?? '',
  appId: googleServices?.client?.[0]?.client_info?.mobilesdk_app_id ?? '',
  projectId: googleServices?.project_info?.project_id ?? '',
  storageBucket: googleServices?.project_info?.storage_bucket ?? '',
  messagingSenderId: googleServices?.project_info?.project_number ?? '',
};

let couponWebFirestoreInstance: WebFirestore | null = null;

const normalizeText = (value: any) =>
  String(value ?? '')
    .trim()
    .toLowerCase();

const isCouponFallbackConfigReady = () =>
  Boolean(
    webFirebaseConfig.apiKey &&
      webFirebaseConfig.appId &&
      webFirebaseConfig.projectId
  );

const normalizeCodeToken = (value: any) =>
  String(value ?? '')
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '');

const normalizeDisplayCode = (value: any) =>
  String(value ?? '')
    .trim()
    .toUpperCase();

const toNumber = (value: any, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const formatAmount = (value: number) =>
  Number.isInteger(value) ? String(value) : value.toFixed(2);

const uniqueValues = (values: any[]) => [...new Set(values.filter(Boolean))];

const parseDateValue = (value: any): Date | null => {
  if (!value) {
    return null;
  }

  if (typeof value?.toDate === 'function') {
    return value.toDate();
  }

  if (value instanceof Date) {
    return value;
  }

  if (typeof value === 'number' || typeof value === 'string') {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  }

  if (typeof value === 'object' && typeof value.seconds === 'number') {
    const date = new Date(value.seconds * 1000);
    return Number.isNaN(date.getTime()) ? null : date;
  }

  return null;
};

const normalizeDiscountType = (value: any): CouponDiscountType => {
  const normalized = normalizeText(value);
  if (
    normalized === 'fixed' ||
    normalized === 'flat' ||
    normalized === 'amount' ||
    normalized === 'cash'
  ) {
    return 'fixed';
  }

  return 'percentage';
};

const collectTokens = (value: any): string[] => {
  if (value === null || value === undefined) {
    return [];
  }

  if (Array.isArray(value)) {
    return value.flatMap((item) => collectTokens(item));
  }

  if (typeof value === 'object') {
    return [
      value?.id,
      value?._id,
      value?.userId,
      value?.customerId,
      value?.phone,
      value?.mobile,
      value?.contactNumber,
      value?.email,
      value?.name,
      value?.title,
      value?.label,
      value?.value,
      value?.slug,
      value?.code,
      value?.couponCode,
      value?.categoryId,
      value?.category_id,
    ]
      .flatMap((item) => collectTokens(item));
  }

  const rawText = String(value).trim();
  if (!rawText) {
    return [];
  }

  const normalized = normalizeText(rawText);
  const digitsOnly = rawText.replace(/\D/g, '');
  const codeToken = normalizeCodeToken(rawText);

  return uniqueValues([
    normalized,
    digitsOnly.length >= 10 ? digitsOnly : '',
    digitsOnly.length >= 10 ? digitsOnly.slice(-10) : '',
    codeToken,
  ]);
};

const normalizeTargetUser = (value: any) => {
  if (value === null || value === undefined) {
    return '';
  }

  if (typeof value === 'object') {
    return String(
      value?.id ??
        value?._id ??
        value?.userId ??
        value?.customerId ??
        value?.phone ??
        value?.mobile ??
        value?.contactNumber ??
        value?.email ??
        value?.name ??
        value?.label ??
        value?.value ??
        ''
    ).trim();
  }

  return String(value).trim();
};

const getCouponStatus = (startAt: Date, endAt: Date) => {
  const now = Date.now();

  if (now < startAt.getTime()) {
    return 'Scheduled' as const;
  }

  if (now > endAt.getTime()) {
    return 'Expired' as const;
  }

  return 'Active' as const;
};

const normalizeCategory = (value: any) => {
  if (typeof value === 'object') {
    return String(value?.name ?? value?.title ?? value?.id ?? '').trim();
  }

  return String(value ?? '').trim();
};

const extractCartCategoryTokens = (cartItems: any[] = []) => {
  const tokenSet = new Set<string>();

  cartItems.forEach((cartItem) => {
    const product = cartItem?.item ?? cartItem ?? {};
    [
      product?.category,
      product?.categoryId,
      product?.category_id,
      product?.categoryName,
      product?.productCategory,
      product?.product_category,
      product?.subcategory,
      product?.subCategory,
      cartItem?.category,
      cartItem?.categoryId,
      cartItem?.category_id,
    ]
      .flatMap((value) => collectTokens(value))
      .forEach((token) => tokenSet.add(token));
  });

  return [...tokenSet];
};

const getUserMatchKeys = (userRef: any) => {
  if (!userRef) {
    return [];
  }

  return uniqueValues(collectTokens(userRef));
};

const matchesTargetUser = (coupon: CouponDocument, userRef?: any) => {
  const targetKeys = coupon.targetUserKeys;
  const userKeys = getUserMatchKeys(userRef);

  if (targetKeys.includes('all')) {
    return true;
  }

  if (!targetKeys.length || !userKeys.length) {
    return false;
  }

  return targetKeys.some((key) => userKeys.includes(key));
};

export const matchesCouponCategory = (
  coupon: CouponDocument,
  cartItems: any[] = []
) => {
  const normalizedCategory = normalizeText(coupon.category);

  if (
    !normalizedCategory ||
    normalizedCategory === 'all' ||
    normalizedCategory === 'all categories'
  ) {
    return true;
  }

  const cartTokens = extractCartCategoryTokens(cartItems);
  return cartTokens.includes(normalizedCategory);
};

const buildCouponMatchKeys = (rawData: Record<string, any>, title: string, id: string) =>
  uniqueValues([
    ...collectTokens(title),
    ...collectTokens(rawData?.title),
    ...collectTokens(rawData?.code),
    ...collectTokens(rawData?.couponCode),
    ...collectTokens(rawData?.coupon),
    ...collectTokens(rawData?.coupon_code),
    ...collectTokens(rawData?.name),
    ...collectTokens(id),
  ]);

const normalizeCouponDocument = (
  id: string,
  rawData: Record<string, any>
): CouponDocument | null => {
  const title = String(
    rawData?.title ??
      rawData?.name ??
      rawData?.couponTitle ??
      rawData?.couponName ??
      rawData?.couponCode ??
      rawData?.code ??
      ''
  ).trim();
  const description = String(
    rawData?.description ?? rawData?.details ?? rawData?.subtitle ?? title
  ).trim();
  const startAt = parseDateValue(
    rawData?.startDate ??
      rawData?.startAt ??
      rawData?.validFrom ??
      rawData?.fromDate
  );
  const endAt = parseDateValue(
    rawData?.endDate ??
      rawData?.endAt ??
      rawData?.validTill ??
      rawData?.validUntil ??
      rawData?.toDate
  );
  const discountValue = Math.max(
    0,
    toNumber(
      rawData?.discountValue ??
        rawData?.discount ??
        rawData?.amount ??
        rawData?.value,
      0
    )
  );
  const minimumOrderAmount = Math.max(
    0,
    toNumber(
      rawData?.minimumOrderAmount ??
        rawData?.minimumOrder ??
        rawData?.minOrderAmount ??
        rawData?.minOrder ??
        rawData?.minimum_purchase_amount ??
        rawData?.min_purchase_amount ??
        rawData?.minimumCartAmount ??
        rawData?.minimumCartValue,
      0
    )
  );
  const targetUserSource =
    rawData?.targetUser ??
    rawData?.assignedUser ??
    rawData?.assignedTo ??
    rawData?.user ??
    rawData?.customer ??
    rawData?.customerId ??
    rawData?.userId ??
    'all';
  const targetUser = normalizeTargetUser(targetUserSource);

  if (!title || !description || !startAt || !endAt) {
    return null;
  }

  if (endAt.getTime() < startAt.getTime()) {
    return null;
  }

  if (discountValue <= 0 || !targetUser) {
    return null;
  }

  const status = getCouponStatus(startAt, endAt);
  const codeSource =
    rawData?.code ??
    rawData?.couponCode ??
    rawData?.coupon ??
    rawData?.coupon_code ??
    title;

  return {
    id,
    code: normalizeDisplayCode(codeSource),
    title,
    description,
    category: normalizeCategory(
      rawData?.category ??
        rawData?.categoryName ??
        rawData?.productCategory ??
        rawData?.product_category ??
        'all'
    ),
    discountType: normalizeDiscountType(
      rawData?.discountType ?? rawData?.type ?? rawData?.discount_mode
    ),
    discountValue,
    minimumOrderAmount,
    targetUser,
    targetUserKeys: uniqueValues(collectTokens(targetUserSource)),
    matchKeys: buildCouponMatchKeys(rawData, title, id),
    startAt,
    endAt,
    status,
    isActive: status === 'Active',
    raw: rawData,
  };
};

const getCouponWebAppInstance = (): WebFirebaseApp => {
  const existingApp = getWebApps().find((app) => app.name === WEB_COUPON_APP_NAME);
  if (existingApp) {
    return existingApp;
  }

  return initializeWebApp(webFirebaseConfig, WEB_COUPON_APP_NAME);
};

const getCouponWebFirestoreInstance = (): WebFirestore => {
  if (couponWebFirestoreInstance) {
    return couponWebFirestoreInstance;
  }

  const app = getCouponWebAppInstance();

  try {
    couponWebFirestoreInstance = initializeWebFirestore(app, {
      experimentalForceLongPolling: true,
    });
  } catch {
    couponWebFirestoreInstance = getWebFirestore(app);
  }

  return couponWebFirestoreInstance;
};

const mapCouponDocuments = (docs: CouponSnapshotDocument[]) =>
  docs
    .map((doc: CouponSnapshotDocument) =>
      normalizeCouponDocument(doc.id, doc.data() as Record<string, any>)
    )
    .filter((coupon: CouponDocument | null): coupon is CouponDocument => Boolean(coupon));

const fetchCouponsFromNativeFirestore = async () => {
  const app = getApp();
  const db = getFirestore(app);
  const snapshot = await getDocs(collection(db, COLLECTION_NAME));

  return mapCouponDocuments(snapshot.docs as CouponSnapshotDocument[]);
};

const fetchCouponsFromWebFirestore = async () => {
  if (!isCouponFallbackConfigReady()) {
    throw new Error('Firebase coupon fallback is not configured.');
  }

  const db = getCouponWebFirestoreInstance();
  const snapshot = await getWebDocs(webCollection(db, COLLECTION_NAME));
  return mapCouponDocuments(snapshot.docs as CouponSnapshotDocument[]);
};

const isBrokenNativeCollectionGetError = (error: unknown) => {
  const message =
    error instanceof Error ? error.message : String(error ?? '');

  return message.includes('collectionGet is not a function');
};

const fetchAllCoupons = async () => {
  try {
    return await fetchCouponsFromNativeFirestore();
  } catch (error) {
    if (!isBrokenNativeCollectionGetError(error)) {
      throw error;
    }

    console.warn(
      'Coupon service: native Firestore collection bridge unavailable, falling back to Web SDK.'
    );
    return fetchCouponsFromWebFirestore();
  }
};

const dedupeCoupons = (coupons: CouponDocument[]) => {
  const seen = new Set<string>();

  return coupons.filter((coupon) => {
    const dedupeKey = coupon.id || coupon.code || coupon.title;
    if (seen.has(dedupeKey)) {
      return false;
    }

    seen.add(dedupeKey);
    return true;
  });
};

export const validateCouponForCart = (
  coupon: CouponDocument,
  context: CouponValidationContext
): CouponValidationResult => {
  if (!coupon.isActive) {
    if (coupon.status === 'Scheduled') {
      return { valid: false, message: 'This coupon is scheduled and not active yet.' };
    }

    return { valid: false, message: 'This coupon has expired.' };
  }

  if (!matchesTargetUser(coupon, context.userRef)) {
    return { valid: false, message: 'This coupon is not assigned to your account.' };
  }

  if (!matchesCouponCategory(coupon, context.cartItems)) {
    return { valid: false, message: 'This coupon does not match items in your cart.' };
  }

  if (context.orderAmount <= 0) {
    return { valid: false, message: 'Add items before applying a coupon.' };
  }

  const subtotal = toNumber(context.orderAmount, 0);
  const minimumOrder = toNumber(coupon.minimumOrderAmount, 0);
  if (subtotal < minimumOrder) {
    return {
      valid: false,
      message: `Minimum order Rs. ${formatAmount(minimumOrder)} required.`,
    };
  }

  return { valid: true, coupon };
};

export const fetchCoupons = async (
  _orderAmount: number,
  _userRef?: any,
  _cartItems: any[] = []
): Promise<CouponDocument[]> => {
  const coupons = dedupeCoupons(await fetchAllCoupons());

  return coupons.sort((left, right) => {
    if (left.isActive !== right.isActive) {
      return Number(right.isActive) - Number(left.isActive);
    }

    if (left.minimumOrderAmount !== right.minimumOrderAmount) {
      return left.minimumOrderAmount - right.minimumOrderAmount;
    }

    return right.discountValue - left.discountValue;
  });
};

export const getCouponByCode = async (
  couponCode: string,
  orderAmount: number,
  userRef?: any,
  cartItems: any[] = []
): Promise<CouponValidationResult> => {
  const normalizedCode = normalizeCodeToken(couponCode);

  if (!normalizedCode) {
    return { valid: false, message: 'Enter a coupon name or code first.' };
  }

  const coupons = dedupeCoupons(await fetchAllCoupons());
  const coupon = coupons.find((item) => item.matchKeys.includes(normalizedCode));

  if (!coupon) {
    return { valid: false, message: 'Coupon not found.' };
  }

  return validateCouponForCart(coupon, {
    orderAmount,
    userRef,
    cartItems,
  });
};
