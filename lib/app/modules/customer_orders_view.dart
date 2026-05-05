import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../data/models/order_model.dart';
import '../theme/app_colors.dart';
import 'order_controller.dart';

class CustomerOrdersView extends GetView<OrderController> {
  const CustomerOrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F8FF),
      appBar: AppBar(title: Text('My Orders'), centerTitle: true),
      body: Obx(() {
        if (controller.orders.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.rpx),
              child: Container(
                padding: EdgeInsets.all(28.rpx),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24.rpx),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 86.wpx,
                      height: 86.hpx,
                      decoration: BoxDecoration(
                        color: Color(0xFFEEF4FF),
                        borderRadius: BorderRadius.circular(28.rpx),
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        size: 42,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 18.hpx),
                    Text(
                      'No orders yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8.hpx),
                    Text(
                      'Your confirmed and delivered orders will appear here.',
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

        return ListView.separated(
          padding: EdgeInsets.all(16.rpx),
          itemCount: controller.orders.length,
          separatorBuilder: (context, index) => SizedBox(height: 12.hpx),
          itemBuilder: (context, index) {
            final order = controller.orders[index];
            return _OrderCard(
              order: order,
              onTap: () => controller.openOrder(order),
            );
          },
        );
      }),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final OrderModel order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final itemCount = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final displayItemCount = itemCount > 0
        ? itemCount
        : order.resolvedItemCount;
    final statusMeta = _OrderStatusMeta.fromOrder(order);
    final inactive = order.isInactive;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24.rpx),
      child: Container(
        padding: EdgeInsets.all(16.rpx),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24.rpx),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
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
                        'Order ID',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.hpx),
                      Text(
                        '#${order.id}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusMeta.backgroundColor,
                    borderRadius: BorderRadius.circular(14.rpx),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusMeta.icon, size: 15, color: statusMeta.color),
                      SizedBox(width: 6.wpx),
                      Text(
                        statusMeta.label,
                        style: TextStyle(
                          color: statusMeta.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.hpx),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoPill(
                  icon: Icons.shopping_basket_outlined,
                  label: displayItemCount > 0
                      ? '$displayItemCount item${displayItemCount == 1 ? '' : 's'}'
                      : 'Items unavailable',
                ),
                _InfoPill(
                  icon: Icons.calendar_month_outlined,
                  label: order.createdAt.toLocal().toString().substring(0, 16),
                ),
              ],
            ),
            SizedBox(height: 14.hpx),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 14.wpx,
                vertical: 12.hpx,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(18.rpx),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _previewLines(order).map((line) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 16.hpx),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Paid',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.hpx),
                      Text(
                        '₹${order.totalPrice.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      inactive ? 'View details' : 'Track order',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4.wpx),
                    Icon(
                      Icons.arrow_right_alt_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<String> _previewLines(OrderModel order) {
    if (order.items.isEmpty) {
      return const ['Items will appear when order details sync.'];
    }
    return order.items.take(3).map((item) {
      final quantity = item.quantity > 0 ? item.quantity : 1;
      final name = item.product.name.trim().isEmpty
          ? 'Item'
          : item.product.name;
      return '$quantity x $name';
    }).toList();
  }
}

class _OrderStatusMeta {
  const _OrderStatusMeta({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color color;

  factory _OrderStatusMeta.fromOrder(OrderModel order) {
    final status =
        (order.raw['deliveryStatus'] ??
                order.raw['delivery_status'] ??
                order.status)
            .toString()
            .trim()
            .toLowerCase();

    if (status == 'delivered' || status == 'completed') {
      return _OrderStatusMeta(
        label: 'Delivered',
        icon: Icons.verified_rounded,
        backgroundColor: const Color(0xFFEAF8EF),
        color: AppColors.success,
      );
    }

    if (status == 'cancelled' || status == 'canceled') {
      return _OrderStatusMeta(
        label: 'Cancelled',
        icon: Icons.cancel_rounded,
        backgroundColor: const Color(0xFFFDECEC),
        color: AppColors.error,
      );
    }

    if (status == 'confirmed' || status == 'assigned' || status == 'accepted') {
      return _OrderStatusMeta(
        label: 'In Progress',
        icon: Icons.local_shipping_outlined,
        backgroundColor: const Color(0xFFEAF1FF),
        color: AppColors.primary,
      );
    }

    if (status == 'picked' ||
        status == 'arriving' ||
        status == 'out_for_delivery') {
      return _OrderStatusMeta(
        label: 'On the way',
        icon: Icons.delivery_dining_rounded,
        backgroundColor: const Color(0xFFEAF1FF),
        color: AppColors.primary,
      );
    }

    return _OrderStatusMeta(
      label: 'Preparing',
      icon: Icons.schedule_rounded,
      backgroundColor: const Color(0xFFFFF5DE),
      color: const Color(0xFFD18A00),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.wpx, vertical: 8.hpx),
      decoration: BoxDecoration(
        color: Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(14.rpx),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          SizedBox(width: 6.wpx),
          Text(
            label,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
