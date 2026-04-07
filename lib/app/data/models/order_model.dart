import 'cart_item_model.dart';

class OrderModel {
  const OrderModel({
    required this.id,
    required this.items,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.paymentMode,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final List<CartItemModel> items;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String paymentMode;
  final double totalPrice;
  final String status;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items.map((item) => item.toJson()).toList(),
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'paymentMode': paymentMode,
      'totalPrice': totalPrice,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    return OrderModel(
      id: json['id']?.toString() ?? '',
      items: rawItems
          .map(
            (item) => CartItemModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      customerName: json['customerName']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      deliveryAddress: json['deliveryAddress']?.toString() ?? '',
      paymentMode: json['paymentMode']?.toString() ?? 'COD',
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'placed',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
