import 'dart:convert';

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

  String get displayPrice => _formatCurrency(numericPrice);

  String get displayMrp {
    final value = double.tryParse(mrp);
    if (value == null || value <= 0) return '';
    return _formatCurrency(value);
  }

  String get resolvedImageUrl {
    return _resolveUrl(imageUrl);
  }

  String get resolvedFeaturedImageUrl {
    final featured = _resolveUrl(featuredImageUrl);
    return featured.isNotEmpty ? featured : resolvedImageUrl;
  }

  List<String> get resolvedGalleryImageUrls {
    final rawImages = raw['images'];
    final gallery = <String>[
      imageUrl,
      if (rawImages is List) ...rawImages.map(_imageString),
      if (rawImages is String) ..._decodeImageList(rawImages),
    ];
    final seen = <String>{};
    return gallery
        .map(_resolveUrl)
        .where((item) => item.isNotEmpty && seen.add(item))
        .toList();
  }

  static String _resolveUrl(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty || value == 'null' || value == 'undefined') return '';
    final decodedList = _decodeImageList(value);
    if (decodedList.isNotEmpty) return _resolveUrl(decodedList.first);
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('data:image/') || value.startsWith('blob:')) {
      return value;
    }
    if (value.toLowerCase().startsWith('http')) return value;
    final normalizedPath = value.replaceAll(r'\', '/');
    if (normalizedPath.startsWith('/')) {
      return '${ApiConstants.mobileHost}$normalizedPath';
    }
    return '${ApiConstants.mobileHost}/$normalizedPath';
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
    final rawImageValue =
        json['image'] ??
        json['imageUrl'] ??
        json['image_url'] ??
        json['product_images'] ??
        json['productImages'] ??
        json['media'] ??
        json['thumbnail'] ??
        (images.isNotEmpty ? images.first : null);
    final rawFeaturedImageValue =
        json['featuredImage'] ??
        json['featureImage'] ??
        json['featured_image'] ??
        json['feature_image'] ??
        json['bannerImage'] ??
        json['banner_image'];
    final imageValue = _imageString(rawImageValue);
    final featuredImageValue = _imageString(rawFeaturedImageValue);
    return ProductModel(
      id: (json['id'] ?? json['_id'] ?? json['productId'])?.toString() ?? '',
      categoryId:
          (json['categoryId'] ??
                  json['category_id'] ??
                  category['id'] ??
                  category['_id'] ??
                  category['categoryId'])
              ?.toString() ??
          '',
      name: json['name']?.toString() ?? json['product_name']?.toString() ?? '',
      description:
          (json['description'] ??
                  json['details'] ??
                  json['subtitle'] ??
                  json['short_description'] ??
                  json['shortDescription'] ??
                  json['product_description'])
              ?.toString() ??
          '',
      unit: _resolveUnit(json),
      price: _numberString(
        json['discountPrice'] ??
            json['discount_price'] ??
            json['price'] ??
            json['unit_price'] ??
            json['unitPrice'] ??
            json['sellingPrice'] ??
            json['selling_price'] ??
            (json['item'] is Map
                ? ((json['item'] as Map)['discountPrice'] ??
                      (json['item'] as Map)['discount_price'] ??
                      (json['item'] as Map)['price'])
                : null),
      ),
      mrp:
          (json['mrp'] ??
                  (json['item'] is Map ? (json['item'] as Map)['mrp'] : null) ??
                  json['originalPrice'] ??
                  json['original_price'] ??
                  (json['item'] is Map
                      ? (json['item'] as Map)['originalPrice']
                      : null))
              ?.toString() ??
          '',
      emoji: json['emoji']?.toString() ?? '',
      imageUrl: imageValue,
      featuredImageUrl: featuredImageValue,
      vendorId:
          (json['vendorId'] ??
                  json['vendor_id'] ??
                  vendor['id'] ??
                  vendor['_id'] ??
                  vendor['vendorId'] ??
                  _inferVendorIdFromAssetPath(json))
              ?.toString() ??
          '',
      branchId:
          (json['branchId'] ??
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
    if (value is String) {
      final decoded = _decodeImageList(value);
      return decoded.isNotEmpty ? decoded.first : value;
    }
    if (value is List && value.isNotEmpty) return _imageString(value.first);
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in [
        'secure_url',
        'url',
        'uri',
        'imageUrl',
        'image',
        'path',
        'src',
        'location',
      ]) {
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
          .map((item) => _imageString(item).trim())
          .where((item) => item.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String _resolveUnit(Map<String, dynamic> json) {
    String? normalize(String raw) {
      final cleaned = raw.replaceAll(RegExp(r'[()]'), ' ').trim();
      final match = RegExp(
        r'(\d+(?:\.\d+)?)\s*(ml|milliliter|millilitre|l|lt|ltr|liter|litre|g|gm|gram|grams|kg|kgs|kilogram|kilograms|pc|pcs|piece|pieces|pack|packs|pkt|pkts)\b',
        caseSensitive: false,
      ).firstMatch(cleaned);
      if (match == null) return null;
      var value = match.group(1) ?? '';
      if (value.contains('.')) {
        while (value.endsWith('0')) {
          value = value.substring(0, value.length - 1);
        }
        if (value.endsWith('.')) {
          value = value.substring(0, value.length - 1);
        }
      }
      final rawUnit = (match.group(2) ?? '').toLowerCase();
      final unit = switch (rawUnit) {
        'milliliter' || 'millilitre' || 'ml' => 'ml',
        'l' || 'lt' || 'ltr' || 'liter' || 'litre' => 'L',
        'g' || 'gm' || 'gram' || 'grams' => 'g',
        'kg' || 'kgs' || 'kilogram' || 'kilograms' => 'kg',
        _ => value == '1' ? 'pc' : 'pcs',
      };
      return unit == 'pc' || unit == 'pcs' ? '$value $unit' : '$value $unit';
    }

    final directCandidates = [
      json['displayUnit'],
      json['display_unit'],
      json['unitDisplay'],
      json['unit_display'],
      json['unitLabel'],
      json['unit_label'],
      json['units'],
      json['quantity'],
      json['quantity_text'],
      json['quantityText'],
      json['pack_size'],
      json['packSize'],
      json['size'],
      json['weight'],
      json['volume'],
      json['net_quantity'],
      json['netQuantity'],
      json['variant'],
    ];
    for (final candidate in directCandidates) {
      if (candidate == null) continue;
      final resolved = normalize(candidate.toString());
      if (resolved != null) return resolved;
    }

    final value =
        [
          json['unit_value'],
          json['unitValue'],
          json['quantity_value'],
          json['quantityValue'],
          json['size_value'],
          json['sizeValue'],
          json['weight_value'],
          json['weightValue'],
          json['volume_value'],
          json['volumeValue'],
          json['qty'],
        ].firstWhere(
          (item) => item != null && item.toString().trim().isNotEmpty,
          orElse: () => null,
        );
    final unit =
        [
          json['unit'],
          json['uom'],
          json['measurement_unit'],
          json['measurementUnit'],
          json['quantity_unit'],
          json['quantityUnit'],
        ].firstWhere(
          (item) => item != null && item.toString().trim().isNotEmpty,
          orElse: () => null,
        );
    if (value != null && unit != null) {
      final resolved = normalize('$value $unit');
      if (resolved != null) return resolved;
    }

    final nameUnit = normalize(json['name']?.toString() ?? '');
    return nameUnit ?? '1 pc';
  }

  static String _numberString(Object? value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    return _formatCurrency(parsed ?? 0);
  }

  static String _formatCurrency(double value) {
    if (value.isNaN || !value.isFinite) return '0';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '');
  }

  static String? _inferVendorIdFromAssetPath(Map<String, dynamic> json) {
    final values = [
      json['image'],
      json['imageUrl'],
      json['product_images'],
      if (json['images'] is List) ...(json['images'] as List),
      if (json['media'] is List) ...(json['media'] as List),
    ].map(_imageString);
    for (final value in values) {
      final match = RegExp(
        r'/vendors/([^/]+)/',
        caseSensitive: false,
      ).firstMatch(value.replaceAll(r'\', '/'));
      if (match != null) return match.group(1);
    }
    return null;
  }
}
