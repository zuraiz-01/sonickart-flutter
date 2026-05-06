// import { create } from 'zustand';
// import { persist, createJSONStorage } from 'zustand/middleware';
// import { mmkvStorage } from './storage';

// interface CartItem {
//   _id: string | number;
//   item: any;
//   count: number;
// }

// interface CartStore {
//   cart: CartItem[];
//   addItem: (item: any) => void;
//   removeItem: (id: string | number) => void;
//   clearCart: () => void;
//   getItemCount: (id: string | number) => number;
//   getTotalPrice: () => number;
// }

// export const useCartStore = create<CartStore>()(
//   persist(
//     (set, get) => ({
//       cart: [],

//       addItem: (item) => {
//         const currentCart = get().cart;
//         const existingItemIndex = currentCart.findIndex(
//           (cartItem) => cartItem?._id === item?._id
//         );
//         //WHEN ITEM EXIST
//         if (existingItemIndex >= 0) {
//           const updatedCart = [...currentCart];
//           updatedCart[existingItemIndex] = {
//             ...updatedCart[existingItemIndex],
//             count: updatedCart[existingItemIndex].count + 1,
//           };
//           set({ cart: updatedCart });
//         } else {
//           set({
//             cart: [...currentCart, { _id: item._id, item: item, count: 1 }],
//           });
//         }
//       },

//       clearCart: () => set({ cart: [] }),
//       removeItem: (id) => {
//         const currentCart = get().cart;
//         const existingItemIndex = currentCart.findIndex(
//           (cartItem) => cartItem?._id === id
//         );

//         if (existingItemIndex >= 0) {
//           const updatedCart = [...currentCart];
//           const existingItem = updatedCart[existingItemIndex];

//           if (existingItem.count > 1) {
//             updatedCart[existingItemIndex] = {
//               ...existingItem,
//               count: existingItem?.count - 1,
//             };
//           } else {
//             updatedCart.splice(existingItemIndex, 1);
//           }

//           set({ cart: updatedCart });
//         }
//       },

//       getItemCount: (id) => {
//         const currentItem = get().cart.find((cartItem) => cartItem._id === id);
//         return currentItem ? currentItem?.count : 0;
//       },

//       getTotalPrice: () => {
//         return get().cart.reduce(
//           (total, cartItem) => total + cartItem.item.price * cartItem.count,
//           0
//         );
//       },
//     }),
//     {
//       name: 'cart-storage',
//       storage: createJSONStorage(() => mmkvStorage),
//     }
//   )
// );

import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { mmkvStorage } from './storage';
import {
  addToCart,
  removeFromCart,
  fetchCart,
  applyCoupon,
  clearCartOnServer,
} from '../service/cartService';
import { resolveDisplayPriceWithGst } from '@utils/productPricing';

/**
 * Cart store.
 * Keeps local cart in sync with backend and exposes reusable cart selectors/actions.
 */
interface CartItem {
  _id: string | number;
  id?: string | number;
  item: any;
  count: number;
  vendorId?: string | number;
  vendor_id?: string | number;
  branchId?: string | number;
  branch_id?: string | number;
}

interface CartStore {
  cart: CartItem[];
  fetchCartFromServer: () => Promise<void>;
  addItem: (item: any) => Promise<void>;
  removeItem: (id: string | number) => Promise<void>;
  removeItemsCompletely: (ids: Array<string | number>) => Promise<void>;
  clearCart: () => Promise<void>;
  getItemCount: (id: string | number) => number;
  getTotalPrice: () => number;
  applyCouponToCart: (cartId: string, code: string) => Promise<any>;
}

