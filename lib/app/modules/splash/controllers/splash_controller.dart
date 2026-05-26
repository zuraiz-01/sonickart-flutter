import 'package:get/get.dart';

import '../../../core/services/service_area_gate_controller.dart';
import '../../../routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';

class SplashController extends GetxController {
  SplashController(this._authController);

  final AuthController _authController;
  final isCheckingServiceArea = true.obs;

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> retryServiceCheck() async {
    isCheckingServiceArea.value = true;
    await _bootstrap();
  }

  Future<void> _bootstrap() async {
    final splashDelay = Future<void>.delayed(const Duration(milliseconds: 900));
    final serviceAreaCheck = _authController.isLoggedIn
        ? _precheckServiceArea()
        : Future<void>.value();
    await splashDelay;
    await serviceAreaCheck.timeout(
      const Duration(milliseconds: 900),
      onTimeout: () {},
    );
    if (_authController.isLoggedIn) {
      Get.offAllNamed(AppRoutes.dashboard);
    } else {
      Get.offAllNamed(AppRoutes.login);
    }
  }

  Future<void> _precheckServiceArea() async {
    if (!Get.isRegistered<ServiceAreaGateController>()) return;
    await Get.find<ServiceAreaGateController>().ensureChecked();
  }
}
