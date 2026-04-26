import 'dart:math' as math;

import 'package:sizer/sizer.dart';

class AppResponsive {
  static const double _designWidth = 375;
  static const double _designHeight = 812;

  static double width(num value) => value * 100.w / _designWidth;

  static double height(num value) => value * 100.h / _designHeight;

  static double radius(num value) => math.min(width(value), height(value));

  static double font(num value) {
    final scaled = value.sp;
    final min = value.toDouble() * 0.9;
    final max = value.toDouble() * 1.2;
    return scaled.clamp(min, max).toDouble();
  }
}

extension ResponsiveNum on num {
  double get wpx => AppResponsive.width(this);

  double get hpx => AppResponsive.height(this);

  double get rpx => AppResponsive.radius(this);

  double get spx => AppResponsive.font(this);
}
