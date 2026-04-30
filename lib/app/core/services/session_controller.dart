import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';

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
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 350),
                    child: Container(
                      width: MediaQuery.sizeOf(context).width * 0.8,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x4D000000),
                            blurRadius: 12,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            color: AppColors.primary,
                            child: Center(
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: const BoxDecoration(
                                  color: AppColors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x33000000),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.schedule_rounded,
                                  size: 48,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 24,
                            ),
                            child: Text(
                              'Please login again',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.black,
                                fontSize: 16,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: controller.loginAgain,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.white,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: const Text('OK'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
