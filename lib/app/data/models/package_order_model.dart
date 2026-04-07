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
      id: json['id']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      packageType: json['packageType']?.toString() ?? '',
      pickupAddress: json['pickupAddress']?.toString() ?? '',
      dropAddress: json['dropAddress']?.toString() ?? '',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      deliveryCharge: (json['deliveryCharge'] as num?)?.toDouble() ?? 0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
