import React from 'react';
import { View, StyleSheet, TouchableOpacity } from 'react-native';
import Icon from 'react-native-vector-icons/Ionicons';
import { RFValue } from 'react-native-responsive-fontsize';
import CustomText from '@components/ui/CustomText';
import { Fonts } from '@utils/Constants';
import colors from '../../theme/colors';

const WalletSection = () => {
  return (
    <View style={styles.card}>
      <View style={styles.headerRow}>
        <View style={styles.iconWrapper}>
          <Icon name="wallet-outline" size={RFValue(20)} color={colors.accentYellow} />
        </View>
        <View style={styles.titleWrapper}>
          <CustomText
            variant="body"
            fontFamily={Fonts.Bold}
            fontSize={16}
            style={[styles.title, styles.boldTitle]}
          >
            SonicKart Wallet & Gift Card
          </CustomText>
          <CustomText
            variant="body"
            fontFamily={Fonts.Bold}
            fontSize={12}
            style={styles.subtitle}
          >
            Manage payments and offers at one place
          </CustomText>
        </View>
      </View>

      <View style={styles.balanceRow}>
        <View>
          <CustomText
            variant="body"
            fontFamily={Fonts.Bold}
            fontSize={12}
            style={styles.balanceLabel}
          >
            Available Balance
          </CustomText>
          <CustomText
            variant="body"
            fontFamily={Fonts.Bold}
            fontSize={16}
            style={styles.balanceValue}
          >
            ₹0
          </CustomText>
        </View>
        <TouchableOpacity
          style={styles.addBalanceButton}
          activeOpacity={0.85}
          accessibilityRole="button"
          accessibilityLabel="Add balance to wallet"
          accessibilityHint="Double tap to add money to your SonicKart wallet"
        >
          <CustomText
            variant="body"
            fontFamily={Fonts.Bold}
            fontSize={12}
            style={styles.addBalanceText}
          >
            Add Balance
          </CustomText>
        </TouchableOpacity>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.white,
    borderRadius: 18,
    padding: 20,
    marginVertical: 20,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.08,
    shadowRadius: 14,
    elevation: 6,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  iconWrapper: {
    width: 44,
    height: 44,
    borderRadius: 12,
    backgroundColor: colors.primaryBlue,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  titleWrapper: {
    flex: 1,
  },
  title: {
    color: colors.primaryBlue,
  },
  boldTitle: {
    fontWeight: '700',
  },
  subtitle: {
    color: colors.greyText,
    marginTop: 4,
  },
  balanceRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  balanceLabel: {
    color: colors.greyText,
    letterSpacing: 0.5,
  },
  balanceValue: {
    color: colors.primaryBlue,
    marginTop: 4,
  },
  addBalanceButton: {
    backgroundColor: colors.primaryBlue,
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 12,
    minHeight: 44,
    justifyContent: 'center',
    alignItems: 'center',
  },
  addBalanceText: {
    color: colors.white,
  },
});

export default WalletSection;
