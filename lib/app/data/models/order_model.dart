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
    this.raw = const {},
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
  final Map<String, dynamic> raw;

  bool get isProductOrder {
    final orderType = (raw['orderType'] ?? raw['order_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final packageType = (raw['packageType'] ?? raw['package_type'] ?? '')
        .toString()
        .trim();
    return orderType != 'package' && packageType.isEmpty;
  }

  bool get isInactive {
    final normalized = status.trim().toLowerCase();
    return normalized == 'delivered' ||
        normalized == 'completed' ||
        normalized == 'cancelled';
  }

  int get resolvedItemCount {
    if (items.isNotEmpty) {
      final itemQuantity = items.fold<int>(
        0,
        (sum, item) => sum + (item.quantity > 0 ? item.quantity : 0),
      );
      return itemQuantity > 0 ? itemQuantity : items.length;
    }

    return _int(
      raw['totalItems'] ??
          raw['total_items'] ??
          raw['itemsCount'] ??
          raw['items_count'] ??
          raw['itemCount'] ??
          raw['item_count'] ??
          raw['orderItemsCount'] ??
          raw['order_items_count'] ??
          raw['totalQuantity'] ??
          raw['total_quantity'] ??
          raw['quantity'] ??
          raw['qty'] ??
          raw['cartCount'] ??
          raw['cart_count'] ??
          raw['productsCount'] ??
          raw['products_count'] ??
          (raw['summary'] is Map
              ? ((raw['summary'] as Map)['totalItems'] ??
                    (raw['summary'] as Map)['total_items'] ??
                    (raw['summary'] as Map)['itemsCount'] ??
                    (raw['summary'] as Map)['items_count'])
              : null) ??
          (raw['data'] is Map
              ? ((raw['data'] as Map)['totalItems'] ??
                    (raw['data'] as Map)['total_items'] ??
                    (raw['data'] as Map)['itemsCount'] ??
                    (raw['data'] as Map)['items_count'])
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...raw,
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
    final rawItems = _extractItems(json);
    final customer = json['customer'] is Map
        ? Map<String, dynamic>.from(json['customer'] as Map)
        : const <String, dynamic>{};
    final deliveryLocation = json['deliveryLocation'] is Map
        ? Map<String, dynamic>.from(json['deliveryLocation'] as Map)
        : const <String, dynamic>{};
    return OrderModel(
      id:
          (json['id'] ?? json['_id'] ?? json['orderId'] ?? json['orderNumber'])
              ?.toString() ??
          '',
      items: rawItems
          .whereType<Map>()
          .map(
            (item) => CartItemModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .where(
            (item) =>
                item.product.id.isNotEmpty || item.product.name.isNotEmpty,
          )
          .toList(),
      customerName:
          (json['customerName'] ??
                  customer['name'] ??
                  deliveryLocation['fullName'])
              ?.toString() ??
          '',
      customerPhone:
          (json['customerPhone'] ??
                  customer['phone'] ??
                  deliveryLocation['contactNumber'])
              ?.toString() ??
          '',
      deliveryAddress:
          (json['deliveryAddress'] ??
                  json['customerAddress'] ??
                  json['shippingAddress'] ??
                  deliveryLocation['address'])
              ?.toString() ??
          '',
      paymentMode:
          (json['paymentMode'] ?? json['payment_mode'])?.toString() ?? 'COD',
      totalPrice: _number(
        json['totalPrice'] ??
            json['grandTotal'] ??
            json['total'] ??
            json['amount'],
      ),
      status:
          (json['deliveryStatus'] ?? json['delivery_status'] ?? json['status'])
              ?.toString() ??
          'placed',
      createdAt:
          DateTime.tryParse(
            json['createdAt']?.toString() ??
                json['created_at']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      raw: json,
    );
  }

  static List _extractItems(Object? source) {
    if (source is String) return const [];
    if (source is List) return source;
    if (source is! Map) return const [];
    final map = Map<String, dynamic>.from(source);
    for (final key in [
      'items',
      'item',
      'orderItems',
      'order_items',
      'orderItem',
      'order_item',
      'cartItems',
      'cart_items',
      'cart',
      'products',
      'productItems',
      'product_items',
      'orderedItems',
      'ordered_items',
      'lineItems',
      'line_items',
      'details',
      'itemDetails',
      'item_details',
      'productDetails',
      'product_details',
    ]) {
      final found = _extractItems(map[key]);
      if (found.isNotEmpty) return found;
    }
    for (final key in ['data', 'result', 'payload', 'summary', 'meta']) {
      final found = _extractItems(map[key]);
      if (found.isNotEmpty) return found;
    }
    return const [];
  }

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _int(Object? value) {
    if (value is num && value.isFinite && value > 0) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : 0;
  }
}
