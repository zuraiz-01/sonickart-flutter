import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';

import '../../../core/services/service_area_gate_service.dart';
import '../../../theme/app_colors.dart';
import '../controllers/splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  static const double _splashAspectRatio = 1024 / 1352;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF001B42),
      ),
      child: Obx(() {
        final blockedResult = controller.blockedResult.value;
        if (blockedResult != null) {
          return _UnserviceableAreaView(
            result: blockedResult,
            onRetry: controller.retryServiceCheck,
          );
        }
        return const _SplashLogoView();
      }),
    );
  }
}

class _SplashLogoView extends StatelessWidget {
  const _SplashLogoView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF01296F), Color(0xFF002870), Color(0xFF001F50)],
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 360.wpx),
            child: FractionallySizedBox(
              widthFactor: 0.78,
              child: AspectRatio(
                aspectRatio: SplashView._splashAspectRatio,
                child: Image.asset(
                  'assets/images/sonickart_splash.jpeg',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnserviceableAreaView extends StatelessWidget {
  const _UnserviceableAreaView({required this.result, required this.onRetry});

  final ServiceAreaGateResult result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001B42),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _CityBackdropPainter())),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(14.wpx, 12.hpx, 14.wpx, 18.hpx),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 30.hpx,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TopLocationChip(locationLabel: _locationLabel),
                        SizedBox(height: 24.hpx),
                        Padding(
                          padding: EdgeInsets.only(left: 8.wpx),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'HANG',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 46.spx,
                                  height: 0.9,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              Text(
                                'TIGHT!',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 50.spx,
                                  height: 0.95,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              Container(
                                margin: EdgeInsets.only(top: 7.hpx),
                                width: 148.wpx,
                                height: 2.hpx,
                                color: AppColors.accent,
                              ),
                              SizedBox(height: 12.hpx),
                              SizedBox(
                                width: 250.wpx,
                                child: Text(
                                  result.message.isNotEmpty
                                      ? result.message
                                      : 'We are currently live in select areas and expanding quickly to more neighbourhoods and cities.',
                                  style: TextStyle(
                                    color: AppColors.white.withValues(
                                      alpha: 0.84,
                                    ),
                                    fontSize: 12.spx,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(height: 4.hpx),
                              Text(
                                'Stay tuned for updates!',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 13.spx,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 18.hpx),
                        _InfoSteps(reason: result.reason),
                        SizedBox(height: 10.hpx),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(right: 4.wpx),
                            child: Icon(
                              Icons.delivery_dining_rounded,
                              color: AppColors.accent,
                              size: 132.rpx,
                            ),
                          ),
                        ),
                        SizedBox(height: 8.hpx),
                        _RetryButton(onRetry: onRetry),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String get _locationLabel {
    final label = result.locationLabel.trim();
    if (label.isNotEmpty) return label;
    return 'Live location unavailable';
  }
}

class _TopLocationChip extends StatelessWidget {
  const _TopLocationChip({required this.locationLabel});

  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.wpx, vertical: 10.hpx),
            decoration: BoxDecoration(
              color: const Color(0xFF061E49),
              borderRadius: BorderRadius.circular(12.rpx),
              border: Border.all(color: const Color(0xFF12346F)),
            ),
            child: Row(
              children: [
                Container(
                  width: 31.rpx,
                  height: 31.rpx,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16.rpx),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                SizedBox(width: 8.wpx),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unserviceable area',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 13.spx,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2.hpx),
                      Text(
                        locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.82),
                          fontSize: 10.spx,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.accent,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 12.wpx),
        Container(
          width: 38.rpx,
          height: 38.rpx,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accent),
            borderRadius: BorderRadius.circular(20.rpx),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: AppColors.accent,
            size: 20,
          ),
        ),
      ],
    );
  }
}

class _InfoSteps extends StatelessWidget {
  const _InfoSteps({required this.reason});

  final ServiceAreaBlockReason reason;

  @override
  Widget build(BuildContext context) {
    final permissionCopy = reason == ServiceAreaBlockReason.locationUnavailable;
    final items = [
      (
        Icons.location_on_outlined,
        permissionCopy ? 'Location Needed' : 'Expanding Quickly',
        permissionCopy
            ? 'Allow location access and retry.'
            : 'More areas, more soon!',
      ),
      (
        Icons.map_outlined,
        'New Places Coming Soon',
        'We are on our way to you.',
      ),
      (
        Icons.favorite_border_rounded,
        'Thank You For Your Patience!',
        'Good things are on the way.',
      ),
    ];

    return Padding(
      padding: EdgeInsets.only(left: 9.wpx),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.hpx),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36.rpx,
                  height: 36.rpx,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accent),
                    borderRadius: BorderRadius.circular(18.rpx),
                  ),
                  child: Icon(item.$1, color: AppColors.accent, size: 19),
                ),
                SizedBox(width: 10.wpx),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 12.spx,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2.hpx),
                      Text(
                        item.$3,
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.78),
                          fontSize: 10.spx,
                          height: 1.22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: OutlinedButton.icon(
        onPressed: onRetry,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent),
          padding: EdgeInsets.symmetric(horizontal: 18.wpx, vertical: 11.hpx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999.rpx),
          ),
        ),
        icon: const Icon(Icons.my_location_rounded, size: 18),
        label: Text(
          'Check Again',
          style: TextStyle(fontSize: 12.spx, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _CityBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF123A75).withValues(alpha: 0.22)
      ..strokeWidth = 1;
    for (var y = size.height * 0.72; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 38), gridPaint);
    }
    for (var x = -size.width; x < size.width * 1.5; x += 34) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.width * 0.38, size.height * 0.72),
        gridPaint,
      );
    }

    final buildingPaint = Paint()
      ..color = const Color(0xFF092B61).withValues(alpha: 0.9);
    final litPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.48)
      ..style = PaintingStyle.fill;
    final baseY = size.height * 0.76;
    final widths = [24.0, 34.0, 28.0, 42.0, 24.0, 36.0];
    var x = size.width * 0.52;
    for (var i = 0; i < widths.length; i += 1) {
      final height = (58 + (i % 3) * 28).toDouble();
      final rect = Rect.fromLTWH(x, baseY - height, widths[i], height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        buildingPaint,
      );
      for (var wy = rect.top + 12; wy < rect.bottom - 8; wy += 16) {
        canvas.drawRect(Rect.fromLTWH(x + 7, wy, 3, 6), litPaint);
        if (widths[i] > 30) {
          canvas.drawRect(Rect.fromLTWH(x + 20, wy + 4, 3, 6), litPaint);
        }
      }
      x += widths[i] + 8;
    }

    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.18),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.78, size.height * 0.66),
              radius: size.width * 0.42,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.66),
      size.width * 0.42,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
