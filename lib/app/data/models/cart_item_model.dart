import 'product_model.dart';

class CartItemModel {
  const CartItemModel({
    required this.product,
    required this.quantity,
  });

  final ProductModel product;
  final int quantity;

  double get unitPrice => double.tryParse(product.price) ?? 0;

  double get totalPrice => unitPrice * quantity;

  CartItemModel copyWith({
    ProductModel? product,
    int? quantity,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': {
        'id': product.id,
        'categoryId': product.categoryId,
        'name': product.name,
        'description': product.description,
        'unit': product.unit,
        'price': product.price,
        'mrp': product.mrp,
        'emoji': product.emoji,
      },
      'quantity': quantity,
    };
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      product: ProductModel.fromJson(
        Map<String, dynamic>.from(json['product'] as Map? ?? const {}),
      ),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}
