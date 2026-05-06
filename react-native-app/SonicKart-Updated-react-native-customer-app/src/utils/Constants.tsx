import colors from '../theme/colors';

export const Colors = {
    primary: colors.accentYellow,
    primary_light: colors.accentYellow,
    secondary: colors.primaryBlue,
    text: colors.greyText,
    disabled: colors.greyText,
    border: colors.lightBlue,
    backgroundSecondary: colors.lightBlue,
};
export enum Fonts {
    Regular = 'Okra-Regular',
    Medium = 'Okra-Medium',
    Light = 'Okra-MediumLight',
    SemiBold = 'Okra-Bold',
    Bold = 'Okra-ExtraBold',
}

// Light colors gradient array - using white with varying opacity
export const lightColors = [
    'rgba(255,255,255,1)', // colors.white
    'rgba(255,255,255,0.9)',
    'rgba(255,255,255,0.7)',
    'rgba(255,255,255,0.6)',
    'rgba(255,255,255,0.5)',
    'rgba(255,255,255,0.4)',
    'rgba(255,255,255,0.003)',
];

// Dark weather colors gradient array - using dark blue tones
export const darkWeatherColors = [
    'rgba(54, 67, 92, 1)',
    'rgba(54, 67, 92, 0.9)',
    'rgba(54, 67, 92, 0.8)',
    'rgba(54, 67, 92, 0.2)',
    'rgba(54, 67, 92, 0.0)',
];
