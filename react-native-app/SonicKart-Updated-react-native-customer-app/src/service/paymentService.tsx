import { appAxios } from './apiInterceptors';

/**
 * Payment service wrapper for Razorpay flow.
 * - Creates payment order.
 * - Verifies payment signature after checkout success.
 */
// Create Razorpay Order
export const createPaymentOrder = async (
  amount: number,
  currency: string = 'INR'
) => {
  try {
    const response = await appAxios.post('/create-order', {
      amount,
      currency,
    });
    return response.data;
  } catch (error) {
    console.log('Create Payment Order Error:', error);
    return null;
  }
};

// Verify Razorpay Payment
export const verifyPayment = async (
  razorpay_order_id: string,
  razorpay_payment_id: string,
  razorpay_signature: string
) => {
  try {
    const response = await appAxios.post('/verify-payment', {
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature,
    });
    return response.data;
  } catch (error) {
    console.log('Verify Payment Error:', error);
    return null;
  }
};
