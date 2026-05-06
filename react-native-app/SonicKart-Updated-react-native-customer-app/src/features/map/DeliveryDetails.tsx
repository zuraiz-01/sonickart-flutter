import { View, StyleSheet } from 'react-native';
import React, { FC, useMemo } from 'react';
import { Colors, Fonts } from '@utils/Constants';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import { RFValue } from 'react-native-responsive-fontsize';
import CustomText from '@components/ui/CustomText';
import colors from '../../theme/colors';

type DeliveryInfo = {
    addressLabel?: string | null;
    address?: string | null;
    name?: string | null;
    phone?: string | null;
    partnerName?: string | null;
    partnerPhone?: string | null;
};

const DeliveryDetails: FC<{ details?: DeliveryInfo | null, iconColor?: string }> = ({ details, iconColor }) => {
    const info = useMemo(() => {
        return {
            addressLabel: details?.addressLabel?.trim() || 'Delivery at Home',
            address: details?.address?.trim() || 'Address unavailable',
            name: details?.name?.trim() || 'Customer',
            phone: details?.phone?.trim() || 'Add contact number',
            partnerName: details?.partnerName?.trim() || null,
            partnerPhone: details?.partnerPhone?.trim() || null,
        };
    }, [details]);

    return (
        <View style={styles.container}>
            <View style={styles.flexRow2}>
                <View style={styles.iconContainer}>
                    <Icon name="map-marker-outline" color={iconColor || Colors.disabled} size={RFValue(20)} />
                </View>
                <View style={{ width: '80%' }}>
                    <CustomText variant="h7" fontFamily={Fonts.Medium} style={styles.addressLabel}>
                        {info.addressLabel}
                    </CustomText>
                    <CustomText variant="h7" numberOfLines={2} fontFamily={Fonts.Regular} style={styles.addressText}>
                        {info.address}
                    </CustomText>
                </View>
            </View>

        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        width: '100%',
        borderRadius: 15,
        marginVertical: 15,
        paddingVertical: 10,
        backgroundColor: colors.white,
    },
    flexRow2: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 10,
        padding: 10,
    },
    iconContainer: {
        backgroundColor: Colors.backgroundSecondary,
        borderRadius: 100,
        padding: 10,
        justifyContent: 'center',
        alignItems: 'center',
    },
    addressLabel: {
        marginBottom: 2,
    },
    addressText: {
        lineHeight: 22,
    },
});

export default DeliveryDetails;
