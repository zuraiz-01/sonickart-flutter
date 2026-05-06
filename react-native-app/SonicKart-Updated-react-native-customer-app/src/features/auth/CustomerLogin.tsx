// import { View, StyleSheet, ImageBackground, SafeAreaView, Keyboard, TouchableOpacity, ScrollView, TextInput, Platform } from 'react-native';
// import React, { FC, useEffect, useState } from 'react';
// import { GestureHandlerRootView, PanGestureHandler, State } from 'react-native-gesture-handler';
// import { useSafeAreaInsets } from 'react-native-safe-area-context';
// import CustomSafeAreaView from '@components/global/CustomSafeAreaView';
// import { resetAndNavigate } from '@utils/NavigationUtils';
// import CustomText from '@components/ui/CustomText';
// import { Colors, Fonts } from '@utils/Constants';
// import CustomButton from '@components/ui/CustomButton';
// import { customerLogin } from '@service/authService';
// import colors from '../../theme/colors';
// import Icon from 'react-native-vector-icons/MaterialIcons';
// import { RFValue } from 'react-native-responsive-fontsize';
// import auth, { FirebaseAuthTypes } from '@react-native-firebase/auth';
// import CustomAlert from '@components/ui/CustomAlert';
// import { useCustomAlert } from '../../hooks/useCustomAlert';

// const OTP_RESEND_SECONDS = 60;
// const DIAL_CODE = '+91';
// const PHONE_DIGIT_LENGTH = 10;
// const normalizeE164 = (value: string) => `+${value.replace(/\D/g, '')}`;

// /**
//  * Customer login screen.
//  * Login is phone-based and requires agreement acceptance before continue.
//  */
// const CustomerLogin: FC = () => {
//   const insets = useSafeAreaInsets();
//   const [phoneNumber, setPhoneNumber] = useState('');
//   const [otp, setOtp] = useState('');
//   const [sendingOtp, setSendingOtp] = useState(false);
//   const [verifyingOtp, setVerifyingOtp] = useState(false);
//   const [resendTimer, setResendTimer] = useState(0);
//   const [confirmation, setConfirmation] = useState<FirebaseAuthTypes.ConfirmationResult | null>(null);
//   const [gestureSequence, setGestureSequence] = useState<string[]>([]);
//   const [agreementChecked, setAgreementChecked] = useState(false);
//   const { alertConfig, isVisible: alertVisible, hideAlert, showSuccess, showWarning, showError } = useCustomAlert();

//   const inputDigits = (phoneNumber || '').replace(/\D/g, '');
//   const normalizedPhone = inputDigits.slice(0, PHONE_DIGIT_LENGTH);
//   const isValidPhoneNumber = /^\d{10}$/.test(inputDigits);
//   const fullPhone = `${DIAL_CODE}${normalizedPhone}`;

//   const resetOtpFlow = () => {
//     setConfirmation(null);
//     setOtp('');
//     setResendTimer(0);
//   };

//   const getFirebaseErrorMessage = (error: any) => {
//     const code = error?.code as string | undefined;
//     const rawMessage = typeof error?.message === 'string' ? error.message : '';
//     if (code === 'auth/invalid-phone-number') {return 'The phone number is invalid.';}
//     if (code === 'auth/missing-client-identifier') {return 'App verification failed. Please update Firebase SHA setup for this app and try again.';}
//     if (code === 'auth/invalid-verification-code') {return 'The OTP code is incorrect. Please try again.';}
//     if (code === 'auth/session-expired') {return 'The OTP has expired. Please request a new OTP.';}
//     if (rawMessage) {return rawMessage;}
//     if (code) {return `Firebase verification failed (${code}).`;}
//     return 'Firebase verification failed. Please try again.';
//   };

//   useEffect(() => {
//     if (!confirmation || resendTimer <= 0) {
//       return;
//     }

//     const interval = setInterval(() => {
//       setResendTimer((prev) => (prev <= 1 ? 0 : prev - 1));
//     }, 1000);

//     return () => clearInterval(interval);
//   }, [confirmation, resendTimer]);

//   const handleSendOtp = async () => {
//     Keyboard.dismiss();

//     if (!agreementChecked) {
//       showWarning('Agreement Required', 'Please agree to the Terms & Conditions and Privacy Policy to continue.');
//       return;
//     }

//     if (!isValidPhoneNumber) {
//       showWarning('Invalid Number', 'Please enter a valid 10-digit mobile number.');
//       return;
//     }

//     setSendingOtp(true);
//     try {
//       // Always start OTP flow with a clean Firebase auth state.
//       if (auth().currentUser) {
//         await auth().signOut();
//       }

//       let result: FirebaseAuthTypes.ConfirmationResult;
//       try {
//         result = await auth().signInWithPhoneNumber(fullPhone);
//       } catch (error: any) {
//         // Android fallback: retry with reCAPTCHA flow when Play Integrity client identifier is missing.
//         if (Platform.OS === 'android' && error?.code === 'auth/missing-client-identifier') {
//           auth().settings.forceRecaptchaFlowForTesting = true;
//           result = await auth().signInWithPhoneNumber(fullPhone);
//         } else {
//           throw error;
//         }
//       }
//       setConfirmation(result);
//       setOtp('');
//       setResendTimer(OTP_RESEND_SECONDS);
//       showSuccess('OTP Sent', `A verification code has been sent to ${fullPhone}`);
//     } catch (error: any) {
//       showError('OTP Error', getFirebaseErrorMessage(error));
//     } finally {
//       setSendingOtp(false);
//     }
//   };

