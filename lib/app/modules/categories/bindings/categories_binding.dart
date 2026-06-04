import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/network/api_service.dart';
import '../../../data/repositories/ads_repository.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../ads/controllers/ads_controller.dart';
import '../../cart/controllers/cart_controller.dart';
import '../controllers/categories_controller.dart';

class CategoriesBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ApiService>()) {
      Get.put(ApiService(), permanent: true);
    }
    if (!Get.isRegistered<CatalogRepository>()) {
      Get.put(CatalogRepository(Get.find()), permanent: true);
    }
    if (!Get.isRegistered<AdsRepository>()) {
      Get.put(AdsRepository(Get.find()), permanent: true);
    }
    if (!Get.isRegistered<AdsController>()) {
      final adsController = Get.put(AdsController(Get.find()), permanent: true);
      adsController.prefetchCorePlacements();
    }
    if (!Get.isRegistered<CartController>()) {
      Get.put(CartController(GetStorage()), permanent: true);
    }
    if (!Get.isRegistered<CategoriesController>()) {
      Get.put(CategoriesController(Get.find()));
    } else {
      Get.find<CategoriesController>().openFromRouteArguments(Get.arguments);
    }
  }
}
