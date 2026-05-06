import { appAxios } from './apiInterceptors';

/**
 * Cart API helpers.
 * Encapsulates all server operations for cart mutation and retrieval.
 */
// Add or Update item in cart
export const addToCart = async (productId: string, quantity: number = 1) => {
  try {
    const response = await appAxios.post('/cart/add', {
      productId,
      quantity,
    });
    return response.data;
  } catch (error: any) {
    // Only log if it's not a 404 (product not found) or 401 (unauthorized)
    if (error?.response?.status !== 404 && error?.response?.status !== 401) {
      console.error('Add to Cart Error:', error?.response?.data || error?.message);
    }
    return null;
  }
};

// Remove item from cart
export const removeFromCart = async (productId: string) => {
  try {
    const response = await appAxios.delete('/cart/remove', {
      data: { productId },
    });
    return response.data;
  } catch (error) {
    console.log('Remove from Cart Error:', error);
    return null;
  }
};

// Clear entire cart for user
export const clearCartOnServer = async () => {
  try {
    const response = await appAxios.delete('/cart/clear');
    return response.data;
  } catch (error: any) {
    if (error?.response?.status === 404) {
      try {
        const response = await appAxios.post('/cart/clear');
        return response.data;
      } catch (postError) {
        console.log('Clear Cart POST fallback error:', postError);
        return null;
      }
    }
    console.log('Clear Cart Error:', error);
    return null;
  }
};

// Fetch full cart for user
export const fetchCart = async () => {
  try {
    const response = await appAxios.get('/cart/fetch');
    return response.data;
  } catch (error) {
    console.log('Fetch Cart Error:', error);
    return null;
  }
};

// Apply coupon to cart
export const applyCoupon = async (cartId: string, couponCode: string) => {
  try {
    const response = await appAxios.post('/cart/apply-coupon', {
      cartId,
      couponCode,
    });
    return response.data;
  } catch (error) {
    console.log('Apply Coupon Error:', error);
    return null;
  }
};
