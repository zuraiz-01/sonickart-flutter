import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';
import '../../data/models/package_order_model.dart';
import 'controllers/package_controller.dart';

class PackageOrderDetailsView extends GetView<PackageController> {
  PackageOrderDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    final orderId = Get.arguments?['orderId']?.toString() ?? '';
    final PackageOrderModel? order =
        controller.findOrderById(orderId) ?? controller.selectedOrder.value;

    return Scaffold(
      backgroundColor: Color(0xFFF5F8FF),
      appBar: AppBar(title: Text('Package Order'), centerTitle: true),
      body: order == null
          ? Center(
              child: Text(
                'Package order not found.',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.all(16.rpx),
              children: [
                Container(
                  padding: EdgeInsets.all(16.rpx),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Packing your package order',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                SizedBox(height: 4.hpx),
                                Text(
                                  'Order #${order.id}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFEEF4FF),
                              borderRadius: BorderRadius.circular(999.rpx),
                            ),
                            child: Text(
                              order.status,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.hpx),
                      _DetailRow(
                        label: 'Package Type',
                        value: order.packageType,
                      ),
                      _DetailRow(label: 'Pickup', value: order.pickupAddress),
                      _DetailRow(label: 'Drop', value: order.dropAddress),
                      _DetailRow(
                        label: 'Booked At',
                        value: order.createdAt.toLocal().toString().substring(
                          0,
                          16,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.hpx),
                Container(
                  padding: EdgeInsets.all(16.rpx),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill Details',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      SizedBox(height: 14.hpx),
                      _BillRow(
                        label: 'Distance',
                        value: '${order.distanceKm.toStringAsFixed(1)} km',
                      ),
                      SizedBox(height: 10.hpx),
                      _BillRow(
                        label: 'Delivery Charge',
                        value: 'Rs ${order.deliveryCharge.toStringAsFixed(0)}',
                      ),
                      SizedBox(height: 10.hpx),
                      Divider(height: 1, color: AppColors.border),
                      SizedBox(height: 10.hpx),
                      _BillRow(
                        label: 'Grand Total',
                        value: 'Rs ${order.totalPrice.toStringAsFixed(0)}',
                        strong: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.hpx),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  _BillRow({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final weight = strong ? FontWeight.w800 : FontWeight.w600;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.primary, fontWeight: weight),
          ),
        ),
        Text(
          value,
          style: TextStyle(color: AppColors.primary, fontWeight: weight),
        ),
      ],
    );
  }
}
