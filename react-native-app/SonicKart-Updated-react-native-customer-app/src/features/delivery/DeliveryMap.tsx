import { View, StyleSheet, ScrollView, Alert } from 'react-native';
import React, { FC, useCallback, useEffect, useMemo, useState } from 'react';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useAuthStore } from '@state/authStore';
import { confirmOrder, getOrderById, sendLiveOrderUpdates, acceptPackageOrder, updatePackageOrderStatus } from '@service/orderService';
import type { PackageOrderStatus } from '../../types/packageOrder';
import { Colors } from '@utils/Constants';
import { useRoute } from '@react-navigation/native';
import Geolocation from '@react-native-community/geolocation';
import LiveHeader from '@features/map/LiveHeader';
import LiveMap from '@features/map/LiveMap';
import DeliveryDetails from '@features/map/DeliveryDetails';
import OrderSummary from '@features/map/OrderSummary';
import { hocStyles } from '@styles/GlobalStyles';
import CustomButton from '@components/ui/CustomButton';
import colors from '../../theme/colors';

const DeliveryMap: FC = () => {
    const user = useAuthStore(state => state.user);
    const [orderData, setOrderData] = useState<any>(null);
    const [myLocation, setMyLocation] = useState<any>(null);
    const route = useRoute();

    const orderDetails = route?.params as Record<string, any>;
    const resolveOrderId = (data?: any) =>
        data?.id || data?.orderNumber || data?._id || data?.orderId;
    const resolveUserId = (data?: any) => data?.id || data?._id;
    const { setCurrentOrder } = useAuthStore();
    const isPackageOrder = orderData?.orderType === 'package' || orderData?.packageType;

    const deliveryDetails = useMemo(() => {
        if (!orderData) {return null;}
        const location = isPackageOrder ? orderData?.dropLocation : orderData?.deliveryLocation;
        const customer = orderData?.customer || {};
        const partner = orderData?.deliveryPartner || {};
        return {
            addressLabel:
                location?.label ||
                location?.tag ||
                (location?.address ? (isPackageOrder ? 'Drop Address' : 'Delivery Address') : customer?.address ? 'Delivery at Home' : undefined),
            address:
                location?.address ||
                customer?.address ||
                orderData?.customerAddress ||
                orderData?.shippingAddress ||
                null,
            name:
                location?.fullName ||
                location?.name ||
                customer?.name ||
                orderData?.customerName ||
                null,
            phone:
                location?.contactNumber ||
                customer?.phone ||
                orderData?.customerPhone ||
                null,
            partnerName:
                partner?.name ||
                partner?.fullName ||
                partner?.firstName ||
                partner?.lastName ||
                null,
            partnerPhone:
                partner?.phone ||
                partner?.contactNumber ||
                partner?.mobile ||
                partner?.phoneNumber ||
                null,
        };
    }, [orderData, isPackageOrder]);

    const fetchOrderDetails = useCallback(async () => {
        const orderId = resolveOrderId(orderDetails);
        if (!orderId) {
            console.warn('DeliveryMap: Missing order id in route params');
            return;
        }
        try {
            const data = await getOrderById(String(orderId));
            setOrderData(data);
        } catch (error) {
            // silently ignore; header/buttons will just not have order details
        }
    }, [orderDetails]);

    useEffect(() => {
        fetchOrderDetails();
    }, [fetchOrderDetails]);

    useEffect(() => {
        const watchId = Geolocation.watchPosition(
            async (position) => {
                const { latitude, longitude } = position.coords;
                setMyLocation({ latitude, longitude });
            },
            () => {},
            { enableHighAccuracy: true, distanceFilter: 10 }
        );

        return () => {
            Geolocation.clearWatch(watchId);
        };
    }, []);


    const acceptOrder = async () => {
        const orderId = resolveOrderId(orderData);
        if (!orderId) {
            Alert.alert('Error', 'Invalid order data');
            return;
        }

        if (!myLocation && !isPackageOrder) {
            Alert.alert('Location Required', 'Please enable location services to accept orders');
            return;
        }

        try {
            let data;
            if (isPackageOrder) {
                // Extract numeric ID from PKG format
                const numericId = orderId.toString().replace('PKG', '');
                data = await acceptPackageOrder(numericId);
            } else {
                data = await confirmOrder(String(orderId), myLocation);
            }

            if (data) {
                setCurrentOrder(data);
                Alert.alert(
                    'Order Accepted',
                    isPackageOrder ? 'Package order accepted! Please proceed to pickup location.' : 'Grab your package',
                    [{ text: 'OK', onPress: () => fetchOrderDetails() }]
                );
            } else {
                Alert.alert('Error', 'Failed to accept order. Please try again.');
            }
        } catch (error: any) {
            const errorMessage = error?.message || error?.response?.data?.message || 'Failed to accept order';
            const errorCode = error?.code || error?.response?.data?.code;

            // Handle specific error codes
            if (errorCode === 'ORDER_ALREADY_ASSIGNED' || errorCode === 'CONFLICT') {
                Alert.alert(
                    'Order Already Assigned',
                    'This order has already been assigned to another delivery partner.',
                    [{ text: 'OK', onPress: () => fetchOrderDetails() }]
                );
            } else if (errorCode === 'PACKAGE_ORDER_NOT_FOUND') {
                Alert.alert('Order Not Found', 'The package order could not be found.');
            } else {
                Alert.alert('Error', errorMessage);
            }
            fetchOrderDetails();
        }
    };

    const orderPickedUp = async () => {
        const orderId = resolveOrderId(orderData);
        if (!orderId) {
            Alert.alert('Error', 'Invalid order data');
            return;
        }

        if (!myLocation && !isPackageOrder) {
            Alert.alert('Location Required', 'Please enable location services');
            return;
        }

        try {
            let data;
            if (isPackageOrder) {
                // Extract numeric ID from PKG format
                const numericId = orderId.toString().replace('PKG', '');
                data = await updatePackageOrderStatus(numericId, 'picked' as PackageOrderStatus);
            } else {
                data = await sendLiveOrderUpdates(String(orderId), myLocation, 'arriving');
            }

            if (data) {
                setCurrentOrder(data);
                Alert.alert(
                    'Package Picked Up',
                    "Let's deliver it as soon as possible",
                    [{ text: 'OK' }]
                );
            } else {
                Alert.alert('Error', 'Failed to update order status. Please try again.');
            }
        } catch (error: any) {
            const errorMessage = error?.message || error?.response?.data?.message || 'Failed to update order status';
            const errorCode = error?.code || error?.response?.data?.code;

            if (errorCode === 'INVALID_STATUS_TRANSITION') {
                Alert.alert(
                    'Invalid Status',
                    error?.response?.data?.message || 'Cannot update order to this status',
                    [{ text: 'OK', onPress: () => fetchOrderDetails() }]
                );
            } else {
                Alert.alert('Error', errorMessage);
            }
            fetchOrderDetails();
        }
    };

    const orderDelivered = async () => {
        const orderId = resolveOrderId(orderData);
        if (!orderId) {
            Alert.alert('Error', 'Invalid order data');
            return;
        }

        if (!myLocation && !isPackageOrder) {
            Alert.alert('Location Required', 'Please enable location services');
            return;
        }

        // Confirm delivery
        Alert.alert(
            'Confirm Delivery',
            'Are you sure you have delivered this order?',
            [
                { text: 'Cancel', style: 'cancel' },
                {
                    text: 'Confirm',
                    style: 'default',
                    onPress: async () => {
                        try {
                            let data;
                            if (isPackageOrder) {
                                // Extract numeric ID from PKG format
                                const numericId = orderId.toString().replace('PKG', '');
                                data = await updatePackageOrderStatus(numericId, 'delivered' as PackageOrderStatus);
                            } else {
                                data = await sendLiveOrderUpdates(String(orderId), myLocation, 'delivered');
                            }

                            if (data) {
                                setCurrentOrder(null);
                                Alert.alert('Woohoo! You made it🥳', 'Order delivered successfully!');
                            } else {
                                Alert.alert('Error', 'Failed to update order status. Please try again.');
                            }
                        } catch (error: any) {
                            const errorMessage = error?.message || error?.response?.data?.message || 'Failed to update order status';
                            Alert.alert('Error', errorMessage);
                        }
                        fetchOrderDetails();
                    },
                },
            ]
        );
    };


    let message = 'Start this order';
    const deliveryPartnerId = resolveUserId(orderData?.deliveryPartner || orderData?.deliveryPartnerId);
    const userId = resolveUserId(user);
    const status = orderData?.status?.toLowerCase();

    if (isPackageOrder) {
        // Package order status messages
        if (status === 'pending' || status === 'available') {
            message = 'Accept Package Order';
        } else if (deliveryPartnerId === userId && status === 'assigned') {
            message = 'Pick up the package';
        } else if (deliveryPartnerId === userId && status === 'picked') {
            message = 'Deliver the package';
        } else if (deliveryPartnerId === userId && status === 'delivered') {
            message = 'Package delivered!';
        } else if (deliveryPartnerId && userId && deliveryPartnerId !== userId && status !== 'pending' && status !== 'available') {
            message = 'You missed it!';
        }
    } else {
        // Regular order status messages
        if (deliveryPartnerId === userId && status === 'confirmed') {
            message = 'Grab your order';
        } else if (deliveryPartnerId === userId && status === 'arriving') {
            message = 'Complete your order';
        }
        else if (deliveryPartnerId === userId && status === 'delivered') {
            message = 'Your milestone';
        }
        else if (deliveryPartnerId && userId && deliveryPartnerId !== userId && status !== 'available') {
            message = 'You missed it!';
        }
    }

    useEffect(() => {
        async function sendLiveUpdates() {
            if (!orderData) {
                return;
            }

            const orderId = resolveOrderId(orderData);
            const currentStatus = orderData?.status;

            if (!orderId) {
                // no order id; skip
                return;
            }

            if (!myLocation) {
                // no location yet; skip
                return;
            }

            if (deliveryPartnerId !== userId) {
                // not the assigned partner; skip
                return;
            }

            if (currentStatus === 'delivered' || currentStatus === 'cancelled') {
                // final status; skip
                return;
            }

            // Only send live updates for regular (non-package) orders here
            if (isPackageOrder) {
                // package orders handled via package APIs
                return;
            }

            try {
                await sendLiveOrderUpdates(String(orderId), myLocation, currentStatus);
            } catch (error) {
                // ignore client-side live update errors
            } finally {
                fetchOrderDetails();
            }
        }

        if (myLocation) {
            sendLiveUpdates();
        }
    }, [myLocation, isPackageOrder, deliveryPartnerId, userId, orderData, fetchOrderDetails]);



    return (
        <SafeAreaView style={{ flex: 1 }} edges={['top']}>
            <View style={styles.container}>
                <LiveHeader type="Delivery" title={message} secondTitle="Delivery in 10 minutes" />
            <ScrollView
                showsVerticalScrollIndicator={false}
                contentContainerStyle={styles.scrollContent}>

                <LiveMap
                    deliveryPersonLocation={orderData?.deliveryPersonLocation || myLocation}
                    deliveryLocation={isPackageOrder ? orderData?.dropLocation : orderData?.deliveryLocation || null}
                    hasAccepted={deliveryPartnerId === userId && (orderData?.status === 'confirmed' || orderData?.status === 'assigned')}
                    hasPickedUp={orderData?.status === 'arriving' || orderData?.status === 'picked'}
                    pickupLocation={isPackageOrder ? orderData?.pickupLocation : orderData?.pickupLocation || null}
                />

                <DeliveryDetails details={deliveryDetails} />
                <OrderSummary order={orderData} />
            </ScrollView>

            {orderData?.status !== 'delivered' && orderData?.status !== 'cancelled' &&
                <View style={[hocStyles.cartContainer, styles.btnContainer]}>
                    {(orderData?.status === 'available' || orderData?.status === 'pending') &&
                        <CustomButton
                            disabled={false}
                            title={isPackageOrder ? 'Accept Package Order' : 'Accept Order'}
                            onPress={acceptOrder}
                            loading={false}
                        />
                    }
                    {(orderData?.status === 'confirmed' || orderData?.status === 'assigned') &&
                        deliveryPartnerId === userId &&
                        <CustomButton
                            disabled={false}
                            title={isPackageOrder ? 'Package Picked Up' : 'Order Picked Up'}
                            onPress={orderPickedUp}
                            loading={false}
                        />
                    }

                    {(orderData?.status === 'arriving' || orderData?.status === 'picked') &&
                        deliveryPartnerId === userId &&
                        <CustomButton
                            disabled={false}
                            title="Delivered"
                            onPress={orderDelivered}
                            loading={false}
                        />
                    }
                </View>
            }






        </View>
        </SafeAreaView>
    );
};

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: Colors.primary,
    },
    btnContainer: {
        padding: 10,
    },
    scrollContent: {
        paddingBottom: 150,
        backgroundColor: colors.white,
        padding: 15,
    },
    flexRow: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 10,
        width: '100%',
        borderRadius: 15,
        marginTop: 15,
        paddingVertical: 10,
        backgroundColor: colors.white,
        padding: 10,
        borderBottomWidth: 0.7,
        borderColor: Colors.border,
    },
    iconContainer: {
        backgroundColor: Colors.backgroundSecondary,
        borderRadius: 100,
        padding: 10,
        justifyContent: 'center',
        alignItems: 'center',
    },
});

export default DeliveryMap;
