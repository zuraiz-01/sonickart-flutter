import { View, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import React, { FC, useEffect, useState } from 'react';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors } from '@utils/Constants';
import colors from '../../theme/colors';
import CustomText from '@components/ui/CustomText';
import { toTitleCase } from '@utils/stringUtils';

interface SidebarProps {
  selectedCategory: any;
  categories: any;
  onCategoryPress: (category: any) => void;
}

const Sidebar: FC<SidebarProps> = ({
  selectedCategory,
  categories,
  onCategoryPress,
}) => {
  const insets = useSafeAreaInsets();
  const [categoryList, setCategoryList] = useState<any[]>(categories ?? []);

  useEffect(() => {
    if (categories?.length) {
      setCategoryList(categories);
    }
  }, [categories]);

  return (
    <View style={styles.sideBar}>
      <ScrollView
        contentContainerStyle={[styles.scrollContent, { paddingBottom: insets.bottom + 50 }]}
        showsVerticalScrollIndicator={false}
      >
        {categoryList?.map((category: any) => {
          const isSelected = selectedCategory?.id === category?.id;
          return (
            <TouchableOpacity
              key={category?.id ?? category?.name}
              activeOpacity={0.8}
              style={[
                styles.categoryButton,
                isSelected && styles.selectedCategoryButton,
              ]}
              onPress={() => onCategoryPress(category)}
            >
              <CustomText
                fontSize={10}
                style={
                  isSelected
                    ? [styles.categoryLabel, styles.selectedCategoryLabel]
                    : styles.categoryLabel
                }
              >
                {toTitleCase(category?.name)}
              </CustomText>
            </TouchableOpacity>
          );
        })}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  sideBar: {
    width: '30%',
    backgroundColor: colors.white,
    borderRightWidth: 0.8,
    borderRightColor: colors.lightBlue,
  },
  scrollContent: {
  },
  categoryButton: {
    paddingVertical: 18,
    paddingHorizontal: 12,
    justifyContent: 'center',
  },
  selectedCategoryButton: {
    backgroundColor: Colors.secondary + '15',
    borderRightWidth: 4,
    borderRightColor: Colors.secondary,
  },
  categoryLabel: {
    textAlign: 'left',
    color: Colors.secondary,
    fontWeight: '700',
  },
  selectedCategoryLabel: {
    color: Colors.secondary,
    fontWeight: '800',
  },
});

export default Sidebar;
