import { View, StyleSheet, Pressable } from 'react-native';
import React, { FC } from 'react';
import { useCartStore } from '@state/cartStore';
import { Colors, Fonts } from '@utils/Constants';
import CustomText from './CustomText';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import { RFValue } from 'react-native-responsive-fontsize';
import colors from '../../theme/colors';

/**
 * Unified add/stepper control connected to cart store.
 * Shows `ADD` state or quantity +/- controls depending on item count.
 */
interface UniversalAddProps {
  item: any;
  onAdd?: () => void;
  onInitialAdd?: () => void;
  onRemove?: () => void;
}

const UniversalAdd: FC<UniversalAddProps> = ({ item, onAdd, onInitialAdd, onRemove }) => {
  // Use id if available, fallback to _id for backward compatibility
  const itemId = item.id || item._id;
  const count = useCartStore((state) => state.getItemCount(itemId));
  const { addItem, removeItem } = useCartStore();

  const handleInitialAdd = () => {
    addItem(item);
    onAdd?.();
  };

  const handleRemove = () => {
    removeItem(itemId);
    onRemove?.();
  };

  return (
    <View
      style={[
        styles.container,
        { backgroundColor: count === 0 ? colors.accentYellow : Colors.secondary },
      ]}
    >
      {count === 0 ? (
        <Pressable
          onPress={onInitialAdd ? onInitialAdd : handleInitialAdd}
          style={styles.add}
          accessibilityRole="button"
          accessibilityLabel={`Add ${item?.name || 'item'} to cart`}
        >
          <CustomText
            variant="h9"
            fontFamily={Fonts.SemiBold}
            style={styles.addText}
          >
            ADD
          </CustomText>
        </Pressable>
      ) : (
        <View style={styles.counterContainer}>
          <Pressable
            onPress={handleRemove}
            accessibilityRole="button"
            accessibilityLabel={`Decrease quantity of ${item?.name || 'item'}`}
            accessibilityHint="Double tap to remove one item from cart"
          >
            <Icon name="minus" color={colors.white} size={RFValue(13)} />
          </Pressable>
          <CustomText
            fontFamily={Fonts.SemiBold}
            style={styles.text}
            variant="h8"
            accessibilityLabel={`Quantity: ${count}`}
          >
            {count}
          </CustomText>

          <Pressable
            onPress={() => addItem(item)}
            accessibilityRole="button"
            accessibilityLabel={`Increase quantity of ${item?.name || 'item'}`}
            accessibilityHint="Double tap to add one more item to cart"
          >
            <Icon name="plus" color={colors.white} size={RFValue(13)} />
          </Pressable>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 0,
    width: '100%',
    borderRadius: 8,
    minHeight: 40,
  },
  add: {
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 4,
    paddingVertical: 5,
    minHeight: 40,
  },
  addText: {
    color: colors.primaryBlue,
  },
  counterContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    width: '100%',
    paddingHorizontal: 4,
    paddingVertical: 5,
    justifyContent: 'space-between',
  },
  text: {
    color: colors.white,
  },
});

export default UniversalAdd;
