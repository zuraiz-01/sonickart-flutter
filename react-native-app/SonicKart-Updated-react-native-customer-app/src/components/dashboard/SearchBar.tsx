import { StyleSheet, TouchableOpacity } from 'react-native';
import React, { FC } from 'react';
import Icon from 'react-native-vector-icons/Ionicons';
import { Fonts } from '@utils/Constants';
import { RFValue } from 'react-native-responsive-fontsize';
import RollingBar from 'react-native-rolling-bar';
import CustomText from '@components/ui/CustomText';
import colors from '../../theme/colors';
import { navigate } from '@utils/NavigationUtils';

const SearchBar:FC = () => {
    return (
        <TouchableOpacity
            style={styles.container}
            activeOpacity={0.8}
            onPress={() => navigate('SearchScreen')}
            accessibilityRole="search"
            accessibilityLabel="Search for products"
            accessibilityHint="Double tap to search for products"
        >
            <Icon name="search" color={colors.primaryBlue} size={RFValue(20)} />
            <RollingBar interval={3000} defaultStyle={false} customStyle={styles.textContainer}>
                <CustomText variant="h6" fontFamily={Fonts.Medium} style={styles.placeholderText}>Search "sweets"</CustomText>
                <CustomText variant="h6" fontFamily={Fonts.Medium} style={styles.placeholderText}>Search "milk"</CustomText>
                <CustomText variant="h6" fontFamily={Fonts.Medium} style={styles.placeholderText}>Search for ata, dal, coke</CustomText>
                <CustomText variant="h6" fontFamily={Fonts.Medium} style={styles.placeholderText}>Search "chips"</CustomText>
                <CustomText variant="h6" fontFamily={Fonts.Medium} style={styles.placeholderText}>Search "pooja thali"</CustomText>
            </RollingBar>
        </TouchableOpacity>
    );
};


const styles = StyleSheet.create({
    container: {
        backgroundColor: colors.white,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'flex-start',
        borderRadius: 18,
        borderWidth: 1,
        borderColor: colors.primaryBlueOpacity10,
        marginTop: 12,
        overflow: 'hidden',
        marginHorizontal: 14,
        paddingHorizontal: 14,
        minHeight: 52,
        shadowColor: colors.black,
        shadowOffset: { width: 0, height: 6 },
        shadowOpacity: 0.07,
        shadowRadius: 10,
        elevation: 3,
    },
    textContainer: {
        flex: 1,
        paddingLeft: 10,
        height: 52,
        minHeight: 44,
        justifyContent: 'center',
    },
    placeholderText: {
        color: colors.greyText,
    },
});
export default SearchBar;
