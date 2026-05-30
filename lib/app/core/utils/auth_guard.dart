import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../modules/auth/controllers/auth_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import 'responsive.dart';

/// Checks if the user is authenticated before allowing an action.
/// If not authenticated, shows a login prompt dialog.
/// Returns `true` if the user is authenticated, `false` otherwise.
bool requireAuth() {
  final authController = Get.find<AuthController>();
  if (authController.isLoggedIn) return true;

  Get.dialog(
    Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: EdgeInsets.fromLTRB(24.wpx, 28.hpx, 24.wpx, 18.hpx),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20.rpx),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 48.spx,
              color: AppColors.primary,
            ),
            SizedBox(height: 16.hpx),
            Text(
              'Login Required',
              style: TextStyle(
                fontSize: 18.spx,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 10.hpx),
            Text(
              'You need to login to proceed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.spx,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            SizedBox(height: 22.hpx),
            FilledButton(
              onPressed: () {
                Get.back();
                Get.toNamed(AppRoutes.login);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.buttonFill,
                foregroundColor: AppColors.onButtonFill,
                minimumSize: Size(double.infinity, 48.hpx),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.rpx),
                ),
              ),
              child: Text(
                'Login',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15.spx,
                ),
              ),
            ),
            SizedBox(height: 8.hpx),
            TextButton(
              onPressed: Get.back,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                minimumSize: Size(double.infinity, 40.hpx),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.spx,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    barrierColor: Colors.black.withValues(alpha: 0.45),
  );

  return false;
}