//   const handleVerifyOtp = async () => {
//     if (!confirmation) {return;}

//     if (!agreementChecked) {
//       showWarning('Agreement Required', 'Please agree to the Terms & Conditions and Privacy Policy to continue.');
//       return;
//     }

//     const code = (otp || '').replace(/\D/g, '').slice(0, 6);
//     if (code.length !== 6) {
//       showWarning('Invalid OTP', 'Please enter a valid 6-digit OTP.');
//       return;
//     }

//     setVerifyingOtp(true);
//     let otpVerified = false;
//     try {
//       await confirmation.confirm(code);
//       otpVerified = true;

//       const verifiedPhone = normalizeE164(auth().currentUser?.phoneNumber || '');
//       const expectedPhone = normalizeE164(fullPhone);
//       if (!verifiedPhone || verifiedPhone !== expectedPhone) {
//         throw new Error('Verified phone does not match the entered number. Please request OTP again.');
//       }

//       await customerLogin(normalizedPhone, agreementChecked);
//       resetOtpFlow();
//       resetAndNavigate('ProductDashboard');
//     } catch (error: any) {
//       const firebaseCode = error?.code as string | undefined;
//       if (firebaseCode?.startsWith?.('auth/')) {
//         showError('Invalid OTP', getFirebaseErrorMessage(error));
//       } else {
//         if (otpVerified) {
//           try {
//             await auth().signOut();
//           } catch (signOutError) {
//             console.log('Firebase signOut after failed backend login', signOutError);
//           }
//           resetOtpFlow();
//         }
//         const serverMessage = error?.response?.data?.message;
//         const rawMessage = typeof serverMessage === 'string' ? serverMessage : error?.message;
//         const message = otpVerified
//           ? `${rawMessage || 'Login failed on server.'} Please request OTP again.`
//           : (rawMessage || 'Login Failed');
//         showError('Login Failed', message);
//       }
//     } finally {
//       setVerifyingOtp(false);
//     }
//   };

//   const handleChangeNumber = () => {
//     resetOtpFlow();
//   };

//   const handleResendOtp = async () => {
//     if (resendTimer > 0) {
//       return;
//     }
//     await handleSendOtp();
//   };

//   const handleGesture = ({ nativeEvent }: any) => {
//     if (nativeEvent.state === State.END) {
//       const { translationX, translationY } = nativeEvent;
//       let direction = '';
//       if (Math.abs(translationX) > Math.abs(translationY)) {
//         direction = translationX > 0 ? 'right' : 'left';
//       } else {
//         direction = translationY > 0 ? 'down' : 'up';
//       }

//       const newSequence = [...gestureSequence, direction].slice(-5);
//       setGestureSequence(newSequence);

//       if (newSequence.join(' ') === 'up up down left right') {
//         setGestureSequence([]);
//         // resetAndNavigate('DeliveryLogin') // Commented out delivery login
//       }
//     }
//   };

//   return (
//     <GestureHandlerRootView style={styles.container}>
//       <ImageBackground
//         source={require('@assets/images/loginpagebackground.jpeg')}
//         style={styles.background}
//         resizeMode="cover"
//       >
//         <View style={styles.overlay}>
//           <CustomSafeAreaView style={styles.safeArea}>
//             <PanGestureHandler onHandlerStateChange={handleGesture}>
//               <ScrollView
//                 bounces={false}
//                 keyboardDismissMode="on-drag"
//                 keyboardShouldPersistTaps="handled"
//                 contentContainerStyle={styles.subContainer}
//               >
//                 <View style={styles.loginCard}>
//                   <CustomText
//                     variant="h6"
//                     fontFamily={Fonts.Bold}
//                     style={styles.text}
//                   >
//                     Log in or Sign up
//                   </CustomText>

//                   {!confirmation && (
//                     <>
//                       <View style={styles.phoneInputContainer}>
//                         <View style={styles.phonePrefixContainer}>
//                           <CustomText style={styles.phonePrefix}>{DIAL_CODE}</CustomText>
//                         </View>
//                         <TextInput
//                           onChangeText={(text) => {
//                             const digitsOnly = text.replace(/\D/g, '');
//                             setPhoneNumber(digitsOnly.slice(0, PHONE_DIGIT_LENGTH));
//                           }}
//                           value={phoneNumber}
//                           style={styles.phoneInput}
//                           placeholder="Enter 10-digit mobile number"
//                           placeholderTextColor="#999"
//                           inputMode="numeric"
//                           keyboardType="phone-pad"
//                           maxLength={PHONE_DIGIT_LENGTH}
//                           multiline={false}
//                         />
//                         {phoneNumber.length > 0 && (
//                           <TouchableOpacity
//                             onPress={() => setPhoneNumber('')}
//                             style={styles.clearButton}
//                             activeOpacity={0.7}
//                           >
//                             <Icon name="close" size={RFValue(20)} color={colors.greyText || '#666'} />
//                           </TouchableOpacity>
//                         )}
//                       </View>
//                     </>
//                   )}

