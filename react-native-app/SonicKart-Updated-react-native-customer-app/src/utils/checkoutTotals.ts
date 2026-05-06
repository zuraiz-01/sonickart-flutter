import {
  matchesCouponCategory,
  type CouponDiscountType,
  type CouponDocument,
} from '@service/couponService';
import { getDeliverySettingsSnapshot } from '@service/deliverySettingsService';

type CartItem = {
  _id?: string | number;
  id?: string | number;
  count?: number;
  quantity?: number;
  unit_price?: number;
  unitPrice?: number;
  item_gst?: number | null;
  gst_items?: number | null;
  item?: {
    price?: number;
    discountPrice?: number;
    discount_price?: number;
    gstSlab?: number;
    gst_slab?: number;
    gstRate?: number;
    gst_rate?: number;
    gst?: number;
  };
};

export type AppliedCouponSummary = {
  id: string;
  code: string;
  title: string;
  description?: string;
  category: string;
  discountType: CouponDiscountType;
  discountValue: number;
  minimumOrderAmount: number;
  discountAmount: number;
};

export type CheckoutTotals = {
  itemsTotal: number;
  gstAmount: number;
  totalBeforeDiscount: number;
  deliveryCharge: number;
  couponDiscount: number;
  grandTotal: number;
  hasValidItems: boolean;
  appliedCoupon: AppliedCouponSummary | null;
  couponError: string | null;
};

export const getFreeDeliveryThreshold = () =>
  getDeliverySettingsSnapshot().freeDeliveryThreshold;

const sanitizeNumber = (value: any, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const resolveUnitPrice = (cartItem: CartItem) => {
  const priceCandidate =
    cartItem?.item?.discountPrice ??
    cartItem?.item?.discount_price ??
    cartItem?.item?.price ??
    cartItem?.unit_price ??
    cartItem?.unitPrice ??
    0;

  return sanitizeNumber(priceCandidate, 0);
};

const resolveQuantity = (cartItem: CartItem) => {
  const quantity = sanitizeNumber(cartItem?.count ?? cartItem?.quantity ?? 0, 0);
  return quantity > 0 ? quantity : 0;
};

const roundCurrency = (value: number) => Number(value.toFixed(2));
const formatAmount = (value: number) =>
  Number.isInteger(value) ? String(value) : value.toFixed(2);

const calculateCouponDiscountAmount = (
  coupon: CouponDocument,
  itemsTotal: number,
  totalBeforeDiscount: number
) => {
  let discountAmount =
    coupon.discountType === 'percentage'
      ? (itemsTotal * coupon.discountValue) / 100
      : coupon.discountValue;

  return roundCurrency(Math.max(0, Math.min(discountAmount, totalBeforeDiscount)));
};

export const calculateCheckoutTotals = (
  cartItems: CartItem[],
  coupon?: CouponDocument | null
): CheckoutTotals => {
  const normalizedItems = Array.isArray(cartItems) ? cartItems : [];

  const itemsTotal = roundCurrency(
    normalizedItems.reduce((total, cartItem) => {
      const quantity = resolveQuantity(cartItem);
      const unitPrice = resolveUnitPrice(cartItem);
      return total + quantity * unitPrice;
    }, 0)
  );

  const gstAmount = 0;

  const hasValidItems = normalizedItems.some((cartItem) => resolveQuantity(cartItem) > 0);
  const totalBeforeDiscount = itemsTotal;
  const { freeDeliveryThreshold, productDeliveryCharge } =
    getDeliverySettingsSnapshot();
  const deliveryCharge =
    totalBeforeDiscount > 0 && totalBeforeDiscount < freeDeliveryThreshold
      ? productDeliveryCharge
      : 0;

  if (!coupon) {
    return {
      itemsTotal,
      gstAmount,
      totalBeforeDiscount,
      deliveryCharge,
      couponDiscount: 0,
      grandTotal: roundCurrency(totalBeforeDiscount + deliveryCharge),
      hasValidItems,
      appliedCoupon: null,
      couponError: null,
    };
  }

  if (!coupon.isActive) {
    return {
      itemsTotal,
      gstAmount,
      totalBeforeDiscount,
      deliveryCharge,
      couponDiscount: 0,
      grandTotal: roundCurrency(totalBeforeDiscount + deliveryCharge),
      hasValidItems,
      appliedCoupon: null,
      couponError:
        coupon.status === 'Scheduled'
          ? 'Applied coupon is not active yet.'
          : 'Applied coupon has expired.',
    };
  }

  if (!matchesCouponCategory(coupon, normalizedItems)) {
    return {
      itemsTotal,
      gstAmount,
      totalBeforeDiscount,
      deliveryCharge,
      couponDiscount: 0,
      grandTotal: roundCurrency(totalBeforeDiscount + deliveryCharge),
      hasValidItems,
      appliedCoupon: null,
      couponError: 'Applied coupon no longer matches your cart category.',
    };
  }

  const minimumOrderAmount = sanitizeNumber(coupon.minimumOrderAmount, 0);
  if (itemsTotal < minimumOrderAmount) {
    return {
      itemsTotal,
      gstAmount,
      totalBeforeDiscount,
      deliveryCharge,
      couponDiscount: 0,
      grandTotal: roundCurrency(totalBeforeDiscount + deliveryCharge),
      hasValidItems,
      appliedCoupon: null,
      couponError: `Minimum order Rs. ${formatAmount(minimumOrderAmount)} required.`,
    };
  }

  const couponDiscount = calculateCouponDiscountAmount(
    coupon,
    itemsTotal,
    totalBeforeDiscount
  );

  return {
    itemsTotal,
    gstAmount,
    totalBeforeDiscount,
    deliveryCharge,
    couponDiscount,
    grandTotal: roundCurrency(totalBeforeDiscount + deliveryCharge - couponDiscount),
    hasValidItems,
    appliedCoupon: {
      id: coupon.id,
      code: coupon.code,
      title: coupon.title,
      description: coupon.description,
      category: coupon.category,
      discountType: coupon.discountType,
      discountValue: coupon.discountValue,
      minimumOrderAmount,
      discountAmount: couponDiscount,
    },
    couponError: null,
  };
};
