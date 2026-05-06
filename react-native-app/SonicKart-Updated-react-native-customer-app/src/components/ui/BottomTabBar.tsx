import { Platform, StyleSheet, TouchableOpacity, View } from 'react-native';
import React, { FC } from 'react';
import Ionicons from 'react-native-vector-icons/Ionicons';
import MaterialCommunityIcons from 'react-native-vector-icons/MaterialCommunityIcons';
import { RFValue } from 'react-native-responsive-fontsize';
import {
  NavigationProp,
  ParamListBase,
  useNavigation,
  useNavigationState,
} from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import CustomText from './CustomText';
import { Fonts } from '@utils/Constants';
import { resetAndNavigateWithParams } from '@utils/NavigationUtils';
import colors from '../../theme/colors';

interface TabItem {
  name: string;
  icon: string;
  iconFilled: string;
  route: string;
  IconComponent?: typeof Ionicons;
  params?: object;
}

const BottomTabBar: FC = () => {
  const navigation = useNavigation<NavigationProp<ParamListBase>>();
  const insets = useSafeAreaInsets();
  const currentRoute =
    useNavigationState((state) => state?.routes?.[state?.index ?? 0]?.name) ??
    navigation?.getState?.()?.routes?.[
      navigation?.getState?.()?.index ?? 0
    ]?.name;

  const tabs: TabItem[] = [
    {
      name: 'Home',
      icon: 'home-outline',
      iconFilled: 'home',
      route: 'ProductDashboard',
      IconComponent: Ionicons,
    },
    {
      name: 'Categories',
      icon: 'shape-outline',
      iconFilled: 'shape',
      route: 'ProductCategories',
      IconComponent: MaterialCommunityIcons,
    },
    {
      name: 'Cart',
      icon: 'cart-outline',
      iconFilled: 'cart',
      route: 'CartScreen',
      IconComponent: Ionicons,
    },
    {
      name: 'Package',
      icon: 'cube-outline',
      iconFilled: 'cube',
      route: 'Package',
      IconComponent: Ionicons,
    },
    {
      name: 'Profile',
      icon: 'person-outline',
      iconFilled: 'person',
      route: 'Profile',
      IconComponent: Ionicons,
    },
  ];

  const isActive = (route: string) => currentRoute === route;

  const handleNavigate = (route: string, active: boolean, params?: object) => {
    if (active) {
      return;
    }

    try {
      resetAndNavigateWithParams(route, params);
    } catch (error) {
      console.log('BottomTabBar navigate error', error);
    }
  };

  return (
    <View style={[styles.safeAreaWrap, { paddingBottom: insets.bottom + 6 }]}>
      <View style={styles.topAccent} />
      <View style={styles.container}>
        <View style={styles.tabsRow}>
          {tabs.map((tab) => {
            const active = isActive(tab.route);
            const IconComponent = tab.IconComponent || Ionicons;

            return (
              <TouchableOpacity
                key={tab.route}
                style={styles.tab}
                onPress={() => handleNavigate(tab.route, active, tab.params)}
                activeOpacity={0.8}
              >
                {active ? (
                  <View style={styles.activeTabWrap}>
                    <View style={styles.activeTabOuter}>
                      <View style={styles.activeTabInner}>
                        <IconComponent
                          name={tab.iconFilled}
                          size={RFValue(17.5)}
                          color={colors.primaryBlue}
                        />
                      </View>
                    </View>
                  </View>
                ) : (
                  <IconComponent
                    name={tab.icon}
                    size={RFValue(18)}
                    color={colors.greyText}
                  />
                )}

                <CustomText
                  variant="h9"
                  fontFamily={Fonts.Medium}
                  style={[
                    styles.label,
                    active ? styles.activeLabel : null,
                    { color: active ? colors.primaryBlue : colors.greyText },
                  ]}
                >
                  {tab.name}
                </CustomText>
              </TouchableOpacity>
            );
          })}
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  safeAreaWrap: {
    backgroundColor: 'transparent',
    paddingHorizontal: 12,
    paddingTop: 6,
  },
  topAccent: {
    position: 'absolute',
    left: 12,
    right: 12,
    top: 6,
    height: 24,
    borderTopLeftRadius: 22,
    borderTopRightRadius: 22,
    backgroundColor: colors.primaryBlue,
  },
  container: {
    backgroundColor: colors.white,
    borderRadius: 22,
    minHeight: 74,
    paddingTop: 8,
    paddingHorizontal: 8,
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: -2 },
    shadowOpacity: 0.12,
    shadowRadius: 10,
    elevation: 10,
    overflow: 'visible',
  },
  tabsRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-between',
  },
  tab: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingTop: Platform.OS === 'ios' ? 7 : 5,
    paddingBottom: 8,
    minHeight: 54,
  },
  label: {
    marginTop: 4,
    fontSize: RFValue(8.1),
  },
  activeLabel: {
    marginTop: 10,
  },
  activeTabWrap: {
    marginTop: -20,
    marginBottom: 2,
  },
  activeTabOuter: {
    width: 46,
    height: 46,
    borderRadius: 23,
    backgroundColor: colors.primaryBlue,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.16,
    shadowRadius: 10,
    elevation: 7,
  },
  activeTabInner: {
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: colors.white,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
  },
});

export default BottomTabBar;
