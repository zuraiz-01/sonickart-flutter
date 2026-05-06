const sanitizeNumber = (value: any, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

export const resolveGstRate = (value: any) => {
  const gstCandidate =
    value?.item_gst ??
    value?.gst_items ??
    value?.gstSlab ??
    value?.gst_slab ??
    value?.gstRate ??
    value?.gst_rate ??
    value?.gst ??
    value?.item?.gstSlab ??
    value?.item?.gst_slab ??
    value?.item?.gstRate ??
    value?.item?.gst_rate ??
    value?.item?.gst ??
    0;

  return Math.max(0, sanitizeNumber(gstCandidate, 0));
};

export const resolveBasePrice = (value: any) =>
  sanitizeNumber(
    value?.discountPrice ??
      value?.discount_price ??
      value?.price ??
      value?.unit_price ??
      value?.unitPrice ??
      value?.item?.discountPrice ??
      value?.item?.discount_price ??
      value?.item?.price ??
      0,
    0
  );

export const resolveMrpPrice = (value: any) => {
  const mrpCandidate =
    value?.mrp ??
    value?.item?.mrp ??
    value?.originalPrice ??
    value?.item?.originalPrice;

  const normalized = sanitizeNumber(mrpCandidate, 0);
  return normalized > 0 ? normalized : null;
};

export const addGstToAmount = (amount: number, gstRate: number) =>
  Number((amount + (amount * gstRate) / 100).toFixed(2));

export const resolveDisplayPriceWithGst = (value: any) =>
  resolveBasePrice(value);

export const resolveDisplayMrpWithGst = (value: any) => {
  const mrp = resolveMrpPrice(value);
  if (!mrp) {
    return null;
  }

  return mrp;
};

export const formatCurrencyValue = (value: number | null | undefined) => {
  if (value === null || value === undefined || Number.isNaN(Number(value))) {
    return '0';
  }

  const numericValue = Number(value);
  return Number.isInteger(numericValue)
    ? String(numericValue)
    : numericValue.toFixed(2).replace(/\.00$/, '');
};
