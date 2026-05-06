const UNIT_REGEX = /(\d+(?:\.\d+)?)\s*(ml|milliliter|millilitre|l|lt|ltr|liter|litre|g|gm|gram|grams|kg|kgs|kilogram|kilograms|pc|pcs|piece|pieces|pack|packs|pkt|pkts)\b/i;

const normalizeToken = (token: string) => {
  const normalized = token.trim().toLowerCase();

  if (['milliliter', 'millilitre', 'ml'].includes(normalized)) {
    return 'ml';
  }

  if (['l', 'lt', 'ltr', 'liter', 'litre'].includes(normalized)) {
    return 'L';
  }

  if (['g', 'gm', 'gram', 'grams'].includes(normalized)) {
    return 'g';
  }

  if (['kg', 'kgs', 'kilogram', 'kilograms'].includes(normalized)) {
    return 'kg';
  }

  if (['pc', 'pcs', 'piece', 'pieces', 'pack', 'packs', 'pkt', 'pkts'].includes(normalized)) {
    return 'pcs';
  }

  return normalized;
};

const trimNumericValue = (value: string) => {
  if (!value.includes('.')) {
    return value;
  }
  return value.replace(/\.0+$/, '').replace(/(\.\d*?)0+$/, '$1');
};

const withPiecePlurality = (value: string, unit: string) => {
  if (unit !== 'pcs') {
    return `${value} ${unit}`;
  }

  return value === '1' ? '1 pc' : `${value} pcs`;
};

const normalizeUnitString = (raw: string): string | null => {
  const cleaned = raw.replace(/[()]/g, ' ').replace(/\s+/g, ' ').trim();
  if (!cleaned) {
    return null;
  }

  const matched = cleaned.match(UNIT_REGEX);
  if (!matched) {
    return null;
  }

  const value = trimNumericValue(matched[1]);
  const unit = normalizeToken(matched[2]);

  return withPiecePlurality(value, unit);
};

const tryPairValueAndUnit = (product: any): string | null => {
  const valueCandidates = [
    product?.unit_value,
    product?.unitValue,
    product?.quantity_value,
    product?.quantityValue,
    product?.size_value,
    product?.sizeValue,
    product?.weight_value,
    product?.weightValue,
    product?.volume_value,
    product?.volumeValue,
    product?.qty,
  ];

  const unitCandidates = [
    product?.unit,
    product?.uom,
    product?.measurement_unit,
    product?.measurementUnit,
    product?.quantity_unit,
    product?.quantityUnit,
  ];

  const value = valueCandidates.find(
    (candidate) => candidate !== undefined && candidate !== null && String(candidate).trim() !== ''
  );
  const unit = unitCandidates.find(
    (candidate) => candidate !== undefined && candidate !== null && String(candidate).trim() !== ''
  );

  if (!value || !unit) {
    return null;
  }

  return normalizeUnitString(`${value} ${unit}`);
};

export const getProductUnit = (product: any): string => {
  const directCandidates = [
    product?.displayUnit,
    product?.display_unit,
    product?.unitDisplay,
    product?.unit_display,
    product?.unitLabel,
    product?.unit_label,
    product?.units,
    product?.quantity,
    product?.quantity_text,
    product?.quantityText,
    product?.pack_size,
    product?.packSize,
    product?.size,
    product?.weight,
    product?.volume,
    product?.net_quantity,
    product?.netQuantity,
    product?.variant,
  ];

  for (const candidate of directCandidates) {
    if (candidate === undefined || candidate === null) {
      continue;
    }

    const normalized = normalizeUnitString(String(candidate));
    if (normalized) {
      return normalized;
    }
  }

  const combined = tryPairValueAndUnit(product);
  if (combined) {
    return combined;
  }

  const fromName = normalizeUnitString(String(product?.name ?? ''));
  if (fromName) {
    return fromName;
  }

  return '1 pc';
};
