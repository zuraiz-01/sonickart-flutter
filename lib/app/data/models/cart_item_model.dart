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
      quantity:
          (json['quantity'] as num?)?.toInt() ??
          (json['count'] as num?)?.toInt() ??
          (json['qty'] as num?)?.toInt() ??
          0,
    );
  }
}
