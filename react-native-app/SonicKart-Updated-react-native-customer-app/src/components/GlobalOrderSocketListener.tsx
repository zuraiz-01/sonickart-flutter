import React, { useEffect, useRef } from 'react';
import { SOCKET_URL } from '@service/config';
import { getOrderById } from '@service/orderService';
import { useAuthStore } from '@state/authStore';
import io from 'socket.io-client';

/**
 * Global socket listener for order updates
 * This component listens for order status updates across all pages
 * and automatically updates currentOrder when orders are delivered/cancelled
 */
const GlobalOrderSocketListener: React.FC = () => {
  const { currentOrder, setCurrentOrder, user } = useAuthStore();
  const socketRef = useRef<any>(null);

  useEffect(() => {
    // Only set up socket if user is logged in and has a currentOrder
    if (!user || !currentOrder) {
      // Clean up socket if no currentOrder
      if (socketRef.current) {
        socketRef.current.disconnect();
        socketRef.current = null;
      }
      return;
    }

    // Don't set up socket for package orders (they have their own listeners)
    const isPackageOrder =
      currentOrder?.orderType === 'package' ||
      (currentOrder?.id && String(currentOrder.id).startsWith('PKG')) ||
      (currentOrder?.orderNumber && String(currentOrder.orderNumber).startsWith('PKG'));

    if (isPackageOrder) {
      return;
    }

    // Set up socket connection
    const socketInstance = io(SOCKET_URL, {
      transports: ['websocket'],
      withCredentials: false,
    });

    socketRef.current = socketInstance;

    const orderId =
      currentOrder?.id ||
      currentOrder?._id ||
      currentOrder?.orderId ||
      currentOrder?.orderNumber;

    if (orderId) {
      // Join order room to receive updates
      socketInstance.emit('joinRoom', String(orderId));

      // Also join user room for customer-specific updates
      const userId = user?.id || user?._id;
      if (userId) {
        socketInstance.emit('joinRoom', `user-${userId}`);
      }

      // Listen for live tracking updates (order status changes)
      socketInstance.on('liveTrackingUpdates', async (updatedOrder?: any) => {
        try {
          // If updatedOrder is provided, use it directly
          if (updatedOrder) {
            setCurrentOrder(updatedOrder);

            // Check if order is delivered/cancelled and clear it
            const status = (
              updatedOrder?.deliveryStatus ||
              updatedOrder?.delivery_status ||
              updatedOrder?.status ||
              ''
            ).toLowerCase();

            if (status === 'delivered' || status === 'cancelled') {
              // Small delay to ensure UI updates, then clear
              setTimeout(() => {
                setCurrentOrder(null);
              }, 500);
            }
          } else {
            // If no order data provided, fetch latest from server
            const latestOrder = await getOrderById(String(orderId));
            if (latestOrder) {
              setCurrentOrder(latestOrder);

              const status = (
                latestOrder?.deliveryStatus ||
                latestOrder?.delivery_status ||
                latestOrder?.status ||
                ''
              ).toLowerCase();

              if (status === 'delivered' || status === 'cancelled') {
                setTimeout(() => {
                  setCurrentOrder(null);
                }, 500);
              }
            }
          }
        } catch (error) {
          console.log('Error handling liveTrackingUpdates:', error);
        }
      });

      // Listen for order confirmed updates
      socketInstance.on('orderConfirmed', async () => {
        try {
          const latestOrder = await getOrderById(String(orderId));
          if (latestOrder) {
            setCurrentOrder(latestOrder);
          }
        } catch (error) {
          console.log('Error handling orderConfirmed:', error);
        }
      });

      // Listen for order created (new order)
      socketInstance.on('orderCreated', (newOrder: any) => {
        // Update currentOrder if this is the user's order
        const currentUserId = user?.id || user?._id;
        const orderUserId = newOrder?.customerId || newOrder?.userId;
        if (currentUserId && String(orderUserId) === String(currentUserId)) {
          setCurrentOrder(newOrder);
        }
      });
    }

    // Cleanup function
    return () => {
      if (socketRef.current) {
        socketRef.current.disconnect();
        socketRef.current = null;
      }
    };
  }, [currentOrder, user, setCurrentOrder]);

  // This component doesn't render anything
  return null;
};

export default GlobalOrderSocketListener;
