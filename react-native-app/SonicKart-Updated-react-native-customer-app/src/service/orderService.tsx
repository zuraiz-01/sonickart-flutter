import { appAxios } from './apiInterceptors';
import type { PackageOrder, PackageOrderStatus, ApiError } from '../types/packageOrder';

/**
 * Order service.
 * Contains both regular order APIs and package order APIs.
 */
export const createOrder = async (
  items: any,
  totalPrice: number,
  address?: string,
  latitude?: number,
  longitude?: number,
  vendorId?: string | number | null,
  branchId?: string | number | null,
  orderBreakdown?: {
    subtotal: number;
    deliveryFee: number;
    taxAmount: number;
    paymentMode: string;
    itemsTotal?: number;
    totalWithGst?: number;
    couponId?: string;
    couponCode?: string;
    couponDiscount?: number;
    discountAmount?: number;
    discountType?: string;
  },
  customerName?: string,
  customerPhone?: string
) => {
  try {
    const normalizedItems = Array.isArray(items)
      ? items.map((item: any) => {
          const resolvedVendorId = item?.vendorId ?? item?.vendor_id ?? item?.vendor ?? vendorId;
          const resolvedBranchId = item?.branchId ?? item?.branch_id ?? item?.branch ?? branchId;

          return {
            ...item,
            vendorId: resolvedVendorId ?? undefined,
            vendor_id: resolvedVendorId ?? undefined,
            vendor: resolvedVendorId ?? undefined,
            branchId: resolvedBranchId ?? undefined,
            branch_id: resolvedBranchId ?? undefined,
            branch: resolvedBranchId ?? undefined,
            quantity: item?.quantity ?? item?.count,
          };
        })
      : items;

    const requestBody: any = {
      items: normalizedItems,
      // Use provided vendorId if available; let backend resolve if not provided
      vendorId: vendorId ?? undefined,
      vendor_id: vendorId ?? undefined,
      vendor: vendorId ?? undefined,
      branchId: branchId ?? undefined,
      branch_id: branchId ?? undefined,
      branch: branchId ?? undefined,
      vendorDetails:
        vendorId || branchId
          ? {
              vendorId: vendorId ?? undefined,
              vendor_id: vendorId ?? undefined,
              branchId: branchId ?? undefined,
              branch_id: branchId ?? undefined,
            }
          : undefined,
      routingContext:
        vendorId || branchId
          ? {
              vendorId: vendorId ?? undefined,
              branchId: branchId ?? undefined,
            }
          : undefined,
      totalPrice: totalPrice,
      customerName,
      customerPhone,
    };

    // Include order breakdown if provided
    if (orderBreakdown) {
      requestBody.subtotal = orderBreakdown.subtotal; // Grand Total (incl. GST)
      requestBody.deliveryFee = orderBreakdown.deliveryFee; // Delivery charge
      requestBody.taxAmount = orderBreakdown.taxAmount; // GST amount
      requestBody.paymentMode = orderBreakdown.paymentMode; // Payment method (COD/Online)
      requestBody.itemsTotal = orderBreakdown.itemsTotal;
      requestBody.totalWithGst = orderBreakdown.totalWithGst;
      requestBody.couponId = orderBreakdown.couponId;
      requestBody.couponCode = orderBreakdown.couponCode;
      requestBody.couponDiscount = orderBreakdown.couponDiscount;
      requestBody.discountAmount = orderBreakdown.discountAmount;
      requestBody.discountType = orderBreakdown.discountType;
    }

    // Include address and coordinates if provided
    if (address) {
      requestBody.address = address;
    }
    if (latitude !== undefined && longitude !== undefined) {
      requestBody.latitude = latitude;
      requestBody.longitude = longitude;
    }

    console.log('Create Order Request Payload', {
      vendorId: requestBody.vendorId,
      vendor_id: requestBody.vendor_id,
      branchId: requestBody.branchId,
      branch_id: requestBody.branch_id,
      address: requestBody.address,
      latitude: requestBody.latitude,
      longitude: requestBody.longitude,
      itemsCount: Array.isArray(requestBody.items) ? requestBody.items.length : 0,
      firstItem: Array.isArray(requestBody.items) ? requestBody.items[0] : undefined,
    });

    const response = await appAxios.post('/order', requestBody);
    return response.data;
  } catch (error: any) {
    // Log server response details if available for easier debugging
    const responseData = error?.response?.data;
    console.log('Create Order Error', error);
    if (responseData) {
      console.log('Create Order Error Response:', responseData);
    }
    const serverMessage =
      responseData?.message ||
      responseData?.error ||
      responseData?.details ||
      responseData?.errors?.[0]?.message ||
      responseData?.errors?.[0];
    throw new Error(serverMessage || 'Unable to create order right now. Please try again.');
  }
};

export const getOrderById = async (id: string) => {
  try {
    const response = await appAxios.get(`/order/${id}`);
    return response.data;
  } catch (error) {
    console.log('Fetch Order Error', error);
    return null;
  }
};

export const fetchCustomerOrders = async (userId: string) => {
  try {
    const response = await appAxios.get(`/order?customerId=${userId}`);
    return response.data;
  } catch (error) {
    console.log('Fetch Customer Order Error', error);
    return null;
  }
};

