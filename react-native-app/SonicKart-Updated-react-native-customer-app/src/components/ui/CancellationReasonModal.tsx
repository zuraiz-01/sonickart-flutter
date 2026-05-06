import React, { useState } from 'react';
import {
  View,
  Modal,
  TouchableOpacity,
  TouchableWithoutFeedback,
  StyleSheet,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import { RFValue } from 'react-native-responsive-fontsize';
import CustomText from './CustomText';
import { Fonts } from '@utils/Constants';
import colors from '../../theme/colors';

/**
 * Cancellation reason selector used before cancelling regular product orders.
 */
interface CancellationReasonModalProps {
  visible: boolean;
  onClose: () => void;
  onSelectReason: (reason: string) => void;
  loading?: boolean;
}

const CANCELLATION_REASONS = [
  {
    id: '1',
    title: 'Ordered by mistake',
    icon: 'alert-circle-outline',
  },
  {
    id: '2',
    title: 'Wrong address or delivery location',
    icon: 'map-marker-off-outline',
  },
  {
    id: '3',
    title: 'Found a better price or offer',
    icon: 'tag-outline',
  },
  {
    id: '4',
    title: "Don't need the items anymore",
    icon: 'close-circle-outline',
  },
  {
    id: '5',
    title: 'Delivery time is too long',
    icon: 'clock-alert-outline',
  },
];

const CancellationReasonModal: React.FC<CancellationReasonModalProps> = ({
  visible,
  onClose,
  onSelectReason,
  loading = false,
}) => {
  const [selectedReason, setSelectedReason] = useState<string | null>(null);

  const handleReasonSelect = (reason: string) => {
    setSelectedReason(reason);
  };

  const handleConfirmCancellation = () => {
    if (selectedReason) {
      onSelectReason(selectedReason);
      setSelectedReason(null); // Reset selection
    }
  };

  const handleClose = () => {
    setSelectedReason(null); // Reset selection when closing
    onClose();
  };

  return (
    <Modal
      visible={visible}
      transparent={true}
      animationType="fade"
      onRequestClose={handleClose}
    >
      <TouchableWithoutFeedback onPress={handleClose}>
        <View style={styles.modalOverlay}>
          <TouchableWithoutFeedback onPress={() => {}}>
            <View style={styles.modalContainer}>
              <View style={styles.header}>
                <CustomText variant="h6" fontFamily={Fonts.Bold} style={styles.title}>
                  Why are you cancelling?
                </CustomText>
                <CustomText variant="h8" style={styles.subtitle}>
                  Please select a reason for cancellation
                </CustomText>
              </View>

              <View style={styles.reasonsList}>
                {CANCELLATION_REASONS.map((reason) => (
                  <TouchableOpacity
                    key={reason.id}
                    style={[
                      styles.reasonItem,
                      selectedReason === reason.title && styles.reasonItemSelected,
                    ]}
                    onPress={() => handleReasonSelect(reason.title)}
                    disabled={loading}
                  >
                    <View style={[
                      styles.reasonIconContainer,
                      selectedReason === reason.title && styles.reasonIconSelected,
                    ]}>
                      <Icon
                        name={reason.icon}
                        size={RFValue(18)}
                        color={selectedReason === reason.title ? colors.white : colors.primaryBlue}
                      />
                    </View>
                    <View style={styles.reasonTextContainer}>
                      <CustomText
                        variant="h8"
                        fontFamily={selectedReason === reason.title ? Fonts.SemiBold : Fonts.Medium}
                        style={styles.reasonText}
                      >
                        {reason.title}
                      </CustomText>
                    </View>
                    {selectedReason === reason.title && (
                      <Icon
                        name="check-circle"
                        size={RFValue(20)}
                        color={colors.primaryBlue}
                      />
                    )}
                  </TouchableOpacity>
                ))}
              </View>

              <TouchableOpacity
                style={[
                  styles.confirmButton,
                  (!selectedReason || loading) && styles.confirmButtonDisabled,
                ]}
                onPress={handleConfirmCancellation}
                disabled={!selectedReason || loading}
              >
                <CustomText
                  variant="h7"
                  fontFamily={Fonts.SemiBold}
                  style={[
                    styles.confirmButtonText,
                    (!selectedReason || loading) ? styles.confirmButtonTextDisabled : {},
                  ]}
                >
                  {loading ? 'Cancelling...' : 'Cancel Order'}
                </CustomText>
              </TouchableOpacity>
            </View>
          </TouchableWithoutFeedback>
        </View>
      </TouchableWithoutFeedback>
    </Modal>
  );
};

const styles = StyleSheet.create({
  modalOverlay: {
    flex: 1,
    backgroundColor: colors.blackOpacity40,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  modalContainer: {
    backgroundColor: colors.white,
    borderRadius: 16,
    padding: 20,
    width: '90%',
    maxWidth: 320,
    maxHeight: '70%',
    shadowColor: colors.black,
    shadowOffset: {
      width: 0,
      height: 8,
    },
    shadowOpacity: 0.25,
    shadowRadius: 16,
    elevation: 8,
  },
  header: {
    alignItems: 'center',
    marginBottom: 20,
  },
  title: {
    color: colors.primaryBlue,
    marginBottom: 6,
    textAlign: 'center',
  },
  subtitle: {
    textAlign: 'center',
    opacity: 0.7,
    lineHeight: 18,
  },
  reasonsList: {
    marginBottom: 20,
  },
  reasonItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 10,
    borderRadius: 10,
    marginBottom: 6,
    backgroundColor: colors.lightBlue,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
  },
  reasonItemSelected: {
    backgroundColor: colors.primaryBlueOpacity10,
    borderColor: colors.primaryBlue,
  },
  reasonIconContainer: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: colors.primaryBlueOpacity10,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 10,
  },
  reasonIconSelected: {
    backgroundColor: colors.primaryBlue,
  },
  reasonTextContainer: {
    flex: 1,
  },
  reasonText: {
    color: colors.primaryBlue,
    lineHeight: 20,
  },
  confirmButton: {
    backgroundColor: colors.primaryBlue,
    paddingVertical: 12,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  confirmButtonDisabled: {
    backgroundColor: colors.disabled,
    opacity: 0.6,
  },
  confirmButtonText: {
    color: colors.white,
  },
  confirmButtonTextDisabled: {
    opacity: 0.7,
  },
});

export default CancellationReasonModal;