export const useCartStore = create<CartStore>()(
  persist(
    (set, get) => ({
      cart: [],

      // Fetch cart from backend and update local state
      fetchCartFromServer: async () => {
        const res = await fetchCart();
        if (res?.status === 'success' && res?.items) {
          const currentCart = get().cart;
          const mapped = res.items.map((i: any) => {
            const product = i.product || {};
            const productId = product?.id || product?._id || i.productId;
            const existingItem = currentCart.find(
              (cartItem) => String(cartItem?._id) === String(productId)
            );
            const existingProduct = existingItem?.item || {};
            const normalizedProduct = {
              ...existingProduct,
              ...product,
              vendorId:
                product?.vendorId ||
                product?.vendor_id ||
                product?.vendor?.id ||
                product?.vendor?.vendorId ||
                i?.vendorId ||
                i?.vendor_id ||
                i?.vendor?.id ||
                i?.vendor?.vendorId ||
                existingProduct?.vendorId ||
                existingProduct?.vendor_id,
              vendor_id:
                product?.vendor_id ||
                product?.vendorId ||
                i?.vendor_id ||
                i?.vendorId ||
                existingProduct?.vendor_id ||
                existingProduct?.vendorId,
              vendor:
                product?.vendor ||
                i?.vendor ||
                existingProduct?.vendor,
              branchId:
                product?.branchId ||
                product?.branch_id ||
                product?.branch?.id ||
                product?.branch?.branchId ||
                i?.branchId ||
                i?.branch_id ||
                i?.branch?.id ||
                i?.branch?.branchId ||
                existingProduct?.branchId ||
                existingProduct?.branch_id,
              branch_id:
                product?.branch_id ||
                product?.branchId ||
                i?.branch_id ||
                i?.branchId ||
                existingProduct?.branch_id ||
                existingProduct?.branchId,
              branch:
                product?.branch ||
                i?.branch ||
                existingProduct?.branch,
              image:
                product?.image ||
                product?.imageUrl ||
                product?.images?.[0] ||
                product?.thumbnail ||
                product?.primaryImage ||
                product?.media?.[0] ||
                existingProduct?.image,
            };
            return {
              _id: productId,
              item: normalizedProduct,
              count: i.quantity,
              vendorId:
                normalizedProduct?.vendorId ||
                normalizedProduct?.vendor_id ||
                normalizedProduct?.vendor?.id ||
                normalizedProduct?.vendor?.vendorId,
              vendor_id:
                normalizedProduct?.vendor_id ||
                normalizedProduct?.vendorId,
              branchId:
                normalizedProduct?.branchId ||
                normalizedProduct?.branch_id ||
                normalizedProduct?.branch?.id ||
                normalizedProduct?.branch?.branchId,
              branch_id:
                normalizedProduct?.branch_id ||
                normalizedProduct?.branchId,
            };
          });
          set({ cart: mapped });
        }
      },

      // Add to cart + backend call
      addItem: async (item) => {
        // Use id if available, fallback to _id for backward compatibility
        const productId = item.id || item._id;
        if (!productId) {
          console.error('Product ID not found:', item);
          return;
        }

        const res = await addToCart(String(productId), 1);
        if (res?.status === 'success') {
          const currentCart = get().cart;
          const itemId = productId;
          const existingItemIndex = currentCart.findIndex(
            (cartItem) => String(cartItem?._id) === String(itemId)
          );

          if (existingItemIndex >= 0) {
            const updatedCart = [...currentCart];
            updatedCart[existingItemIndex].count += 1;
            set({ cart: updatedCart });
          } else {
            set({
              cart: [
                ...currentCart,
                {
                  _id: itemId,
                  item: item,
                  count: 1,
                  vendorId:
                    item?.vendorId ||
                    item?.vendor_id ||
                    item?.vendor?.id ||
                    item?.vendor?.vendorId,
                  vendor_id:
                    item?.vendor_id ||
                    item?.vendorId,
                  branchId:
                    item?.branchId ||
                    item?.branch_id ||
                    item?.branch?.id ||
                    item?.branch?.branchId,
                  branch_id:
                    item?.branch_id ||
                    item?.branchId,
                },
              ],
            });
          }
        }
      },

      // Remove from cart + backend call
      removeItem: async (id) => {
        const currentCart = get().cart;
        const existingItemIndex = currentCart.findIndex(
          (cartItem) => cartItem?._id === id
        );

        if (existingItemIndex >= 0) {
          const updatedCart = [...currentCart];
          const existingItem = updatedCart[existingItemIndex];

          if (existingItem.count > 1) {
            updatedCart[existingItemIndex].count -= 1;
            set({ cart: updatedCart });
          } else {
            updatedCart.splice(existingItemIndex, 1);
            set({ cart: updatedCart });
          }

          // 🛠 Send remove to backend regardless of quantity
          await removeFromCart(String(id));
        }
      },

      removeItemsCompletely: async (ids) => {
        const normalizedIds = [
          ...new Set(
            ids
              .map((id) => String(id ?? '').trim())
              .filter(Boolean)
          ),
        ];

        if (!normalizedIds.length) {
          return;
        }

        const currentCart = get().cart;
        set({
          cart: currentCart.filter(
            (cartItem) => {
              const cartItemIds = [
                cartItem?._id,
                cartItem?.id,
                cartItem?.item?.id,
                cartItem?.item?._id,
                cartItem?.item?.productId,
              ]
                .map((value) => String(value ?? '').trim())
                .filter(Boolean);

              return !cartItemIds.some((id) => normalizedIds.includes(id));
            }
          ),
        });

        await Promise.all(
          normalizedIds.map((id) => removeFromCart(id))
        );
      },

      // Clear local cart only (could also hit a backend endpoint if needed)
      clearCart: async () => {
        try {
          const res = await clearCartOnServer();
          if (res?.status === 'success') {
            set({ cart: [] });
          } else {
            await get().fetchCartFromServer();
          }
        } catch (error) {
          console.log('Clear cart failed', error);
          await get().fetchCartFromServer();
        }
      },

      // Selector for item count
      getItemCount: (id) => {
        const currentItem = get().cart.find((cartItem) => cartItem._id === id);
        return currentItem ? currentItem.count : 0;
      },

      // Selector for total price
      getTotalPrice: () => {
        return get().cart.reduce((total, cartItem) => {
          const unitPrice = resolveDisplayPriceWithGst(cartItem);
          return total + unitPrice * cartItem.count;
        }, 0);
      },

      // Optional coupon support
      applyCouponToCart: async (cartId: string, code: string) => {
        const res = await applyCoupon(cartId, code);
        return res;
      },
    }),
    {
      name: 'cart-storage',
      storage: createJSONStorage(() => mmkvStorage),
    }
  )
);
