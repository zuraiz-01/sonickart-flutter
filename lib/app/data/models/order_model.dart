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
      'orderId': id,
      'items': items.map((item) => item.toJson()).toList(),
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'paymentMode': paymentMode,
      'payment_mode': paymentMode,
      'totalPrice': totalPrice,
      'grandTotal': totalPrice,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] ?? json['orderItems'] ?? json['cartItems']) as List? ?? const [];
    final customer = json['customer'] is Map ? Map<String, dynamic>.from(json['customer'] as Map) : const <String, dynamic>{};
    final deliveryLocation = json['deliveryLocation'] is Map ? Map<String, dynamic>.from(json['deliveryLocation'] as Map) : const <String, dynamic>{};
    return OrderModel(
      id: (json['id'] ?? json['_id'] ?? json['orderId'] ?? json['orderNumber'])?.toString() ?? '',
      items: rawItems
          .whereType<Map>()
          .map((item) => CartItemModel.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.product.id.isNotEmpty || item.product.name.isNotEmpty)
          .toList(),
      customerName: (json['customerName'] ?? customer['name'] ?? deliveryLocation['fullName'])?.toString() ?? '',
      customerPhone: (json['customerPhone'] ?? customer['phone'] ?? deliveryLocation['contactNumber'])?.toString() ?? '',
      deliveryAddress: (json['deliveryAddress'] ?? json['customerAddress'] ?? json['shippingAddress'] ?? deliveryLocation['address'])?.toString() ?? '',
      paymentMode: (json['paymentMode'] ?? json['payment_mode'])?.toString() ?? 'COD',
      totalPrice: _number(json['totalPrice'] ?? json['grandTotal'] ?? json['total'] ?? json['amount']),
      status: (json['deliveryStatus'] ?? json['delivery_status'] ?? json['status'])?.toString() ?? 'placed',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
