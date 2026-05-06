import {
  View,
  StyleSheet,
  Image,
  TouchableOpacity,
  ScrollView,
  Modal,
  Alert,
  KeyboardAvoidingView,
  Platform,
  TouchableWithoutFeedback,
  Linking,
} from 'react-native';
import React, { FC, useEffect, useMemo, useState } from 'react';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAuthStore } from '@state/authStore';
import { useCartStore } from '@state/cartStore';
import CustomHeader from '@components/ui/CustomHeader';
import CustomText from '@components/ui/CustomText';
import CustomInput from '@components/ui/CustomInput';
import { Fonts } from '@utils/Constants';
import WalletSection from './WalletSection';
import ActionButton from './ActionButton';
import { resetAndNavigate, navigate } from '@utils/NavigationUtils';
import Icon from 'react-native-vector-icons/Ionicons';
import { RFValue } from 'react-native-responsive-fontsize';
import colors from '../../theme/colors';
import { logoutAndClearSession, updateUserProfile } from '@service/authService';
import BottomTabBar from '@components/ui/BottomTabBar';

const PROFILE_ICON_COLOR = colors.accentYellow;

/**
 * Customer profile hub.
 * Includes profile edit, quick actions, app menu actions, and logout.
 */
const Profile: FC = () => {
  const { user } = useAuthStore();
  const { clearCart } = useCartStore();
  const insets = useSafeAreaInsets();

  const [isEditModalVisible, setEditModalVisible] = useState(false);
  const [savingProfile, setSavingProfile] = useState(false);
  const [isNotificationModalVisible, setNotificationModalVisible] = useState(false);
  const [isRewardsModalVisible, setRewardsModalVisible] = useState(false);
  const [isGiftCardsModalVisible, setGiftCardsModalVisible] = useState(false);
  const [isSuggestModalVisible, setSuggestModalVisible] = useState(false);
  const [isRefundsModalVisible, setRefundsModalVisible] = useState(false);
  const [profileForm, setProfileForm] = useState({
    name: '',
    phone: '',
    email: '',
  });

  useEffect(() => {
    setProfileForm({
      name: user?.name || '',
      phone: user?.phone || '',
      email: user?.email || '',
    });
  }, [user]);

  const initials = useMemo(() => {
    const seed = user?.name || user?.phone || 'Guest';
    const cleaned = seed.trim();
    if (!cleaned) {return 'G';}
    const parts = cleaned.split(' ');
    if (parts.length === 1) {
      return parts[0].charAt(0).toUpperCase();
    }
    return (
      (parts[0]?.charAt(0) || '') + (parts[1]?.charAt(0) || '')
    ).toUpperCase();
  }, [user]);

  const openWebsite = async () => {
    const url = 'https://sonickartnow.com';
    try {
      const canOpen = await Linking.canOpenURL(url);
      if (canOpen) {
        await Linking.openURL(url);
      } else {
        Alert.alert('Error', 'Unable to open website. Please visit sonickartnow.com manually.');
      }
    } catch (error) {
      Alert.alert('Error', 'Unable to open website. Please visit sonickartnow.com manually.');
    }
  };

  const openMailClient = async (subject: string) => {
    const email = 'support@sonickartnow.com';
    const url = `mailto:${email}?subject=${encodeURIComponent(subject)}`;
    try {
      const canOpen = await Linking.canOpenURL(url);
      if (canOpen) {
        await Linking.openURL(url);
      } else {
        Alert.alert('Contact us', `Drop us a mail at ${email}`);
      }
    } catch (error) {
      Alert.alert('Contact us', `Drop us a mail at ${email}`);
    }
  };

  const handleQuickActionPress = (action: 'orders' | 'help') => {
    switch (action) {
      case 'orders':
        navigate('CustomerOrders');
        break;
      case 'help':
        openMailClient('Need help');
        break;
      default:
        break;
    }
  };

  const handleMenuAction = (action: string) => {
    switch (action) {
      case 'refunds':
        setRefundsModalVisible(true);
        break;
      case 'giftcards':
        setGiftCardsModalVisible(true);
        break;
      case 'addresses':
        navigate('AddressBook');
        break;
      case 'edit':
        setEditModalVisible(true);
        break;
      case 'rewards':
        setRewardsModalVisible(true);
        break;
      case 'suggest':
        setSuggestModalVisible(true);
        break;
      case 'notifications':
        setNotificationModalVisible(true);
        break;
      case 'about':
        openWebsite();
        break;
      default:
        break;
    }
  };

  const handleSaveProfile = async () => {
    const trimmedPhone = profileForm.phone?.trim();
    const trimmedName = profileForm.name?.trim();

    if (!trimmedPhone || trimmedPhone.length < 10) {
      Alert.alert('Phone required', 'Enter a valid 10-digit phone number.');
      return;
    }

    setSavingProfile(true);
    try {
      await updateUserProfile({
        name: trimmedName,
        phone: trimmedPhone,
        email: profileForm.email?.trim(),
      });
      setEditModalVisible(false);
    } catch (error) {
      Alert.alert('Update failed', 'Unable to update your profile right now.');
    } finally {
      setSavingProfile(false);
    }
  };

  const renderAvatar = () => {
    if (user?.profileImage) {
      return (
        <Image
          source={{ uri: user.profileImage }}
          style={styles.avatar}
          defaultSource={require('@assets/images/logo.png')}
        />
      );
    }
    return (
      <View style={[styles.avatar, styles.initialAvatar]}>
        <CustomText variant="h2" fontFamily={Fonts.Bold} style={styles.initialsText}>
          {initials}
        </CustomText>
      </View>
    );
  };

  const renderNotificationModal = () => (
    <Modal
      visible={isNotificationModalVisible}
      animationType="slide"
      transparent
      onRequestClose={() => setNotificationModalVisible(false)}
    >
      <TouchableWithoutFeedback onPress={() => setNotificationModalVisible(false)}>
        <View style={styles.modalOverlay}>
          <TouchableWithoutFeedback>
            <View style={styles.modalCard}>
              <View style={styles.notificationIconContainer}>
                <Icon name="notifications-outline" size={RFValue(48)} color={PROFILE_ICON_COLOR} />
              </View>
              <CustomText variant="h4" fontFamily={Fonts.Bold} style={styles.modalTitle}>
                Notifications
              </CustomText>
              <CustomText variant="body" fontFamily={Fonts.Bold} style={styles.notificationMessage}>
                Notification preferences will be available shortly.
              </CustomText>
              <TouchableOpacity
                style={[styles.modalButton, styles.modalPrimary, styles.notificationButton]}
                onPress={() => setNotificationModalVisible(false)}
              >
                <CustomText variant="h7" fontFamily={Fonts.Bold} style={styles.primaryText}>
                  OK
                </CustomText>
              </TouchableOpacity>
            </View>
          </TouchableWithoutFeedback>
        </View>
      </TouchableWithoutFeedback>
    </Modal>
  );

  const renderRewardsModal = () => (
    <Modal
      visible={isRewardsModalVisible}
      animationType="slide"
      transparent
      onRequestClose={() => setRewardsModalVisible(false)}
    >
      <TouchableWithoutFeedback onPress={() => setRewardsModalVisible(false)}>
        <View style={styles.modalOverlay}>
          <TouchableWithoutFeedback>
            <View style={styles.modalCard}>
              <View style={styles.notificationIconContainer}>
                <Icon name="star-outline" size={RFValue(48)} color={PROFILE_ICON_COLOR} />
              </View>
              <CustomText variant="h4" fontFamily={Fonts.Bold} style={styles.modalTitle}>
                Rewards
              </CustomText>
              <CustomText variant="body" fontFamily={Fonts.Bold} style={styles.notificationMessage}>
                Earn points on every order. Feature coming soon!
              </CustomText>
              <TouchableOpacity
                style={[styles.modalButton, styles.modalPrimary, styles.notificationButton]}
                onPress={() => setRewardsModalVisible(false)}
              >
                <CustomText variant="h7" fontFamily={Fonts.Bold} style={styles.primaryText}>
                  OK
                </CustomText>
              </TouchableOpacity>
            </View>
          </TouchableWithoutFeedback>
        </View>
      </TouchableWithoutFeedback>
    </Modal>
  );

  const renderGiftCardsModal = () => (
    <Modal
      visible={isGiftCardsModalVisible}
      animationType="slide"
      transparent
      onRequestClose={() => setGiftCardsModalVisible(false)}
    >
      <TouchableWithoutFeedback onPress={() => setGiftCardsModalVisible(false)}>
        <View style={styles.modalOverlay}>
          <TouchableWithoutFeedback>
            <View style={styles.modalCard}>
              <View style={styles.notificationIconContainer}>
                <Icon name="gift-outline" size={RFValue(48)} color={PROFILE_ICON_COLOR} />
              </View>
              <CustomText variant="h4" fontFamily={Fonts.Bold} style={styles.modalTitle}>
                Gift Cards
              </CustomText>
              <CustomText variant="body" fontFamily={Fonts.Bold} style={styles.notificationMessage}>
                Purchase and send gift cards to your loved ones. Feature coming soon!
              </CustomText>
              <TouchableOpacity
                style={[styles.modalButton, styles.modalPrimary, styles.notificationButton]}
                onPress={() => setGiftCardsModalVisible(false)}
              >
                <CustomText variant="h7" fontFamily={Fonts.Bold} style={styles.primaryText}>
                  OK
                </CustomText>
              </TouchableOpacity>
            </View>
          </TouchableWithoutFeedback>
        </View>
      </TouchableWithoutFeedback>
    </Modal>
  );

  const renderSuggestModal = () => (
    <Modal
      visible={isSuggestModalVisible}
      animationType="slide"
      transparent
      onRequestClose={() => setSuggestModalVisible(false)}
    >
      <TouchableWithoutFeedback onPress={() => setSuggestModalVisible(false)}>
        <View style={styles.modalOverlay}>
          <TouchableWithoutFeedback>
            <View style={styles.modalCard}>
              <View style={styles.notificationIconContainer}>
                <Icon name="bulb-outline" size={RFValue(48)} color={PROFILE_ICON_COLOR} />
              </View>
              <CustomText variant="h4" fontFamily={Fonts.Bold} style={styles.modalTitle}>
                Suggest Products
              </CustomText>
              <CustomText variant="body" fontFamily={Fonts.Bold} style={styles.notificationMessage}>
                Have a product suggestion? We'd love to hear from you! Feature coming soon!
              </CustomText>
              <TouchableOpacity
                style={[styles.modalButton, styles.modalPrimary, styles.notificationButton]}
                onPress={() => setSuggestModalVisible(false)}
              >
                <CustomText variant="h7" fontFamily={Fonts.Bold} style={styles.primaryText}>
                  OK
                </CustomText>
              </TouchableOpacity>
            </View>
          </TouchableWithoutFeedback>
        </View>
      </TouchableWithoutFeedback>
    </Modal>
  );



  const renderRefundsModal = () => (
    <Modal
      visible={isRefundsModalVisible}
      animationType="slide"
      transparent
      onRequestClose={() => setRefundsModalVisible(false)}
    >
      <TouchableWithoutFeedback onPress={() => setRefundsModalVisible(false)}>
        <View style={styles.modalOverlay}>
          <TouchableWithoutFeedback>
            <View style={styles.modalCard}>
              <View style={styles.notificationIconContainer}>
                <Icon name="return-down-back-outline" size={RFValue(48)} color={PROFILE_ICON_COLOR} />
              </View>
              <CustomText variant="h4" fontFamily={Fonts.Bold} style={styles.modalTitle}>
                Refunds
              </CustomText>
              <CustomText variant="body" fontFamily={Fonts.Bold} style={styles.notificationMessage}>
                View and manage your refund requests. Feature coming soon!
              </CustomText>
              <TouchableOpacity
                style={[styles.modalButton, styles.modalPrimary, styles.notificationButton]}
                onPress={() => setRefundsModalVisible(false)}
              >
                <CustomText variant="h7" fontFamily={Fonts.Bold} style={styles.primaryText}>
                  OK
                </CustomText>
              </TouchableOpacity>
            </View>
          </TouchableWithoutFeedback>
        </View>
      </TouchableWithoutFeedback>
    </Modal>
  );

  const renderEditProfileModal = () => (
    <Modal
      visible={isEditModalVisible}
      animationType="slide"
      transparent
      onRequestClose={() => setEditModalVisible(false)}
    >
      <TouchableWithoutFeedback onPress={() => !savingProfile && setEditModalVisible(false)}>
        <View style={styles.modalOverlay}>
          <TouchableWithoutFeedback>
            <KeyboardAvoidingView
              behavior={Platform.OS === 'ios' ? 'padding' : undefined}
              style={styles.modalCard}
            >
              <CustomText variant="h4" fontFamily={Fonts.Bold} style={styles.modalTitle}>
                Edit Profile
              </CustomText>

              <View style={styles.inputGroup}>
                <CustomText variant="h8" fontFamily={Fonts.Bold} style={styles.inputLabel}>
                  Full Name
                </CustomText>
                <CustomInput
                  placeholder="Enter your full name"
                  value={profileForm.name}
                  onChangeText={(text) =>
                    setProfileForm((prev) => ({ ...prev, name: text }))
                  }
                  onClear={() => setProfileForm((prev) => ({ ...prev, name: '' }))}
                  left={
                    <Icon
                      name="person-outline"
                      color={colors.primaryBlue}
                      style={{ marginLeft: 10 }}
                      size={RFValue(18)}
                    />
                  }
                />
              </View>

              <View style={styles.inputGroup}>
                <CustomText variant="h8" fontFamily={Fonts.Bold} style={styles.inputLabel}>
                  Phone number
                </CustomText>
                <CustomInput
                  placeholder="Enter 10-digit phone number"
                  keyboardType="phone-pad"
                  value={profileForm.phone}
                  maxLength={10}
                  onChangeText={(text) =>
                    setProfileForm((prev) => ({ ...prev, phone: text.replace(/\D/g, '') }))
                  }
                  onClear={() => setProfileForm((prev) => ({ ...prev, phone: '' }))}
                  left={
                    <Icon
                      name="call-outline"
                      color={colors.primaryBlue}
                      style={{ marginLeft: 10 }}
                      size={RFValue(18)}
                    />
                  }
                />
              </View>

              <View style={styles.modalActions}>
                <TouchableOpacity
                  style={[styles.modalButton, styles.modalSecondary]}
                  onPress={() => setEditModalVisible(false)}
                  disabled={savingProfile}
                >
                  <CustomText variant="h7" fontFamily={Fonts.Bold} style={styles.secondaryText}>
                    Cancel
                  </CustomText>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.modalButton, styles.modalPrimary]}
                  onPress={handleSaveProfile}
                  disabled={savingProfile}
                >
                  <CustomText variant="h7" fontFamily={Fonts.Bold} style={styles.primaryText}>
                    {savingProfile ? 'Saving...' : 'Save'}
                  </CustomText>
                </TouchableOpacity>
              </View>
            </KeyboardAvoidingView>
          </TouchableWithoutFeedback>
        </View>
      </TouchableWithoutFeedback>
    </Modal>
  );

  const renderHeader = () => {
    return (
      <View>
        <View style={styles.profileHeroCard}>
          <View style={styles.heroTopRow}>
            <View style={styles.heroBadge}>
              <CustomText
                variant="h9"
                fontFamily={Fonts.Bold}
                style={styles.heroBadgeText}
              >
                MY PROFILE
              </CustomText>
            </View>
            <TouchableOpacity
              style={styles.editProfileChip}
              onPress={() => setEditModalVisible(true)}
              activeOpacity={0.82}
            >
              <Icon name="create-outline" size={RFValue(14)} color={colors.primaryBlue} />
              <CustomText
                variant="h9"
                fontFamily={Fonts.Bold}
                style={styles.editProfileChipText}
              >
                Edit
              </CustomText>
            </TouchableOpacity>
          </View>

          <View style={styles.avatarSection}>
            <View style={styles.avatarContainer}>
              {renderAvatar()}
            </View>
            <CustomText
              variant="body"
              fontFamily={Fonts.Bold}
              fontSize={13}
              style={styles.accountTitle}
            >
              Your Account
            </CustomText>
            <CustomText
              variant="body"
              fontFamily={Fonts.Bold}
              fontSize={20}
              style={[styles.profileName, styles.boldText]}
            >
              {user?.name || user?.phone || 'Guest User'}
            </CustomText>
            <CustomText
              variant="body"
              fontFamily={Fonts.Medium}
              fontSize={13}
              style={styles.phoneText}
            >
              {user?.phone}
            </CustomText>
            {user?.email ? (
              <CustomText
                variant="body"
                fontFamily={Fonts.Medium}
                fontSize={12}
                style={styles.emailText}
              >
                {user.email}
              </CustomText>
            ) : null}

          </View>

          <View style={styles.quickActionsContainer}>
            <TouchableOpacity
              style={styles.quickActionCard}
              activeOpacity={0.7}
              accessibilityRole="button"
              accessibilityLabel="View orders"
              accessibilityHint="Double tap to view your orders"
              onPress={() => handleQuickActionPress('orders')}
            >
              <Icon name="receipt-outline" size={RFValue(22)} color={PROFILE_ICON_COLOR} />
              <CustomText
                variant="body"
                fontFamily={Fonts.Bold}
                fontSize={12}
                style={styles.quickActionLabel}
              >
                Orders
              </CustomText>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.quickActionCard}
              activeOpacity={0.7}
              accessibilityRole="button"
              accessibilityLabel="Get help"
              accessibilityHint="Double tap to get help and support"
              onPress={() => handleQuickActionPress('help')}
            >
              <Icon name="help-circle-outline" size={RFValue(22)} color={PROFILE_ICON_COLOR} />
              <CustomText
                variant="body"
                fontFamily={Fonts.Bold}
                fontSize={12}
                style={styles.quickActionLabel}
              >
                Help
              </CustomText>
            </TouchableOpacity>
          </View>
        </View>

        <WalletSection />

        <View style={styles.menuContainer}>
          <ActionButton
            icon="return-down-back-outline"
            label="Refunds"
            onPress={() => handleMenuAction('refunds')}
          />
          <ActionButton
            icon="gift-outline"
            label="Gift Cards"
            onPress={() => handleMenuAction('giftcards')}
          />
          <ActionButton
            icon="location-outline"
            label="Addresses"
            onPress={() => handleMenuAction('addresses')}
          />
          <ActionButton
            icon="star-outline"
            label="Rewards"
            onPress={() => handleMenuAction('rewards')}
          />
          <ActionButton
            icon="bulb-outline"
            label="Suggest Products"
            onPress={() => handleMenuAction('suggest')}
          />
          <ActionButton
            icon="notifications-outline"
            label="Notifications"
            onPress={() => handleMenuAction('notifications')}
          />
          <ActionButton
            icon="information-circle-outline"
            label="About"
            onPress={() => handleMenuAction('about')}
            showDivider={false}
          />
        </View>

        <View style={styles.logoutContainer}>
          <ActionButton
            icon="log-out-outline"
            label="Logout"
            onPress={async () => {
              await clearCart();
              await logoutAndClearSession();
              resetAndNavigate('CustomerLogin');
            }}
            isLogout={true}
          />
        </View>

      </View>
    );
  };

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <CustomHeader title="Profile" />
      <ScrollView
        contentContainerStyle={[
          styles.scrollViewContent,
          {
            paddingBottom: insets.bottom + 96,
            paddingHorizontal: 16,
          },
        ]}
        showsVerticalScrollIndicator={false}
      >
        {renderHeader()}
      </ScrollView>
      <BottomTabBar />
      {renderEditProfileModal()}
      {renderNotificationModal()}
      {renderRewardsModal()}
      {renderGiftCardsModal()}
      {renderSuggestModal()}
      {renderRefundsModal()}
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F8FF',
  },
  scrollViewContent: {
    paddingTop: 14,
  },
  profileHeroCard: {
    backgroundColor: colors.white,
    borderRadius: 22,
    paddingHorizontal: 18,
    paddingTop: 16,
    paddingBottom: 18,
    marginBottom: 18,
    borderWidth: 1,
    borderColor: colors.blackOpacity05,
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.08,
    shadowRadius: 14,
    elevation: 4,
  },
  heroTopRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  heroBadge: {
    backgroundColor: '#EAF1FF',
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  heroBadgeText: {
    color: colors.primaryBlue,
    fontSize: 10,
    letterSpacing: 0.8,
  },
  editProfileChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#F7F9FF',
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  editProfileChipText: {
    color: colors.primaryBlue,
    fontSize: 11,
  },
  avatarSection: {
    alignItems: 'center',
    marginBottom: 20,
    marginTop: 4,
  },
  avatarContainer: {
    position: 'relative',
    marginBottom: 15,
  },
  avatar: {
    width: 100,
    height: 100,
    borderRadius: 50,
    backgroundColor: colors.lightBlue,
  },
  initialAvatar: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  initialsText: {
    color: colors.primaryBlue,
  },
  accountTitle: {
    marginTop: 4,
    color: colors.primaryBlue,
    letterSpacing: 1,
    opacity: 0.75,
  },
  profileName: {
    color: colors.primaryBlue,
    marginTop: 6,
    letterSpacing: 0.4,
  },
  boldText: {
    fontWeight: '700',
  },
  phoneText: {
    marginTop: 5,
    color: colors.primaryBlue,
    letterSpacing: 0.4,
    opacity: 0.8,
  },
  emailText: {
    marginTop: 4,
    color: colors.greyText,
  },
  quickActionsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 0,
    paddingHorizontal: 0,
  },
  quickActionCard: {
    flex: 1,
    backgroundColor: '#F3F7FF',
    borderRadius: 16,
    paddingVertical: 16,
    paddingHorizontal: 10,
    alignItems: 'center',
    justifyContent: 'center',
    marginHorizontal: 4,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
    shadowColor: colors.black,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 3,
    elevation: 3,
    minHeight: 44,
  },
  quickActionLabel: {
    marginTop: 8,
    color: colors.primaryBlue,
    textAlign: 'center',
    letterSpacing: 0.4,
    fontWeight: '700',
  },
  menuContainer: {
    backgroundColor: colors.white,
    borderRadius: 18,
    marginBottom: 20,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: colors.blackOpacity05,
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.06,
    shadowRadius: 12,
    elevation: 3,
  },
  logoutContainer: {
    marginBottom: 20,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
    padding: 20,
  },
  modalCard: {
    backgroundColor: colors.white,
    borderRadius: 16,
    padding: 20,
    elevation: 10,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
    shadowColor: colors.primaryBlue,
    shadowOpacity: 0.15,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 12 },
  },
  modalTitle: {
    marginBottom: 16,
    color: colors.primaryBlue,
    textAlign: 'center',
    letterSpacing: 1,
    fontWeight: '700',
  },
  modalActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: 12,
    marginTop: 10,
  },
  modalButton: {
    minWidth: 100,
    paddingVertical: 12,
    borderRadius: 10,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
    shadowColor: colors.primaryBlue,
    shadowOpacity: 0.12,
    shadowOffset: { width: 0, height: 6 },
    shadowRadius: 10,
  },
  modalPrimary: {
    backgroundColor: colors.secondaryBlue,
    borderColor: colors.secondaryBlue,
  },
  modalSecondary: {
    backgroundColor: colors.white,
    borderColor: colors.primaryBlue,
  },
  primaryText: {
    color: colors.white,
  },
  secondaryText: {
    color: colors.primaryBlue,
  },
  inputGroup: {
    marginBottom: 12,
  },
  inputLabel: {
    color: colors.primaryBlue,
    marginBottom: 6,
  },
  notificationIconContainer: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: colors.lightBlue,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 20,
    alignSelf: 'center',
  },
  notificationMessage: {
    fontSize: 14,
    color: colors.primaryBlue,
    textAlign: 'center',
    marginBottom: 24,
    lineHeight: 20,
  },
  notificationButton: {
    width: '100%',
    marginTop: 0,
  },
});

export default Profile;