export const fetchOrders = async (
  status: string,
  userId: string,
  vendorId: string  // Changed from branchId to vendorId (backward compatible)
) => {
  // Support both vendorId (preferred) and branchId (backward compatibility)
  const filterParam = vendorId ? `vendorId=${vendorId}` : `branchId=${vendorId}`;
  let uri =
    status === 'available'
      ? `/order?status=${status}&${filterParam}`
      : `/order?${filterParam}&deliveryPartnerId=${userId}&status=delivered`;

  try {
    const response = await appAxios.get(uri);
    return response.data;
  } catch (error) {
    console.log('Fetch Delivery Order Error', error);
    return null;
  }
};

export const sendLiveOrderUpdates = async (
  id: string,
  location: any,
  status: string
) => {
  try {
    const response = await appAxios.patch(`/order/${id}/status`, {
      deliveryPersonLocation: location,
      status,
    });
    return response.data;
  } catch (error) {
    console.log('sendLiveOrderUpdates Error', error);
    return null;
  }
};

export const confirmOrder = async (id: string, location: any) => {
  try {
    const response = await appAxios.post(`/order/${id}/confirm`, {
      deliveryPersonLocation: location,
    });
    return response.data;
  } catch (error) {
    console.log('confirmOrder Error', error);
    return null;
  }
};

export const cancelOrderItems = async (orderId: string, cancellationReason?: string) => {
  try {
    const response = await appAxios.post(`/order/${orderId}/cancel-items`, {
      cancellationReason,
    });
    return response.data;
  } catch (error) {
    console.log('Cancel Order Items Error', error);
    throw error;
  }
};

// Package order functions
type PackageOrderFetchScope = 'customer' | 'delivery' | 'available';

export const fetchPackageOrders = async (
  status: string,
  userId?: string,
  scope: PackageOrderFetchScope = 'customer'
): Promise<PackageOrder[]> => {
  let uri = '/order/package';
  const params: any = {};

  if (status && status !== 'all') {
    params.status = status;
  }

  if (userId) {
    if (scope === 'customer') {
      params.customerId = userId;
    } else if (scope === 'delivery') {
      params.deliveryPartnerId = userId;
    }
  }

  try {
    const response = await appAxios.get<PackageOrder[]>(uri, { params });
    return response.data || [];
  } catch (error: any) {
    const apiError = error?.response?.data as ApiError;
    console.error('Fetch Package Orders Error', {
      message: apiError?.message || error.message,
      code: apiError?.code,
      status: error?.response?.status,
    });

    // Return empty array on error to prevent UI breakage
    return [];
  }
};

export const acceptPackageOrder = async (packageOrderId: string): Promise<PackageOrder> => {
  try {
    // Extract numeric ID if PKG format
    const numericId = packageOrderId.toString().replace('PKG', '');
    const response = await appAxios.post<PackageOrder>(`/order/package/${numericId}/accept`);
    return response.data;
  } catch (error: any) {
    const apiError = error?.response?.data as ApiError;
    const errorMessage = apiError?.message || error.message || 'Failed to accept package order';

    console.error('Accept Package Order Error', {
      message: errorMessage,
      code: apiError?.code,
      status: error?.response?.status,
      packageOrderId,
    });

    // Re-throw with user-friendly message
    const friendlyError = new Error(errorMessage);
    (friendlyError as any).code = apiError?.code;
    (friendlyError as any).status = error?.response?.status;
    throw friendlyError;
  }
};

export const updatePackageOrderStatus = async (
  packageOrderId: string,
  status: PackageOrderStatus
): Promise<PackageOrder> => {
  try {
    // Extract numeric ID if PKG format
    const numericId = packageOrderId.toString().replace('PKG', '');
    const response = await appAxios.patch<PackageOrder>(`/order/package/${numericId}/status`, {
      status,
    });
    return response.data;
  } catch (error: any) {
    const apiError = error?.response?.data as ApiError;
    const errorMessage = apiError?.message || error.message || 'Failed to update package order status';

    console.error('Update Package Order Status Error', {
      message: errorMessage,
      code: apiError?.code,
      status: error?.response?.status,
      packageOrderId,
      requestedStatus: status,
    });

    // Re-throw with user-friendly message
    const friendlyError = new Error(errorMessage);
    (friendlyError as any).code = apiError?.code;
    (friendlyError as any).status = error?.response?.status;
    throw friendlyError;
  }
};

export const cancelPackageOrder = async (packageOrderId: string): Promise<PackageOrder> => {
  try {
    // Extract numeric ID if PKG format
    const numericId = packageOrderId.toString().replace('PKG', '');
    const response = await appAxios.post<PackageOrder>(`/order/package/${numericId}/cancel`);
    return response.data;
  } catch (error: any) {
    const apiError = error?.response?.data as ApiError;
    const errorMessage = apiError?.message || error.message || 'Failed to cancel package order';

    console.error('Cancel Package Order Error', {
      message: errorMessage,
      code: apiError?.code,
      status: error?.response?.status,
      packageOrderId,
    });

    // Re-throw with user-friendly message
    const friendlyError = new Error(errorMessage);
    (friendlyError as any).code = apiError?.code;
    (friendlyError as any).status = error?.response?.status;
    throw friendlyError;
  }
};
