import { View, StyleSheet, TouchableOpacity } from 'react-native';
import React, { FC } from 'react';
import { Fonts } from '@utils/Constants';
import { RFValue } from 'react-native-responsive-fontsize';
import Icon from 'react-native-vector-icons/Ionicons';
import CustomText from '@components/ui/CustomText';
import colors from '../../theme/colors';

interface ActionButtonProps {
    icon: string;
    label: string;
    onPress?: () => void;
    showDivider?: boolean;
    isLogout?: boolean;
}

const ActionButton: FC<ActionButtonProps> = ({ icon, label, onPress, showDivider = true, isLogout = false }) => {
    if (isLogout) {
        return (
            <View style={styles.container}>
                <TouchableOpacity
                    style={styles.logoutButton}
                    onPress={onPress}
                    activeOpacity={0.7}
                    accessibilityRole="button"
                    accessibilityLabel={label}
                    accessibilityHint="Double tap to logout"
                >
                    <Icon name={icon} color={colors.accentYellow} size={RFValue(20)} />
                    <CustomText
                        variant="body"
                        fontFamily={Fonts.Bold}
                        fontSize={14}
                        style={styles.logoutText}
                    >
                        {label}
                    </CustomText>
                </TouchableOpacity>
            </View>
        );
    }

    return (
        <View style={styles.container}>
            <TouchableOpacity
                style={styles.btn}
                onPress={onPress}
                activeOpacity={0.7}
                accessibilityRole="button"
                accessibilityLabel={label}
                accessibilityHint={`Double tap to ${label.toLowerCase()}`}
            >
                <Icon name={icon} color={colors.accentYellow} size={RFValue(20)} />
                <CustomText
                    variant="body"
                    fontFamily={Fonts.Bold}
                    fontSize={12}
                    style={styles.label}
                >
                    {label}
                </CustomText>
                <Icon name="chevron-forward" color={colors.greyText} size={RFValue(20)} />
            </TouchableOpacity>
            {showDivider && <View style={styles.divider} />}
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        backgroundColor: colors.white,
    },
    btn: {
        flexDirection: 'row',
        alignItems: 'center',
        paddingVertical: 15,
        paddingHorizontal: 15,
        gap: 15,
        minHeight: 44,
    },
    label: {
        flex: 1,
        color: colors.primaryBlue,
        letterSpacing: 0.4,
    },
    divider: {
        height: 1,
        backgroundColor: colors.blackOpacity05,
        marginLeft: 15,
    },
    logoutButton: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        paddingVertical: 15,
        paddingHorizontal: 15,
        marginVertical: 10,
        backgroundColor: colors.white,
        borderWidth: 1,
        borderColor: colors.primaryBlue,
        borderRadius: 10,
        gap: 10,
        minHeight: 44,
    },
    logoutText: {
        color: colors.primaryBlue,
        letterSpacing: 0.6,
        fontSize: 14,
        fontWeight: '700',
    },
});

export default ActionButton;
