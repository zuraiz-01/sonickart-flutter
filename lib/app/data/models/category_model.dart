import 'dart:convert';

import '../../core/constants/api_constants.dart';

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.emoji,
    this.imageUrl = '',
    this.raw = const {},
  });

  final String id;
  final String name;
  final String emoji;
  final String imageUrl;
  final Map<String, dynamic> raw;

  String get resolvedImageUrl {
    final value = imageUrl.trim();
    if (value.isEmpty) return '';
    final decodedList = _decodeImageList(value);
    if (decodedList.isNotEmpty) return _resolveUrl(decodedList.first);
    return _resolveUrl(value);
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

  Map<String, dynamic> toJson() {
    return {...raw, 'id': id, 'name': name, 'emoji': emoji, 'image': imageUrl};
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: (json['id'] ?? json['_id'] ?? json['categoryId'])?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '',
      imageUrl: _imageString(
        json['image'] ??
            json['categoryImage'] ??
            json['category_image'] ??
            json['icon'] ??
            json['thumbnail'],
      ),
      raw: json,
    );
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
