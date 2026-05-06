import axios from 'axios';
import { BASE_URL } from './config';
import { tokenStorage } from '@state/storage';
import { refresh_tokens } from './authService';
import { Alert } from 'react-native';

/**
 * Shared axios client used across authenticated APIs.
 * - Adds bearer token on each request.
 * - Auto-refreshes token on 401 once, then retries.
 * - Shows generic alert for non-401 server errors.
 */
export const appAxios = axios.create({
  baseURL: BASE_URL,
});

appAxios.interceptors.request.use(async (config) => {
  const accessToken = tokenStorage.getString('accessToken');
  if (accessToken) {
    config.headers.Authorization = `Bearer ${accessToken}`;
  }
  return config;
});

appAxios.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    // Handle 401 errors (token expired)
    if (error.response && error.response.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      try {
        const newAccessToken = await refresh_tokens();
        if (newAccessToken) {
          // Update the authorization header and retry the request
          originalRequest.headers.Authorization = `Bearer ${newAccessToken}`;
          return appAxios(originalRequest);
        }
      } catch (refreshError) {
        console.log('ERROR REFRESHING TOKEN', refreshError);
        // Token refresh failed, session expired modal will be shown by refresh_tokens function
        return Promise.reject(error);
      }
    }

    // Handle other errors (but not 401 since we handle that above)
    if (error.response && error.response.status !== 401) {
      const errorMessage = error.response.data?.message || 'Something went wrong';
      Alert.alert('Error', errorMessage);
    }

    return Promise.reject(error);
  }
);
