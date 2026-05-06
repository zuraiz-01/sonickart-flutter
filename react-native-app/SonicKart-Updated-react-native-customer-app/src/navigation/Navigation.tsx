import React, { FC } from 'react';
import { StatusBar } from 'react-native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { NavigationContainer } from '@react-navigation/native';
import SplashScreen from '@features/auth/SplashScreen';
import { navigationRef } from '@utils/NavigationUtils';
// import DeliveryLogin from '@features/auth/DeliveryLogin';
import CustomerLogin from '@features/auth/CustomerLogin';
import ProductDashboard from '@features/dashboard/ProductDashboard';
// import DeliveryDashboard from '@features/delivery/DeliveryDashboard';
import ProductCategories from '@features/category/ProductCategories';
import ProductOrder from '@features/order/ProductOrder';
import OrderSuccess from '@features/order/OrderSuccess';
import CustomerOrders from '@features/order/CustomerOrders';
import CartScreen from '@features/cart/CartScreen';
import LiveTracking from '@features/map/LiveTracking';
import Profile from '@features/profile/Profile';
import AddressBook from '@features/profile/AddressBook';
// import DeliveryMap from '@features/delivery/DeliveryMap';
import SearchScreen from '@features/search/SearchScreen';
import ProductDetail from '@features/product/ProductDetail';
import BuyAgainScreen from '@features/dashboard/BuyAgainScreen';
import PackageScreen from '@features/dashboard/PackageScreen';
import PackageOrderDetails from '@features/order/PackageOrderDetails';
import SessionExpiredModal from '@components/ui/SessionExpiredModal';
import GlobalOrderSocketListener from '@components/GlobalOrderSocketListener';
import { useAuthStore } from '@state/authStore';
import { resetAndNavigate } from '@utils/NavigationUtils';
import { logoutAndClearSession } from '@service/authService';

const Stack = createNativeStackNavigator();

/**
 * Main app navigator.
 * Customer routes are active here.
 * Delivery routes exist in codebase but are currently commented out.
 */
const Navigation: FC = () => {
  const { showSessionExpiredModal, setShowSessionExpiredModal } = useAuthStore();

  const handleLoginAgain = async () => {
    setShowSessionExpiredModal(false);
    await logoutAndClearSession();
    resetAndNavigate('CustomerLogin');
  };

  return (
    <>
      {/* Global socket listener for order updates across all pages */}
      <GlobalOrderSocketListener />

      <StatusBar
        translucent={true}
        backgroundColor="transparent"
        barStyle="dark-content"
      />
      <NavigationContainer ref={navigationRef}>
        <Stack.Navigator
          initialRouteName="SplashScreen"
          screenOptions={{
            headerShown: false,
          }}
        >
          <Stack.Screen name="SplashScreen" component={SplashScreen} />
          {/* <Stack.Screen name="DeliveryMap" component={DeliveryMap} /> */}
          <Stack.Screen name="Profile" component={Profile} />
          <Stack.Screen name="AddressBook" component={AddressBook} />
          <Stack.Screen name="ProductDashboard" component={ProductDashboard} />
          <Stack.Screen name="LiveTracking" component={LiveTracking} />
          <Stack.Screen name="ProductCategories" component={ProductCategories} />
          <Stack.Screen name="BuyAgain" component={BuyAgainScreen} />
          <Stack.Screen name="Package" component={PackageScreen} />
          <Stack.Screen name="PackageOrderDetails" component={PackageOrderDetails} />
          <Stack.Screen name="SearchScreen" component={SearchScreen} />
          {/* <Stack.Screen name="DeliveryDashboard" component={DeliveryDashboard} /> */}
          <Stack.Screen name="CartScreen" component={CartScreen} />
          <Stack.Screen name="ProductOrder" component={ProductOrder} />
          <Stack.Screen name="ProductDetail" component={ProductDetail} />
          <Stack.Screen name="CustomerOrders" component={CustomerOrders} />
          <Stack.Screen name="OrderSuccess" component={OrderSuccess} />
          {/* <Stack.Screen
            options={{
              animation: 'fade',
            }}
            name="DeliveryLogin"
            component={DeliveryLogin}
          /> */}
          <Stack.Screen
            options={{
              animation: 'fade',
            }}
            name="CustomerLogin"
            component={CustomerLogin}
          />
        </Stack.Navigator>
      </NavigationContainer>

      {/* Global Session Expired Modal */}
      <SessionExpiredModal
        visible={showSessionExpiredModal}
        onLoginAgain={handleLoginAgain}
      />
    </>
  );
};

export default Navigation;
