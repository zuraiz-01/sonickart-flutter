import { Colors, Fonts } from '@utils/Constants';
import { FC } from 'react';
import { ActivityIndicator, StyleSheet, TouchableOpacity } from 'react-native';
import CustomText from './CustomText';
import colors from '../../theme/colors';

/**
 * Primary reusable button with disabled and loading support.
 */
interface CustomButtonProps {
    onPress: () => void;
    title: string;
    disabled: boolean;
    loading: boolean;
    buttonColor?: string;
    style?: object;
}

const CustomButton: FC<CustomButtonProps>
    = ({
        onPress,
        title,
        disabled,
        loading,
        buttonColor,
        style,
    }) => {
        return (
            <TouchableOpacity
                onPress={onPress}
                disabled={disabled || loading}
                activeOpacity={0.8}
                style={[
                    styles.btn,
                    {
                        backgroundColor: disabled
                            ? Colors.disabled
                            : (buttonColor || Colors.secondary),
                        opacity: disabled ? 0.6 : 1,
                    },
                    style,
                ]}
            >
                {loading ?
                    <ActivityIndicator
                        color={colors.white}
                        size="small"
                    /> :
                    <CustomText
                        variant="h6"
                        style={styles.text}
                        fontFamily={Fonts.SemiBold}
                        numberOfLines={1}
                    >
                        {title}
                    </CustomText>
                }
            </TouchableOpacity>
        );
    };

const styles = StyleSheet.create({
    btn: {
        justifyContent: 'center',
        alignItems: 'center',
        borderRadius: 10,
        paddingVertical: 15,
        paddingHorizontal: 20,
        marginVertical: 8,
        shadowColor: '#000',
        shadowOffset: {
            width: 0,
            height: 2,
        },
        shadowOpacity: 0.1,
        shadowRadius: 3,
        elevation: 3,
    },
    text: {
        color: colors.white,
        textAlign: 'center',
    },
});

export default CustomButton;
