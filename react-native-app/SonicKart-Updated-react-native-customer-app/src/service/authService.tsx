// import axios from 'axios';
// import { BASE_URL } from './config';
// import { tokenStorage, storage } from '@state/storage';
// import { useAuthStore } from '@state/authStore';
// import { appAxios } from './apiInterceptors';
// import auth from '@react-native-firebase/auth';

// /**
//  * Auth and user profile service methods.
//  * Handles login, user refresh/update, and refresh-token lifecycle.
//  */
// export const deliveryLogin = async (email: string, password: string) => {
//   try {
//     const response = await axios.post(`${BASE_URL}/delivery/login`, {
//       email,
//       password,
//     });
//     const { accessToken, refreshToken, deliveryPartner } = response.data;
//     tokenStorage.set('accessToken', accessToken);
//     tokenStorage.set('refreshToken', refreshToken);
//     const { setUser } = useAuthStore.getState();
//     setUser(deliveryPartner);
//     return deliveryPartner;
//   } catch (error: any) {
//     throw error;
//   }
// };

// export const customerLogin = async (phone: string, agreement?: boolean) => {
//   try {
//     const response = await axios.post(`${BASE_URL}/customer/login`, {
//       phone,
//       agreement,
//     });
//     const { accessToken, refreshToken, customer } = response.data;
//     tokenStorage.set('accessToken', accessToken);
//     tokenStorage.set('refreshToken', refreshToken);
//     const { setUser } = useAuthStore.getState();
//     setUser(customer);
//     return customer;
//   } catch (error: any) {
//     // Re-throw so UI can show specific server message
//     throw error;
//   }
// };

// export const refetchUser = async (setUser: any) => {
//   try {
//     const response = await appAxios.get('/user');
//     setUser(response.data.user);
//   } catch (error) {
//     console.log('Login Error', error);
//   }
// };

// export const updateUserLocation = async (data: any, setUser: any) => {
//   try {
//     await appAxios.patch('/user', data);
//     refetchUser(setUser);
//   } catch (error) {
//     console.log('updateUserLocation Error', error);
//   }
// };

// export const updateUserProfile = async (data: any) => {
//   try {
//     const { setUser } = useAuthStore.getState();
//     await appAxios.patch('/user', data);
//     await refetchUser(setUser);
//   } catch (error) {
//     console.log('updateUserProfile Error', error);
//     throw error;
//   }
// };

// export const refresh_tokens = async () => {
//   try {
//     const refreshToken = tokenStorage.getString('refreshToken');

//     if (!refreshToken) {
//       throw new Error('No refresh token available');
//     }

//     const response = await axios.post(`${BASE_URL}/refresh-token`, {
//       refreshToken,
//     });

//     const new_access_token = response.data.accessToken;
//     const new_refresh_token = response.data.refreshToken;

//     tokenStorage.set('accessToken', new_access_token);
//     tokenStorage.set('refreshToken', new_refresh_token);
//     return new_access_token;
//   } catch (error) {
//     console.log('REFRESH TOKEN ERROR', error);

//     // Clear all tokens and storage
//     tokenStorage.clearAll();
//     storage.clearAll();

//     // Show session expired modal with a slight delay to ensure UI is ready
//     setTimeout(() => {
//       const { setShowSessionExpiredModal } = useAuthStore.getState();
//       setShowSessionExpiredModal(true);
//     }, 100);

//     throw error; // Re-throw to let interceptor handle it
//   }
// };

// export const logoutAndClearSession = async () => {
//   try {
//     // Ensure Firebase phone-auth session is cleared only on explicit logout.
//     await auth().signOut();
//   } catch (error) {
//     console.log('Firebase signOut error', error);
//   } finally {
//     const { logout } = useAuthStore.getState();
//     logout();
//     tokenStorage.clearAll();
//     storage.clearAll();
//   }
// };
import axios from 'axios';
import { BASE_URL } from './config';
import { tokenStorage, storage } from '@state/storage';
import { useAuthStore } from '@state/authStore';
import { useLocationStore } from '@state/locationStore';
import { appAxios } from './apiInterceptors';
import auth from '@react-native-firebase/auth';

/**
 * Auth and user profile service methods.
 * Handles login, user refresh/update, and refresh-token lifecycle.
 */
