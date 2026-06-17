import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../modules/auth/controllers/auth_controller.dart';
import '../../routes/app_routes.dart';
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
      insetPadding: EdgeInsets.symmetric(horizontal: 16.wpx),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 365.wpx),
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFFDFDFE),
            borderRadius: BorderRadius.circular(31.rpx),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.17),
                blurRadius: 28.rpx,
                offset: Offset(0, 16.hpx),
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
                  Transform.translate(
                    offset: Offset(0, -3.hpx),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        38.wpx,
                        60.hpx,
                        38.wpx,
                        25.hpx,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDFDFE),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(21.rpx),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Login Required',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: TextStyle(
                              color: const Color(0xFF082A78),
                              fontSize: 28.spx,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                              height: 1.05,
                            ),
                          ),
                          SizedBox(height: 17.hpx),
                          Container(
                            width: 34.wpx,
                            height: 3.hpx,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB20D),
                              borderRadius: BorderRadius.circular(99.rpx),
                            ),
                          ),
                          SizedBox(height: 20.hpx),
                          Text(
                            'Please login to add addresses,\nplace orders and track deliveries.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF47485A),
                              fontSize: 15.7.spx,
                              fontWeight: FontWeight.w600,
                              height: 1.55,
                              letterSpacing: 0,
                            ),
                          ),
                          SizedBox(height: 31.hpx),
                          _LoginRequiredButton(onPressed: onConfirm),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(top: 53.hpx, child: const _SecurityBadge()),
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
      height: 134.hpx,
      width: double.infinity,
      child: CustomPaint(
        painter: _LoginRequiredHeaderPainter(),
        child: Stack(
          children: [
            Positioned(
              left: 69.wpx,
              top: 82.hpx,
              child: _HeaderDots(color: Colors.white.withValues(alpha: 0.28)),
            ),
            Positioned(
              right: 24.wpx,
              top: 82.hpx,
              child: _HeaderDots(color: Colors.white.withValues(alpha: 0.28)),
            ),
            Positioned(
              left: 111.wpx,
              top: 49.hpx,
              child: _MiniMark(color: Colors.white.withValues(alpha: 0.95)),
            ),
            Positioned(
              right: 118.wpx,
              top: 48.hpx,
              child: _MiniMark(color: Colors.white.withValues(alpha: 0.86)),
            ),
            Positioned(
              right: 83.wpx,
              top: 77.hpx,
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
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 118.rpx,
          height: 118.rpx,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0B4DD0).withValues(alpha: 0.13),
          ),
        ),
        Container(
          width: 101.rpx,
          height: 101.rpx,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0B4DD0).withValues(alpha: 0.2),
          ),
        ),
        Container(
          width: 86.rpx,
          height: 86.rpx,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 13.rpx,
                offset: Offset(0, 7.hpx),
              ),
            ],
          ),
          child: Center(
            child: SizedBox(
              width: 56.rpx,
              height: 62.rpx,
              child: CustomPaint(painter: _ShieldLockPainter()),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginRequiredButton extends StatelessWidget {
  const _LoginRequiredButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48.hpx,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFCE28), Color(0xFFFFAA00)],
          ),
          borderRadius: BorderRadius.circular(14.rpx),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB000).withValues(alpha: 0.36),
              blurRadius: 14.rpx,
              offset: Offset(0, 6.hpx),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14.rpx),
          child: InkWell(
            borderRadius: BorderRadius.circular(14.rpx),
            onTap: onPressed,
            child: Center(
              child: Text(
                'OK',
                style: TextStyle(
                  color: const Color(0xFF082A78),
                  fontSize: 20.spx,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
            ),
          ),
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
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF04349E), Color(0xFF052B91), Color(0xFF033DAB)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, basePaint);

    final softPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..color = Colors.white.withValues(alpha: 0.055);

    canvas.drawCircle(
      Offset(size.width * -0.06, size.height * 1.12),
      size.width * 0.43,
      Paint()..color = const Color(0xFF073FA9),
    );
    canvas.drawCircle(
      Offset(size.width * 1.1, size.height * 1.04),
      size.width * 0.47,
      Paint()..color = const Color(0xFF07359A),
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.58),
      size.width * 0.24,
      Paint()..color = Colors.white.withValues(alpha: 0.045),
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.58),
      size.width * 0.165,
      softPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShieldLockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shield = Path()
      ..moveTo(size.width * 0.5, size.height * 0.03)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.16,
        size.width * 0.24,
        size.height * 0.19,
        size.width * 0.13,
        size.height * 0.23,
      )
      ..lineTo(size.width * 0.13, size.height * 0.48)
      ..cubicTo(
        size.width * 0.13,
        size.height * 0.74,
        size.width * 0.31,
        size.height * 0.9,
        size.width * 0.5,
        size.height * 0.99,
      )
      ..cubicTo(
        size.width * 0.69,
        size.height * 0.9,
        size.width * 0.87,
        size.height * 0.74,
        size.width * 0.87,
        size.height * 0.48,
      )
      ..lineTo(size.width * 0.87, size.height * 0.23)
      ..cubicTo(
        size.width * 0.76,
        size.height * 0.19,
        size.width * 0.65,
        size.height * 0.16,
        size.width * 0.5,
        size.height * 0.03,
      )
      ..close();

    canvas.drawPath(shield, Paint()..color = const Color(0xFF073FAA));
    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.055
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF0B5BE7),
    );
    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.56),
    );

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.31,
        size.height * 0.48,
        size.width * 0.38,
        size.height * 0.31,
      ),
      Radius.circular(size.width * 0.085),
    );
    final shackle = Path()
      ..moveTo(size.width * 0.36, size.height * 0.49)
      ..lineTo(size.width * 0.36, size.height * 0.36)
      ..cubicTo(
        size.width * 0.36,
        size.height * 0.19,
        size.width * 0.64,
        size.height * 0.19,
        size.width * 0.64,
        size.height * 0.36,
      )
      ..lineTo(size.width * 0.64, size.height * 0.49);

    canvas.drawPath(
      shackle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.08
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFFFFBE18));

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.61),
      size.width * 0.035,
      Paint()..color = const Color(0xFF082A78),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.482,
          size.height * 0.62,
          size.width * 0.036,
          size.height * 0.1,
        ),
        Radius.circular(size.width * 0.018),
      ),
      Paint()..color = const Color(0xFF082A78),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
