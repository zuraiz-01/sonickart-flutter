import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../data/models/order_model.dart';
import '../theme/app_colors.dart';
import 'order_controller.dart';

class CustomerOrderDetailsView extends GetView<OrderController> {
  CustomerOrderDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    final orderId = Get.arguments?['orderId']?.toString() ?? '';
    final OrderModel? order =
        controller.findOrderById(orderId) ?? controller.selectedOrder.value;

    return Scaffold(
      backgroundColor: Color(0xFFF5F8FF),
      appBar: AppBar(title: Text('Order Details'), centerTitle: true),
      body: order == null
          ? Center(
              child: Text(
                'Order not found.',
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
                      Text(
                        'Order #${order.id}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6.hpx),
                      Text(
                        order.createdAt.toLocal().toString().substring(0, 16),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 16.hpx),
                      _DetailLine(label: 'Status', value: 'Preparing'),
                      _DetailLine(label: 'Payment', value: order.paymentMode),
                      _DetailLine(
                        label: 'Delivery Address',
                        value: order.deliveryAddress,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.hpx),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    children: order.items.map((item) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surface,
                          child: Text(item.product.emoji),
                        ),
                        title: Text(
                          item.product.name,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${item.quantity} x ${item.product.unit}',
                        ),
                        trailing: Text(
                          'Rs ${item.totalPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    }).toList(),
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total Paid',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        'Rs ${order.totalPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
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
          SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
