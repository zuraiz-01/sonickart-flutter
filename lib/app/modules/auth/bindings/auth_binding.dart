import 'package:get/get.dart';

import '../../../core/network/api_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../controllers/auth_controller.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ApiService>()) {
      Get.put(ApiService(), permanent: true);
    }

    if (!Get.isRegistered<AuthRepository>()) {
      Get.put(AuthRepository(Get.find()), permanent: true);
    }

    if (!Get.isRegistered<AuthController>()) {
      Get.put(AuthController(Get.find()), permanent: true);
    }
  }
}
