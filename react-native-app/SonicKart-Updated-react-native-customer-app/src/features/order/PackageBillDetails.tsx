import { View, StyleSheet, TouchableOpacity } from 'react-native';
import React, { FC } from 'react';
import CustomText from '@components/ui/CustomText';
import { Colors, Fonts } from '@utils/Constants';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { RFValue } from 'react-native-responsive-fontsize';
import colors from '../../theme/colors';
import { navigate } from '@utils/NavigationUtils';
import { useAuthStore } from '@state/authStore';
import { getPackageOrderById } from '@service/packageService';

/**
 * Billing summary block for package orders.
 * Can also navigate to full tracking/description for the selected package order.
 */
type PackageBillDetailsProps = {
  packageType?: string;
  distanceKm?: number | null;
  deliveryCharge?: number | null;
  totalPrice?: number | null;
  status?: string;
  orderId?: string | number | null;
  order?: any;
  showViewFullDescription?: boolean;
};

const ReportItem: FC<{
  iconName: string;
  title: string;
  value?: string | number | null;
}> = ({ iconName, title, value }) => {
  const displayValue = value !== null && value !== undefined
    ? (typeof value === 'number' ? `₹${value.toFixed(2)}` : String(value))
    : '--';

  return (
    <View style={[styles.flexRowBetween, { marginBottom: 10 }]}>
      <View style={styles.flexRow}>
        <Icon
          name={iconName}
          size={RFValue(14)}
          color={colors.accentYellow}
        />
        <CustomText
          variant="h8"
          fontFamily={Fonts.Medium}
        >
          {title}
        </CustomText>
      </View>
      <CustomText variant="h8" fontFamily={Fonts.SemiBold}>
        {displayValue}
      </CustomText>
    </View>
  );
};

const PackageBillDetails: FC<PackageBillDetailsProps> = ({
  packageType,
  distanceKm,
  deliveryCharge,
  totalPrice,
  status,
  orderId,
  order,
  showViewFullDescription = true,
}) => {
  const isCancelled = status?.toLowerCase() === 'cancelled';
  const { setCurrentOrder } = useAuthStore();

  const handleViewFullDescription = async () => {
    const resolvedOrderId =
      orderId || order?.orderId || order?.orderNumber || order?.id || order?._id;

    // If we already have the order details, use them and go to tracking
    if (order) {
      setCurrentOrder(order);
      navigate('LiveTracking');
      return;
    }

    // Try to fetch details if we only have an ID
    if (resolvedOrderId) {
      try {
        const normalizedId = String(resolvedOrderId).replace(/^PKG/i, '');
        const latestOrder = await getPackageOrderById(normalizedId);
        if (latestOrder) {
          setCurrentOrder(latestOrder);
        }
      } catch (error) {
        // Silent fail; still navigate with whatever we have
        console.warn('PackageBillDetails: failed to fetch order by id', error);
      }
      navigate('LiveTracking');
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.headerRow}>
        <CustomText
          style={[styles.headingText, styles.heading]}
          fontFamily={Fonts.Bold}
          fontSize={16}
        >
          Bill Details
        </CustomText>
        {isCancelled && (
          <View style={styles.cancelledBadge}>
            <Icon name="cancel" size={RFValue(12)} color={colors.cancelled} />
            <CustomText
              style={styles.cancelledText}
              fontFamily={Fonts.SemiBold}
              fontSize={12}
            >
              Cancelled
            </CustomText>
          </View>
        )}
      </View>

      <View style={styles.billContainer}>
        <ReportItem
          iconName="inventory"
          title="Package Type"
          value={packageType || 'N/A'}
        />
        <ReportItem
          iconName="straighten"
          title="Distance"
          value={distanceKm !== null && distanceKm !== undefined ? `${distanceKm.toFixed(2)} km` : null}
        />
        <ReportItem
          iconName="pedal-bike"
          title="Delivery Charge"
          value={deliveryCharge}
        />
      </View>

      <View style={[styles.flexRowBetween, styles.totalRow]}>
        <CustomText
          style={[styles.totalLabelText, styles.heading, isCancelled && styles.cancelledTotal]}
          fontFamily={Fonts.Bold}
          fontSize={16}
        >
          Grand Total
        </CustomText>
        <CustomText
          style={[styles.totalAmountText, styles.heading, isCancelled && styles.cancelledTotal]}
          fontFamily={Fonts.Bold}
          fontSize={16}
        >
          ₹{totalPrice !== null && totalPrice !== undefined ? totalPrice.toFixed(2) : '0.00'}
        </CustomText>
      </View>

      {(orderId || order) && showViewFullDescription && (
        <TouchableOpacity
          style={styles.viewFullDescriptionButton}
          onPress={handleViewFullDescription}
          activeOpacity={0.7}
        >
          <Icon
            name="description"
            size={RFValue(18)}
            color={colors.primaryBlue}
          />
          <CustomText
            style={styles.viewFullDescriptionText}
            fontFamily={Fonts.SemiBold}
            fontSize={14}
          >
            View Full Description
          </CustomText>
          <Icon
            name="arrow-forward"
            size={RFValue(18)}
            color={colors.primaryBlue}
          />
        </TouchableOpacity>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: colors.white,
    borderRadius: 0,
    paddingTop: 16,
    paddingBottom: 20,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginHorizontal: 16,
    marginBottom: 12,
  },
  headingText: {
    flex: 1,
  },
  cancelledBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.lightRed,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
    gap: 4,
  },
  cancelledText: {
    color: colors.cancelled,
  },
  cancelledTotal: {
    textDecorationLine: 'line-through',
    opacity: 0.6,
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
    paddingHorizontal: 8,
    paddingTop: 4,
    paddingBottom: 0,
    borderBottomColor: Colors.border,
    borderBottomWidth: 0.7,
  },
  flexRowBetween: {
    justifyContent: 'space-between',
    alignItems: 'center',
    flexDirection: 'row',
    paddingHorizontal: 8,
  },
  flexRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
  },
  totalRow: {
    marginTop: 16,
  },
  viewFullDescriptionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    marginTop: 20,
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: colors.backgroundSecondary,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: colors.primaryBlue,
  },
  viewFullDescriptionText: {
    color: colors.primaryBlue,
    flex: 1,
    textAlign: 'center',
  },
});

export default PackageBillDetails;
