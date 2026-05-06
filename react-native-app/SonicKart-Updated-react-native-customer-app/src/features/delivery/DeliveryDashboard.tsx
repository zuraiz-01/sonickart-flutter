import { View, StyleSheet, FlatList, RefreshControl, TouchableOpacity } from 'react-native';
import React, { FC, useEffect, useState, useCallback } from 'react';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Colors, Fonts } from '@utils/Constants';
import { useAuthStore } from '@state/authStore';
import { fetchOrders, fetchPackageOrders } from '@service/orderService';
import CustomText from '@components/ui/CustomText';
import OrderItem from '@components/delivery/OrderItem';
import Geolocation from '@react-native-community/geolocation';
import { reverseGeocode } from '@service/mapService';
import withLiveOrder from './withLiveOrder';
import io from 'socket.io-client';
import { SOCKET_URL } from '@service/config';
import Ionicons from 'react-native-vector-icons/Ionicons';
import { navigate } from '@utils/NavigationUtils';
import colors from '../../theme/colors';

const DeliveryDashboard: FC = () => {
  const { user, setUser } = useAuthStore();
  const [selectedTab] = useState<'available' | 'delivered'>('available');
  const [, setLoading] = useState(true);
  const [data, setData] = useState<any[]>([]);
  const [refreshing, setRefreshing] = useState(false);


  const updateUser = useCallback(() => {
    Geolocation.getCurrentPosition(
      position => {
        const { latitude, longitude } = position.coords;
        reverseGeocode(latitude, longitude, setUser);
      },
      err => console.log(err),
      {
        enableHighAccuracy: false,
        timeout: 15000,
      }
    );
  }, [setUser]);


  useEffect(() => {
    updateUser();
  }, [updateUser]);



  const renderOrderItem = ({ item, index }: any) => {
    return (
      <OrderItem index={index} item={item} />
    );
  };

  const fetchData = useCallback(async () => {
    setData([]);
    setRefreshing(true);
    setLoading(true);

    try {
      const userId = user?.id || user?._id;
      if (!userId) {
        setRefreshing(false);
        setLoading(false);
        return;
      }
      const branchId = user?.branch?.id || user?.branchId || user?.branch;

      // Fetch both regular orders and package orders in parallel
      const [regularOrders, packageOrders] = await Promise.allSettled([
        fetchOrders(selectedTab, String(userId), branchId),
        fetchPackageOrders(
          selectedTab === 'available' ? 'available' : 'delivered',
          String(userId),
          selectedTab === 'available' ? 'available' : 'delivery'
        ),
      ]);

      // Extract results, handling errors gracefully
      const regularOrdersData = regularOrders.status === 'fulfilled' ? (regularOrders.value || []) : [];
      const packageOrdersData = packageOrders.status === 'fulfilled' ? (packageOrders.value || []) : [];

      // Log errors if any
      if (regularOrders.status === 'rejected') {
        console.error('Failed to fetch regular orders:', regularOrders.reason);
      }
      if (packageOrders.status === 'rejected') {
        console.error('Failed to fetch package orders:', packageOrders.reason);
      }

      // Combine and sort by creation date (newest first)
      const combinedOrders = [...regularOrdersData, ...packageOrdersData].sort((a, b) => {
        const dateA = new Date(a.createdAt || a.created_at || 0).getTime();
        const dateB = new Date(b.createdAt || b.created_at || 0).getTime();
        return dateB - dateA;
      });

      setData(combinedOrders);
    } catch (error: any) {
      console.error('Error fetching orders:', error);
      // Don't show alert on every fetch, just log it
      setData([]);
    } finally {
      setRefreshing(false);
      setLoading(false);
    }
  }, [user, selectedTab]);


  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Socket.io integration for real-time order updates
  useEffect(() => {
    if (!user) {return;}

    const branchId = user?.branch?.id || user?.branchId || user?.branch;
    if (!branchId) {return;}

    const socketInstance = io(SOCKET_URL, {
      transports: ['websocket'],
      withCredentials: false,
    });

    // Join branch-specific room to receive new order notifications
    const branchRoom = `branch-${branchId}`;
    socketInstance.emit('joinRoom', branchRoom);
    console.log(`🔴 Delivery partner joined branch room: ${branchRoom}`);

    // Listen for new orders available in the branch
    socketInstance.on('newOrderAvailable', (newOrder) => {
      console.log('📦 New order available:', newOrder);
      // Only refresh if we're on the "available" tab
      if (selectedTab === 'available') {
        fetchData();
      }
    });

    // Listen for new package orders
    socketInstance.on('newPackageOrderAvailable', (newOrder) => {
      console.log('📦 New package order available:', newOrder);
      if (selectedTab === 'available') {
        fetchData();
      }
    });

    return () => {
      socketInstance.disconnect();
    };
  }, [user, selectedTab, fetchData]);



  return (
    <SafeAreaView style={{ flex: 1 }} edges={['top']}>
      <View style={styles.container}>
        <View style={styles.subContainer}>
        <TouchableOpacity
          activeOpacity={0.8}
          style={styles.homeCard}
          onPress={() => navigate('ProductDashboard')}
        >
          <View style={styles.homeCardContent}>
            <View style={styles.homeIconContainer}>
              <Ionicons name="home" size={24} color={colors.white} />
            </View>
            <CustomText variant="h6" fontFamily={Fonts.SemiBold} style={styles.homeCardText}>
              Home
            </CustomText>
          </View>
        </TouchableOpacity>

        <FlatList
          data={data}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={async () => await fetchData()}
            />
          }
          renderItem={renderOrderItem}
          keyExtractor={(item) => item.orderId || item.id || `order-${item.orderNumber}`}
          contentContainerStyle={styles.flatlistContaienr}
        />
      </View>
    </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: Colors.backgroundSecondary,
    flex: 1,
  },
  subContainer: {
    backgroundColor: Colors.backgroundSecondary,
    flex: 1,
    padding: 6,
  },
  homeCard: {
    backgroundColor: colors.white,
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    marginHorizontal: 6,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
    shadowColor: colors.black,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  homeCardContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  homeIconContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: Colors.secondary,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  homeCardText: {
    color: Colors.secondary,
    fontSize: 18,
  },
  flatlistContaienr: {
    padding: 2,
  },
  center: {
    flex: 1,
    marginTop: 60,
    justifyContent: 'center',
    alignItems: 'center',
  },
});

export default withLiveOrder(DeliveryDashboard);
