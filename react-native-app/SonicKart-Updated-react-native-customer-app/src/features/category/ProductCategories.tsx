import {
  View,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import React, { FC, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Fonts } from '@utils/Constants';
import Sidebar from './Sidebar';
import {
  getAllCategories,
  getProductsByCategoryId,
} from '@service/productService';
import ProductList from './ProductList';
import colors from '../../theme/colors';
import CustomHeader from '@components/ui/CustomHeader';
import CustomText from '@components/ui/CustomText';
import { toTitleCase } from '@utils/stringUtils';
import { useRoute } from '@react-navigation/native';
import { useCategoryStore } from '@state/categoryStore';
import { useDeliverySettingsStore } from '@state/deliverySettingsStore';
import BottomTabBar from '@components/ui/BottomTabBar';
import { useVendorLocationContext } from '../../hooks/useVendorLocationContext';

type ProductCategoriesRouteParams = {
  categoryId?: string | number;
  categoryName?: string;
  productId?: string | number;
  preferredVendorId?: string | number;
};

/**
 * Category browse screen.
 * Loads categories, resolves vendor by selected address, and fetches vendor-aware products.
 */
const ProductCategories: FC = () => {
  const route = useRoute();
  const routeParams = route?.params as ProductCategoriesRouteParams | undefined;

  const lastCategoryId = useCategoryStore((state) => state.lastCategoryId);
  const setLastCategoryId = useCategoryStore(
    (state) => state.setLastCategoryId
  );
  const productRadiusKm = useDeliverySettingsStore(
    (state) => state.settings.productRadiusKm
  );
  const { vendorIds: selectedVendorIds, scopedCoordinate, vendorResolving } =
    useVendorLocationContext();

  const routeCategoryId = useMemo(() => {
    if (!routeParams?.categoryId) {
      return undefined;
    }
    return String(routeParams.categoryId);
  }, [routeParams?.categoryId]);

  const routeProductId = useMemo(() => {
    if (!routeParams?.productId) {
      return undefined;
    }
    return String(routeParams.productId);
  }, [routeParams?.productId]);

  const routePreferredVendorId = useMemo(() => {
    if (!routeParams?.preferredVendorId) {
      return undefined;
    }
    return String(routeParams.preferredVendorId);
  }, [routeParams?.preferredVendorId]);

  const [initialCategoryId, setInitialCategoryId] = useState<string | undefined>(
    routeCategoryId
  );

  useEffect(() => {
    if (routeCategoryId) {
      setInitialCategoryId(routeCategoryId);
    }
  }, [routeCategoryId]);

  const [categories, setCategories] = useState<any[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<any>(null);
  const [products, setProducts] = useState<any[]>([]);
  const [categoriesLoading, setCategoriesLoading] = useState<boolean>(true);
  const [productsLoading, setProductsLoading] = useState<boolean>(false);
  const [productsResolved, setProductsResolved] = useState<boolean>(false);
  const latestProductsRequestRef = useRef(0);
  const preferredVendorIds = useMemo(
    () =>
      String(routePreferredVendorId ?? '')
        .split(',')
        .map((vendorId) => vendorId.trim())
        .filter(Boolean),
    [routePreferredVendorId]
  );

  const fetchCategories = async () => {
    try {
      setCategoriesLoading(true);
      const data = await getAllCategories();
      setCategories(data);
    } catch (error) {
      console.log('Error Fetching Categories', error);
    } finally {
      setCategoriesLoading(false);
    }
  };

  useEffect(() => {
    fetchCategories();
  }, []);

  const fetchProducts = useCallback(async (categoryId: string | number) => {
    const requestId = latestProductsRequestRef.current + 1;
    latestProductsRequestRef.current = requestId;

    try {
      setProductsResolved(false);
      setProductsLoading(true);
      const preferredScopedVendors = preferredVendorIds.filter((vendorId) =>
        selectedVendorIds.includes(vendorId)
      );
      const vendorIds =
        preferredScopedVendors.length > 0 ? preferredScopedVendors : selectedVendorIds;

      if (!vendorIds.length) {
        if (latestProductsRequestRef.current !== requestId) {
          return;
        }
        setProducts([]);
        return;
      }

      const data =
        vendorIds.length > 1
          ? (
              await Promise.all(
                vendorIds.map(async (vendorId) => {
                  const vendorProducts = await getProductsByCategoryId(String(categoryId), {
                    vendorId,
                    latitude: scopedCoordinate?.latitude,
                    longitude: scopedCoordinate?.longitude,
                    radiusKm: productRadiusKm,
                  });

                  return vendorProducts.map((product: any) => ({
                    ...product,
                    vendorId: product?.vendorId || product?.vendor_id || vendorId,
                    vendor_id: product?.vendor_id || product?.vendorId || vendorId,
                  }));
                })
              )
            ).flat()
          : await getProductsByCategoryId(String(categoryId), {
              vendorId: vendorIds[0],
              latitude: scopedCoordinate?.latitude,
              longitude: scopedCoordinate?.longitude,
              radiusKm: productRadiusKm,
            });

      if (latestProductsRequestRef.current !== requestId) {
        return;
      }
      setProducts(data);
    } catch (error) {
      console.log('Error Fetching Products', error);
    } finally {
      if (latestProductsRequestRef.current !== requestId) {
        return;
      }
      setProductsResolved(true);
      setProductsLoading(false);
    }
  }, [
    productRadiusKm,
    preferredVendorIds,
    scopedCoordinate?.latitude,
    scopedCoordinate?.longitude,
    selectedVendorIds,
  ]);

  useEffect(() => {
    if (!categories.length) {
      return;
    }

    let nextCategory = categories[0];

    if (initialCategoryId) {
      const match = categories.find(
        (category) => String(category.id) === String(initialCategoryId)
      );
      if (match) {
        nextCategory = match;
      }
    } else if (lastCategoryId) {
      const storedMatch = categories.find(
        (category) => String(category.id) === String(lastCategoryId)
      );
      if (storedMatch) {
        nextCategory = storedMatch;
      }
    }

    if (nextCategory?.id && nextCategory?.id !== selectedCategory?.id) {
      setSelectedCategory(nextCategory);
      setLastCategoryId(String(nextCategory.id));
      if (
        initialCategoryId &&
        String(nextCategory.id) === String(initialCategoryId)
      ) {
        setInitialCategoryId(undefined);
      }
    }
  }, [
    categories,
    initialCategoryId,
    lastCategoryId,
    selectedCategory?.id,
    setLastCategoryId,
  ]);

  useEffect(() => {
    if (selectedCategory?.id && !vendorResolving) {
      fetchProducts(selectedCategory.id);
    }
  }, [selectedCategory?.id, vendorResolving, fetchProducts]);

  const handleCategorySelect = (category: any) => {
    setProductsResolved(false);
    setSelectedCategory(category);
    setLastCategoryId(category?.id ? String(category.id) : null);
    setInitialCategoryId(undefined);
  };

  return (
    <SafeAreaView style={{ flex: 1 }} edges={['top']}>
      <View style={styles.mainContainer}>
        <CustomHeader
          title={toTitleCase(selectedCategory?.name) || 'Categories'}
          search
        />
      <View style={styles.subContainer}>
        {!categoriesLoading && (
          <Sidebar
            categories={categories}
            selectedCategory={selectedCategory}
            onCategoryPress={handleCategorySelect}
          />
        )}
        <View style={styles.productWrapper}>
          {categoriesLoading || vendorResolving ? (
            <ActivityIndicator size="small" color={colors.primaryBlue} />
          ) : productsLoading ? (
            <ActivityIndicator
              size="large"
              color={colors.primaryBlue}
              style={styles.center}
            />
          ) : selectedCategory?.id && productsResolved && !(products?.length > 0) ? (
            <View style={styles.emptyState}>
              <CustomText
                variant="h8"
                fontFamily={Fonts.Bold}
                style={styles.emptyText}
              >
                New categories will be avaliable soon.
              </CustomText>
            </View>
          ) : (
            <ProductList
              data={products || []}
              targetProductId={routeProductId}
            />
          )}
        </View>
      </View>
      </View>
      <BottomTabBar />
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  mainContainer: {
    flex: 1,
    backgroundColor: colors.white,
  },
  subContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
  },
  productWrapper: {
    flex: 1,
    height: '100%',
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 20,
  },
  emptyText: {
    textAlign: 'center',
    color: colors.primaryBlue,
    fontWeight: '700',
  },
});

export default ProductCategories;
