import { getDeliverySettingsSnapshot } from '@service/deliverySettingsService';

export const getProductVendorRadiusKm = () =>
  getDeliverySettingsSnapshot().productRadiusKm;
