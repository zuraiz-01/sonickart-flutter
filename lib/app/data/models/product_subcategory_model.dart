import 'dart:convert';

import '../../core/constants/api_constants.dart';

class ProductSubcategoryModel {
  const ProductSubcategoryModel({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description = '',
    this.imageUrl = '',
    this.isActive = true,
    this.isMixed = false,
    this.raw = const {},
  });

  final String id;
  final String categoryId;
  final String name;
  final String description;
  final String imageUrl;
  final bool isActive;
  final bool isMixed;
  final Map<String, dynamic> raw;

  static const mixedId = '__mixed_products__';

  String get resolvedImageUrl {
    final value = imageUrl.trim();
    if (value.isEmpty) return '';
    final decodedList = _decodeImageList(value);
    if (decodedList.isNotEmpty) return _resolveUrl(decodedList.first);
    return _resolveUrl(value);
  }

  factory ProductSubcategoryModel.mixed({required String categoryId}) {
    return ProductSubcategoryModel(
      id: mixedId,
      categoryId: categoryId,
      name: 'Mixed Products',
      description: 'Products without a subcategory',
      isMixed: true,
    );
  }

  factory ProductSubcategoryModel.fromJson(
    Map<String, dynamic> json, {
    String? fallbackCategoryId,
  }) {
    return ProductSubcategoryModel(
      id: _idString(json['id'] ?? json['_id'] ?? json['subcategoryId']),
      categoryId: _idString(
        json['categoryId'] ??
            json['category_id'] ??
            json['parentCategoryId'] ??
            fallbackCategoryId,
      ),
      name:
          json['name']?.toString() ??
          json['title']?.toString() ??
          json['subcategory']?.toString() ??
          '',
      description:
          json['description']?.toString() ??
          json['details']?.toString() ??
          json['subtitle']?.toString() ??
          '',
      imageUrl: _imageString(
        json['subcategory_image'] ??
            json['subcategoryImage'] ??
            json['image'] ??
            json['imageUrl'] ??
            json['image_url'] ??
            json['icon'] ??
            json['icon_url'] ??
            json['thumbnail'],
      ),
      isActive: _boolValue(json['is_active'] ?? json['isActive'] ?? true),
      raw: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...raw,
      'id': id,
      'categoryId': categoryId,
      'name': name,
      'description': description,
      'image': imageUrl,
      'isActive': isActive,
    };
  }

  static String _resolveUrl(String value) {
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('http')) return value;
    final normalizedPath = value.replaceAll(r'\', '/');
    if (normalizedPath.startsWith('/')) {
      return '${ApiConstants.mobileHost}$normalizedPath';
    }
    return '${ApiConstants.mobileHost}/$normalizedPath';
  }

  static String _idString(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    if (normalized.isEmpty || normalized == '0' || normalized == 'null') {
      return '';
    }
    return normalized;
  }

  static bool _boolValue(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return true;
    return !['0', 'false', 'inactive', 'no'].contains(normalized);
  }

  static String _imageString(Object? value) {
    if (value == null) return '';
    if (value is String) {
      final decoded = _decodeImageList(value);
      return decoded.isNotEmpty ? decoded.first : value;
    }
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

  static List<String> _decodeImageList(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) return const [];
    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is! List) return const [];
      return parsed
          .map(_imageString)
          .where((item) => item.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
