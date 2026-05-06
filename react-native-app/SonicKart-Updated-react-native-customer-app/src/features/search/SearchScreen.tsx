import { View, StyleSheet, TextInput, ActivityIndicator, TouchableOpacity } from 'react-native';
import React, { FC, useState, useEffect, useRef, useCallback } from 'react';
import { SafeAreaView } from 'react-native-safe-area-context';
import CustomHeader from '@components/ui/CustomHeader';
import { Colors, Fonts } from '@utils/Constants';
import { searchProducts } from '@service/productService';
import ProductList from '@features/category/ProductList';
import CustomText from '@components/ui/CustomText';
import Icon from 'react-native-vector-icons/Ionicons';
import { RFValue } from 'react-native-responsive-fontsize';
import { useDeliverySettingsStore } from '@state/deliverySettingsStore';
import colors from '../../theme/colors';
import { useVendorLocationContext } from '../../hooks/useVendorLocationContext';

const normalizeIdToken = (value: any) => String(value ?? '').trim();

const uniqueValues = (values: string[]) => [...new Set(values.filter(Boolean))];

const collectProductVendorIds = (product: any) =>
  uniqueValues([
    normalizeIdToken(product?.vendorId),
    normalizeIdToken(product?.vendor_id),
    normalizeIdToken(product?.vendor?.id),
    normalizeIdToken(product?.vendor?.vendorId),
  ]);

/**
 * Product search screen with 500ms debounced API calls.
 */
