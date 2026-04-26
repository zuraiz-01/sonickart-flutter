class PackageOrderModel {
  const PackageOrderModel({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.packageType,
    required this.pickupAddress,
    required this.dropAddress,
    required this.distanceKm,
    required this.deliveryCharge,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String customerName;
  final String customerPhone;
  final String packageType;
  final String pickupAddress;
  final String dropAddress;
  final double distanceKm;
  final double deliveryCharge;
  final double totalPrice;
  final String status;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': id,
      'orderType': 'package',
      'customerName': customerName,
      'customerPhone': customerPhone,
      'packageType': packageType,
      'pickupAddress': pickupAddress,
      'dropAddress': dropAddress,
      'distanceKm': distanceKm,
      'deliveryCharge': deliveryCharge,
      'totalPrice': totalPrice,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PackageOrderModel.fromJson(Map<String, dynamic> json) {
    return PackageOrderModel(
      id:
          (json['id'] ?? json['_id'] ?? json['orderId'] ?? json['orderNumber'])
              ?.toString() ??
          '',
      customerName:
          (json['customerName'] ?? json['senderName'] ?? json['receiverName'])
              ?.toString() ??
          '',
      customerPhone:
          (json['customerPhone'] ??
                  json['senderPhone'] ??
                  json['receiverPhone'])
              ?.toString() ??
          '',
      packageType:
          (json['packageType'] ?? json['type'])?.toString() ?? 'Package',
      pickupAddress:
          (json['pickupAddress'] ?? json['pickup_location'] ?? json['pickup'])
              ?.toString() ??
          '',
      dropAddress:
          (json['dropAddress'] ?? json['drop_location'] ?? json['drop'])
              ?.toString() ??
          '',
      distanceKm: _number(
        json['distanceKm'] ?? json['distance'] ?? json['distance_km'],
      ),
      deliveryCharge: _number(
        json['deliveryCharge'] ?? json['delivery_charge'],
      ),
      totalPrice: _number(
        json['totalPrice'] ??
            json['grandTotal'] ??
            json['amount'] ??
            json['deliveryCharge'],
      ),
      status:
          (json['deliveryStatus'] ?? json['delivery_status'] ?? json['status'])
              ?.toString() ??
          'pending',
      createdAt:
          DateTime.tryParse(
            json['createdAt']?.toString() ??
                json['created_at']?.toString() ??
                '',
          ) ??
          DateTime.now(),
    );
  }

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