//                   {confirmation && (
//                     <>
//                       <View style={styles.otpNoticeContainer}>
//                         <CustomText
//                           style={styles.otpNoticeLabel}
//                           variant="h8"
//                           fontFamily={Fonts.Medium}
//                         >
//                           A verification code has been sent to
//                         </CustomText>
//                         <CustomText
//                           style={styles.otpNoticeNumber}
//                           variant="h8"
//                           fontFamily={Fonts.Bold}
//                         >
//                           {fullPhone}
//                         </CustomText>
//                       </View>

//                       <View style={styles.phoneInputContainer}>
//                         <View style={styles.phonePrefixContainer}>
//                           <CustomText style={styles.phonePrefix}>OTP</CustomText>
//                         </View>
//                         <TextInput
//                           onChangeText={(text) => setOtp(text.replace(/\D/g, '').slice(0, 6))}
//                           value={otp}
//                           style={[styles.phoneInput, styles.otpInputInline]}
//                           placeholder="Enter 6-digit OTP"
//                           placeholderTextColor="#999"
//                           inputMode="numeric"
//                           keyboardType="number-pad"
//                           maxLength={6}
//                           multiline={false}
//                         />
//                       </View>

//                       <View style={styles.otpActions}>
//                         <TouchableOpacity onPress={handleResendOtp} disabled={sendingOtp || verifyingOtp || resendTimer > 0}>
//                           <CustomText style={styles.otpActionText} variant="h8" fontFamily={Fonts.SemiBold}>
//                             {resendTimer > 0
//                               ? `Resend OTP in 00:${String(resendTimer).padStart(2, '0')}`
//                               : 'Resend OTP'}
//                           </CustomText>
//                         </TouchableOpacity>
//                         <TouchableOpacity onPress={handleChangeNumber} disabled={sendingOtp || verifyingOtp}>
//                           <CustomText style={styles.otpActionText} variant="h8" fontFamily={Fonts.SemiBold}>
//                             Change Number
//                           </CustomText>
//                         </TouchableOpacity>
//                       </View>
//                     </>
//                   )}

//                   <TouchableOpacity
//                     style={styles.checkboxContainer}
//                     onPress={() => setAgreementChecked(!agreementChecked)}
//                     activeOpacity={0.7}
//                   >
//                     <View style={[
//                       styles.checkbox,
//                       agreementChecked && styles.checkboxChecked,
//                     ]}>
//                       {agreementChecked && (
//                         <Icon name="check" size={16} color={colors.white} />
//                       )}
//                     </View>
//                     <CustomText
//                       style={styles.agreementText}
//                       variant="h8"
//                       fontFamily={Fonts.Medium}
//                     >
//                       By continuing you agree to SonicKart's Terms & Conditions and Privacy Policy.
//                     </CustomText>
//                   </TouchableOpacity>

//                   <CustomButton
//                     disabled={
//                       !confirmation
//                         ? !isValidPhoneNumber || !agreementChecked
//                         : otp.length !== 6
//                     }
//                     onPress={confirmation ? handleVerifyOtp : handleSendOtp}
//                     loading={sendingOtp || verifyingOtp}
//                     buttonColor="#FFC727"
//                     title={confirmation ? 'Verify OTP' : 'Send OTP'}
//                     style={styles.continueButton}
//                   />
//                 </View>
//               </ScrollView>
//             </PanGestureHandler>
//           </CustomSafeAreaView>

//           {alertConfig && (
//             <CustomAlert
//               visible={alertVisible}
//               title={alertConfig.title}
//               message={alertConfig.message}
//               type={alertConfig.type}
//               primaryButtonText={alertConfig.primaryButtonText}
//               secondaryButtonText={alertConfig.secondaryButtonText}
//               onPrimaryPress={alertConfig.onPrimaryPress}
//               onSecondaryPress={alertConfig.onSecondaryPress}
//               onClose={hideAlert}
//               showSecondaryButton={alertConfig.showSecondaryButton}
//             />
//           )}

//           <View style={[styles.footer, { bottom: insets.bottom }]}>
//             <SafeAreaView>
//               <CustomText
//                 fontFamily={Fonts.Bold}
//                 style={styles.footerText}
//               >
//                 Your city's essentials, delivered fast.
//               </CustomText>
//             </SafeAreaView>
//           </View>
//         </View>
//       </ImageBackground>
//     </GestureHandlerRootView>
//   );
// };

