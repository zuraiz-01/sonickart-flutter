import { View, TouchableOpacity, StyleSheet, ActivityIndicator } from 'react-native';
import React, { FC } from 'react';
import { Colors, Fonts } from '@utils/Constants';
import CustomText from './CustomText';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { RFValue } from 'react-native-responsive-fontsize';
import colors from '../../theme/colors';

interface ArrowButtonProps {
    title: string;
    onPress?: () => void;
    price?: number;
    loading?: boolean;
    disabled?: boolean;
}

const ArrowButton: FC<ArrowButtonProps> = ({ title, onPress, price, loading, disabled = false }) => {
    const isDisabled = loading || disabled;
    const hasPrice = typeof price === 'number' && price !== 0;
    const accessibilityLabel = hasPrice
        ? `${title}, Total: ₹${price! + 34}`
        : title;

    return (
        <TouchableOpacity
            activeOpacity={0.8}
            disabled={isDisabled}
            onPress={onPress}
            accessibilityRole="button"
            accessibilityLabel={accessibilityLabel}
            accessibilityState={{ disabled: isDisabled }}
            style={[
                styles.btn,
                hasPrice ? styles.btnWithPrice : styles.btnCentered,
                isDisabled && styles.disabledBtn,
            ]}>

            {hasPrice && (
                <View>
                    <CustomText
                        variant="h7"
                        style={{ color: isDisabled ? colors.disabled : colors.white }}
                        fontFamily={Fonts.Medium}
                    >
                        {`₹${price! + 34}.0`}
                    </CustomText>

                    <CustomText
                        variant="h9"
                        fontFamily={Fonts.Medium}
                        style={{ color: isDisabled ? colors.disabled : colors.white }}
                    >
                        TOTAL
                    </CustomText>
                </View>
            )}

            <View style={[styles.labelWrap, hasPrice ? styles.labelWrapWithPrice : null]}>
                <CustomText
                    variant="h6"
                    style={[
                        styles.labelText,
                        { color: isDisabled ? colors.disabled : colors.white },
                    ]}
                    fontFamily={Fonts.Medium}
                >
                    {title}
                </CustomText>
            </View>

            <View style={styles.iconWrap}>
                {loading ? (
                    <ActivityIndicator
                        color={colors.white}
                        style={styles.iconLoader}
                        size="small"
                    />
                ) : (
                    <Icon
                        name="arrow-right"
                        color={isDisabled ? colors.disabled : colors.white}
                        size={RFValue(25)}
                    />
                )}
            </View>
        </TouchableOpacity>
    );
};

const styles = StyleSheet.create({
    btn: {
        backgroundColor: Colors.secondary,
        padding: 10,
        alignItems: 'center',
        flexDirection: 'row',
        borderRadius: 12,
        marginVertical: 10,
        marginHorizontal: 15,
        minHeight: 44,
        position: 'relative',
    },
    btnWithPrice: {
        justifyContent: 'space-between',
    },
    btnCentered: {
        justifyContent: 'center',
    },
    disabledBtn: {
        backgroundColor: Colors.disabled,
        opacity: 0.6,
    },
    labelWrap: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
    },
    labelWrapWithPrice: {
        position: 'absolute',
        left: 0,
        right: 0,
        alignItems: 'center',
    },
    labelText: {
        textAlign: 'center',
    },
    iconWrap: {
        minWidth: 28,
        alignItems: 'flex-end',
        justifyContent: 'center',
    },
    iconLoader: {
        marginHorizontal: 5,
    },
});

export default ArrowButton;
