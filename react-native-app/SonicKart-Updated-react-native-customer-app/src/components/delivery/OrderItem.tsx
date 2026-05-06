import { View, StyleSheet, TouchableOpacity } from 'react-native';
import React, { FC } from 'react';
import { Colors, Fonts } from '@utils/Constants';
import CustomText from '@components/ui/CustomText';
import { RFValue } from 'react-native-responsive-fontsize';
import { formatISOToCustom } from '@utils/DateUtils';
import  Icon  from 'react-native-vector-icons/MaterialCommunityIcons';
import { navigate } from '@utils/NavigationUtils';
import { useAuthStore } from '@state/authStore';
import colors from '../../theme/colors';

interface CartItem {
    _id: string | number;
    item: any;
    count: number
}

interface Order {
    orderId: string;
    orderNumber?: string | number;
    id?: string | number;
    orderType?: 'package' | 'regular';
    order_type?: 'send' | 'receive' | 'package' | 'regular' | string;
    packageOrderType?: 'send' | 'receive'; // For package orders: send or receive
    items?: CartItem[];
    deliveryLocation?: any;
    pickupLocation?: any;
    dropLocation?: any;
    packageType?: string;
    totalPrice?: number;
    price?: number;
    distanceKm?: number;
    createdAt: string;
    created_at?: string;
    status: string;
}

function getStatusColor(status: string) {
    switch (status.toLowerCase()) {
        case 'available':
        case 'pending':
            return colors.success;
        case 'confirmed':
        case 'assigned':
            return colors.info;
        case 'delivered':
        case 'completed':
            return colors.cyan;
        case 'picked':
            return colors.warning || colors.accentYellow;
        case 'cancelled':
            return colors.danger;
        default:
            return colors.muted;
    }
}