// const styles = StyleSheet.create({
//   container: {
//     flex: 1,
//     backgroundColor: colors.white,
//   },
//   background: {
//     flex: 1,
//     width: '100%',
//     height: '100%',
//   },
//   overlay: {
//     flex: 1,
//     backgroundColor: 'rgba(9, 39, 116, 0.4)',
//   },
//   safeArea: {
//     backgroundColor: 'transparent',
//   },
//   text: {
//     color: colors.primaryBlue,
//     letterSpacing: 0.8,
//     textAlign: 'center',
//     fontWeight: '700',
//     fontSize: 18,
//     marginBottom: 20,
//   },
//   subContainer: {
//     flexGrow: 1,
//     justifyContent: 'center',
//     alignItems: 'center',
//     paddingHorizontal: 16,
//     paddingVertical: 24,
//   },
//   phoneInputContainer: {
//     flexDirection: 'row',
//     width: '100%',
//     marginBottom: 20,
//     borderRadius: 12,
//     borderWidth: 1.5,
//     borderColor: 'rgba(9, 39, 116, 0.18)',
//     backgroundColor: 'rgba(255, 255, 255, 0.82)',
//     shadowColor: colors.primaryBlue,
//     shadowOffset: { width: 0, height: 2 },
//     shadowOpacity: 0.08,
//     shadowRadius: 4,
//     elevation: 3,
//     alignItems: 'center',
//     minHeight: 50,
//   },
//   phonePrefixContainer: {
//     backgroundColor: 'transparent',
//     paddingHorizontal: 16,
//     justifyContent: 'center',
//     alignItems: 'center',
//     borderTopLeftRadius: 10,
//     borderBottomLeftRadius: 10,
//     height: '100%',
//     minHeight: 50,
//   },
//   phonePrefix: {
//     color: '#092774',
//     fontSize: RFValue(15),
//     fontFamily: Fonts.Bold,
//     letterSpacing: 0.5,
//     lineHeight: RFValue(15) * 1.2,
//   },
//   phoneInput: {
//     flex: 1,
//     color: '#092774',
//     fontFamily: Fonts.SemiBold,
//     letterSpacing: 0.5,
//     fontSize: RFValue(15),
//     paddingHorizontal: 12,
//     paddingVertical: 14,
//     textAlignVertical: 'center',
//     includeFontPadding: false,
//   },
//   clearButton: {
//     paddingHorizontal: 12,
//     paddingVertical: 8,
//     justifyContent: 'center',
//     alignItems: 'center',
//   },
//   loginCard: {
//     maxWidth: 400,
//     alignSelf: 'center',
//     width: '100%',
//     justifyContent: 'center',
//     alignItems: 'center',
//     backgroundColor: 'rgba(255, 255, 255, 0.76)',
//     borderRadius: 24,
//     padding: 24,
//     borderWidth: 1,
//     borderColor: 'rgba(255, 255, 255, 0.38)',
//     shadowColor: colors.black,
//     shadowOffset: { width: 0, height: 12 },
//     shadowOpacity: 0.18,
//     shadowRadius: 18,
//     elevation: 10,
//   },
//   footer: {
//     borderTopWidth: 0.8,
//     borderColor: Colors.border,
//     zIndex: 22,
//     position: 'absolute',
//     justifyContent: 'center',
//     alignItems: 'center',
//     backgroundColor: colors.primaryBlue,
//     width: '100%',
//     paddingHorizontal: 16,
//     paddingVertical: 8,
//   },
//   footerText: {
//     color: colors.white,
//     textAlign: 'center',
//     letterSpacing: 0.6,
//     fontSize: 10,
//   },
//   otpInputContainer: {
//     width: '100%',
//     marginBottom: 8,
//     borderRadius: 12,
//     borderWidth: 1.5,
//     borderColor: colors.primaryBlue,
//     backgroundColor: colors.white,
//     alignItems: 'center',
//     minHeight: 50,
//   },
//   otpInput: {
//     width: '100%',
//     color: '#092774',
//     fontFamily: Fonts.SemiBold,
//     letterSpacing: 6,
//     fontSize: RFValue(16),
//     paddingHorizontal: 16,
//     paddingVertical: 14,
//     textAlign: 'center',
//     includeFontPadding: false,
//   },
//   otpInputInline: {
//     letterSpacing: 2,
//     textAlign: 'left',
//   },
//   otpActions: {
//     width: '100%',
//     flexDirection: 'row',
//     justifyContent: 'space-between',
//     marginBottom: 6,
//   },
//   otpActionText: {
//     color: colors.primaryBlue,
//     textDecorationLine: 'underline',
//     fontSize: 12,
//   },
//   otpNoticeContainer: {
//     width: '100%',
//     marginBottom: 10,
//     paddingHorizontal: 4,
//   },
//   otpNoticeLabel: {
//     color: colors.primaryBlue,
//     fontSize: 12,
//     textAlign: 'center',
//     opacity: 0.9,
//     marginBottom: 2,
//   },
//   otpNoticeNumber: {
//     color: colors.primaryBlue,
//     fontSize: 13,
//     textAlign: 'center',
//     letterSpacing: 0.4,
//   },
//   checkboxContainer: {
//     flexDirection: 'row',
//     alignItems: 'flex-start',
//     marginBottom: 20,
//     paddingVertical: 8,
//   },
//   checkbox: {
//     width: 20,
//     height: 20,
//     borderWidth: 2,
//     borderColor: colors.primaryBlue,
//     borderRadius: 4,
//     justifyContent: 'center',
//     alignItems: 'center',
//     backgroundColor: colors.white,
//     marginRight: 8,
//   },
//   checkboxChecked: {
//     backgroundColor: colors.primaryBlue,
//   },
//   agreementText: {
//     color: colors.primaryBlue,
//     letterSpacing: 0.4,
//     fontSize: 12,
//     lineHeight: 18,
//     flex: 1,
//   },
//   continueButton: {
//     width: '100%',
//     minWidth: 280,
//   },
// });
// export default CustomerLogin;
import {
  View,
  StyleSheet,
  ImageBackground,
  SafeAreaView,
  Keyboard,
  TouchableOpacity,
  ScrollView,
  TextInput,
} from 'react-native';
import React, { FC, useEffect, useMemo, useState } from 'react';
import {
  GestureHandlerRootView,
  PanGestureHandler,
  State,
} from 'react-native-gesture-handler';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import CustomSafeAreaView from '@components/global/CustomSafeAreaView';
import { resetAndNavigate } from '@utils/NavigationUtils';
import CustomText from '@components/ui/CustomText';
import { Colors, Fonts } from '@utils/Constants';
import CustomButton from '@components/ui/CustomButton';
import { customerLogin } from '@service/authService';
import colors from '../../theme/colors';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { RFValue } from 'react-native-responsive-fontsize';
import auth, { FirebaseAuthTypes } from '@react-native-firebase/auth';
import CustomAlert from '@components/ui/CustomAlert';
import { useCustomAlert } from '../../hooks/useCustomAlert';

