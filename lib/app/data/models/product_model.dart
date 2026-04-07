class ProductModel {
  const ProductModel({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.unit,
    required this.price,
    required this.mrp,
    required this.emoji,
  });

  final String id;
  final String categoryId;
  final String name;
  final String description;
  final String unit;
  final String price;
  final String mrp;
  final String emoji;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      mrp: json['mrp']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '📦',
    );
  }
}
