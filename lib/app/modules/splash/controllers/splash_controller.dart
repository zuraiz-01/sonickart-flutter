import 'package:get/get.dart';

import '../../../core/services/service_area_gate_service.dart';
import '../../../routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';

class SplashController extends GetxController {
  SplashController(this._authController, this._serviceAreaGateService);

  final AuthController _authController;
  final ServiceAreaGateService _serviceAreaGateService;
  final blockedResult = Rxn<ServiceAreaGateResult>();
  final isCheckingServiceArea = true.obs;

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> retryServiceCheck() async {
    blockedResult.value = null;
    isCheckingServiceArea.value = true;
    await _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final gateResult = await _serviceAreaGateService.evaluate();
    if (!gateResult.isAllowed) {
      blockedResult.value = gateResult;
      isCheckingServiceArea.value = false;
      return;
    }

    if (_authController.isLoggedIn) {
      Get.offAllNamed(AppRoutes.dashboard);
    } else {
      Get.offAllNamed(AppRoutes.login);
    }
  }
}
