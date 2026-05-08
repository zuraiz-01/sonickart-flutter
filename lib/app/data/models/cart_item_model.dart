import 'product_model.dart';

class CartItemModel {
  const CartItemModel({required this.product, required this.quantity});

  final ProductModel product;
  final int quantity;

  double get unitPrice => double.tryParse(product.price) ?? 0;

  double get totalPrice => unitPrice * quantity;

  CartItemModel copyWith({ProductModel? product, int? quantity}) {
    return CartItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
      'count': quantity,
    };
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final productSource = json['product'] ?? json['item'];
    final productJson = productSource is Map
        ? Map<String, dynamic>.from(productSource)
        : <String, dynamic>{};
    if (productSource != null && productSource is! Map) {
      productJson['id'] = productSource;
    }
    productJson.addAll({
      for (final key in [
        'productId',
        'product_id',
        'itemId',
        'item_id',
        'name',
        'productName',
        'product_name',
        'itemName',
        'item_name',
        'title',
        'price',
        'unitPrice',
        'unit_price',
        'discountPrice',
        'discount_price',
        'mrp',
        'image',
        'imageUrl',
        'image_url',
        'thumbnail',
        'categoryId',
        'category_id',
        'categoryName',
        'vendorId',
        'vendor_id',
        'branchId',
        'branch_id',
      ])
        if (json[key] != null && productJson[key] == null) key: json[key],
    });
    return CartItemModel(
      product: ProductModel.fromJson(productJson),
      quantity: _quantityFrom(json) ?? 0,
    );
  }

  static int? _quantityFrom(Map<String, dynamic> source) {
    for (final key in [
      'quantity',
      'count',
      'qty',
      'itemQuantity',
      'item_quantity',
      'orderedQty',
      'ordered_qty',
      'orderedQuantity',
      'ordered_quantity',
      'productQuantity',
      'product_quantity',
      'productQty',
      'product_qty',
      'selectedQuantity',
      'selected_quantity',
      'cartQuantity',
      'cart_quantity',
      'itemCount',
      'item_count',
      'orderQuantity',
      'order_quantity',
    ]) {
      final parsed = _intFrom(source[key]);
      if (parsed != null) return parsed;
    }
    return _nestedQuantity(source['item']) ??
        _nestedQuantity(source['product']);
  }

  static int? _nestedQuantity(Object? value) {
    if (value is! Map) return null;
    for (final key in [
      'quantity',
      'count',
      'qty',
      'itemQuantity',
      'item_quantity',
      'itemCount',
      'item_count',
      'totalQuantity',
      'total_quantity',
      'productQuantity',
      'product_quantity',
    ]) {
      final parsed = _intFrom(value[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static int? _intFrom(Object? value) {
    if (value is num && value.isFinite) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}
