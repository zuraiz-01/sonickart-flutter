class AddressModel {
  const AddressModel({
    required this.id,
    required this.fullName,
    required this.contactNumber,
    required this.address,
    this.isSelected = false,
  });

  final String id;
  final String fullName;
  final String contactNumber;
  final String address;
  final bool isSelected;

  AddressModel copyWith({
    String? id,
    String? fullName,
    String? contactNumber,
    String? address,
    bool? isSelected,
  }) {
    return AddressModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      contactNumber: contactNumber ?? this.contactNumber,
      address: address ?? this.address,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'contactNumber': contactNumber,
      'address': address,
      'isSelected': isSelected,
    };
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      contactNumber: json['contactNumber']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      isSelected: json['isSelected'] == true,
    );
  }
}
