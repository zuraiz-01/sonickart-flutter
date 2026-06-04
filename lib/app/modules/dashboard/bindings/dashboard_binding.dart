import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/customer_socket_notification_service.dart';
import '../../../core/services/local_notification_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/order_socket_service.dart';
import '../../../core/services/package_socket_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/service_area_gate_controller.dart';
import '../../../core/services/service_area_gate_service.dart';
import '../../../data/repositories/ads_repository.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../ads/controllers/ads_controller.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../categories/controllers/categories_controller.dart';
import '../../order_controller.dart';
import '../../package/controllers/package_controller.dart';
import '../../profile/controllers/profile_controller.dart';
import '../controllers/dashboard_controller.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<DashboardController>() &&
        !Get.isPrepared<DashboardController>()) {
      Get.lazyPut(DashboardController.new, fenix: true);
    }
    if (!Get.isRegistered<ApiService>()) {
      Get.put(ApiService(), permanent: true);
    }
    if (!Get.isRegistered<ServiceAreaGateService>()) {
      Get.put(
        ServiceAreaGateService(apiService: Get.find<ApiService>()),
        permanent: true,
      );
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
    if (!Get.isRegistered<NotificationService>()) {
      Get.put(NotificationService(GetStorage()), permanent: true);
    }
    if (!Get.isRegistered<LocalNotificationService>()) {
      Get.put(LocalNotificationService(), permanent: true).init();
    }
    if (!Get.isRegistered<PushNotificationService>()) {
      Get.put(PushNotificationService(), permanent: true).init();
    } else {
      Get.find<PushNotificationService>().registerCurrentToken();
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
    if (!Get.isRegistered<CategoriesController>()) {
      Get.put(CategoriesController(Get.find()), permanent: true);
    }
    if (!Get.isRegistered<ServiceAreaGateController>()) {
      Get.put(
        ServiceAreaGateController(serviceAreaGateService: Get.find()),
        permanent: true,
      );
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
    if (!Get.isRegistered<CustomerSocketNotificationService>()) {
      Get.put(CustomerSocketNotificationService(), permanent: true).init();
    } else {
      Get.find<CustomerSocketNotificationService>().connectForCurrentUser();
    }
  }
}
