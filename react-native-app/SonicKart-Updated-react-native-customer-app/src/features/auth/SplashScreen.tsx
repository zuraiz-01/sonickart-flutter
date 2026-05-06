import { View, StyleSheet, Image, Alert, StatusBar } from 'react-native';
import React, { FC, useCallback, useEffect } from 'react';
import SplashIllustration from '@assets/images/SonicKartsplash.jpeg';
import LinearGradient from 'react-native-linear-gradient';
import GeoLocation from '@react-native-community/geolocation';
import { useAuthStore } from '@state/authStore';
import { useLocationStore } from '@state/locationStore';
import { tokenStorage } from '@state/storage';
import { resetAndNavigate } from '@utils/NavigationUtils';
import { jwtDecode } from 'jwt-decode';
import { refetchUser, refresh_tokens } from '@service/authService';

const SPLASH_ASPECT_RATIO = 1024 / 1352;

GeoLocation.setRNConfiguration({
  skipPermissionRequests: false,
  authorizationLevel: 'always',
  enableBackgroundLocationUpdates: true,
  locationProvider: 'auto',
});

interface DecodedToken {
  exp: number;
}

/**
 * Startup gate screen.
 * Validates token state and decides initial route (dashboard vs login).
 */
const SplashScreen: FC = () => {
  const { user, setUser } = useAuthStore();
  const clearLocationSelection = useLocationStore(
    (state) => state.clearLocationSelection
  );

  const tokenCheck = useCallback(async () => {
    const accessToken = tokenStorage.getString('accessToken') as string;
    const refreshToken = tokenStorage.getString('refreshToken') as string;

    if (accessToken) {
      if (!refreshToken) {
        const { setShowSessionExpiredModal } = useAuthStore.getState();
        setShowSessionExpiredModal(true);
        return false;
      }

      const decodedAccessToken = jwtDecode<DecodedToken>(accessToken);
      const decodedRefreshToken = jwtDecode<DecodedToken>(refreshToken);

      const currentTime = Date.now() / 1000;

      if (decodedRefreshToken?.exp < currentTime) {
        const { setShowSessionExpiredModal } = useAuthStore.getState();
        setShowSessionExpiredModal(true);
        return false;
      }

      if (decodedAccessToken?.exp < currentTime) {
        try {
          await refresh_tokens();
          await refetchUser(setUser);
        } catch (error) {
          console.log(error);
          Alert.alert('There was an error refreshing token!');
          return false;
        }
      }

      // Only navigate to ProductDashboard for customers
      // Delivery functionality is commented out
      if (user?.role === 'Customer') {
        resetAndNavigate('ProductDashboard');
      } else {
        // resetAndNavigate("DeliveryDashboard") // Commented out
        resetAndNavigate('ProductDashboard'); // Default to customer dashboard
      }

      return true;
    }
    resetAndNavigate('CustomerLogin');
    return false;
  }, [setUser, user]);

  useEffect(() => {
    const fetchUserLocation = async () => {
      try {
        // Always start with device live location context on a fresh app launch.
        clearLocationSelection();
        GeoLocation.requestAuthorization();
        await tokenCheck();
      } catch (error) {
        Alert.alert('Sorry we need location service to give you better shopping experience');
      }
    };
    const timeoutId = setTimeout(fetchUserLocation, 1000);
    return () => clearTimeout(timeoutId);
  }, [clearLocationSelection, tokenCheck]);

  return (
    <LinearGradient
      colors={['#01296F', '#002870', '#001F50']}
      start={{ x: 0, y: 0 }}
      end={{ x: 0.85, y: 1 }}
      style={styles.container}
    >
      <StatusBar translucent backgroundColor="transparent" barStyle="light-content" />
      <View style={styles.logoWrapper}>
        <Image source={SplashIllustration} style={styles.logoImage} resizeMode="contain" />
      </View>
    </LinearGradient>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  logoWrapper: {
    width: '78%',
    maxWidth: 360,
    aspectRatio: SPLASH_ASPECT_RATIO,
    justifyContent: 'center',
    alignItems: 'center',
  },
  logoImage: {
    width: '100%',
    height: '100%',
  },
});

export default SplashScreen;
