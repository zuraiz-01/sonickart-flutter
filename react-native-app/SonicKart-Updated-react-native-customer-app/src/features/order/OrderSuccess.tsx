import { BackHandler, View, StyleSheet } from 'react-native';
import React, { FC, useEffect } from 'react';
import { SafeAreaView } from 'react-native-safe-area-context';
import { screenWidth } from '@utils/Scaling';
import { Colors, Fonts } from '@utils/Constants';
import LottieView from 'lottie-react-native';
import CustomText from '@components/ui/CustomText';
import { useAuthStore } from '@state/authStore';
import { navigate, resetAndNavigate } from '@utils/NavigationUtils';

const OrderSuccess: FC = () => {
    const { user } = useAuthStore();

    useEffect(() => {
        const timeoutId = setTimeout(() => {
            resetAndNavigate('ProductDashboard');
            setTimeout(() => {
                navigate('LiveTracking');
            }, 60);
        }, 2300);
        return () => clearTimeout(timeoutId);
    }, []);

    useEffect(() => {
        const subscription = BackHandler.addEventListener('hardwareBackPress', () => {
            resetAndNavigate('ProductDashboard');
            return true;
        });

        return () => subscription.remove();
    }, []);

    return (
        <SafeAreaView style={{ flex: 1 }} edges={['top']}>
            <View style={styles.container}>
            <LottieView
                source={require('@assets/animations/confirm.json')}
                autoPlay
                duration={2000}
                loop={false}
                speed={1}
                style={styles.lottiewView}
                enableMergePathsAndroidForKitKatAndAbove
                hardwareAccelerationAndroid
            />
            <CustomText variant="h8" fontFamily={Fonts.SemiBold} style={styles.orderPlaceText}>
                ORDER PLACED
            </CustomText>
            <View style={styles.deliveryContainer}>
                <CustomText variant="h4" fontFamily={Fonts.SemiBold} style={styles.deliveryText}>
                    Delivering to Home
                </CustomText>
            </View>
            <CustomText variant="h7" style={styles.addressText} fontFamily={Fonts.Medium}>
                {user?.address || 'Somewhere, Knowhere😁'}
            </CustomText>
        </View>
        </SafeAreaView>
    );
};

const styles = StyleSheet.create({
    container: {
        justifyContent: 'center',
        alignItems: 'center',
        flex: 1,
    },
    lottiewView: {
        width: screenWidth * 0.6,
        height: 150,
    },
    orderPlaceText: {
        opacity: 0.4,
    },
    deliveryContainer: {
        borderBottomWidth: 2,
        paddingBottom: 4,
        marginBottom: 5,
        borderColor: Colors.secondary,
    },
    deliveryText: {
        marginTop: 15,
        borderColor: Colors.secondary,
    },
    addressText: {
        opacity: 0.8,
        width: '80%',
        textAlign: 'center',
        marginTop: 10,
        lineHeight: 24,
    },
});

export default OrderSuccess;
