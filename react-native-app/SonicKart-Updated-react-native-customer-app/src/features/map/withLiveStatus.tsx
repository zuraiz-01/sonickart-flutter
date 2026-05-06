import { SOCKET_URL } from '@service/config';
import { getOrderById } from '@service/orderService';
import { getPackageOrderById } from '@service/packageService';
import { useAuthStore } from '@state/authStore';
import React, { FC, useEffect } from 'react';
import { StyleSheet, View } from 'react-native';
import io from 'socket.io-client';

/**
 * HOC that attaches socket listeners for live status refresh.
 * Keeps `currentOrder` in sync while wrapped screen is mounted.
 */
const withLiveStatus = <P extends object>(
  WrappedComponent: React.ComponentType<P>
): FC<P> => {
  const WithLiveStatusComponent: FC<P> = (props) => {
    const { currentOrder, setCurrentOrder } = useAuthStore();
    const resolveOrderId = (order: any = currentOrder) =>
      order?.id ||
      order?._id ||
      order?.orderId ||
      order?.orderNumber;

    const toOrderKey = (value: unknown): string | null => {
      if (value === null || value === undefined) {return null;}
      const raw = String(value).trim();
      if (!raw) {return null;}
      const upper = raw.toUpperCase();
      if (upper.startsWith('PKG')) {
        return upper.replace(/^PKG/, '');
      }
      return upper;
    };

    const isPackageOrder = (order: any = currentOrder) => {
      const orderId = resolveOrderId(order);
      return (
        order?.orderType === 'package' ||
        Boolean(order?.packageType) ||
        (orderId && String(orderId).toUpperCase().startsWith('PKG'))
      );
    };

    const isSameOrder = (incomingOrder: any) => {
      if (!incomingOrder || !currentOrder) {return false;}
      const currentIds = [
        resolveOrderId(currentOrder),
        currentOrder?.id,
        currentOrder?.orderNumber,
        currentOrder?._id,
        currentOrder?.orderId,
      ]
        .map(toOrderKey)
        .filter(Boolean) as string[];

      const incomingIds = [
        resolveOrderId(incomingOrder),
        incomingOrder?.id,
        incomingOrder?.orderNumber,
        incomingOrder?._id,
        incomingOrder?.orderId,
      ]
        .map(toOrderKey)
        .filter(Boolean) as string[];

      if (currentIds.length === 0 || incomingIds.length === 0) {return false;}
      return incomingIds.some((id) => currentIds.includes(id));
    };

    const fetchOrderDetails = async () => {
      const orderId = resolveOrderId();
      if (!orderId) {
        // no order id; skip
        return;
      }

      const packageOrder = isPackageOrder();

      const normalizedId = String(orderId).replace(/^PKG/i, '');

      const data = packageOrder
        ? await getPackageOrderById(normalizedId)
        : await getOrderById(String(orderId));

      if (data) {
        setCurrentOrder(data);
      }
    };

    useEffect(() => {
      if (currentOrder) {
        const socketInstance = io(SOCKET_URL, {
          transports: ['websocket'],
          withCredentials: false,
        });
        const orderRoomId = resolveOrderId();
        const packageOrder = isPackageOrder(currentOrder);

        if (orderRoomId) {
          socketInstance.emit('joinRoom', orderRoomId);
          // Join package-specific room if it's a package order
          if (packageOrder) {
            const numericId = String(orderRoomId).replace(/^PKG/i, '');
            socketInstance.emit('joinRoom', `package-${numericId}`);
            // Also join user room for package updates
            const userId = currentOrder?.userId || currentOrder?.customerId;
            if (userId) {
              socketInstance.emit('joinRoom', `user-${userId}`);
            }
          }
        }

        socketInstance.on('liveTrackingUpdates', (updatedOrder) => {
          if (updatedOrder && !isSameOrder(updatedOrder)) {
            return;
          }
          fetchOrderDetails();
        });

        socketInstance.on('orderConfirmed', (updatedOrder) => {
          if (updatedOrder && !isSameOrder(updatedOrder)) {
            return;
          }
          fetchOrderDetails();
        });

        // Listen for package order status updates
        socketInstance.on('packageOrderStatusUpdated', (updatedOrder) => {
          if (!isSameOrder(updatedOrder)) {
            return;
          }
          fetchOrderDetails();
        });

        socketInstance.on('packageOrderAssigned', (updatedOrder) => {
          if (!isSameOrder(updatedOrder)) {
            return;
          }
          fetchOrderDetails();
        });

        return () => {
          socketInstance.disconnect();
        };
      }
      // Keep subscription scoped to current order object changes.
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [currentOrder]);

    return (
      <View style={styles.container}>
        <WrappedComponent {...props} />
      </View>
    );
  };

  return WithLiveStatusComponent;
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});

export default withLiveStatus;
