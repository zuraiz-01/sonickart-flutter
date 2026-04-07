import 'package:get/get.dart';

import '../../../routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';

class SplashController extends GetxController {
  SplashController(this._authController);

  final AuthController _authController;

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (_authController.isLoggedIn) {
      Get.offAllNamed(AppRoutes.dashboard);
    } else {
      Get.offAllNamed(AppRoutes.login);
    }
  }
}
