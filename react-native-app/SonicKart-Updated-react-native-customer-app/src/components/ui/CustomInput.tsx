import { Colors, Fonts } from '@utils/Constants';
import { FC } from 'react';
import { StyleSheet, TextInput, TouchableOpacity, View } from 'react-native';
import { RFValue } from 'react-native-responsive-fontsize';
import Icon from 'react-native-vector-icons/Ionicons';
import colors from '../../theme/colors';

/**
 * Reusable text input with optional left icon/content and clear action on right.
 */

interface InputProps {
    left: React.ReactNode;
    onClear?: () => void;
    right?: boolean
}

const CustomInput:
    FC<InputProps & React.ComponentProps<typeof TextInput>>
    = ({
        onClear,
        left,
        right = true,
        style,
        ...props
    }) => {
        return (
            <View style={styles.flexRow}>
                {left && <View style={styles.leftContainer}>{left}</View>}
                <TextInput
                    {...props}
                    style={[styles.inputContainer, style]}
                    placeholderTextColor={colors.greyText}
                />
                {right && (
                    <View style={styles.icon}>
                        {props.value?.length !== 0 && (
                            <TouchableOpacity onPress={onClear}>
                                <Icon name="close-circle-sharp" size={RFValue(16)} color={colors.greyText} />
                            </TouchableOpacity>
                        )}
                    </View>
                )}
            </View>
        );
    };

const styles = StyleSheet.create({
    flexRow: {
        flexDirection: 'row',
        alignItems: 'center',
        borderRadius: 10,
        borderWidth: 0.5,
        width: '100%',
        marginVertical: 10,
        backgroundColor: colors.white,
        shadowOffset: { width: 1, height: 1 },
        shadowOpacity: 0.6,
        shadowRadius: 2,
        shadowColor: Colors.border,
        borderColor: Colors.border,
        height: 45,
    },
    leftContainer: {
        paddingLeft: 12,
        paddingRight: 4,
        justifyContent: 'center',
        alignItems: 'center',
        height: '100%',
    },
    inputContainer: {
        flex: 1,
        fontFamily: Fonts.SemiBold,
        fontSize: RFValue(12),
        paddingVertical: 0,
        paddingHorizontal: 6,
        color: colors.primaryBlue,
        textAlignVertical: 'center',
        height: '100%',

    },
    icon: {
        paddingRight: 12,
        justifyContent: 'center',
        alignItems: 'center',
        height: '100%',
    },
});

export default CustomInput;
