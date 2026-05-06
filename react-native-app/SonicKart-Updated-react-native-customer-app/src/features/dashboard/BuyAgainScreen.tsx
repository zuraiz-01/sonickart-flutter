import React, { FC } from 'react';
import { View, StyleSheet } from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import CustomHeader from '@components/ui/CustomHeader';
import CustomText from '@components/ui/CustomText';
import colors from '../../theme/colors';
import { Fonts } from '@utils/Constants';
import BottomTabBar from '@components/ui/BottomTabBar';

const BuyAgainScreen: FC = () => {
  const insets = useSafeAreaInsets();
  return (
    <SafeAreaView style={{ flex: 1 }} edges={['top']}>
      <View style={styles.container}>
        <CustomHeader title="Buy Again" />
        <View style={[styles.content, { paddingBottom: insets.bottom + 120 }]}>
          <CustomText
            fontFamily={Fonts.Bold}
            fontSize={20}
            style={styles.title}
          >
            Coming Soon
          </CustomText>
          <CustomText
            fontFamily={Fonts.Medium}
            style={styles.subtitle}
            numberOfLines={2}
          >
            We are building a personalised Buy Again list for you.
          </CustomText>
        </View>
      </View>
      <BottomTabBar />
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.white,
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 24,
  },
  title: {
    color: colors.primaryBlue,
    marginBottom: 8,
    textAlign: 'center',
  },
  subtitle: {
    color: colors.darkBlue,
    textAlign: 'center',
  },
});

export default BuyAgainScreen;

