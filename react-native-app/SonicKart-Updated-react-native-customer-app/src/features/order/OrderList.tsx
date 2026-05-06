import { View, StyleSheet } from 'react-native';
import React from 'react';
import { useCartStore } from '@state/cartStore';
import OrderItem from './OrderItem';
import colors from '../../theme/colors';

interface OrderListProps {
  onCartEmpty?: () => void;
}

const OrderList: React.FC<OrderListProps> = ({ onCartEmpty }) => {
  const cartItems = useCartStore((state) => state.cart);
  return (
    <View style={styles.container}>
      {cartItems?.map((item) => {
        const key = item?.id || item?._id;
        return <OrderItem key={key} item={item} onCartEmpty={onCartEmpty} />;
      })}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: colors.white,
    marginHorizontal: 16,
    marginBottom: 14,
    borderRadius: 22,
    overflow: 'hidden',
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.03,
    shadowRadius: 4,
    elevation: 1,
  },
});
export default OrderList;
