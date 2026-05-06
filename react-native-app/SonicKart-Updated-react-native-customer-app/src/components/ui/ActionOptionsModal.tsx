import React from 'react';
import {
  Modal,
  StyleSheet,
  TouchableOpacity,
  TouchableWithoutFeedback,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import CustomText from './CustomText';
import { Fonts } from '@utils/Constants';
import colors from '../../theme/colors';

/**
 * Generic action-selection modal (primary/secondary/ghost options).
 */
type OptionType = 'primary' | 'secondary' | 'ghost';

type Option = {
  label: string;
  onPress?: () => void;
  type?: OptionType;
};

interface ActionOptionsModalProps {
  visible: boolean;
  title: string;
  message?: string;
  options: Option[];
  onClose: () => void;
}

const PRIMARY = '#092774';

const formatHeadingCase = (text?: string) => {
  if (!text) {
    return '';
  }

  const trimmed = text.trim();
  if (!trimmed) {
    return '';
  }

  return trimmed.charAt(0).toUpperCase() + trimmed.slice(1).toLowerCase();
};

const ActionOptionsModal: React.FC<ActionOptionsModalProps> = ({
  visible,
  title,
  message,
  options,
  onClose,
}) => {
  const insets = useSafeAreaInsets();

  const handleOptionPress = (option: Option) => {
    onClose();
    option?.onPress?.();
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      presentationStyle="overFullScreen"
      statusBarTranslucent
      navigationBarTranslucent
      hardwareAccelerated
      onRequestClose={onClose}
    >
      <TouchableWithoutFeedback onPress={onClose}>
        <View
          style={[
            styles.overlay,
            {
              paddingTop: Math.max(24, insets.top + 12),
              paddingBottom: Math.max(24, insets.bottom + 16),
            },
          ]}
        >
          <TouchableWithoutFeedback onPress={() => {}}>
            <View style={styles.card}>
              <CustomText variant="h5" fontFamily={Fonts.Bold} style={styles.title}>
                {title}
              </CustomText>
              {message ? (
                <CustomText variant="h8" style={styles.message}>
                  {message}
                </CustomText>
              ) : null}

              <View style={styles.optionsContainer}>
                {options.map((option, index) => (
                  <TouchableOpacity
                    key={`${option.label}-${index}`}
                    style={[
                      styles.optionButton,
                      option.type === 'primary' && styles.primaryButton,
                      option.type === 'secondary' && styles.secondaryButton,
                      option.type === 'ghost' && styles.ghostButton,
                    ]}
                    activeOpacity={0.85}
                    onPress={() => handleOptionPress(option)}
                  >
                    <CustomText
                      variant="h7"
                      fontFamily={Fonts.Bold}
                      style={[
                        styles.optionText,
                        option.type === 'primary' && styles.primaryText,
                        option.type === 'secondary' && styles.secondaryText,
                        option.type === 'ghost' && styles.ghostText,
                      ]}
                    >
                      {formatHeadingCase(option.label)}
                    </CustomText>
                  </TouchableOpacity>
                ))}
              </View>
            </View>
          </TouchableWithoutFeedback>
        </View>
      </TouchableWithoutFeedback>
    </Modal>
  );
};

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    position: 'absolute',
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    backgroundColor: 'rgba(9,39,116,0.35)',
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 24,
    paddingVertical: 24,
  },
  card: {
    width: '92%',
    maxWidth: 380,
    maxHeight: '90%',
    backgroundColor: colors.white,
    borderRadius: 18,
    padding: 24,
    borderWidth: 1.5,
    borderColor: PRIMARY,
    shadowColor: PRIMARY,
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.18,
    shadowRadius: 20,
    elevation: 10,
  },
  title: {
    color: PRIMARY,
    textAlign: 'center',
    letterSpacing: 0.8,
    fontWeight: '700',
  },
  message: {
    marginTop: 8,
    textAlign: 'center',
    color: colors.greyText,
  },
  optionsContainer: {
    marginTop: 20,
    gap: 12,
  },
  optionButton: {
    paddingVertical: 14,
    borderRadius: 12,
    borderWidth: 1.5,
    borderColor: PRIMARY,
    justifyContent: 'center',
    alignItems: 'center',
  },
  primaryButton: {
    backgroundColor: PRIMARY,
  },
  secondaryButton: {
    backgroundColor: colors.white,
  },
  ghostButton: {
    borderColor: 'transparent',
    backgroundColor: 'transparent',
  },
  optionText: {
    color: PRIMARY,
    letterSpacing: 0.8,
    fontWeight: '700',
  },
  primaryText: {
    color: colors.white,
  },
  secondaryText: {
    color: PRIMARY,
  },
  ghostText: {
    color: colors.greyText,
  },
});

export default ActionOptionsModal;
