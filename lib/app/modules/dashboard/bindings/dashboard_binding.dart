import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/order_socket_service.dart';
import '../../../core/services/package_socket_service.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../order_controller.dart';
import '../../package/controllers/package_controller.dart';
import '../../profile/controllers/profile_controller.dart';
import '../controllers/dashboard_controller.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ApiService>()) {
      Get.put(ApiService(), permanent: true);
    }
    if (!Get.isRegistered<CatalogRepository>()) {
      Get.put(CatalogRepository(Get.find()), permanent: true);
    }
    if (!Get.isRegistered<CartController>()) {
      Get.put(CartController(GetStorage()), permanent: true);
    }
    if (!Get.isRegistered<OrderController>()) {
      Get.put(OrderController(GetStorage()), permanent: true);
    }
    if (!Get.isRegistered<PackageController>()) {
      Get.put(PackageController(GetStorage()), permanent: true);
    }
    if (!Get.isRegistered<ProfileController>()) {
      Get.put(ProfileController(GetStorage()), permanent: true);
    }
    if (!Get.isRegistered<OrderSocketService>()) {
      Get.put(OrderSocketService(), permanent: true).init();
    } else {
      Get.find<OrderSocketService>().bindOrderController(
        Get.find<OrderController>(),
      );
    }
    if (!Get.isRegistered<PackageSocketService>()) {
      Get.put(PackageSocketService(), permanent: true).init();
    }
    Get.lazyPut(DashboardController.new);
  }
}
