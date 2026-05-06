import axios from 'axios';
import { BASE_URL } from './config';
import { normalizeImageUrl } from '@utils/imageUtils';
import { getProductUnit } from '@utils/productUnit';
import { getProductVendorRadiusKm } from '@utils/vendorRadius';

/**
 * Product catalog APIs.
 * Includes category listing, category-wise products, and search.
 */
const resolveProductImage = (product: any): string | null =>
  normalizeImageUrl(product?.image) ||
  normalizeImageUrl(product?.product_images) ||
  normalizeImageUrl(product?.images) ||
  null;

const inferVendorIdFromAssetPath = (product: any) => {
  const imageCandidates = [
    product?.image,
    product?.imageUrl,
    product?.product_images,
    ...(Array.isArray(product?.images) ? product.images : []),
    ...(Array.isArray(product?.media) ? product.media : []),
  ]
    .flat()
    .filter(Boolean)
    .map((value) => String(value));

  const vendorMatch = imageCandidates
    .map((value) => value.match(/\/vendors\/([^/]+)\//i))
    .find(Boolean);

  return vendorMatch?.[1] ?? null;
};

const normalizeProduct = (
  product: any,
  context?: { fallbackVendorId?: string | number }
) => {
  const resolvedVendorId =
    product?.vendorId ||
    product?.vendor_id ||
    product?.vendor?.id ||
    product?.vendor?.vendorId ||
    inferVendorIdFromAssetPath(product) ||
    context?.fallbackVendorId;

  const resolvedBranchId =
    product?.branchId ||
    product?.branch_id ||
    product?.branch?.id ||
    product?.branch?.branchId;

  return {
    ...product,
    vendorId: resolvedVendorId,
    vendor_id: product?.vendor_id || resolvedVendorId,
    branchId: resolvedBranchId,
    branch_id: product?.branch_id || resolvedBranchId,
    image: resolveProductImage(product),
    displayUnit: getProductUnit(product),
  };
};

export const getAllCategories = async () => {
  try {
    const response = await axios.get(`${BASE_URL}/categories`);
    return response.data;
  } catch (error) {
    console.log('Error Categories', error);
    return [];
  }
};

export const getProductsByCategoryId = async (
  id: string,
  options?: {
    vendorId?: string | number;
    latitude?: number;
    longitude?: number;
    radiusKm?: number;
  }
) => {
  try {
    const response = await axios.get(`${BASE_URL}/products/${id}`, {
      params: {
        vendorId: options?.vendorId,
        latitude: options?.latitude,
        longitude: options?.longitude,
        radiusKm: options?.radiusKm ?? getProductVendorRadiusKm(),
      },
    });

    const products = Array.isArray(response.data)
      ? response.data.map((product: any) =>
          normalizeProduct(product, {
            fallbackVendorId: options?.vendorId,
          })
        )
      : [];

    console.log(`Products fetched for category ${id}:`, products.length, 'products');
    if (products.length > 0) {
      console.log('Sample product image:', {
        id: products[0].id,
        name: products[0].name,
        hasImage: !!products[0].image,
        imageUrl: products[0].image,
      });
    }

    return products;
  } catch (error: any) {
    console.error('Error fetching products:', error?.response?.data || error?.message);
    return [];
  }
};

export const searchProducts = async (
  query: string,
  options?: {
    vendorId?: string | number;
    latitude?: number;
    longitude?: number;
    radiusKm?: number;
  }
) => {
  try {
    if (!query || query.trim().length === 0) {
      return [];
    }

    const response = await axios.get(`${BASE_URL}/products/search`, {
      params: {
        q: query.trim(),
        vendorId: options?.vendorId,
        latitude: options?.latitude,
        longitude: options?.longitude,
        radiusKm: options?.radiusKm ?? getProductVendorRadiusKm(),
      },
    });

    const products = Array.isArray(response.data)
      ? response.data.map((product: any) => normalizeProduct(product))
      : [];

    console.log(`Products searched for "${query}":`, products.length, 'products');
    return products;
  } catch (error: any) {
    console.error('Error searching products:', error?.response?.data || error?.message);
    return [];
  }
};
