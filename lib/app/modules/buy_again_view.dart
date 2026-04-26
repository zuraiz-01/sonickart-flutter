import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'cart/controllers/cart_controller.dart';
import 'order_controller.dart';

class BuyAgainView extends GetView<OrderController> {
  BuyAgainView({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();
    return Scaffold(
      backgroundColor: Color(0xFFF5F8FF),
      appBar: AppBar(title: Text('Buy Again'), centerTitle: true),
      body: Obx(() {
        final orders = controller.orders
            .where((order) => order.items.isNotEmpty)
            .toList();
        if (orders.isEmpty) {
          return Center(child: Text('Previous orders will appear here.'));
        }
        return ListView.separated(
          padding: EdgeInsets.all(16.rpx),
          itemCount: orders.length,
          separatorBuilder: (_, __) => SizedBox(height: 12.hpx),
          itemBuilder: (context, index) {
            final order = orders[index];
            return Container(
              padding: EdgeInsets.all(16.rpx),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18.rpx),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.id,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8.hpx),
                  Text(
                    '${order.items.length} items - Rs ${order.totalPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 12.hpx),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: order.items
                        .map(
                          (item) => Chip(
                            label: Text(
                              '${item.product.name} x${item.quantity}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  SizedBox(height: 12.hpx),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        for (final item in order.items) {
                          for (var i = 0; i < item.quantity; i++) {
                            await cart.addItem(item.product);
                          }
                        }
                        Get.toNamed(AppRoutes.checkout);
                      },
                      child: Text('Add all and checkout'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}
