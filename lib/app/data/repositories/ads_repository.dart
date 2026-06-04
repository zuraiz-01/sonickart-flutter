import 'package:flutter/foundation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_service.dart';
import '../models/app_ad_model.dart';

class AdsRepository {
  AdsRepository(this._apiService);

  final ApiService _apiService;

  Future<List<AppAdModel>> fetchAds(String placement) async {
    try {
      final response = await _apiService.get(
        endpoint: ApiConstants.ads,
        query: {'placement': placement},
        authenticated: false,
      );
      final rawAds = _extractAds(response);
      return rawAds
          .whereType<Map>()
          .map((raw) => AppAdModel.fromJson(Map<String, dynamic>.from(raw)))
          .where((ad) => ad.mediaUrl.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      debugPrint('AdsRepository.fetchAds($placement) failed: $error');
      return const <AppAdModel>[];
    }
  }

  List<dynamic> _extractAds(Map<String, dynamic> response) {
    final direct = response['ads'] ?? response['data'];
    if (direct is List) return direct;
    if (direct is Map) {
      for (final key in const ['ads', 'items', 'results', 'data']) {
        final value = direct[key];
        if (value is List) return value;
      }
    }
    return const <dynamic>[];
  }
}
