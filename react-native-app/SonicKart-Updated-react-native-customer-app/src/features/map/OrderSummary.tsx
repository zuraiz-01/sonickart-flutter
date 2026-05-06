import { View, StyleSheet } from 'react-native';
import React, { FC } from 'react';
import { Colors, Fonts } from '@utils/Constants';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import MaterialIcon from 'react-native-vector-icons/MaterialIcons';
import { RFValue } from 'react-native-responsive-fontsize';
import CustomText from '@components/ui/CustomText';
import colors from '../../theme/colors';

const OrderSummary: FC<{ order: any, iconColor?: string }> = ({ order, iconColor }) => {
    // Check if this is a package order - Commented out to prevent showing package info for regular orders
    // const isPackageOrder = useMemo(() => {
    //     return order?.orderType === 'package' ||
    //            (order?.orderId && String(order.orderId).startsWith('PKG')) ||
    //            (!order?.items || (Array.isArray(order.items) && order.items.length === 0 && order.deliveryCharge));
    // }, [order]);
    const isCancelled = order?.status?.toLowerCase() === 'cancelled';

    return (
        <View style={styles.container}>
            <View style={styles.flexRow}>
                <View style={styles.iconContainer}>
                    <Icon
                        name="shopping-outline"
                        color={iconColor || Colors.disabled}
                        size={RFValue(20)}
                    />
                </View>
                <View style={{ flex: 1 }}>
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                        <CustomText variant="h7" fontFamily={Fonts.SemiBold}>Order summary</CustomText>
                        {isCancelled && (
                            <View style={styles.cancelledBadge}>
                                <MaterialIcon name="cancel" size={RFValue(12)} color={colors.cancelled} />
                                <CustomText
                                    style={styles.cancelledText}
                                    fontFamily={Fonts.SemiBold}
                                    fontSize={10}
                                >
                                    Cancelled
                                </CustomText>
                            </View>
                        )}
                    </View>
                    <CustomText variant="h9" fontFamily={Fonts.Medium}>Order ID - #{order?.orderId}</CustomText>
                </View>
            </View>

            {/* Package order info - Commented out to prevent showing package info for regular orders */}
            {/* {isPackageOrder ? (
                <View style={styles.packageContainer}>
                    <View style={styles.packageInfoRow}>
                        <MaterialIcon name='inventory' size={RFValue(16)} color={Colors.disabled} />
                        <View style={styles.packageInfo}>
                            <CustomText variant='h9' fontFamily={Fonts.Medium} style={styles.packageLabel}>
                                Package Type
                            </CustomText>
                            <CustomText variant='h8' fontFamily={Fonts.SemiBold}>
                                {order?.packageType || 'N/A'}
                            </CustomText>
                        </View>
                    </View>
                    {order?.pickupLocation?.address && (
                        <View style={styles.packageInfoRow}>
                            <MaterialIcon name='location-on' size={RFValue(16)} color={Colors.disabled} />
                            <View style={styles.packageInfo}>
                                <CustomText variant='h9' fontFamily={Fonts.Medium} style={styles.packageLabel}>
                                    Pickup
                                </CustomText>
                                <CustomText variant='h9' numberOfLines={2}>
                                    {order.pickupLocation.address}
                                </CustomText>
                            </View>
                        </View>
                    )}
                    {order?.dropLocation?.address && (
                        <View style={styles.packageInfoRow}>
                            <MaterialIcon name='location-on' size={RFValue(16)} color={Colors.disabled} />
                            <View style={styles.packageInfo}>
                                <CustomText variant='h9' fontFamily={Fonts.Medium} style={styles.packageLabel}>
                                    Drop Off
                                </CustomText>
                                <CustomText variant='h9' numberOfLines={2}>
                                    {order.dropLocation.address}
                                </CustomText>
                            </View>
                        </View>
                    )}
                    {order?.distanceKm !== null && order?.distanceKm !== undefined && (
                        <View style={styles.packageInfoRow}>
                            <MaterialIcon name='straighten' size={RFValue(16)} color={Colors.disabled} />
                            <View style={styles.packageInfo}>
                                <CustomText variant='h9' fontFamily={Fonts.Medium} style={styles.packageLabel}>
                                    Distance
                                </CustomText>
                                <CustomText variant='h8' fontFamily={Fonts.SemiBold}>
                                    {order.distanceKm.toFixed(2)} km
                                </CustomText>
                            </View>
                        </View>
                    )}
                </View>
            ) : null} */}

        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        width: '100%',
        borderRadius: 15,
        marginTop: 15,
        marginBottom: 5, // Reduced bottom margin to bring items closer
        paddingVertical: 10,
        backgroundColor: colors.white,
    },
    iconContainer: {
        backgroundColor: Colors.backgroundSecondary,
        borderRadius: 100,
        padding: 10,
        justifyContent: 'center',
        alignItems: 'center',
    },
    flexRow: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 10,
        padding: 10,
        borderBottomWidth: 0.7,
        borderColor: Colors.border,
    },
    packageContainer: {
        padding: 10,
    },
    packageInfoRow: {
        flexDirection: 'row',
        alignItems: 'flex-start',
        gap: 10,
        paddingVertical: 8,
        borderBottomWidth: 0.7,
        borderColor: Colors.border,
    },
    packageInfo: {
        flex: 1,
    },
    packageLabel: {
        marginBottom: 4,
        opacity: 0.7,
    },
    cancelledBadge: {
        flexDirection: 'row',
        alignItems: 'center',
        backgroundColor: colors.lightRed,
        paddingHorizontal: 6,
        paddingVertical: 2,
        borderRadius: 4,
        gap: 4,
    },
    cancelledText: {
        color: colors.cancelled,
    },
});

export default OrderSummary;
