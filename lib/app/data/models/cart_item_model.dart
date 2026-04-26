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
    final productJson = json['product'] ?? json['item'] ?? json;
    return CartItemModel(
      product: ProductModel.fromJson(
        Map<String, dynamic>.from(productJson as Map? ?? const {}),
      ),
      quantity:
          (json['quantity'] as num?)?.toInt() ??
          (json['count'] as num?)?.toInt() ??
          0,
    );
  }
}
