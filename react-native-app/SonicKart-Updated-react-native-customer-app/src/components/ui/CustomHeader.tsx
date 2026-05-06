import { View, StyleSheet, Pressable } from 'react-native';
import React, { FC } from 'react';
import { Colors, Fonts } from '@utils/Constants';
import Icon from 'react-native-vector-icons/Ionicons';
import { RFValue } from 'react-native-responsive-fontsize';
import { goBackOr } from '@utils/NavigationUtils';
import CustomText from './CustomText';
import colors from '../../theme/colors';

/**
 * Simple top header with back action and optional trailing search icon.
 */
const CustomHeader: FC<{
    title: string;
    search?: boolean;
    fallbackRoute?: string;
    fallbackParams?: object;
    resetOnFallback?: boolean;
}> = ({
    title,
    search,
    fallbackRoute = 'ProductDashboard',
    fallbackParams,
    resetOnFallback = true,
}) => {
    return (
        <View style={styles.flexRow}>
            <Pressable
                onPress={() => goBackOr(fallbackRoute, fallbackParams, resetOnFallback)}
                accessibilityRole="button"
                accessibilityLabel="Go back"
                accessibilityHint="Double tap to go back to previous screen"
                style={styles.backButton}
            >
                <Icon name="chevron-back" color={Colors.text} size={RFValue(16)} />
            </Pressable>
            <View style={styles.titleContainer}>
                <CustomText
                    style={styles.text}
                    variant="body"
                    fontFamily={Fonts.Bold}
                    fontSize={16}
                >
                    {title}
                </CustomText>
            </View>
            <View style={styles.trailing}>
                {search && <Icon name="search" color={Colors.text} size={RFValue(16)} />}
            </View>
        </View>
    );
};


const styles = StyleSheet.create({
    flexRow: {
        padding: 10,
        height: 60,
        flexDirection: 'row',
        alignItems: 'center',
        backgroundColor: colors.white,
        borderBottomWidth: 0.6,
        borderColor: Colors.border,
    },
    backButton: {
        minWidth: 44,
        minHeight: 44,
        justifyContent: 'center',
        alignItems: 'center',
    },
    titleContainer: {
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
    },
    trailing: {
        minWidth: 44,
        alignItems: 'flex-end',
        justifyContent: 'center',
    },
    text: {
        textAlign: 'center',
        fontWeight: '700',
    },
});
export default CustomHeader;
