import 'react-native-gesture-handler';
import React, { useEffect } from 'react';
import { StatusBar, AppState } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import Navigation from '@navigation/Navigation';
import { tokenManager } from '@service/tokenManager';
import { useAuthStore } from '@state/authStore';
import { useDeliverySettingsStore } from '@state/deliverySettingsStore';

/**
 * Root app container.
 * - Sets up gesture + safe area providers.
 * - Mounts navigation.
 * - Starts/stops token monitoring based on login state.
 */
const App = () => {
  const { user } = useAuthStore();
  const loadDeliverySettings = useDeliverySettingsStore(
    (state) => state.loadSettings
  );

  useEffect(() => {
    loadDeliverySettings().catch((error) => {
      console.warn('Unable to load delivery settings at app startup.', error);
    });
  }, [loadDeliverySettings]);

  useEffect(() => {
    // Start token monitoring when user is logged in
    if (user) {
      tokenManager.startTokenMonitoring();
    } else {
      tokenManager.stopTokenMonitoring();
    }

    // Handle app state changes
    const handleAppStateChange = (nextAppState: string) => {
      if (nextAppState === 'active' && user) {
        // Check token when app becomes active
        tokenManager.checkAndRefreshToken();
      }
    };

    const subscription = AppState.addEventListener('change', handleAppStateChange);

    return () => {
      subscription?.remove();
      tokenManager.stopTokenMonitoring();
    };
  }, [user]);

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <StatusBar translucent backgroundColor="transparent" />
        <Navigation />
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
};

export default App;
