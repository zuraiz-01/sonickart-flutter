import { StyleSheet, TextStyle } from 'react-native';
import { RFValue } from 'react-native-responsive-fontsize';
import colors from '../theme/colors';
import { Fonts } from '../utils/Constants';

/**
 * Global Typography Styles
 *
 * Default font: Poppins-Regular
 * Heading font: Poppins-SemiBold
 * Default text color: #092774 (primaryBlue)
 * Consistent padding: 15-20px
 */

// Base text styles
export const baseTextStyle: TextStyle = {
  fontFamily: Fonts.Regular,
  color: colors.primaryBlue,
};

// Heading styles
export const headingStyles = StyleSheet.create({
  h1: {
    ...baseTextStyle,
    fontFamily: Fonts.SemiBold,
    fontSize: RFValue(28),
    lineHeight: RFValue(36),
    paddingHorizontal: 20,
    paddingVertical: 15,
  },
  h2: {
    ...baseTextStyle,
    fontFamily: Fonts.SemiBold,
    fontSize: RFValue(24),
    lineHeight: RFValue(32),
    paddingHorizontal: 20,
    paddingVertical: 15,
  },
  h3: {
    ...baseTextStyle,
    fontFamily: Fonts.SemiBold,
    fontSize: RFValue(20),
    lineHeight: RFValue(28),
    paddingHorizontal: 18,
    paddingVertical: 15,
  },
  h4: {
    ...baseTextStyle,
    fontFamily: Fonts.SemiBold,
    fontSize: RFValue(18),
    lineHeight: RFValue(24),
    paddingHorizontal: 18,
    paddingVertical: 15,
  },
  h5: {
    ...baseTextStyle,
    fontFamily: Fonts.SemiBold,
    fontSize: RFValue(16),
    lineHeight: RFValue(22),
    paddingHorizontal: 18,
    paddingVertical: 15,
  },
  h6: {
    ...baseTextStyle,
    fontFamily: Fonts.SemiBold,
    fontSize: RFValue(14),
    lineHeight: RFValue(20),
    paddingHorizontal: 15,
    paddingVertical: 12,
  },
});

// Body text styles
export const bodyStyles = StyleSheet.create({
  body: {
    ...baseTextStyle,
    fontFamily: Fonts.Regular,
    fontSize: RFValue(14),
    lineHeight: RFValue(20),
    paddingHorizontal: 15,
    paddingVertical: 12,
  },
  bodySmall: {
    ...baseTextStyle,
    fontFamily: Fonts.Regular,
    fontSize: RFValue(12),
    lineHeight: RFValue(18),
    paddingHorizontal: 15,
    paddingVertical: 12,
  },
  bodyLarge: {
    ...baseTextStyle,
    fontFamily: Fonts.Regular,
    fontSize: RFValue(16),
    lineHeight: RFValue(24),
    paddingHorizontal: 18,
    paddingVertical: 15,
  },
});

// Label and caption styles
export const labelStyles = StyleSheet.create({
  label: {
    ...baseTextStyle,
    fontFamily: Fonts.Regular,
    fontSize: RFValue(12),
    lineHeight: RFValue(18),
    paddingHorizontal: 15,
    paddingVertical: 10,
  },
  caption: {
    ...baseTextStyle,
    fontFamily: Fonts.Regular,
    fontSize: RFValue(10),
    lineHeight: RFValue(16),
    paddingHorizontal: 15,
    paddingVertical: 10,
  },
});

// Button text styles
export const buttonStyles = StyleSheet.create({
  button: {
    ...baseTextStyle,
    fontFamily: Fonts.SemiBold,
    fontSize: RFValue(14),
    lineHeight: RFValue(20),
    paddingHorizontal: 20,
    paddingVertical: 12,
    textAlign: 'center',
  },
  buttonSmall: {
    ...baseTextStyle,
    fontFamily: Fonts.SemiBold,
    fontSize: RFValue(12),
    lineHeight: RFValue(18),
    paddingHorizontal: 18,
    paddingVertical: 10,
    textAlign: 'center',
  },
  buttonLarge: {
    ...baseTextStyle,
    fontFamily: Fonts.SemiBold,
    fontSize: RFValue(16),
    lineHeight: RFValue(24),
    paddingHorizontal: 20,
    paddingVertical: 15,
    textAlign: 'center',
  },
});

// Container padding styles
export const containerStyles = StyleSheet.create({
  defaultPadding: {
    paddingHorizontal: 20,
    paddingVertical: 15,
  },
  smallPadding: {
    paddingHorizontal: 15,
    paddingVertical: 12,
  },
  largePadding: {
    paddingHorizontal: 20,
    paddingVertical: 20,
  },
  horizontalPadding: {
    paddingHorizontal: 20,
  },
  verticalPadding: {
    paddingVertical: 15,
  },
});

// Combined typography exports
export const Typography = {
  ...headingStyles,
  ...bodyStyles,
  ...labelStyles,
  ...buttonStyles,
  ...containerStyles,
};

export default Typography;

