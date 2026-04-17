class AddressModel {
  const AddressModel({
    required this.id,
    required this.fullName,
    required this.contactNumber,
    required this.address,
    this.latitude,
    this.longitude,
    this.placeId = '',
    this.vendorId = '',
    this.isSelected = false,
  });

  final String id;
  final String fullName;
  final String contactNumber;
  final String address;
  final double? latitude;
  final double? longitude;
  final String placeId;
  final String vendorId;
  final bool isSelected;

  AddressModel copyWith({
    String? id,
    String? fullName,
    String? contactNumber,
    String? address,
    double? latitude,
    double? longitude,
    String? placeId,
    String? vendorId,
    bool? isSelected,
  }) {
    return AddressModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      contactNumber: contactNumber ?? this.contactNumber,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeId: placeId ?? this.placeId,
      vendorId: vendorId ?? this.vendorId,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'contactNumber': contactNumber,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'placeId': placeId,
      'vendorId': vendorId,
      'isSelected': isSelected,
    };
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    double? number(Object? value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    final liveLocation = json['liveLocation'] is Map
        ? Map<String, dynamic>.from(json['liveLocation'] as Map)
        : const <String, dynamic>{};
    return AddressModel(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      fullName: (json['fullName'] ?? json['name'] ?? json['customerName'])?.toString() ?? '',
      contactNumber: (json['contactNumber'] ?? json['phone'] ?? json['mobile'])?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: number(json['latitude'] ?? liveLocation['latitude']),
      longitude: number(json['longitude'] ?? liveLocation['longitude']),
      placeId: json['placeId']?.toString() ?? '',
      vendorId: (json['vendorId'] ?? json['vendor_id'])?.toString() ?? '',
      isSelected: json['isSelected'] == true,
    );
  }
}