const OrderItem: FC<{ item: Order; index: number }> = ({ item, index: _index }) => {
    const isPackageOrder = item.orderType === 'package' || item.packageType;
    const orderId = item.orderId || item.orderNumber || `#${item.id}`;
    const createdAt = item.createdAt || item.created_at;
    const deliveryAddress = item.deliveryLocation?.address || item.dropLocation?.address;
    const price = item.totalPrice || item.price || 0;
    const { setCurrentOrder } = useAuthStore();

    const handleNavigate = () => {
        if (isPackageOrder) {
            setCurrentOrder(item);
            navigate('PackageOrderDetails', {
                orderId: orderId,
                order: item,
            });
            return;
        }

        // navigate('DeliveryMap', {
        //     ...item
        // }); // Commented out delivery map navigation
    };

    // Get package order type (send or receive) - check multiple possible field names
    const packageOrderType = item.packageOrderType || item.order_type || (item.orderType === 'package' ? 'send' : null);
    const isReceivePackage = packageOrderType === 'receive';
    const isSendPackage = packageOrderType === 'send' || (isPackageOrder && !isReceivePackage);

    return (
        <View style={styles.container}>
            {/* Corner Tag for Send/Receive Package */}
            {isPackageOrder && (isSendPackage || isReceivePackage) && (
                <View style={[
                    styles.cornerTag,
                    isSendPackage ? styles.sendTag : styles.receiveTag,
                ]}>
                    <CustomText variant="h8" style={styles.cornerTagText} fontFamily={Fonts.SemiBold}>
                        {isSendPackage ? 'Send Package' : 'Receive Package'}
                    </CustomText>
                </View>
            )}

            <View style={styles.flexRowBetween}>
                <View style={styles.orderIdContainer}>
                    <CustomText variant="h8" fontFamily={Fonts.Medium}>
                        {orderId}
                    </CustomText>
                    {isPackageOrder && (
                        <View style={styles.packageBadge}>
                            <Icon name="package-variant" size={RFValue(12)} color={Colors.primary} />
                            <CustomText variant="h8" style={styles.packageTypeText} fontFamily={Fonts.SemiBold}>
                                {item.packageType}
                            </CustomText>
                        </View>
                    )}
                </View>

                <View style={[
                    styles.statusContainer,
                ]}>
                    <CustomText
                        variant="h8"
                        fontFamily={Fonts.SemiBold}
                        style={[styles.statusText, { color: getStatusColor(item.status) }]}>
                        {item.status}
                    </CustomText>
                </View>
            </View>

            {isPackageOrder ? (
                <View style={styles.packageInfoContainer}>
                    <View style={styles.locationRow}>
                        <Icon name="map-marker" size={RFValue(14)} color={colors.success} />
                        <CustomText variant="h8" numberOfLines={1} style={styles.locationText}>
                            Pickup: {item.pickupLocation?.address || 'N/A'}
                        </CustomText>
                    </View>
                    <View style={styles.locationRow}>
                        <Icon name="map-marker-check" size={RFValue(14)} color={colors.danger} />
                        <CustomText variant="h8" numberOfLines={1} style={styles.locationText}>
                            Drop: {item.dropLocation?.address || deliveryAddress || 'N/A'}
                        </CustomText>
                    </View>
                    {item.distanceKm && (
                        <CustomText variant="h8" style={styles.distanceText}>
                            Distance: {item.distanceKm} km
                        </CustomText>
                    )}
                </View>
            ) : (
                <View style={styles.itemsContainer}>
                    {item.items && item.items.length > 0 ? (
                        item.items.slice(0, 2).map((i, idx) => {
                            return (
                                <CustomText variant="h8" numberOfLines={1} key={idx}>
                                    {i.count}x {i.item?.name || 'Item'}
                                </CustomText>
                            );
                        })
                    ) : (
                        <CustomText variant="h8" numberOfLines={1}>No items</CustomText>
                    )}
                </View>
            )}

            <View style={[styles.flexRowBetween, styles.addressContainer]}>
                <View style={styles.addressTextContainer}>
                    <CustomText variant="h8" numberOfLines={1}>
                        {isPackageOrder ? (item.dropLocation?.address || deliveryAddress) : deliveryAddress}
                    </CustomText>
                    <View style={styles.bottomRow}>
                        <CustomText style={styles.dateText}>
                            {createdAt ? formatISOToCustom(createdAt) : 'N/A'}
                        </CustomText>
                        {price > 0 && (
                            <CustomText style={styles.priceText} fontFamily={Fonts.SemiBold}>
                                ₹{price.toFixed(2)}
                            </CustomText>
                        )}
                    </View>
                </View>
                <TouchableOpacity style={styles.iconContainer} onPress={handleNavigate}>
                    <Icon name="arrow-right-circle" size={RFValue(24)} color={Colors.primary} />
                </TouchableOpacity>
            </View>
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        borderWidth: 0.7,
        padding: 10,
        borderColor: Colors.border,
        borderRadius: 10,
        paddingVertical: 15,
        marginVertical: 10,
        backgroundColor: colors.white,
        position: 'relative',
        overflow: 'visible',
    },
    cornerTag: {
        position: 'absolute',
        top: -8,
        right: 12,
        paddingHorizontal: 8,
        paddingVertical: 4,
        borderRadius: 12,
        zIndex: 10,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.1,
        shadowRadius: 3,
        elevation: 3,
    },
    sendTag: {
        backgroundColor: colors.primaryBlue,
    },
    receiveTag: {
        backgroundColor: colors.secondaryBlue || '#043FA8',
    },
    cornerTagText: {
        fontSize: RFValue(9),
        color: colors.white,
        textTransform: 'uppercase',
    },
    flexRowBetween: {
        justifyContent: 'space-between',
        alignItems: 'center',
        flexDirection: 'row',
    },
    statusContainer: {
        paddingVertical: 4,
        paddingHorizontal: 10,
        borderRadius: 20,
    },
    statusText: {
        textTransform: 'capitalize',
        color: colors.white,
    },
    orderIdContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 8,
        flex: 1,
    },
    packageBadge: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 4,
        backgroundColor: colors.backgroundSecondary,
        paddingHorizontal: 6,
        paddingVertical: 2,
        borderRadius: 8,
    },
    packageTypeText: {
        fontSize: RFValue(10),
        color: Colors.primary,
    },
    itemsContainer: {
        width: '50%',
        marginTop: 10,
    },
    packageInfoContainer: {
        marginTop: 10,
        gap: 6,
    },
    locationRow: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 6,
    },
    locationText: {
        flex: 1,
        fontSize: RFValue(11),
    },
    distanceText: {
        marginTop: 4,
        fontSize: RFValue(10),
        color: colors.muted,
    },
    addressContainer: {
        marginTop: 10,
    },
    addressTextContainer: {
        width: '70%',
    },
    bottomRow: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 8,
        marginTop: 4,
    },
    dateText: {
        fontSize: RFValue(8),
    },
    priceText: {
        fontSize: RFValue(10),
        color: Colors.primary,
    },
    iconContainer: {
        alignItems: 'flex-end',
    },
});
export default OrderItem;
