import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'order_controller.dart';
import 'profile/controllers/profile_controller.dart';

class OrderSuccessView extends StatefulWidget {
  const OrderSuccessView({super.key});

  @override
  State<OrderSuccessView> createState() => _OrderSuccessViewState();
}

class _OrderSuccessViewState extends State<OrderSuccessView> {
  Timer? _timer;
  bool _didNavigate = false;
  late final String? _orderId;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments;
    _orderId = arguments is Map ? arguments['orderId']?.toString() : null;
    _timer = Timer(const Duration(milliseconds: 2300), _openLiveTracking);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) => _openDashboardOnly(),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24.rpx),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/animations/confirm.json',
                    width: 225.wpx,
                    height: 150.hpx,
                    repeat: false,
                    animate: true,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: 10.hpx),
                  Text(
                    'ORDER PLACED',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary.withValues(alpha: 0.42),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 16.hpx),
                  Container(
                    padding: EdgeInsets.only(bottom: 5.hpx),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.primary,
                          width: 2.rpx,
                        ),
                      ),
                    ),
                    child: Text(
                      'Delivering to Home',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  SizedBox(height: 10.hpx),
                  Text(
                    _deliveryAddress,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _deliveryAddress {
    if (Get.isRegistered<ProfileController>()) {
      final address = Get.find<ProfileController>().activeAddress?.address;
      if (address != null && address.trim().isNotEmpty) {
        return address.trim();
      }
    }

    if (Get.isRegistered<OrderController>()) {
      final controller = Get.find<OrderController>();
      final address =
          controller.selectedCheckoutAddress.value?.address ??
          controller.latestOrder.value?.deliveryAddress ??
          controller.activeProductOrder.value?.deliveryAddress;
      if (address != null && address.trim().isNotEmpty) {
        return address.trim();
      }
    }

    return 'Selected delivery address';
  }

  void _openLiveTracking() {
    if (_didNavigate) return;
    _didNavigate = true;
    Get.offAllNamed(AppRoutes.dashboard);
    Future.delayed(const Duration(milliseconds: 60), () {
      Get.toNamed(
        AppRoutes.liveTracking,
        arguments: {
          if (_orderId != null && _orderId.isNotEmpty) 'orderId': _orderId,
        },
      );
    });
  }

  void _openDashboardOnly() {
    if (_didNavigate) return;
    _didNavigate = true;
    _timer?.cancel();
    Get.offAllNamed(AppRoutes.dashboard);
  }
}
