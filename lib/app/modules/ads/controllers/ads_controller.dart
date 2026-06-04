import 'dart:async';

import 'package:get/get.dart';

import '../../../data/models/app_ad_model.dart';
import '../../../data/repositories/ads_repository.dart';

class AdsController extends GetxController {
  AdsController(this._repository);

  final AdsRepository _repository;
  final _adsByPlacement = <String, List<AppAdModel>>{}.obs;
  final _loadingPlacements = <String, bool>{}.obs;
  final _loadedPlacements = <String>{};

  List<AppAdModel> adsFor(String placement) {
    return _adsByPlacement[placement] ?? const <AppAdModel>[];
  }

  bool isLoading(String placement) => _loadingPlacements[placement] == true;

  Future<void> ensureLoaded(String placement, {bool force = false}) async {
    if (!force && _loadedPlacements.contains(placement)) return;
    if (_loadingPlacements[placement] == true) return;

    _loadingPlacements[placement] = true;
    try {
      final ads = await _repository.fetchAds(placement);
      _adsByPlacement[placement] = ads;
      _loadedPlacements.add(placement);
    } finally {
      _loadingPlacements[placement] = false;
    }
  }

  void prefetchCorePlacements() {
    for (final placement in const [
      AppAdPlacement.homeBanner,
      AppAdPlacement.home,
      AppAdPlacement.categories,
      AppAdPlacement.cart,
      AppAdPlacement.checkout,
    ]) {
      unawaited(ensureLoaded(placement));
    }
  }
}
