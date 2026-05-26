import 'dart:convert';

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

  OrderModel copyWith({
    String? id,
    List<CartItemModel>? items,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    String? paymentMode,
    double? totalPrice,
    String? status,
    DateTime? createdAt,
    Map<String, dynamic>? raw,
  }) {
    return OrderModel(
      id: id ?? this.id,
      items: items ?? this.items,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      paymentMode: paymentMode ?? this.paymentMode,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      raw: raw ?? this.raw,
    );
  }

  int? get deliveryRating {
    final value = _firstValue([
      raw['rating'],
      raw['deliveryRating'],
      raw['delivery_rating'],
    ]);
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed < 1 || parsed > 5) return null;
    return parsed;
  }

  String get deliveryRatingFeedback {
    return _firstString([
          raw['ratingFeedback'],
          raw['rating_feedback'],
          raw['deliveryFeedback'],
          raw['delivery_feedback'],
          raw['feedback'],
        ]) ??
        '';
  }

  DateTime? get deliveryRatedAt {
    final value = _firstValue([
      raw['ratedAt'],
      raw['rated_at'],
      raw['deliveryRatedAt'],
      raw['delivery_rated_at'],
    ]);
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  bool get hasDeliveryRating => deliveryRating != null;

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
        normalized == 'complete' ||
        normalized == 'completed' ||
        normalized == 'finished' ||
        normalized == 'done' ||
        normalized == 'cancelled' ||
        normalized == 'canceled';
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
          raw['orderItemCount'] ??
          raw['order_item_count'] ??
          raw['totalItemCount'] ??
          raw['total_item_count'] ??
          raw['itemsTotal'] ??
          raw['items_total'] ??
          raw['totalQuantity'] ??
          raw['total_quantity'] ??
          raw['quantity'] ??
          raw['qty'] ??
          raw['cartCount'] ??
          raw['cart_count'] ??
          raw['noOfItems'] ??
          raw['no_of_items'] ??
          raw['numberOfItems'] ??
          raw['number_of_items'] ??
          raw['productsCount'] ??
          raw['products_count'] ??
          raw['productCount'] ??
          raw['product_count'] ??
          raw['totalProducts'] ??
          raw['total_products'] ??
          raw['orderedItemsCount'] ??
          raw['ordered_items_count'] ??
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
    final deliveryOrder = _firstMap([
      json['deliveryOrder'],
      json['delivery_order'],
      json['delivery'],
      json['deliveryDetails'],
      json['delivery_details'],
      json['deliveryStatusInfo'],
      json['delivery_status_info'],
    ]);
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
          (json['deliveryStatus'] ??
                  json['delivery_status'] ??
                  deliveryOrder['deliveryStatus'] ??
                  deliveryOrder['delivery_status'] ??
                  deliveryOrder['status'] ??
                  json['status'])
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
    if (source is String) {
      final trimmed = source.trim();
      if (trimmed.isEmpty) return const [];
      try {
        return _extractItems(jsonDecode(trimmed));
      } catch (_) {
        return const [];
      }
    }
    if (source is List) return source;
    if (source is! Map) return const [];
    final map = Map<String, dynamic>.from(source);
    if (map.isNotEmpty &&
        map.keys.every((key) => RegExp(r'^\d+$').hasMatch(key))) {
      return map.values.toList();
    }
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
      'orderDetails',
      'order_details',
      'details',
      'itemDetails',
      'item_details',
      'productDetails',
      'product_details',
    ]) {
      final found = _extractItems(map[key]);
      if (found.isNotEmpty) return found;
    }
    for (final key in [
      'order',
      'data',
      'result',
      'results',
      'payload',
      'summary',
      'meta',
      'records',
      'list',
      'rows',
      'docs',
    ]) {
      final found = _extractItems(map[key]);
      if (found.isNotEmpty) return found;
    }
    final objectValues = map.values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(_looksLikeOrderItem)
        .toList();
    if (objectValues.isNotEmpty) return objectValues;
    return const [];
  }

  static bool _looksLikeOrderItem(Map<String, dynamic> item) {
    const keys = [
      'product',
      'item',
      'productId',
      'product_id',
      'itemId',
      'item_id',
      'name',
      'productName',
      'product_name',
      'itemName',
      'item_name',
      'quantity',
      'count',
      'qty',
    ];
    return keys.any(item.containsKey);
  }

  static Map<String, dynamic> _firstMap(List<Object?> values) {
    for (final value in values) {
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      if (value is List) {
        for (final item in value) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
        }
      }
    }
    return const <String, dynamic>{};
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

  static Object? _firstValue(List<Object?> values) {
    for (final value in values) {
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      return value;
    }
    return null;
  }

  static String? _firstString(List<Object?> values) {
    final value = _firstValue(values)?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }
}
