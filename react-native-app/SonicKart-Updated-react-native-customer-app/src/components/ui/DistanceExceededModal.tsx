import React, { FC } from 'react';
import {
  Modal,
  View,
  StyleSheet,
  Dimensions,
} from 'react-native';

const { width } = Dimensions.get('window');
import Icon from 'react-native-vector-icons/MaterialIcons';
import CustomText from './CustomText';
import CustomButton from './CustomButton';
import { Fonts } from '@utils/Constants';
import colors from '../../theme/colors';

/**
 * Informational modal shown when pickup/drop distance exceeds allowed package range.
 */
interface DistanceExceededModalProps {
  visible: boolean;
  onClose: () => void;
  distance: number;
  maxDistance: number;
}

const DistanceExceededModal: FC<DistanceExceededModalProps> = ({
  visible,
  onClose,
  distance,
  maxDistance,
}) => {
  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onClose}
    >
      <View style={styles.overlay}>
        <View style={styles.modalContainer}>
          {/* Header with icon */}
          <View style={styles.header}>
            <View style={styles.iconContainer}>
              <Icon name="location-off" size={40} color={colors.primaryBlue} />
            </View>
            <CustomText
              fontFamily={Fonts.Bold}
              style={styles.title}
            >
              Delivery Range Exceeded
            </CustomText>
          </View>

          {/* Content */}
          <View style={styles.content}>
            <CustomText
              fontFamily={Fonts.Medium}
              style={styles.message}
            >
              The delivery distance of {distance.toFixed(1)} km exceeds our maximum delivery range of {maxDistance} km.
            </CustomText>
            <CustomText
              fontFamily={Fonts.Medium}
              style={styles.subMessage}
            >
              Please choose locations within our delivery area.
            </CustomText>
            <CustomText
              fontFamily={Fonts.Medium}
              style={styles.subMessage}
            >
              Delivery available only within {maxDistance}km
            </CustomText>
          </View>

          {/* Action Button */}
          <View style={styles.buttonContainer}>
            <CustomButton
              onPress={onClose}
              title="OK, Got it"
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
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 20,
  },
  modalContainer: {
    backgroundColor: colors.white,
    borderRadius: 16,
    width: width * 0.8,
    maxWidth: 320,
    padding: 24,
    overflow: 'hidden',
    elevation: 10,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.25,
    shadowRadius: 8,
  },
  header: {
    backgroundColor: colors.primaryBlue,
    paddingVertical: 20,
    paddingHorizontal: 16,
    alignItems: 'center',
    marginBottom: 20,
  },
  iconContainer: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: colors.cyan, // Teal color
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 10,
  },
  title: {
    color: colors.white,
    textAlign: 'center',
    fontSize: 18,
  },
  content: {
    paddingVertical: 24,
    paddingHorizontal: 18,
    justifyContent: 'center',
    alignItems: 'center',
    minHeight: 60,
    marginBottom: 20,
  },
  message: {
    textAlign: 'center',
    color: colors.black,
    fontSize: 16,
    marginBottom: 0,
  },
  subMessage: {
    textAlign: 'center',
    color: colors.black,
    fontSize: 14,
    marginTop: 8,
    marginBottom: 0,
  },
  buttonContainer: {
    paddingHorizontal: 18,
    paddingBottom: 18,
  },
});

export default DistanceExceededModal;
