import { StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import colors from '../theme/colors';
import Typography from './Typography';

// Helper hook to get safe area aware styles
export const useSafeAreaStyles = () => {
  const insets = useSafeAreaInsets();

  return StyleSheet.create({
    cartContainer: {
      position: 'absolute',
      left: 16,
      right: 16,
      bottom: 120 + insets.bottom,
      backgroundColor: colors.white,
      borderRadius: 16,
      paddingHorizontal: 14,
      paddingVertical: 8,
      elevation: 12,
      shadowColor: colors.black,
      shadowOffset: { width: 0, height: 6 },
      shadowOpacity: 0.18,
      shadowRadius: 8,
      zIndex: 999,
    },
  });
};

// Backward-compatible alias for existing imports
export const getSafeAreaStyles = useSafeAreaStyles;

export const hocStyles = StyleSheet.create({
  cartContainer: {
    position: 'absolute',
    left: 16,
    right: 16,
    bottom: 120, // Default fallback - components should use getSafeAreaStyles() instead
    backgroundColor: colors.white,
    borderRadius: 16,
    paddingHorizontal: 14,
    paddingVertical: 8,
    elevation: 12,
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.18,
    shadowRadius: 8,
    zIndex: 999,
  },
});

// Export typography styles for easy access
export { Typography };
export default { hocStyles, Typography };
