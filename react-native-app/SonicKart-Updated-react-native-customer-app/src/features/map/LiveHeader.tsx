import { View, StyleSheet, Pressable } from 'react-native';
import React, { FC } from 'react';
import Icon from 'react-native-vector-icons/Ionicons';
import { goBackOr } from '@utils/NavigationUtils';
import { useAuthStore } from '@state/authStore';
import CustomText from '@components/ui/CustomText';
import { Fonts } from '@utils/Constants';
import colors from '../../theme/colors';

const LiveHeader: FC<{
    type: 'Customer' | 'Delivery';
    title: string;
    secondTitle: string
}> = ({
    title,
    type,
    secondTitle,
}) => {
        const isCustomer = type === 'Customer';
        const { currentOrder, setCurrentOrder } = useAuthStore();

        return (
            <View style={styles.headerContainer}>
                <Pressable
                    style={styles.backButton}
                    onPress={() => {
                        const currentStatus = String(
                            currentOrder?.deliveryStatus ??
                              currentOrder?.delivery_status ??
                              currentOrder?.status ??
                              ''
                        )
                            .trim()
                            .toLowerCase();

                        if (isCustomer) {
                            if (currentStatus === 'delivered' || currentStatus === 'completed') {
                                setCurrentOrder(null);
                            }
                            goBackOr('ProductDashboard');
                            return;
                        }
                        goBackOr('ProductDashboard');
                    }}
                >
                    <Icon
                        name="chevron-back"
                        size={16}
                        color={isCustomer ? colors.white : colors.greyText}
                    />
                </Pressable>

                <CustomText
                    variant="h8"
                    fontFamily={Fonts.Medium}
                    style={isCustomer ? styles.titleTextWhite : styles.titleTextBlack}
                >
                    {title}
                </CustomText>
                <CustomText
                    variant="h4"
                    fontFamily={Fonts.SemiBold}
                    style={isCustomer ? styles.titleTextWhite : styles.titleTextBlack}
                >
                    {secondTitle}
                </CustomText>
            </View>
        );
    };

const styles = StyleSheet.create({
    headerContainer: {
        justifyContent: 'center',
        alignItems: 'center',
        paddingHorizontal: 16,
        paddingVertical: 8,
    },
    backButton: {
        position: 'absolute',
        left: 20,
        justifyContent: 'center',
        alignItems: 'center',
        borderRadius: 8,
        padding: 8,
    },
    titleTextBlack: {
        color: colors.greyText,
    },
    titleTextWhite: {
        color: colors.white,
    },
});
export default LiveHeader;
