import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';

import '../../core/services/notification_service.dart';
import '../../theme/app_colors.dart';

class NotificationsView extends GetView<NotificationService> {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        actions: [
          Obx(
            () => TextButton(
              onPressed: controller.notifications.isEmpty
                  ? null
                  : controller.clearAll,
              child: const Text('Clear'),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final items = controller.notifications;
        if (items.isEmpty) {
          return const _EmptyNotifications();
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(16.wpx, 14.hpx, 16.wpx, 24.hpx),
          itemBuilder: (context, index) {
            return _NotificationTile(notification: items[index]);
          },
          separatorBuilder: (_, _) => SizedBox(height: 10.hpx),
          itemCount: items.length,
        );
      }),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final meta = _NotificationVisual.fromCategory(notification.category);
    return Container(
      padding: EdgeInsets.all(14.rpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42.rpx,
            height: 42.rpx,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.rpx),
            ),
            child: Icon(meta.icon, color: meta.color, size: 22),
          ),
          SizedBox(width: 12.wpx),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14.spx,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.spx,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 5.hpx),
                Text(
                  notification.message,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.spx,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}/${time.year}';
  }
}

class _NotificationVisual {
  const _NotificationVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  factory _NotificationVisual.fromCategory(String category) {
    return switch (category) {
      'address' => const _NotificationVisual(
        icon: Icons.location_on_rounded,
        color: AppColors.secondaryBlue,
      ),
      'cart' => const _NotificationVisual(
        icon: Icons.shopping_cart_rounded,
        color: AppColors.primary,
      ),
      'order' => const _NotificationVisual(
        icon: Icons.receipt_long_rounded,
        color: AppColors.success,
      ),
      'package' => const _NotificationVisual(
        icon: Icons.local_shipping_rounded,
        color: Color(0xFF8754D1),
      ),
      'profile' => const _NotificationVisual(
        icon: Icons.person_rounded,
        color: Color(0xFF0B8F86),
      ),
      _ => const _NotificationVisual(
        icon: Icons.notifications_rounded,
        color: AppColors.primary,
      ),
    };
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.rpx),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86.rpx,
              height: 86.rpx,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24.rpx),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.primary,
                size: 42,
              ),
            ),
            SizedBox(height: 16.hpx),
            Text(
              'No notifications yet',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18.spx,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6.hpx),
            Text(
              'Your cart, address, order, package and profile updates will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.spx,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
