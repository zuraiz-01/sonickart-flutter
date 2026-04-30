import 'package:get/get.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/service_area_gate_service.dart';
import '../../auth/bindings/auth_binding.dart';
import '../controllers/splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    AuthBinding().dependencies();
    if (!Get.isRegistered<ServiceAreaGateService>()) {
      Get.put(
        ServiceAreaGateService(apiService: Get.find<ApiService>()),
        permanent: true,
      );
    }
    Get.put(SplashController(Get.find(), Get.find()));
  }
}
