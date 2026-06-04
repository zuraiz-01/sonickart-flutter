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
    LoginRequiredDialog(
      onConfirm: () {
        Get.back();
        Get.toNamed(AppRoutes.login);
      },
    ),
    barrierColor: Colors.black.withValues(alpha: 0.45),
  );

  return false;
}

class LoginRequiredDialog extends StatelessWidget {
  const LoginRequiredDialog({super.key, required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 18.wpx),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 360.wpx),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(30.rpx),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 26.rpx,
                offset: Offset(0, 14.hpx),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _LoginRequiredHeader(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      34.wpx,
                      54.hpx,
                      34.wpx,
                      26.hpx,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Login Required',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            color: AppColors.lightPrimary,
                            fontSize: 27.spx,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                            height: 1.05,
                          ),
                        ),
                        SizedBox(height: 18.hpx),
                        Container(
                          width: 34.wpx,
                          height: 3.5.hpx,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(99.rpx),
                          ),
                        ),
                        SizedBox(height: 21.hpx),
                        Text(
                          'Please login to add addresses,\nplace orders and track deliveries.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF4A4A5F),
                            fontSize: 15.5.spx,
                            fontWeight: FontWeight.w600,
                            height: 1.55,
                            letterSpacing: 0,
                          ),
                        ),
                        SizedBox(height: 32.hpx),
                        SizedBox(
                          width: double.infinity,
                          height: 48.hpx,
                          child: FilledButton(
                            onPressed: onConfirm,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.lightPrimary,
                              elevation: 8,
                              shadowColor: AppColors.accent.withValues(
                                alpha: 0.32,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.rpx),
                              ),
                            ),
                            child: Text(
                              'OK',
                              style: TextStyle(
                                fontSize: 20.spx,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(top: 52.hpx, child: const _SecurityBadge()),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginRequiredHeader extends StatelessWidget {
  const _LoginRequiredHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 126.hpx,
      width: double.infinity,
      child: CustomPaint(
        painter: _LoginRequiredHeaderPainter(),
        child: Stack(
          children: [
            Positioned(
              left: 103.wpx,
              top: 43.hpx,
              child: _HeaderDots(color: Colors.white.withValues(alpha: 0.48)),
            ),
            Positioned(
              right: 30.wpx,
              top: 73.hpx,
              child: _HeaderDots(color: Colors.white.withValues(alpha: 0.28)),
            ),
            Positioned(
              left: 112.wpx,
              top: 35.hpx,
              child: _MiniMark(color: Colors.white.withValues(alpha: 0.92)),
            ),
            Positioned(
              right: 135.wpx,
              top: 38.hpx,
              child: _MiniMark(color: Colors.white.withValues(alpha: 0.86)),
            ),
            Positioned(
              right: 96.wpx,
              top: 66.hpx,
              child: _ShortLines(color: Colors.white.withValues(alpha: 0.82)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  const _SecurityBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92.rpx,
      height: 92.rpx,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14.rpx,
            offset: Offset(0, 8.hpx),
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.security_rounded,
              color: AppColors.lightSecondaryBlue,
              size: 58.spx,
            ),
            Positioned(
              bottom: 24.hpx,
              child: Container(
                width: 26.rpx,
                height: 23.rpx,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(5.rpx),
                  border: Border.all(color: Colors.white, width: 1.2.rpx),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  color: AppColors.lightSecondaryBlue,
                  size: 15.spx,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderDots extends StatelessWidget {
  const _HeaderDots({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34.wpx,
      height: 34.hpx,
      child: Wrap(
        spacing: 6.wpx,
        runSpacing: 6.hpx,
        children: List.generate(
          9,
          (_) => Container(
            width: 2.4.rpx,
            height: 2.4.rpx,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _MiniMark extends StatelessWidget {
  const _MiniMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16.wpx,
      height: 22.hpx,
      child: Stack(
        children: [
          _Dot(left: 3.wpx, top: 1.hpx, color: color),
          _Dot(left: 11.wpx, top: 7.hpx, color: color),
          _Dash(left: 0, top: 15.hpx, color: color),
          _Dash(left: 8.wpx, top: 18.hpx, color: color),
        ],
      ),
    );
  }
}

class _ShortLines extends StatelessWidget {
  const _ShortLines({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 23.wpx,
      height: 17.hpx,
      child: Stack(
        children: [
          _Dash(left: 0, top: 1.hpx, width: 12.wpx, color: color),
          _Dash(left: 7.wpx, top: 10.hpx, width: 16.wpx, color: color),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.left, required this.top, required this.color});

  final double left;
  final double top;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: 3.4.rpx,
        height: 3.4.rpx,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _Dash extends StatelessWidget {
  const _Dash({
    required this.left,
    required this.top,
    required this.color,
    this.width,
  });

  final double left;
  final double top;
  final double? width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: width ?? 8.wpx,
        height: 2.2.hpx,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99.rpx),
        ),
      ),
    );
  }
}

class _LoginRequiredHeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()..color = AppColors.lightSecondaryBlue;
    canvas.drawRect(Offset.zero & size, basePaint);

    final darkPaint = Paint()..color = AppColors.lightPrimary;
    final leftPaint = Paint()..color = const Color(0xFF073B9F);
    final softPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..color = Colors.white.withValues(alpha: 0.06);

    canvas.drawCircle(
      Offset(size.width * -0.08, size.height * 1.12),
      size.width * 0.44,
      leftPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 1.1, size.height * 1.04),
      size.width * 0.48,
      darkPaint..color = const Color(0xFF073393),
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.56),
      size.width * 0.24,
      Paint()..color = Colors.white.withValues(alpha: 0.05),
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.56),
      size.width * 0.17,
      softPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