const OTP_RESEND_SECONDS = 60;
const DIAL_CODE = '+91';
const PHONE_DIGIT_LENGTH = 10;
const normalizeE164 = (value: string) => `+${value.replace(/\D/g, '')}`;

const CustomerLogin: FC = () => {
  const insets = useSafeAreaInsets();

  const [phoneNumber, setPhoneNumber] = useState('');
  const [otp, setOtp] = useState('');

  const [sendingOtp, setSendingOtp] = useState(false);
  const [verifyingOtp, setVerifyingOtp] = useState(false);

  const [resendTimer, setResendTimer] = useState(0);
  const [confirmation, setConfirmation] =
    useState<FirebaseAuthTypes.ConfirmationResult | null>(null);

  const [gestureSequence, setGestureSequence] = useState<string[]>([]);
  const [agreementChecked, setAgreementChecked] = useState(false);

  // Prevent double-login race
  const [loginInProgress, setLoginInProgress] = useState(false);

  const {
    alertConfig,
    isVisible: alertVisible,
    hideAlert,
    showSuccess,
    showWarning,
    showError,
  } = useCustomAlert();

  const inputDigits = useMemo(
    () => (phoneNumber || '').replace(/\D/g, ''),
    [phoneNumber],
  );

  const normalizedPhone = useMemo(
    () => inputDigits.slice(0, PHONE_DIGIT_LENGTH),
    [inputDigits],
  );

  const isValidPhoneNumber = useMemo(
    () => /^\d{10}$/.test(normalizedPhone),
    [normalizedPhone],
  );

  const fullPhone = useMemo(
    () => `${DIAL_CODE}${normalizedPhone}`,
    [normalizedPhone],
  );

  const resetOtpFlow = () => {
    setConfirmation(null);
    setOtp('');
    setResendTimer(0);
    setLoginInProgress(false);
  };

  const getFirebaseErrorMessage = (error: any) => {
    const code = error?.code as string | undefined;
    const rawMessage = typeof error?.message === 'string' ? error.message : '';

    if (code === 'auth/invalid-phone-number') return 'The phone number is invalid.';
    if (code === 'auth/invalid-verification-code')
      return 'The OTP code is incorrect. Please try again.';
    if (code === 'auth/session-expired')
      return 'The OTP has expired. Please request a new OTP.';
    if (code === 'auth/too-many-requests')
      return 'Too many attempts. Please try again later.';

    if (code === 'auth/missing-client-identifier') {
      return 'App verification failed. Please ensure Play Console App Signing SHA-1/SHA-256 are added in Firebase and Play Integrity is enabled.';
    }

    if (rawMessage) return rawMessage;
    if (code) return `Firebase verification failed (${code}).`;
    return 'Firebase verification failed. Please try again.';
  };

  const getFirebaseErrorAlert = (error: any) => {
    const code = error?.code as string | undefined;
    const message = getFirebaseErrorMessage(error);

    let title = 'Firebase Auth Error';
    if (code === 'auth/invalid-verification-code') title = 'Wrong OTP';
    if (code === 'auth/session-expired') title = 'OTP Expired';
    if (code === 'auth/missing-client-identifier') title = 'Firebase Setup Error';
    if (code === 'auth/too-many-requests') title = 'Too Many Attempts';

    return { title, message: code ? `${message} [${code}]` : message };
  };

  useEffect(() => {
    if (!confirmation || resendTimer <= 0) return;

    const interval = setInterval(() => {
      setResendTimer(prev => (prev <= 1 ? 0 : prev - 1));
    }, 1000);

    return () => clearInterval(interval);
  }, [confirmation, resendTimer]);

  /**
   * After Firebase verification, do backend login + navigate.
   * Used by:
   * - Auto verification
   * - Manual OTP confirm
   */
  const proceedBackendLogin = async (user: FirebaseAuthTypes.User) => {
    if (loginInProgress) return;

    const verifiedPhone = normalizeE164(user.phoneNumber || '');
    const expectedPhone = normalizeE164(fullPhone);

    if (!verifiedPhone || verifiedPhone !== expectedPhone) {
      throw new Error(
        'Verified phone does not match the entered number. Please request OTP again.',
      );
    }

    setLoginInProgress(true);

    const firebaseIdToken = await user.getIdToken(true);

    await customerLogin(normalizedPhone, agreementChecked, {
      firebaseIdToken,
      firebaseUid: user.uid,
      phoneE164: expectedPhone,
    });

    resetOtpFlow();
    resetAndNavigate('ProductDashboard');
  };

  // Auto verification / instant verification
  useEffect(() => {
    if (!confirmation) return;

    const unsubscribe = auth().onAuthStateChanged(async user => {
      try {
        if (!user) return;
        if (!agreementChecked) return;

        await proceedBackendLogin(user);
      } catch {
        // Keep user on OTP screen if auto-login fails
      }
    });

    return unsubscribe;
  }, [confirmation, agreementChecked, fullPhone, normalizedPhone, loginInProgress]);

  const handleSendOtp = async () => {
    Keyboard.dismiss();

    if (!agreementChecked) {
      showWarning(
        'Agreement Required',
        'Please agree to the Terms & Conditions and Privacy Policy to continue.',
      );
      return;
    }

    if (!isValidPhoneNumber) {
      showWarning('Invalid Number', 'Please enter a valid 10-digit mobile number.');
      return;
    }

    if (sendingOtp || verifyingOtp) return;

    setSendingOtp(true);

    try {
      if (auth().currentUser) {
        await auth().signOut();
      }

      const result = await auth().signInWithPhoneNumber(fullPhone);

      setConfirmation(result);
      setOtp('');
      setResendTimer(OTP_RESEND_SECONDS);
      setLoginInProgress(false);

      showSuccess('OTP Sent', `A verification code has been sent to ${fullPhone}`);
    } catch (error: any) {
      const firebaseError = getFirebaseErrorAlert(error);
      showError(firebaseError.title, firebaseError.message);
    } finally {
      setSendingOtp(false);
    }
  };

  const handleVerifyOtp = async () => {
    if (!confirmation) return;

    if (!agreementChecked) {
      showWarning(
        'Agreement Required',
        'Please agree to the Terms & Conditions and Privacy Policy to continue.',
      );
      return;
    }

    const code = (otp || '').replace(/\D/g, '').slice(0, 6);
    if (code.length !== 6) {
      showWarning('Invalid OTP', 'Please enter a valid 6-digit OTP.');
      return;
    }

    if (verifyingOtp || sendingOtp || loginInProgress) return;

    setVerifyingOtp(true);

    try {
      const currentUser = auth().currentUser;
      const expectedPhone = normalizeE164(fullPhone);
      const alreadyVerifiedPhone = normalizeE164(currentUser?.phoneNumber || '');

      if (currentUser && alreadyVerifiedPhone && alreadyVerifiedPhone === expectedPhone) {
        await proceedBackendLogin(currentUser);
        return;
      }

      await confirmation.confirm(code);

      const userAfterConfirm = auth().currentUser;
      if (!userAfterConfirm) {
        throw new Error(
          'Verification succeeded but no user session found. Please try again.',
        );
      }

      await proceedBackendLogin(userAfterConfirm);
    } catch (error: any) {
      const firebaseCode = error?.code as string | undefined;

      if (firebaseCode?.startsWith?.('auth/')) {
        const firebaseError = getFirebaseErrorAlert(error);
        showError(firebaseError.title, firebaseError.message);

        if (
          firebaseCode === 'auth/session-expired' ||
          firebaseCode === 'auth/invalid-verification-code'
        ) {
          setOtp('');
        }
        return;
      }

      try {
        await auth().signOut();
      } catch {}

      resetOtpFlow();

      const serverMessage = error?.response?.data?.message;
      const rawMessage =
        typeof serverMessage === 'string' ? serverMessage : error?.message;

      showError(
        'Login Failed',
        `${rawMessage || 'Login failed.'} Please request OTP again.`,
      );
    } finally {
      setVerifyingOtp(false);
    }
  };

  const handleChangeNumber = () => {
    resetOtpFlow();
  };

  const handleResendOtp = async () => {
    if (resendTimer > 0) return;
    await handleSendOtp();
  };

  const handleGesture = ({ nativeEvent }: any) => {
    if (nativeEvent.state === State.END) {
      const { translationX, translationY } = nativeEvent;

      let direction = '';
      if (Math.abs(translationX) > Math.abs(translationY)) {
        direction = translationX > 0 ? 'right' : 'left';
      } else {
        direction = translationY > 0 ? 'down' : 'up';
      }

      const newSequence = [...gestureSequence, direction].slice(-5);
      setGestureSequence(newSequence);

      if (newSequence.join(' ') === 'up up down left right') {
        setGestureSequence([]);
        // resetAndNavigate('DeliveryLogin')
      }
    }
  };

  return (
    <GestureHandlerRootView style={styles.container}>
      <ImageBackground
        source={require('@assets/images/loginpagebackground.jpeg')}
        style={styles.background}
        resizeMode="cover"
      >
        <View style={styles.overlay}>
          <CustomSafeAreaView style={styles.safeArea}>
            <PanGestureHandler onHandlerStateChange={handleGesture}>
              <ScrollView
                bounces={false}
                keyboardDismissMode="on-drag"
                keyboardShouldPersistTaps="handled"
                contentContainerStyle={styles.subContainer}
              >
                <View style={styles.loginCard}>
                  <CustomText
                    variant="h6"
                    fontFamily={Fonts.Bold}
                    style={styles.text}
                  >
                    Log in or Sign up
                  </CustomText>

                  {!confirmation && (
                    <View style={styles.phoneInputContainer}>
                      <View style={styles.phonePrefixContainer}>
                        <CustomText style={styles.phonePrefix}>{DIAL_CODE}</CustomText>
                      </View>

                      <TextInput
                        onChangeText={(text) => {
                          const digitsOnly = text.replace(/\D/g, '');
                          setPhoneNumber(digitsOnly.slice(0, PHONE_DIGIT_LENGTH));
                        }}
                        value={phoneNumber}
                        style={styles.phoneInput}
                        placeholder="Enter 10-digit mobile number"
                        placeholderTextColor="#999"
                        inputMode="numeric"
                        keyboardType="phone-pad"
                        maxLength={PHONE_DIGIT_LENGTH}
                        multiline={false}
                      />

                      {phoneNumber.length > 0 && (
                        <TouchableOpacity
                          onPress={() => setPhoneNumber('')}
                          style={styles.clearButton}
                          activeOpacity={0.7}
                        >
                          <Icon
                            name="close"
                            size={RFValue(20)}
                            color={colors.greyText || '#666'}
                          />
                        </TouchableOpacity>
                      )}
                    </View>
                  )}

                  {confirmation && (
                    <>
                      <View style={styles.otpNoticeContainer}>
                        <CustomText
                          style={styles.otpNoticeLabel}
                          variant="h8"
                          fontFamily={Fonts.Medium}
                        >
                          A verification code has been sent to
                        </CustomText>
                        <CustomText
                          style={styles.otpNoticeNumber}
                          variant="h8"
                          fontFamily={Fonts.Bold}
                        >
                          {fullPhone}
                        </CustomText>
                      </View>

                      <View style={styles.phoneInputContainer}>
                        <View style={styles.phonePrefixContainer}>
                          <CustomText style={styles.phonePrefix}>OTP</CustomText>
                        </View>

                        <TextInput
                          onChangeText={(text) =>
                            setOtp(text.replace(/\D/g, '').slice(0, 6))
                          }
                          value={otp}
                          style={[styles.phoneInput, styles.otpInputInline]}
                          placeholder="Enter 6-digit OTP"
                          placeholderTextColor="#999"
                          inputMode="numeric"
                          keyboardType="number-pad"
                          maxLength={6}
                          multiline={false}
                        />
                      </View>

                      <View style={styles.otpActions}>
                        <TouchableOpacity
                          onPress={handleResendOtp}
                          disabled={sendingOtp || verifyingOtp || resendTimer > 0}
                        >
                          <CustomText
                            style={styles.otpActionText}
                            variant="h8"
                            fontFamily={Fonts.SemiBold}
                          >
                            {resendTimer > 0
                              ? `Resend OTP in 00:${String(resendTimer).padStart(2, '0')}`
                              : 'Resend OTP'}
                          </CustomText>
                        </TouchableOpacity>

                        <TouchableOpacity
                          onPress={handleChangeNumber}
                          disabled={sendingOtp || verifyingOtp}
                        >
                          <CustomText
                            style={styles.otpActionText}
                            variant="h8"
                            fontFamily={Fonts.SemiBold}
                          >
                            Change Number
                          </CustomText>
                        </TouchableOpacity>
                      </View>
                    </>
                  )}

                  <TouchableOpacity
                    style={styles.checkboxContainer}
                    onPress={() => setAgreementChecked(!agreementChecked)}
                    activeOpacity={0.7}
                  >
                    <View
                      style={[
                        styles.checkbox,
                        agreementChecked && styles.checkboxChecked,
                      ]}
                    >
                      {agreementChecked && (
                        <Icon name="check" size={16} color={colors.white} />
                      )}
                    </View>

                    <CustomText
                      style={styles.agreementText}
                      variant="h8"
                      fontFamily={Fonts.Medium}
                    >
                      By continuing you agree to SonicKart&apos;s Terms & Conditions and
                      Privacy Policy.
                    </CustomText>
                  </TouchableOpacity>

                  <CustomButton
                    disabled={
                      !confirmation
                        ? !isValidPhoneNumber || !agreementChecked
                        : otp.replace(/\D/g, '').length !== 6 || loginInProgress
                    }
                    onPress={confirmation ? handleVerifyOtp : handleSendOtp}
                    loading={sendingOtp || verifyingOtp || loginInProgress}
                    buttonColor="#FFC727"
                    title={confirmation ? 'Verify OTP' : 'Send OTP'}
                    style={styles.continueButton}
                  />
                </View>
              </ScrollView>
            </PanGestureHandler>
          </CustomSafeAreaView>

          {alertConfig && (
            <CustomAlert
              visible={alertVisible}
              title={alertConfig.title}
              message={alertConfig.message}
              type={alertConfig.type}
              primaryButtonText={alertConfig.primaryButtonText}
              secondaryButtonText={alertConfig.secondaryButtonText}
              onPrimaryPress={alertConfig.onPrimaryPress}
              onSecondaryPress={alertConfig.onSecondaryPress}
              onClose={hideAlert}
              showSecondaryButton={alertConfig.showSecondaryButton}
            />
          )}

          <View style={[styles.footer, { bottom: insets.bottom }]}>
            <SafeAreaView>
              <CustomText
                fontFamily={Fonts.Bold}
                style={styles.footerText}
              >
                Your city&apos;s essentials, delivered fast.
              </CustomText>
            </SafeAreaView>
          </View>
        </View>
      </ImageBackground>
    </GestureHandlerRootView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.white,
  },
  background: {
    flex: 1,
    width: '100%',
    height: '100%',
  },
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(9, 39, 116, 0.4)',
  },
  safeArea: {
    backgroundColor: 'transparent',
  },
  text: {
    color: colors.primaryBlue,
    letterSpacing: 0.8,
    textAlign: 'center',
    fontWeight: '700',
    fontSize: 18,
    marginBottom: 20,
  },
  subContainer: {
    flexGrow: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 24,
  },
  phoneInputContainer: {
    flexDirection: 'row',
    width: '100%',
    marginBottom: 20,
    borderRadius: 12,
    borderWidth: 1.5,
    borderColor: 'rgba(9, 39, 116, 0.18)',
    backgroundColor: 'rgba(255, 255, 255, 0.82)',
    shadowColor: colors.primaryBlue,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 3,
    alignItems: 'center',
    minHeight: 50,
  },
  phonePrefixContainer: {
    backgroundColor: 'transparent',
    paddingHorizontal: 16,
    justifyContent: 'center',
    alignItems: 'center',
    borderTopLeftRadius: 10,
    borderBottomLeftRadius: 10,
    height: '100%',
    minHeight: 50,
  },
  phonePrefix: {
    color: '#092774',
    fontSize: RFValue(15),
    fontFamily: Fonts.Bold,
    letterSpacing: 0.5,
    lineHeight: RFValue(15) * 1.2,
  },
  phoneInput: {
    flex: 1,
    color: '#092774',
    fontFamily: Fonts.SemiBold,
    letterSpacing: 0.5,
    fontSize: RFValue(15),
    paddingHorizontal: 12,
    paddingVertical: 14,
    textAlignVertical: 'center',
    includeFontPadding: false,
  },
  clearButton: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loginCard: {
    maxWidth: 400,
    alignSelf: 'center',
    width: '100%',
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: colors.white,
    borderRadius: 24,
    padding: 24,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.38)',
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.18,
    shadowRadius: 18,
    elevation: 10,
  },
  footer: {
    borderTopWidth: 0.8,
    borderColor: Colors.border,
    zIndex: 22,
    position: 'absolute',
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: colors.primaryBlue,
    width: '100%',
    paddingHorizontal: 16,
    paddingVertical: 8,
  },
  footerText: {
    color: colors.white,
    textAlign: 'center',
    letterSpacing: 0.6,
    fontSize: 10,
  },
  otpInputInline: {
    letterSpacing: 2,
    textAlign: 'left',
  },
  otpActions: {
    width: '100%',
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 6,
  },
  otpActionText: {
    color: colors.primaryBlue,
    textDecorationLine: 'underline',
    fontSize: 12,
  },
  otpNoticeContainer: {
    width: '100%',
    marginBottom: 10,
    paddingHorizontal: 4,
  },
  otpNoticeLabel: {
    color: colors.primaryBlue,
    fontSize: 12,
    textAlign: 'center',
    opacity: 0.9,
    marginBottom: 2,
  },
  otpNoticeNumber: {
    color: colors.primaryBlue,
    fontSize: 13,
    textAlign: 'center',
    letterSpacing: 0.4,
  },
  checkboxContainer: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 20,
    paddingVertical: 8,
  },
  checkbox: {
    width: 20,
    height: 20,
    borderWidth: 2,
    borderColor: colors.primaryBlue,
    borderRadius: 4,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: colors.white,
    marginRight: 8,
  },
  checkboxChecked: {
    backgroundColor: colors.primaryBlue,
  },
  agreementText: {
    color: colors.primaryBlue,
    letterSpacing: 0.4,
    fontSize: 12,
    lineHeight: 18,
    flex: 1,
  },
  continueButton: {
    width: '100%',
    minWidth: 280,
  },
});

export default CustomerLogin;
