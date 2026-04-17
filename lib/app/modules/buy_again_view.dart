import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'cart/controllers/cart_controller.dart';
import 'order_controller.dart';

class BuyAgainView extends GetView<OrderController> {
  const BuyAgainView({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartController>();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(title: const Text('Buy Again'), centerTitle: true),
      body: Obx(() {
        final orders = controller.orders.where((order) => order.items.isNotEmpty).toList();
        if (orders.isEmpty) {
          return const Center(child: Text('Previous orders will appear here.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = orders[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.primary.withValues(alpha: 0.08))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.id, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('${order.items.length} items - Rs ${order.totalPrice.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: order.items.map((item) => Chip(label: Text('${item.product.name} x${item.quantity}'))).toList(),
                  ),
                  const SizedBox(height: 12),
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
                      child: const Text('Add all and checkout'),
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
