import '../../core/constants/api_constants.dart';

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
    this.imageUrl = '',
    this.featuredImageUrl = '',
    this.vendorId = '',
    this.branchId = '',
    this.raw = const {},
  });

  final String id;
  final String categoryId;
  final String name;
  final String description;
  final String unit;
  final String price;
  final String mrp;
  final String emoji;
  final String imageUrl;
  final String featuredImageUrl;
  final String vendorId;
  final String branchId;
  final Map<String, dynamic> raw;

  double get numericPrice => double.tryParse(price) ?? 0;

  String get resolvedImageUrl {
    return _resolveUrl(imageUrl);
  }

  String get resolvedFeaturedImageUrl {
    final featured = _resolveUrl(featuredImageUrl);
    return featured.isNotEmpty ? featured : resolvedImageUrl;
  }

  static String _resolveUrl(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http')) return value;
    if (value.startsWith('/')) return '${ApiConstants.mobileHost}$value';
    return '${ApiConstants.mobileHost}/$value';
  }

  Map<String, dynamic> toJson() {
    return {
      ...raw,
      'id': id,
      'categoryId': categoryId,
      'name': name,
      'description': description,
      'unit': unit,
      'price': price,
      'mrp': mrp,
      'emoji': emoji,
      'image': imageUrl,
      'featuredImage': featuredImageUrl,
      'vendorId': vendorId,
      'branchId': branchId,
    };
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final category = json['category'] is Map
        ? Map<String, dynamic>.from(json['category'] as Map)
        : const <String, dynamic>{};
    final vendor = json['vendor'] is Map
        ? Map<String, dynamic>.from(json['vendor'] as Map)
        : const <String, dynamic>{};
    final branch = json['branch'] is Map
        ? Map<String, dynamic>.from(json['branch'] as Map)
        : const <String, dynamic>{};
    final images = json['images'] is List ? json['images'] as List : const [];
    final rawImageValue = json['image'] ??
        json['product_images'] ??
        json['productImages'] ??
        json['thumbnail'] ??
        (images.isNotEmpty ? images.first : null);
    final rawFeaturedImageValue = json['featuredImage'] ??
        json['featureImage'] ??
        json['featured_image'] ??
        json['feature_image'] ??
        json['bannerImage'] ??
        json['banner_image'];
    final imageValue = _imageString(rawImageValue);
    final featuredImageValue = _imageString(rawFeaturedImageValue);
    return ProductModel(
      id: (json['id'] ?? json['_id'] ?? json['productId'])?.toString() ?? '',
      categoryId: (json['categoryId'] ??
                  json['category_id'] ??
                  category['id'] ??
                  category['_id'] ??
                  category['categoryId'])
              ?.toString() ??
          '',
      name: json['name']?.toString() ?? json['product_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      unit: (json['unit'] ?? json['quantity'] ?? json['weight'] ?? json['size'])
              ?.toString() ??
          '',
      price: (json['discountPrice'] ??
                  json['discount_price'] ??
                  json['sellingPrice'] ??
                  json['selling_price'] ??
                  json['price'])
              ?.toString() ??
          '0',
      mrp: (json['mrp'] ?? json['originalPrice'] ?? json['original_price'])
              ?.toString() ??
          '',
      emoji: json['emoji']?.toString() ?? '',
      imageUrl: imageValue,
      featuredImageUrl: featuredImageValue,
      vendorId: (json['vendorId'] ??
                  json['vendor_id'] ??
                  vendor['id'] ??
                  vendor['_id'] ??
                  vendor['vendorId'])
              ?.toString() ??
          '',
      branchId: (json['branchId'] ??
                  json['branch_id'] ??
                  branch['id'] ??
                  branch['_id'] ??
                  branch['branchId'])
              ?.toString() ??
          '',
      raw: json,
    );
  }

  static String _imageString(Object? value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List && value.isNotEmpty) return _imageString(value.first);
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in ['url', 'image', 'path', 'src', 'location']) {
        final next = map[key];
        if (next != null && next.toString().isNotEmpty) return next.toString();
      }
    }
    return value.toString();
  }
}
