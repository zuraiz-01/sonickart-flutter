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
    this.pickupLatitude,
    this.pickupLongitude,
    this.pickupPlaceId = '',
    this.dropLatitude,
    this.dropLongitude,
    this.dropPlaceId = '',
    this.distanceText = '',
    this.durationSeconds = 0,
    this.durationText = '',
    this.packageOrderType = 'send',
    this.raw = const {},
  });

  final String id;
  final String customerName;
  final String customerPhone;
  final String packageType;
  final String pickupAddress;
  final String dropAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String pickupPlaceId;
  final double? dropLatitude;
  final double? dropLongitude;
  final String dropPlaceId;
  final double distanceKm;
  final String distanceText;
  final int durationSeconds;
  final String durationText;
  final double deliveryCharge;
  final double totalPrice;
  final String status;
  final DateTime createdAt;
  final String packageOrderType;
  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': id,
      'orderType': 'package',
      'customerName': customerName,
      'customerPhone': customerPhone,
      'packageType': packageType,
      'packageOrderType': packageOrderType,
      'pickupAddress': pickupAddress,
      'dropAddress': dropAddress,
      'pickupLocation': {
        'address': pickupAddress,
        if (pickupLatitude != null) 'latitude': pickupLatitude,
        if (pickupLongitude != null) 'longitude': pickupLongitude,
        if (pickupPlaceId.isNotEmpty) 'placeId': pickupPlaceId,
      },
      'dropLocation': {
        'address': dropAddress,
        if (dropLatitude != null) 'latitude': dropLatitude,
        if (dropLongitude != null) 'longitude': dropLongitude,
        if (dropPlaceId.isNotEmpty) 'placeId': dropPlaceId,
      },
      'distanceKm': distanceKm,
      'distance': (distanceKm * 1000).round(),
      'distanceText': distanceText.isNotEmpty
          ? distanceText
          : '${distanceKm.toStringAsFixed(1)} km',
      'duration': durationSeconds,
      'durationText': durationText,
      'deliveryCharge': deliveryCharge,
      'totalPrice': totalPrice,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'raw': raw,
    };
  }

  factory PackageOrderModel.fromJson(Map<String, dynamic> json) {
    final pickup = _locationMap(
      json['pickupLocation'] ??
          json['pickup_location'] ??
          json['pickup'] ??
          json['pickupAddress'],
    );
    final drop = _locationMap(
      json['dropLocation'] ??
          json['drop_location'] ??
          json['drop'] ??
          json['dropAddress'],
    );
    final distanceKm = _distanceKm(json);
    final deliveryCharge = _number(
      json['deliveryCharge'] ?? json['delivery_charge'],
    );
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
      packageOrderType:
          (json['packageOrderType'] ?? json['package_order_type'])
              ?.toString() ??
          'send',
      pickupAddress: _firstString([
        pickup['address'],
        json['pickupAddress'],
        json['pickup_address'],
      ]),
      pickupLatitude: _numberOrNull(
        pickup['latitude'] ?? pickup['lat'] ?? json['pickupLatitude'],
      ),
      pickupLongitude: _numberOrNull(
        pickup['longitude'] ??
            pickup['lng'] ??
            pickup['long'] ??
            json['pickupLongitude'],
      ),
      pickupPlaceId: _firstString([
        pickup['placeId'],
        pickup['place_id'],
        json['pickupPlaceId'],
      ]),
      dropAddress: _firstString([
        drop['address'],
        json['dropAddress'],
        json['drop_address'],
      ]),
      dropLatitude: _numberOrNull(
        drop['latitude'] ?? drop['lat'] ?? json['dropLatitude'],
      ),
      dropLongitude: _numberOrNull(
        drop['longitude'] ??
            drop['lng'] ??
            drop['long'] ??
            json['dropLongitude'],
      ),
      dropPlaceId: _firstString([
        drop['placeId'],
        drop['place_id'],
        json['dropPlaceId'],
      ]),
      distanceKm: distanceKm,
      distanceText:
          json['distanceText']?.toString() ??
          (distanceKm > 0 ? '${distanceKm.toStringAsFixed(1)} km' : ''),
      durationSeconds: _number(
        json['duration'] ?? json['durationSeconds'],
      ).round(),
      durationText: json['durationText']?.toString() ?? '',
      deliveryCharge: deliveryCharge,
      totalPrice: _number(
        json['totalPrice'] ??
            json['grandTotal'] ??
            json['amount'] ??
            deliveryCharge,
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
      raw: Map<String, dynamic>.from(json),
    );
  }

  static Map<String, dynamic> _locationMap(Object? source) {
    if (source is Map) return Map<String, dynamic>.from(source);
    if (source == null) return const {};
    return {'address': source.toString()};
  }

  static String _firstString(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != '{}') return text;
    }
    return '';
  }

  static double _distanceKm(Map<String, dynamic> json) {
    final direct = _numberOrNull(json['distanceKm'] ?? json['distance_km']);
    if (direct != null) return direct;
    final rawDistance = _numberOrNull(json['distance']);
    if (rawDistance == null) return 0;
    return rawDistance > 100 ? rawDistance / 1000 : rawDistance;
  }

  static double? _numberOrNull(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static double _number(Object? value) {
    return _numberOrNull(value) ?? 0;
  }
}
