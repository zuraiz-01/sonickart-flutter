import { Fonts } from '@utils/Constants';
import { StyleSheet, Text, TextStyle, StyleProp, TextProps } from 'react-native';
import { RFValue } from 'react-native-responsive-fontsize';
import colors from '../../theme/colors';

/**
 * Typography wrapper used across app for consistent font family and variant sizing.
 */
interface Props extends TextProps {
    variant?:
    'h1' |
    'h2' |
    'h3' |
    'h4' |
    'h5' |
    'h6' |
    'h7' |
    'h8' |
    'h9' |
    'h10' |
    'body';
    fontFamily?: Fonts;
    fontSize?: number;
    style?: StyleProp<TextStyle>;
    children?: React.ReactNode;
}

const CustomText: React.FC<Props> = ({
    variant = 'body',
    fontFamily = Fonts.Regular,
    fontSize,
    style,
    children,
    numberOfLines,
    ...props
}) => {

    let computedFontSize: number;

    switch (variant) {
        case 'h1':
            computedFontSize = RFValue(fontSize || 22);
            break;
        case 'h2':
            computedFontSize = RFValue(fontSize || 20);
            break;
        case 'h3':
            computedFontSize = RFValue(fontSize || 18);
            break;
        case 'h4':
            computedFontSize = RFValue(fontSize || 16);
            break;
        case 'h5':
            computedFontSize = RFValue(fontSize || 14);
            break;
        case 'h6':
            computedFontSize = RFValue(fontSize || 12);
            break;
        case 'h7':
            computedFontSize = RFValue(fontSize || 12);
            break;
        case 'h8':
            computedFontSize = RFValue(fontSize || 10);
            break;
        case 'h9':
            computedFontSize = RFValue(fontSize || 9);
            break;
        case 'h10':
            computedFontSize = RFValue(fontSize || 8);
            break;
        case 'body':
            computedFontSize = RFValue(fontSize || 12);
            break;
    }


    const fontFamilyStyle = {
        fontFamily,
    };

    return (
        <Text style={[
            styles.text,
            { color: colors.primaryBlue, fontSize: computedFontSize },
            fontFamilyStyle,
            style,
        ]}
            numberOfLines={numberOfLines !== undefined ? numberOfLines : undefined}
            {...props}
        >
            {children}
        </Text>
    );
};


export default CustomText;

const styles = StyleSheet.create({
    text: {
        textAlign: 'left',
    },
});
