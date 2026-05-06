import React, { FC } from 'react';
import {
  Modal,
  View,
  StyleSheet,
  Dimensions,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import CustomText from './CustomText';
import CustomButton from './CustomButton';
import { Fonts } from '@utils/Constants';
import colors from '../../theme/colors';

/**
 * Session-expired dialog shown after refresh token failure.
 */
const { width } = Dimensions.get('window');

interface SessionExpiredModalProps {
  visible: boolean;
  onLoginAgain: () => void;
}

const SessionExpiredModal: FC<SessionExpiredModalProps> = ({
  visible,
  onLoginAgain,
}) => {
  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onLoginAgain}
    >
      <View style={styles.overlay}>
        <View style={styles.modalContainer}>
          {/* Blue Header Section */}
          <View style={styles.header}>
            <View style={styles.iconContainer}>
              <Icon name="schedule" size={48} color={colors.primaryBlue} />
            </View>
          </View>

          {/* White Content Section */}
          <View style={styles.content}>
            <CustomText
              fontFamily={Fonts.Medium}
              style={styles.message}
            >
              Please login again
            </CustomText>
          </View>

          {/* Action Button */}
          <View style={styles.buttonContainer}>
            <CustomButton
              onPress={onLoginAgain}
              title="OK"
              buttonColor={colors.primaryBlue}
              disabled={false}
              loading={false}
            />
          </View>
        </View>
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 20,
  },
  modalContainer: {
    backgroundColor: colors.white,
    width: width * 0.8,
    maxWidth: 350,
    borderRadius: 20,
    overflow: 'hidden',
    elevation: 15,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 8,
    },
    shadowOpacity: 0.3,
    shadowRadius: 12,
  },
  header: {
    backgroundColor: colors.primaryBlue,
    paddingVertical: 24,
    paddingHorizontal: 24,
    alignItems: 'center',
  },
  iconContainer: {
    backgroundColor: colors.white,
    width: 60,
    height: 60,
    borderRadius: 30,
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.2,
    shadowRadius: 4,
  },
  content: {
    paddingVertical: 24,
    paddingHorizontal: 24,
    alignItems: 'center',
  },
  message: {
    textAlign: 'center',
    color: colors.black,
    fontSize: 16,
    lineHeight: 24,
  },
  buttonContainer: {
    paddingHorizontal: 24,
    paddingBottom: 24,
  },
});

export default SessionExpiredModal;
