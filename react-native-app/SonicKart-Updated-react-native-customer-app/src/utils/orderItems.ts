const normalizeCount = (value: any) => {
  const numericValue = Number(value);
  return Number.isFinite(numericValue) && numericValue > 0 ? numericValue : 0;
};

const normalizeCollection = (collection: any): any[] => {
  if (typeof collection === 'string') {
    try {
      const parsedCollection = JSON.parse(collection);
      return normalizeCollection(parsedCollection);
    } catch {
      return [];
    }
  }

  if (Array.isArray(collection)) {
    return collection;
  }

  if (
    collection &&
    typeof collection === 'object' &&
    !Array.isArray(collection)
  ) {
    const commonArrayKeys = [
      'items',
      'item',
      'orderItems',
      'order_items',
      'orderItem',
      'order_item',
      'products',
      'productItems',
      'product_items',
      'lineItems',
      'line_items',
      'cartItems',
      'cart_items',
      'itemDetails',
      'item_details',
      'productDetails',
      'product_details',
    ];

    for (const key of commonArrayKeys) {
      const normalizedByKey = normalizeCollection(collection?.[key]);
      if (normalizedByKey.length > 0) {
        return normalizedByKey;
      }
    }

    const wrapperKeys = ['data', 'result', 'results', 'payload', 'records', 'list', 'rows', 'docs'];

    for (const key of wrapperKeys) {
      const wrappedCollection = normalizeCollection(collection?.[key]);
      if (wrappedCollection.length > 0) {
        return wrappedCollection;
      }
    }

    const objectKeys = Object.keys(collection);
    if (objectKeys.length > 0 && objectKeys.every((key) => /^\d+$/.test(key))) {
      return objectKeys
        .sort((left, right) => Number(left) - Number(right))
        .map((key) => collection[key])
        .filter((value) => value !== null && value !== undefined);
    }

    const values = Object.values(collection).filter(
      (value) => value !== null && value !== undefined && typeof value === 'object'
    );
    if (values.length > 0) {
      return values;
    }
  }

  return [];
};

const resolveItemQuantity = (item: any) =>
  normalizeCount(
    item?.count ??
      item?.quantity ??
      item?.qty ??
      item?.itemQuantity ??
      item?.item_quantity ??
      item?.ordered_qty ??
      item?.orderedQty ??
      item?.item_count ??
      item?.items_count ??
      item?.total_items ??
      item?.total_quantity ??
      item?.product_quantity ??
      item?.product_qty ??
      item?.selected_quantity ??
      item?.cart_quantity ??
      item?.ordered_quantity ??
      item?.itemCount ??
      item?.itemsCount ??
      item?.totalItems ??
      item?.totalQuantity ??
      item?.productQuantity ??
      item?.productQty ??
      item?.selectedQuantity ??
      item?.cartQuantity ??
      item?.orderedQuantity ??
      item?.orderQuantity ??
      item?.order_quantity ??
      item?.item?.count ??
      item?.item?.quantity ??
      item?.item?.qty ??
      item?.item?.itemQuantity ??
      item?.item?.item_quantity ??
      item?.item?.item_count ??
      item?.item?.items_count ??
      item?.item?.total_items ??
      item?.item?.total_quantity ??
      item?.item?.itemCount ??
      item?.item?.totalQuantity ??
      item?.product?.count ??
      item?.product?.quantity ??
      item?.product?.qty ??
      item?.product?.itemQuantity ??
      item?.product?.item_quantity ??
      item?.product?.item_count ??
      item?.product?.items_count ??
      item?.product?.total_items ??
      item?.product?.total_quantity
  );

export const resolveOrderItems = (order: any): any[] => {
  const candidateCollections = [
    order?.items,
    order?.item,
    order?.orderItems,
    order?.order_items,
    order?.orderItem,
    order?.order_item,
    order?.cartItems,
    order?.cart_items,
    order?.cart,
    order?.products,
    order?.productItems,
    order?.product_items,
    order?.orderedItems,
    order?.ordered_items,
    order?.lineItems,
    order?.line_items,
    order?.order_details,
    order?.orderDetails,
    order?.details,
    order?.itemDetails,
    order?.item_details,
    order?.productDetails,
    order?.product_details,
    order?.summary?.items,
    order?.summary?.products,
    order?.meta?.items,
    order?.meta?.products,
    order?.cart?.items,
    order?.cart?.products,
    order?.order?.item,
    order?.order?.items,
    order?.order?.orderItems,
    order?.order?.order_items,
    order?.order?.orderItem,
    order?.order?.order_item,
    order?.order?.products,
    order?.order?.itemDetails,
    order?.order?.item_details,
    order?.order?.productDetails,
    order?.order?.product_details,
    order?.data?.item,
    order?.data?.items,
    order?.data?.orderItems,
    order?.data?.order_items,
    order?.data?.orderItem,
    order?.data?.order_item,
    order?.data?.products,
    order?.data?.itemDetails,
    order?.data?.item_details,
    order?.data?.productDetails,
    order?.data?.product_details,
    order?.result?.item,
    order?.result?.items,
    order?.result?.orderItems,
    order?.result?.order_items,
    order?.result?.orderItem,
    order?.result?.order_item,
    order?.result?.products,
    order?.payload?.item,
    order?.payload?.items,
    order?.payload?.orderItems,
    order?.payload?.order_items,
    order?.payload?.orderItem,
    order?.payload?.order_item,
    order?.payload?.products,
  ];

  for (const collection of candidateCollections) {
    const normalizedCollection = normalizeCollection(collection);
    if (normalizedCollection.length > 0) {
      return normalizedCollection;
    }
  }

  return [];
};

