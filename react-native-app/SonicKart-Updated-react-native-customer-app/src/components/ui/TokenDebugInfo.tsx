import React, { useState, useEffect } from 'react';
import { View, StyleSheet } from 'react-native';
import CustomText from './CustomText';
import { tokenManager } from '@service/tokenManager';
import { Fonts } from '@utils/Constants';
import colors from '../../theme/colors';

const TokenDebugInfo: React.FC = () => {
  const [expiryTime, setExpiryTime] = useState<number | null>(null);

  useEffect(() => {
    const updateExpiryTime = () => {
      const time = tokenManager.getTokenExpiryTime();
      setExpiryTime(time);
    };

    updateExpiryTime();
    const interval = setInterval(updateExpiryTime, 60000); // Update every minute

    return () => clearInterval(interval);
  }, []);

  if (!expiryTime || expiryTime <= 0) {return null;}

  const getStatusColor = () => {
    if (expiryTime < 60) {return colors.red;} // Less than 1 hour
    if (expiryTime < 180) {return colors.orange;} // Less than 3 hours
    return colors.green;
  };

  const formatTime = (minutes: number) => {
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;

    if (hours > 0) {
      return `${hours}h ${mins}m`;
    }
    return `${mins}m`;
  };

  return (
    <View style={styles.container}>
      <CustomText
        fontFamily={Fonts.Medium}
        style={[styles.text, { color: getStatusColor() }]}
      >
        Token expires in: {formatTime(expiryTime)}
      </CustomText>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    top: 50,
    right: 10,
    backgroundColor: 'rgba(255, 255, 255, 0.9)',
    padding: 8,
    borderRadius: 8,
    zIndex: 1000,
  },
  text: {
    fontSize: 12,
  },
});

export default TokenDebugInfo;
