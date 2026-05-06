import React from 'react';
import {
  Modal,
  StyleSheet,
  TouchableOpacity,
  TouchableWithoutFeedback,
  View,
} from 'react-native';
import CustomText from './CustomText';
import { Fonts } from '@utils/Constants';
import colors from '../../theme/colors';
import { RFValue } from 'react-native-responsive-fontsize';
import IonIcon from 'react-native-vector-icons/Ionicons';

/**
 * Custom modal alert used instead of native Alert for consistent branding and actions.
 */
type AlertType = 'info' | 'success' | 'warning' | 'error';

interface CustomAlertProps {
  visible: boolean;
  title: string;
  message?: string;
  type?: AlertType;
  primaryButtonText?: string;
  secondaryButtonText?: string;
  onPrimaryPress?: () => void;
  onSecondaryPress?: () => void;
  onClose: () => void;
  showSecondaryButton?: boolean;
}

const getIconName = (type: AlertType): string => {
  switch (type) {
    case 'success':
      return 'checkmark-circle-outline';
    case 'warning':
      return 'warning-outline';
    case 'error':
      return 'close-circle-outline';
    default:
      return 'information-circle-outline';
  }
};

const CustomAlert: React.FC<CustomAlertProps> = ({
  visible,
  title,
  message,
  type = 'info',
  primaryButtonText = 'OK',
  secondaryButtonText = 'Cancel',
  onPrimaryPress,
  onSecondaryPress,
  onClose,
  showSecondaryButton = false,
}) => {
  const handlePrimaryPress = () => {
    onClose();
    onPrimaryPress?.();
  };

  const handleSecondaryPress = () => {
    onClose();
    onSecondaryPress?.();
  };

  return (
    <Modal
      visible={visible}
      transparent={true}
      animationType="fade"
      onRequestClose={onClose}
    >
      <TouchableWithoutFeedback onPress={onClose}>
        <View style={styles.modalOverlay}>
          <TouchableWithoutFeedback onPress={() => {}}>
            <View style={styles.alertCard}>
              <View style={styles.iconWrapper}>
                <IonIcon
                  name={getIconName(type)}
                  size={RFValue(32)}
                  color={colors.primaryBlue}
                />
              </View>

              <CustomText variant="h5" fontFamily={Fonts.Bold} style={styles.title}>
                {title}
              </CustomText>

              {message && (
                <CustomText variant="h7" style={styles.message}>
                  {message}
                </CustomText>
              )}

              <View style={styles.buttonContainer}>
                {showSecondaryButton && (
                  <TouchableOpacity
                    style={[styles.button, styles.secondaryButton]}
                    onPress={handleSecondaryPress}
                  >
                    <CustomText variant="h7" fontFamily={Fonts.Medium} style={styles.secondaryText}>
                      {secondaryButtonText}
                    </CustomText>
                  </TouchableOpacity>
                )}

                <TouchableOpacity
                  style={[
                    styles.button,
                    styles.primaryButton,
                    showSecondaryButton && styles.flexButton,
                  ]}
                  onPress={handlePrimaryPress}
                >
                  <CustomText variant="h7" fontFamily={Fonts.Medium} style={styles.primaryText}>
                    {primaryButtonText}
                  </CustomText>
                </TouchableOpacity>
              </View>
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
  alertCard: {
    backgroundColor: colors.white,
    borderRadius: 20,
    padding: 24,
    alignItems: 'center',
    width: '100%',
    maxWidth: 340,
    alignSelf: 'center',
    shadowColor: colors.black,
    shadowOffset: {
      width: 0,
      height: 10,
    },
    shadowOpacity: 0.25,
    shadowRadius: 20,
    elevation: 10,
  },
  iconWrapper: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: colors.primaryBlueOpacity10,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
  },
  title: {
    color: colors.primaryBlue,
    marginBottom: 8,
    textAlign: 'center',
  },
  message: {
    textAlign: 'center',
    opacity: 0.8,
    marginBottom: 24,
    lineHeight: 22,
  },
  buttonContainer: {
    width: '100%',
    flexDirection: 'row',
    gap: 12,
  },
  button: {
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  flexButton: {
    flex: 1,
  },
  primaryButton: {
    backgroundColor: colors.primaryBlue,
    width: '100%',
  },
  secondaryButton: {
    backgroundColor: colors.lightBlue,
    borderWidth: 1,
    borderColor: colors.primaryBlue,
    flex: 1,
  },
  primaryText: {
    color: colors.white,
  },
  secondaryText: {
    color: colors.primaryBlue,
  },
});

export default CustomAlert;