const SearchScreen: FC = () => {
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [products, setProducts] = useState<any[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [hasSearched, setHasSearched] = useState<boolean>(false);
  const [vendorContextMissing, setVendorContextMissing] = useState<boolean>(false);
  const searchTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const productRadiusKm = useDeliverySettingsStore(
    (state) => state.settings.productRadiusKm
  );
  const { vendorIds, scopedCoordinate, vendorResolving } = useVendorLocationContext();

  const performSearch = useCallback(async (query: string) => {
    if (!query || query.trim().length === 0) {
      setProducts([]);
      setHasSearched(false);
      setVendorContextMissing(false);
      setLoading(false);
      return;
    }

    if (vendorResolving) {
      setLoading(true);
      setVendorContextMissing(false);
      return;
    }

    try {
      setLoading(true);
      setHasSearched(true);
      setVendorContextMissing(false);

      if (!vendorIds.length) {
        setProducts([]);
        setVendorContextMissing(true);
        return;
      }

      const results =
        vendorIds.length > 1
          ? (
              await Promise.all(
                vendorIds.map(async (vendorId) => {
                  return searchProducts(query, {
                    vendorId,
                    latitude: scopedCoordinate?.latitude,
                    longitude: scopedCoordinate?.longitude,
                    radiusKm: productRadiusKm,
                  });
                })
              )
            ).flat()
          : await searchProducts(query, {
              vendorId: vendorIds[0],
              latitude: scopedCoordinate?.latitude,
              longitude: scopedCoordinate?.longitude,
              radiusKm: productRadiusKm,
            });

      const uniqueProducts = new Map<string, any>();

      (Array.isArray(results) ? results : []).forEach((product: any) => {
        const productId = String(product?.id ?? product?._id ?? '').trim();
        if (!productId || uniqueProducts.has(productId)) {
          return;
        }
        uniqueProducts.set(productId, product);
      });

      const filteredProducts = Array.from(uniqueProducts.values()).filter((product: any) => {
        const productVendorIds = collectProductVendorIds(product);
        if (!productVendorIds.length) {
          return false;
        }

        return productVendorIds.some((vendorId) => vendorIds.includes(vendorId));
      });

      setProducts(filteredProducts);
    } catch (error) {
      console.error('Error searching products:', error);
      setProducts([]);
    } finally {
      setLoading(false);
    }
  }, [
    productRadiusKm,
    scopedCoordinate?.latitude,
    scopedCoordinate?.longitude,
    vendorIds,
    vendorResolving,
  ]);

  useEffect(() => {
    // Clear previous timeout
    if (searchTimeoutRef.current) {
      clearTimeout(searchTimeoutRef.current);
    }

    // Set new timeout for debounced search
    searchTimeoutRef.current = setTimeout(() => {
      performSearch(searchQuery);
    }, 500); // 500ms debounce

    // Cleanup function
    return () => {
      if (searchTimeoutRef.current) {
        clearTimeout(searchTimeoutRef.current);
      }
    };
  }, [
    searchQuery,
    performSearch,
  ]);

  const clearSearch = () => {
    setSearchQuery('');
    setProducts([]);
    setHasSearched(false);
    setVendorContextMissing(false);
  };

  return (
    <SafeAreaView style={{ flex: 1 }} edges={['top']}>
      <View style={styles.mainContainer}>
        <CustomHeader title="Search Products" />
      <View style={styles.searchContainer}>
        <View style={styles.searchInputContainer}>
          <Icon name="search" color={colors.primaryBlue} size={RFValue(20)} style={styles.searchIcon} />
          <TextInput
            style={styles.searchInput}
            placeholder="Search for products..."
            placeholderTextColor={colors.greyText}
            value={searchQuery}
            onChangeText={setSearchQuery}
            autoFocus={true}
            returnKeyType="search"
            accessibilityRole="search"
            accessibilityLabel="Search input"
          />
          {searchQuery.length > 0 && (
            <TouchableOpacity
              onPress={clearSearch}
              style={styles.clearButton}
              accessibilityRole="button"
              accessibilityLabel="Clear search"
            >
              <Icon name="close-circle" color={colors.greyText} size={RFValue(20)} />
            </TouchableOpacity>
          )}
        </View>
      </View>

      {loading ? (
        <View style={styles.centerContainer}>
          <ActivityIndicator size="large" color={Colors.border} />
          <CustomText
            variant="h8"
            fontFamily={Fonts.Medium}
            style={styles.loadingText}
          >
            Searching...
          </CustomText>
        </View>
      ) : hasSearched && products.length === 0 ? (
        <View style={styles.centerContainer}>
          <Icon name="search-outline" color={colors.greyText} size={RFValue(60)} />
          <CustomText
            variant="h6"
            fontFamily={Fonts.Medium}
            style={styles.emptyText}
          >
            {vendorContextMissing ? 'Location not available' : 'No products found'}
          </CustomText>
          <CustomText
            variant="h8"
            fontFamily={Fonts.Regular}
            style={styles.emptySubText}
          >
            {vendorContextMissing
              ? 'Enable location or select a delivery address to search nearby vendor products.'
              : 'Try searching with different keywords'}
          </CustomText>
        </View>
      ) : !hasSearched ? (
        <View style={styles.centerContainer}>
          <Icon name="search-outline" color={colors.greyText} size={RFValue(60)} />
          <CustomText
            variant="h6"
            fontFamily={Fonts.Medium}
            style={styles.emptyText}
          >
            Search for products
          </CustomText>
          <CustomText
            variant="h8"
            fontFamily={Fonts.Regular}
            style={styles.emptySubText}
          >
            Enter a product name to search
          </CustomText>
        </View>
      ) : (
        <View style={styles.resultsContainer}>
          <CustomText
            variant="h8"
            fontFamily={Fonts.Medium}
            style={styles.resultsCount}
          >
            {products.length} {products.length === 1 ? 'product' : 'products'} found
          </CustomText>
          <ProductList data={products} />
        </View>
      )}
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  mainContainer: {
    flex: 1,
    backgroundColor: colors.white,
  },
  searchContainer: {
    paddingHorizontal: 10,
    paddingVertical: 10,
    backgroundColor: colors.white,
    borderBottomWidth: 0.6,
    borderColor: Colors.border,
  },
  searchInputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.white,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: colors.primaryBlue,
    paddingHorizontal: 10,
    minHeight: 44,
  },
  searchIcon: {
    marginRight: 8,
  },
  searchInput: {
    flex: 1,
    fontSize: RFValue(14),
    fontFamily: Fonts.Regular,
    color: Colors.text,
    paddingVertical: 10,
  },
  clearButton: {
    padding: 4,
    marginLeft: 8,
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 20,
  },
  loadingText: {
    marginTop: 10,
    color: colors.greyText,
  },
  emptyText: {
    marginTop: 16,
    color: Colors.text,
    textAlign: 'center',
  },
  emptySubText: {
    marginTop: 8,
    color: colors.greyText,
    textAlign: 'center',
  },
  resultsContainer: {
    flex: 1,
  },
  resultsCount: {
    paddingHorizontal: 20,
    paddingVertical: 10,
    color: colors.greyText,
    backgroundColor: Colors.backgroundSecondary,
  },
});

export default SearchScreen;
