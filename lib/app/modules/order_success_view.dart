import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

class OrderSuccessView extends StatefulWidget {
  OrderSuccessView({super.key});

  @override
  State<OrderSuccessView> createState() => _OrderSuccessViewState();
}

class _OrderSuccessViewState extends State<OrderSuccessView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration(milliseconds: 2200), () {
      Get.offAllNamed(AppRoutes.dashboard);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F8FF),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.rpx),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 124.wpx,
                height: 124.hpx,
                decoration: BoxDecoration(
                  color: Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(62.rpx),
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 72,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 18.hpx),
              Text(
                'ORDER PLACED',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 14.hpx),
              Text(
                'Delivering to your selected address',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 10.hpx),
              Text(
                'Order completed flow ready hai. Aap ko dashboard par wapas le jaaya ja raha hai.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
