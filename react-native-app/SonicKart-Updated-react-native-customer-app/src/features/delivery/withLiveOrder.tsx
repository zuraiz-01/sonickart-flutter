
import CustomText from '@components/ui/CustomText';
import Geolocation from '@react-native-community/geolocation';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { sendLiveOrderUpdates } from '@service/orderService';
import { useAuthStore } from '@state/authStore';
import { hocStyles } from '@styles/GlobalStyles';
import { Colors, Fonts } from '@utils/Constants';
import React, { FC, useEffect, useState } from 'react';
import { View, StyleSheet, Image, TouchableOpacity } from 'react-native';


const withLiveOrder = <P extends object>(WrappedComponent: React.ComponentType<P>): FC<P> => {
    const WithLiveOrder: FC<P> = (props) => {
        const insets = useSafeAreaInsets();
        const { currentOrder } = useAuthStore();
        const user = useAuthStore(state => state.user);
        const [myLocation, setMyLocation] = useState<any>(null);

        const resolveOrderId = (order?: any) =>
            order?.id || order?.orderNumber || order?._id || order?.orderId;
        const resolveUserId = (entity?: any) => entity?.id || entity?._id;

        // Watch delivery partner location when there is an active currentOrder
        useEffect(() => {
            if (currentOrder) {
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
            }
        }, [currentOrder]);

        // Send live updates to server whenever myLocation changes
        useEffect(() => {
            async function sendLiveUpdates() {
                if (!currentOrder) {
                    return;
                }

                const deliveryPartnerId = resolveUserId(currentOrder?.deliveryPartner);
                const userId = resolveUserId(user);
                const orderId = resolveOrderId(currentOrder);
                const status = currentOrder?.status;

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

                if (status === 'delivered' || status === 'cancelled') {
                    // final status; skip
                    return;
                }

                try {
                    await sendLiveOrderUpdates(String(orderId), myLocation, status);
                } catch (error) {
                    // ignore client-side send errors
                }
            }

            // Only attempt when we have a location
            if (myLocation) {
                sendLiveUpdates();
            }
        }, [myLocation, currentOrder, user]);

        return (
            <View style={styles.container}>
                <WrappedComponent {...props} />
                {currentOrder && (
                    <View style={[hocStyles.cartContainer, { bottom: 120 + insets.bottom, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20 }]}>
                        <View style={styles.flexRow}>
                            <View style={styles.img}>
                                <Image source={require('../../assets/icons/bucket.png')} style={{ width: 20, height: 20 }} />
                            </View>
                            <View style={{ width: '65%' }}>
                                <CustomText variant="h6" fontFamily={Fonts.SemiBold}>#{currentOrder?.orderId}</CustomText>
                                <CustomText variant="h9" fontFamily={Fonts.Medium}>{currentOrder?.deliveryLocation?.address} </CustomText>
                            </View>
                        </View>
                        <TouchableOpacity onPress={() => {
                            // navigate('DeliveryMap', {
                            //     ...currentOrder
                            // }) // Commented out delivery map navigation
                        }} style={styles.btn}>
                            <CustomText variant="h8" style={{ color: Colors.secondary }} fontFamily={Fonts.Medium}>Continue</CustomText>
                        </TouchableOpacity>
                    </View>
                )}
            </View>
        );
    };

    return WithLiveOrder;
};

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    flexRow: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 10,
        borderRadius: 15,
        marginBottom: 15,
        paddingVertical: 10,
        padding: 10,
    },
    img: {
        backgroundColor: Colors.backgroundSecondary,
        borderRadius: 100,
        padding: 10,
        justifyContent: 'center',
        alignItems: 'center',
    },
    btn: {
        paddingHorizontal: 10,
        paddingVertical: 2,
        borderWidth: 0.7,
        borderColor: Colors.secondary,
        borderRadius: 5,
    },
});

export default withLiveOrder;
