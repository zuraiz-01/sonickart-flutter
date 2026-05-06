import { StyleSheet, FlatList, View } from 'react-native';
import React, { FC, useEffect, useMemo, useRef } from 'react';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors, Fonts } from '@utils/Constants';
import ProductItem from './ProductItem';
import CustomText from '@components/ui/CustomText';
import colors from '../../theme/colors';

const NUM_COLUMNS = 2;

/**
 * Reusable two-column list renderer for product cards.
 */
const ProductList: FC<{ data: any; targetProductId?: string; showEmptyState?: boolean }> = ({
  data,
  targetProductId,
  showEmptyState = false,
}) => {
  const insets = useSafeAreaInsets();
  const listRef = useRef<FlatList>(null);
  const targetIndex = useMemo(() => {
    if (!targetProductId) {
      return -1;
    }

    return data.findIndex(
      (item: any) => String(item?.id ?? item?._id ?? '') === targetProductId
    );
  }, [data, targetProductId]);
  const targetRowIndex = useMemo(() => {
    if (targetIndex < 0) {
      return -1;
    }

    return Math.floor(targetIndex / NUM_COLUMNS);
  }, [targetIndex]);

  useEffect(() => {
    if (targetRowIndex < 0) {
      return;
    }

    const timeoutId = setTimeout(() => {
      const maxRowIndex = Math.max(0, Math.ceil(data.length / NUM_COLUMNS) - 1);
      const safeRowIndex = Math.min(targetRowIndex, maxRowIndex);

      listRef.current?.scrollToIndex({
        index: safeRowIndex,
        animated: true,
        viewPosition: 0.2,
      });
    }, 250);

    return () => clearTimeout(timeoutId);
  }, [data.length, targetRowIndex]);

  const renderItem = ({ item, index }: any) => {
    return <ProductItem item={item} index={index} />;
  };

  return (
    <FlatList
      ref={listRef}
      data={data}
      keyExtractor={(item, index) => String(item?.id ?? item?._id ?? index)}
      renderItem={renderItem}
      style={styles.container}
      contentContainerStyle={[styles.content, { paddingBottom: insets.bottom + 100 }]}
      columnWrapperStyle={styles.row}
      numColumns={NUM_COLUMNS}
      initialNumToRender={12}
      maxToRenderPerBatch={12}
      removeClippedSubviews={false}
      ListEmptyComponent={
        showEmptyState ? (
          <View style={styles.emptyState}>
            <CustomText
              variant="h8"
              fontFamily={Fonts.Bold}
              style={styles.emptyText}
            >
              Products will be add soon.
            </CustomText>
          </View>
        ) : null
      }
      onScrollToIndexFailed={(info) => {
        const maxRowIndex = Math.max(0, Math.ceil(data.length / NUM_COLUMNS) - 1);
        const safeRowIndex = Math.min(info.index, maxRowIndex);
        listRef.current?.scrollToOffset({
          offset: info.averageItemLength * safeRowIndex,
          animated: true,
        });
      }}
    />
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    height: '100%',
    backgroundColor: Colors.backgroundSecondary,
  },
  content: {
    paddingVertical: 10,
    paddingHorizontal: 8,
  },
  row: {
    justifyContent: 'space-between',
  },
  emptyState: {
    flex: 1,
    minHeight: 240,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 20,
  },
  emptyText: {
    textAlign: 'center',
    color: colors.primaryBlue,
    fontWeight: '700',
  },
});
export default ProductList;
