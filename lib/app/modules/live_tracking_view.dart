import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/order_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'order_controller.dart';

class LiveTrackingView extends GetView<OrderController> {
  const LiveTrackingView({super.key});

  @override
  Widget build(BuildContext context) {
    final argId = Get.arguments?['orderId']?.toString();
    final order = argId == null ? controller.latestOrder.value : controller.findOrderById(argId);
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(title: const Text('Live Tracking'), centerTitle: true),
      body: order == null
          ? const Center(child: Text('No active order found.'))
          : _TrackingBody(order: order, controller: controller),
    );
  }
}

class _TrackingBody extends StatelessWidget {
  const _TrackingBody({required this.order, required this.controller});

  final OrderModel order;
  final OrderController controller;

  @override
  Widget build(BuildContext context) {
    final eta = controller.etaFor(order);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 220,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF4FF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 72, color: AppColors.primary),
              const SizedBox(height: 12),
              Text('Live map preview', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('ETA ${eta == null ? 'Tracking live' : '$eta mins'}', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: _statusTitle(order.status),
          rows: [
            ('Order', order.id),
            ('Status', order.status),
            ('Payment', order.paymentMode),
            ('Address', order.deliveryAddress),
            ('Total', 'Rs ${order.totalPrice.toStringAsFixed(0)}'),
          ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Ordered Items (${order.items.length})',
          rows: order.items.map((item) => (item.product.name, '${item.quantity} x Rs ${item.product.price}')).toList(),
        ),
        const SizedBox(height: 16),
        if (order.status.toLowerCase() != 'cancelled' && order.status.toLowerCase() != 'delivered')
          FilledButton.icon(
            onPressed: () => controller.cancelOrder(order),
            icon: const Icon(Icons.cancel_outlined),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
            label: const Text('Cancel Order', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Get.toNamed(AppRoutes.customerOrderDetails, arguments: {'orderId': order.id}),
          child: const Text('View Order Details'),
        ),
      ],
    );
  }

  String _statusTitle(String status) {
    final lower = status.toLowerCase();
    if (lower == 'cancelled') return 'Order Cancelled';
    if (lower == 'delivered') return 'Order Delivered';
    if (lower == 'confirmed' || lower == 'accepted') return 'Arriving Soon';
    if (lower == 'arriving' || lower == 'out_for_delivery') return 'Order Picked Up';
    return 'Packing your order';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.primary.withValues(alpha: 0.08))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 92, child: Text(row.$1, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700))),
                    Expanded(child: Text(row.$2, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
