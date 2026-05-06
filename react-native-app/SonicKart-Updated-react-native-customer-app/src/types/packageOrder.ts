/**
 * TypeScript types for Package Orders
 */

export type PackageType = string;

export type PackageOrderStatus =
  | 'pending'
  | 'assigned'
  | 'confirmed'
  | 'picked'
  | 'picked_up'
  | 'arriving'
  | 'out_for_delivery'
  | 'delivered'
  | 'cancelled';

export interface PackageLocation {
  address: string;
  latitude: number;
  longitude: number;
  placeId?: string;
  label?: string;
  tag?: string;
}

export interface PackageOrder {
  id: number;
  orderId: string;
  orderNumber: string;
  orderType: 'package';
  userId: number;
  customerId: number;
  customer?: {
    id: number;
    name: string;
    phone: string;
    email?: string;
    address?: string;
  };
  packageType: PackageType;
  pickupLocation: PackageLocation;
  dropLocation: PackageLocation;
  deliveryLocation: PackageLocation;
  distanceKm: number;
  price: number;
  totalPrice: number;
  deliveryCharge: number;
  deliveryPartnerId: number | null;
  deliveryPartnerName?: string | null;
  deliveryPartnerPhone?: string | null;
  deliveryPartner?: {
    id?: number | string | null;
    name?: string | null;
    phone?: string | null;
    liveLocation?: any;
    address?: string | null;
  };
  deliveryPersonLocation?: {
    latitude?: number | string | null;
    longitude?: number | string | null;
    lat?: number | string | null;
    lng?: number | string | null;
  } | null;
  status: PackageOrderStatus;
  createdAt: string;
  created_at?: string;
  updatedAt: string;
  updated_at?: string;
  items: never[]; // Package orders don't have items
}

export interface PackageOrderData {
  pickupLocation: PackageLocation;
  dropLocation: PackageLocation;
  packageType: PackageType;
  distance: number; // in meters
  distanceText: string;
  duration: number; // in seconds
  durationText: string;
  deliveryCharge: number;
  customerName?: string;
  customerPhone?: string;
  specialInstructions?: string;
}

export interface ApiError {
  message: string;
  code?: string;
  error?: string;
  validStatuses?: string[];
  validTransitions?: string[];
  currentStatus?: string;
  requestedStatus?: string;
}