export const resolveOrderItemCount = (order: any) => {
  if (!order) {
    return 0;
  }

  const items = resolveOrderItems(order);
  if (items.length > 0) {
    const derivedCount = items.reduce(
      (total: number, item: any) => total + resolveItemQuantity(item),
      0
    );

    return derivedCount > 0 ? derivedCount : items.length;
  }

  const orderLevelCount = normalizeCount(
    order?.totalItems ??
      order?.total_items ??
      order?.itemsCount ??
      order?.items_count ??
      order?.itemCount ??
      order?.item_count ??
      order?.orderItemsCount ??
      order?.order_items_count ??
      order?.orderItemCount ??
      order?.order_item_count ??
      order?.totalItemCount ??
      order?.total_item_count ??
      order?.itemsTotal ??
      order?.items_total ??
      order?.totalQuantity ??
      order?.total_quantity ??
      order?.quantity ??
      order?.qty ??
      order?.cartCount ??
      order?.cart_count ??
      order?.noOfItems ??
      order?.no_of_items ??
      order?.numberOfItems ??
      order?.number_of_items ??
      order?.productsCount ??
      order?.products_count ??
      order?.productCount ??
      order?.product_count ??
      order?.totalProducts ??
      order?.total_products ??
      order?.orderedItemsCount ??
      order?.ordered_items_count ??
      order?.order?.totalItems ??
      order?.order?.total_items ??
      order?.order?.itemsCount ??
      order?.order?.items_count ??
      order?.order?.itemCount ??
      order?.order?.item_count ??
      order?.order?.orderItemsCount ??
      order?.order?.order_items_count ??
      order?.order?.orderItemCount ??
      order?.order?.order_item_count ??
      order?.order?.productsCount ??
      order?.order?.products_count ??
      order?.summary?.totalItems ??
      order?.summary?.total_items ??
      order?.summary?.itemsCount ??
      order?.summary?.items_count ??
      order?.summary?.itemCount ??
      order?.summary?.item_count ??
      order?.summary?.orderItemsCount ??
      order?.summary?.order_items_count ??
      order?.summary?.orderItemCount ??
      order?.summary?.order_item_count ??
      order?.summary?.totalQuantity ??
      order?.summary?.total_quantity ??
      order?.summary?.productsCount ??
      order?.summary?.products_count ??
      order?.meta?.totalItems ??
      order?.meta?.total_items ??
      order?.meta?.itemCount ??
      order?.meta?.item_count ??
      order?.meta?.itemsCount ??
      order?.meta?.items_count ??
      order?.meta?.orderItemsCount ??
      order?.meta?.order_items_count ??
      order?.meta?.orderItemCount ??
      order?.meta?.order_item_count ??
      order?.meta?.productsCount ??
      order?.meta?.products_count ??
      order?.data?.totalItems ??
      order?.data?.total_items ??
      order?.data?.itemCount ??
      order?.data?.item_count ??
      order?.data?.itemsCount ??
      order?.data?.items_count ??
      order?.data?.orderItemsCount ??
      order?.data?.order_items_count ??
      order?.data?.orderItemCount ??
      order?.data?.order_item_count ??
      order?.data?.productsCount ??
      order?.data?.products_count ??
      order?.result?.totalItems ??
      order?.result?.total_items ??
      order?.result?.itemCount ??
      order?.result?.item_count ??
      order?.result?.itemsCount ??
      order?.result?.items_count ??
      order?.result?.orderItemsCount ??
      order?.result?.order_items_count ??
      order?.result?.orderItemCount ??
      order?.result?.order_item_count ??
      order?.result?.productsCount ??
      order?.result?.products_count ??
      order?.payload?.totalItems ??
      order?.payload?.total_items ??
      order?.payload?.itemCount ??
      order?.payload?.item_count ??
      order?.payload?.itemsCount ??
      order?.payload?.items_count ??
      order?.payload?.orderItemsCount ??
      order?.payload?.order_items_count ??
      order?.payload?.orderItemCount ??
      order?.payload?.order_item_count
  );

  if (__DEV__ && orderLevelCount === 0) {
    console.log('resolveOrderItemCount: zero-count order payload', {
      orderId: order?.orderId ?? order?.id ?? order?._id,
      topLevelKeys: Object.keys(order || {}),
      itemsKeys: Object.keys(order?.items || {}),
      orderKeys: Object.keys(order?.order || {}),
      dataKeys: Object.keys(order?.data || {}),
    });
  }

  return orderLevelCount;
};

export const resolveOrderItemPreviewLines = (order: any) => {
  const items = resolveOrderItems(order);

  const namedItems = items
    .map((orderItem) => {
      const quantity = resolveItemQuantity(orderItem) || 1;
      const name =
        orderItem?.item?.name ||
        orderItem?.product?.name ||
        orderItem?.product_name ||
        orderItem?.productName ||
        orderItem?.name ||
        'Item';

      return `${quantity}x ${name}`;
    })
    .filter(Boolean);

  if (namedItems.length <= 2) {
    return namedItems;
  }

  return [namedItems[0], namedItems[1], `+${namedItems.length - 2} more items`];
};
