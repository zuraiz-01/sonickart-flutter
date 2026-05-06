import { useState } from 'react';

type AlertType = 'info' | 'success' | 'warning' | 'error';

interface AlertConfig {
  title: string;
  message?: string;
  type?: AlertType;
  primaryButtonText?: string;
  secondaryButtonText?: string;
  onPrimaryPress?: () => void;
  onSecondaryPress?: () => void;
  showSecondaryButton?: boolean;
}

export const useCustomAlert = () => {
  const [alertConfig, setAlertConfig] = useState<AlertConfig | null>(null);
  const [isVisible, setIsVisible] = useState(false);

  const showAlert = (config: AlertConfig) => {
    setAlertConfig(config);
    setIsVisible(true);
  };

  const hideAlert = () => {
    setIsVisible(false);
    setAlertConfig(null);
  };

  // Convenience methods for different alert types
  const showInfo = (title: string, message?: string, onPress?: () => void) => {
    showAlert({
      title,
      message,
      type: 'info',
      onPrimaryPress: onPress,
    });
  };

  const showSuccess = (title: string, message?: string, onPress?: () => void) => {
    showAlert({
      title,
      message,
      type: 'success',
      onPrimaryPress: onPress,
    });
  };

  const showWarning = (title: string, message?: string, onPress?: () => void) => {
    showAlert({
      title,
      message,
      type: 'warning',
      onPrimaryPress: onPress,
    });
  };

  const showError = (title: string, message?: string, onPress?: () => void) => {
    showAlert({
      title,
      message,
      type: 'error',
      onPrimaryPress: onPress,
    });
  };

  const showConfirm = (
    title: string,
    message?: string,
    onConfirm?: () => void,
    onCancel?: () => void,
    confirmText = 'Yes',
    cancelText = 'No'
  ) => {
    showAlert({
      title,
      message,
      type: 'warning',
      primaryButtonText: confirmText,
      secondaryButtonText: cancelText,
      onPrimaryPress: onConfirm,
      onSecondaryPress: onCancel,
      showSecondaryButton: true,
    });
  };

  return {
    alertConfig,
    isVisible,
    showAlert,
    hideAlert,
    showInfo,
    showSuccess,
    showWarning,
    showError,
    showConfirm,
  };
};
