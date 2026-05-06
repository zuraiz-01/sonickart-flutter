/**
 * Order calculation utilities
 */

import type { CouponDocument } from '@service/couponService';
import { calculateCheckoutTotals } from './checkoutTotals';

type CartItem = Parameters<typeof calculateCheckoutTotals>[0][number];

/**
 * Calculate order breakdown for database storage
 */
export const calculateOrderBreakdown = (
  cart: CartItem[],
  paymentMode: string = 'COD',
  coupon?: CouponDocument | null
) => {
  const checkoutTotals = calculateCheckoutTotals(cart, coupon);

  return {
    subtotal: checkoutTotals.grandTotal,
    deliveryFee: checkoutTotals.deliveryCharge,
    taxAmount: checkoutTotals.gstAmount,
    paymentMode,
    itemsTotal: checkoutTotals.itemsTotal,
    totalWithGst: checkoutTotals.totalBeforeDiscount,
    couponId: checkoutTotals.appliedCoupon?.id,
    couponCode: checkoutTotals.appliedCoupon?.code,
    couponDiscount: checkoutTotals.couponDiscount,
    discountAmount: checkoutTotals.couponDiscount,
    discountType: checkoutTotals.appliedCoupon?.discountType,
  };
};
