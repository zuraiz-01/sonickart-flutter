import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../utils/auth_guard.dart';
import '../../routes/app_routes.dart';

class SessionController extends GetxController {
  SessionController(this._storage);

  final GetStorage _storage;
  final isSessionExpiredVisible = false.obs;

  Future<void> showExpiredSession() async {
    await _clearSession();
    isSessionExpiredVisible.value = true;
  }

  Future<void> loginAgain() async {
    isSessionExpiredVisible.value = false;
    await _clearSession();
    Get.offAllNamed(AppRoutes.login);
  }

  Future<void> clearSessionSilently() async {
    await _clearSession();
  }

  Future<void> _clearSession() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      debugPrint(
        'SessionController._clearSession Firebase signOut failed: $error',
      );
    }
    await _storage.remove('accessToken');
    await _storage.remove('refreshToken');
    await _storage.remove('currentUser');
    await _storage.remove('isLoggedIn');
  }
}

class SessionExpiredOverlay extends StatelessWidget {
  const SessionExpiredOverlay({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SessionController>()) {
      Get.put(SessionController(GetStorage()), permanent: true);
    }
    final controller = Get.find<SessionController>();
    return Obx(
      () => Stack(
        children: [
          ?child,
          if (controller.isSessionExpiredVisible.value)
            Positioned.fill(
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                child: LoginRequiredDialog(onConfirm: controller.loginAgain),
              ),
            ),
        ],
      ),
    );
  }
}
