class AppAdPlacement {
  static const home = 'home';
  static const homeBanner = 'home_banner';
  static const categories = 'categories';
  static const cart = 'cart';
  static const checkout = 'checkout';
}

class AppAdModel {
  const AppAdModel({
    required this.id,
    required this.mediaType,
    required this.mediaUrl,
    this.title = '',
    this.linkUrl = '',
    this.displayOrder = 0,
  });

  final String id;
  final String title;
  final String mediaType;
  final String mediaUrl;
  final String linkUrl;
  final int displayOrder;

  bool get isVideo => mediaType.toLowerCase() == 'video';
  bool get hasLink => linkUrl.trim().isNotEmpty;

  factory AppAdModel.fromJson(Map<String, dynamic> json) {
    final mediaType = _readString(json, const ['mediaType', 'media_type']);
    return AppAdModel(
      id: _readString(json, const ['id', 'ad_id']),
      title: _readString(json, const ['title', 'name']),
      mediaType: mediaType.isEmpty ? 'image' : mediaType.toLowerCase(),
      mediaUrl: _readString(json, const ['mediaUrl', 'media_url', 'url']),
      linkUrl: _readString(json, const ['linkUrl', 'link_url', 'target_url']),
      displayOrder: _readInt(json, const ['displayOrder', 'display_order']),
    );
  }

  static String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  static int _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }
}
