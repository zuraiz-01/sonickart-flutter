export const GOOGLE_MAP_API = 'AIzaSyBFCpSF0bW2Z8UWxoN0Y_fefdwzI3Wlej0';
import { Platform } from 'react-native';

/**
 * Central runtime configuration.
 * Keeps API base URL, socket URL, and Google Maps key in one place.
 */
/**
 * Development servers for local testing only
 * - Android emulator uses 10.0.2.2 → maps to your host machine’s localhost
 * - iOS simulator can use localhost directly
 */

const LOCALHOST_CONFIG = {

  ANDROID: 'https://api.sonickartnow.com/mobile',
  IOS: 'https://api.sonickartnow.com/mobile',
};

// Select correct host based on platform
const SELECTED_HOST =
  Platform.OS === 'ios'
    ? LOCALHOST_CONFIG.IOS
    : LOCALHOST_CONFIG.ANDROID;

// Final URLs
export const BASE_URL = `${SELECTED_HOST}/api`;
export const SOCKET_URL = SELECTED_HOST;

