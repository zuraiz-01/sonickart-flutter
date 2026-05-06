import { View, StyleSheet } from 'react-native';
import React, { FC, useMemo } from 'react';
import CustomText from '@components/ui/CustomText';
import { Fonts } from '@utils/Constants';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { RFValue } from 'react-native-responsive-fontsize';
import colors from '../../theme/colors';
import type { CouponDocument } from '@service/couponService';
import { calculateCheckoutTotals } from '@utils/checkoutTotals';

type BillCartItem = Parameters<typeof calculateCheckoutTotals>[0][number];

const formatCurrency = (value: number | null | undefined) => {
  if (value === null || value === undefined || Number.isNaN(Number(value))) {
    return '0.00';
  }

  return Number(value).toFixed(2);
};

const ReportItem: FC<{
  iconName: string;
  underline?: boolean;
  title: string;
  price?: number | null;
  showDash?: boolean;
  largerText?: boolean;
  isDiscount?: boolean;
}> = ({ iconName, underline, title, price, showDash, largerText = false, isDiscount = false }) => {
  const formattedPrice = showDash ? '--' : formatCurrency(price);
  const pricePrefix = showDash ? '' : isDiscount ? '-₹' : '₹';

  return (
    <View style={[styles.flexRowBetween, { marginBottom: 12 }]}>
      <View style={styles.flexRow}>
        <Icon
          name={iconName}
          size={RFValue(largerText ? 17 : 16)}
          color={colors.accentYellow}
        />
        <CustomText
          variant="h9"
          fontFamily={Fonts.Medium}
          style={{
            textDecorationLine: underline ? 'underline' : 'none',
            textDecorationStyle: 'dashed',
            fontSize: largerText ? 13.5 : undefined,
          }}
        >
          {title}
        </CustomText>
      </View>
      <CustomText
        variant="h9"
        fontFamily={Fonts.SemiBold}
        style={{ fontSize: largerText ? 13.5 : undefined }}
      >
        {showDash ? formattedPrice : `${pricePrefix}${formattedPrice}`}
      </CustomText>
    </View>
  );
};

const BillDetails: FC<{
  totalItemPrice?: number;
  cartItems?: BillCartItem[];
  largerText?: boolean;
  coupon?: CouponDocument | null;
}> = ({
  cartItems = [],
  largerText = false,
  coupon = null,
}) => {
  const totals = useMemo(
    () => calculateCheckoutTotals(cartItems, coupon),
    [cartItems, coupon]
  );

  if (totals.itemsTotal <= 0 || !totals.hasValidItems) {
    return (
      <View style={styles.container}>
        <CustomText
          style={[styles.headingText, styles.heading]}
          fontFamily={Fonts.Bold}
          fontSize={largerText ? 18 : 17}
        >
          Bill Details
        </CustomText>

        <View style={styles.billContainer}>
          <ReportItem iconName="article" title="Items total (incl. GST)" price={0} largerText={largerText} />
          <ReportItem iconName="pedal-bike" title="Delivery charge" price={0} largerText={largerText} />
        </View>
        <View style={[styles.flexRowBetween, styles.totalRow]}>
          <CustomText
            style={[styles.totalLabelText, styles.heading]}
            fontFamily={Fonts.Bold}
            fontSize={largerText ? 18 : 17}
          >
            Grand Total
          </CustomText>
          <CustomText
            style={[styles.totalAmountText, styles.heading]}
            fontFamily={Fonts.Bold}
            fontSize={largerText ? 18 : 17}
          >
            ₹0.00
          </CustomText>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <CustomText
        style={[styles.headingText, styles.heading]}
        fontFamily={Fonts.Bold}
        fontSize={largerText ? 18 : 17}
      >
        Bill Details
      </CustomText>

      <View style={styles.billContainer}>
        <ReportItem
          iconName="article"
          title="Items total (incl. GST)"
          price={totals.totalBeforeDiscount}
          largerText={largerText}
        />
        <ReportItem
          iconName="pedal-bike"
          title="Delivery charge"
          price={totals.deliveryCharge}
          largerText={largerText}
        />
        {totals.appliedCoupon && totals.couponDiscount > 0 && (
          <ReportItem
            iconName="sell"
            title={`Coupon (${totals.appliedCoupon.code})`}
            price={totals.couponDiscount}
            largerText={largerText}
            isDiscount={true}
          />
        )}
      </View>
      <View style={[styles.flexRowBetween, styles.totalRow]}>
        <CustomText
          style={[styles.totalLabelText, styles.heading]}
          fontFamily={Fonts.Bold}
          fontSize={largerText ? 18 : 17}
        >
          Grand Total
        </CustomText>
        <CustomText
          style={[styles.totalAmountText, styles.heading]}
          fontFamily={Fonts.Bold}
          fontSize={largerText ? 18 : 17}
        >
          {`₹${totals.grandTotal.toFixed(2)}`}
        </CustomText>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: colors.white,
    borderRadius: 18,
    paddingTop: 18,
    paddingBottom: 18,
    borderWidth: 1,
    borderColor: colors.blackOpacity05,
    marginHorizontal: 16,
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.06,
    shadowRadius: 10,
    elevation: 3,
  },
  headingText: {
    marginHorizontal: 16,
    marginBottom: 14,
  },
  totalLabelText: {
    marginLeft: 12,
  },
  totalAmountText: {
    marginRight: 12,
  },
  heading: {
    color: colors.primaryBlue,
    fontWeight: '700',
  },
  billContainer: {
    paddingHorizontal: 14,
    paddingTop: 6,
    paddingBottom: 2,
    borderBottomColor: colors.blackOpacity05,
    borderBottomWidth: 1,
  },
  flexRowBetween: {
    justifyContent: 'space-between',
    alignItems: 'center',
    flexDirection: 'row',
    paddingHorizontal: 14,
  },
  flexRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 7,
    flexShrink: 1,
  },
  totalRow: {
    marginTop: 18,
  },
});

export default BillDetails;