export const deliveryLogin = async (email: string, password: string) => {
  try {
    const response = await axios.post(`${BASE_URL}/delivery/login`, {
      email,
      password,
    });
    const { accessToken, refreshToken, deliveryPartner } = response.data;
    tokenStorage.set('accessToken', accessToken);
    tokenStorage.set('refreshToken', refreshToken);
    const { setUser } = useAuthStore.getState();
    setUser(deliveryPartner);
    return deliveryPartner;
  } catch (error: any) {
    throw error;
  }
};

type CustomerLoginVerificationData = {
  firebaseIdToken?: string;
  firebaseUid?: string;
  phoneE164?: string;
};

const applyCustomerAuthState = (data: any) => {
  const { accessToken, refreshToken, customer } = data;
  tokenStorage.set('accessToken', accessToken);
  tokenStorage.set('refreshToken', refreshToken);
  const { setUser } = useAuthStore.getState();
  setUser(customer);
  return customer;
};

const shouldRetryCustomerLoginWithVerification = (error: any) => {
  const status = error?.response?.status as number | undefined;
  const message = String(
    error?.response?.data?.message || error?.message || '',
  ).toLowerCase();

  if (status === 400 || status === 401 || status === 403) {
    return true;
  }

  return (
    message.includes('invalid otp') ||
    message.includes('otp') ||
    message.includes('verification') ||
    message.includes('phone auth')
  );
};

export const customerLogin = async (
  phone: string,
  agreement?: boolean,
  verification?: CustomerLoginVerificationData,
) => {
  try {
    const response = await axios.post(`${BASE_URL}/customer/login`, {
      phone,
      agreement,
    });
    return applyCustomerAuthState(response.data);
  } catch (error: any) {
    // Backward compatible fallback for production backends that require Firebase proof payload.
    if (
      !verification ||
      !verification.firebaseIdToken ||
      !shouldRetryCustomerLoginWithVerification(error)
    ) {
      throw error;
    }

    const fallbackPayload = {
      phone: verification.phoneE164 || phone,
      agreement,
      firebaseIdToken: verification.firebaseIdToken,
      firebaseUid: verification.firebaseUid,
    };

    const fallbackResponse = await axios.post(
      `${BASE_URL}/customer/login`,
      fallbackPayload,
      {
        headers: {
          Authorization: `Bearer ${verification.firebaseIdToken}`,
          'x-firebase-token': verification.firebaseIdToken,
        },
      },
    );

    return applyCustomerAuthState(fallbackResponse.data);
  }
};

export const refetchUser = async (setUser: any) => {
  try {
    const response = await appAxios.get('/user');
    setUser(response.data.user);
  } catch (error) {
    console.log('Login Error', error);
  }
};

export const updateUserLocation = async (data: any, setUser: any) => {
  try {
    await appAxios.patch('/user', data);
    refetchUser(setUser);
  } catch (error) {
    console.log('updateUserLocation Error', error);
  }
};

export const updateUserProfile = async (data: any) => {
  try {
    const { setUser } = useAuthStore.getState();
    await appAxios.patch('/user', data);
    await refetchUser(setUser);
  } catch (error) {
    console.log('updateUserProfile Error', error);
    throw error;
  }
};

export const refresh_tokens = async () => {
  try {
    const refreshToken = tokenStorage.getString('refreshToken');

    if (!refreshToken) {
      throw new Error('No refresh token available');
    }

    const response = await axios.post(`${BASE_URL}/refresh-token`, {
      refreshToken,
    });

    const new_access_token = response.data.accessToken;
    const new_refresh_token = response.data.refreshToken;

    tokenStorage.set('accessToken', new_access_token);
    tokenStorage.set('refreshToken', new_refresh_token);
    return new_access_token;
  } catch (error) {
    console.log('REFRESH TOKEN ERROR', error);

    tokenStorage.clearAll();
    storage.clearAll();

    setTimeout(() => {
      const { setShowSessionExpiredModal } = useAuthStore.getState();
      setShowSessionExpiredModal(true);
    }, 100);

    throw error;
  }
};

export const logoutAndClearSession = async () => {
  try {
    // Ensure Firebase phone-auth session is cleared only on explicit logout.
    await auth().signOut();
  } catch (error) {
    console.log('Firebase signOut error', error);
  } finally {
    const { logout } = useAuthStore.getState();
    const { clearLocationSelection } = useLocationStore.getState();
    logout();
    clearLocationSelection();
    tokenStorage.clearAll();
    storage.clearAll();
  }
};
