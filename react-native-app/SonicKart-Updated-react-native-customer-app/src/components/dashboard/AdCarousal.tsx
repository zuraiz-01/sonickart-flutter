import { View, StyleSheet, TouchableOpacity } from 'react-native';
import React, { FC } from 'react';
import { screenWidth } from '@utils/Scaling';
import LinearGradient from 'react-native-linear-gradient';
import CustomText from '@components/ui/CustomText';
import { Fonts } from '@utils/Constants';
import colors from '../../theme/colors';
import { RFValue } from 'react-native-responsive-fontsize';

const AdCarousal: FC<{ adData: any }> = () => {
    return (
        <View style={styles.container}>
            <LinearGradient
                colors={[colors.primaryBlue, colors.secondaryBlue]}
                style={styles.gradient}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 0 }}
            >
                <View style={styles.content}>
                    <CustomText variant="h3" fontFamily={Fonts.Bold} style={styles.title}>
                        Your City, Your Cart in Minutes.
                    </CustomText>
                    <TouchableOpacity
                        style={styles.orderButton}
                        activeOpacity={0.8}
                        accessibilityRole="button"
                        accessibilityLabel="Order Now"
                    >
                        <CustomText variant="h6" fontFamily={Fonts.SemiBold} style={styles.buttonText}>
                            Order Now
                        </CustomText>
                    </TouchableOpacity>
                </View>
            </LinearGradient>
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        marginVertical: 20,
        marginHorizontal: 20,
        borderRadius: 12,
        overflow: 'hidden',
    },
    gradient: {
        width: '100%',
        height: screenWidth * 0.4,
        borderRadius: 12,
        padding: 20,
        justifyContent: 'center',
    },
    content: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'flex-start',
    },
    title: {
        color: colors.white,
        marginBottom: 20,
        fontSize: RFValue(16),
    },
    orderButton: {
        backgroundColor: colors.accentYellow,
        paddingHorizontal: 24,
        paddingVertical: 12,
        borderRadius: 8,
        minHeight: 44,
        justifyContent: 'center',
        alignItems: 'center',
    },
    buttonText: {
        color: colors.primaryBlue,
    },
});

export default AdCarousal;
