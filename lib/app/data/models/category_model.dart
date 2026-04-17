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
    if (value.startsWith('http')) return value;
    if (value.startsWith('/')) return '${ApiConstants.mobileHost}$value';
    return '${ApiConstants.mobileHost}/$value';
  }

  Map<String, dynamic> toJson() {
    return {
      ...raw,
      'id': id,
      'name': name,
      'emoji': emoji,
      'image': imageUrl,
    };
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: (json['id'] ?? json['_id'] ?? json['categoryId'])?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '',
      imageUrl: _imageString(json['image'] ??
          json['categoryImage'] ??
          json['category_image'] ??
          json['icon'] ??
          json['thumbnail']),
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
