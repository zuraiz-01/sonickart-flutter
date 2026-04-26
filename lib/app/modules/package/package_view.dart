import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';
import 'controllers/package_controller.dart';

class PackageView extends GetView<PackageController> {
  PackageView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        color: Color(0xFFF5F8FF),
        child: Column(
          children: [
            SizedBox(height: 12.hpx),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _TopTabs(
                selectedMode: controller.viewMode.value,
                onSelected: controller.setViewMode,
              ),
            ),
            SizedBox(height: 8.hpx),
            Expanded(
              child: controller.viewMode.value == PackageViewMode.orders
                  ? _OrdersPane(controller: controller)
                  : _SendPane(controller: controller),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopTabs extends StatelessWidget {
  _TopTabs({required this.selectedMode, required this.onSelected});

  final PackageViewMode selectedMode;
  final ValueChanged<PackageViewMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8.rpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Send Package',
            icon: Icons.add_circle_outline_rounded,
            active: selectedMode == PackageViewMode.send,
            onTap: () => onSelected(PackageViewMode.send),
          ),
          SizedBox(width: 8.wpx),
          _TabButton(
            label: 'My Packages',
            icon: Icons.inventory_2_outlined,
            active: selectedMode == PackageViewMode.orders,
            onTap: () => onSelected(PackageViewMode.orders),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  _TabButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.rpx),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.hpx, horizontal: 10.wpx),
          decoration: BoxDecoration(
            color: active ? Color(0xFFEEF4FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(14.rpx),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
              SizedBox(width: 8.wpx),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendPane extends StatelessWidget {
  _SendPane({required this.controller});

  final PackageController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.wpx, 8.hpx, 16.wpx, 24.hpx),
      children: [
        if (controller.currentStep.value == PackageStep.initial)
          _InitialStep(controller: controller),
        if (controller.currentStep.value == PackageStep.pickup)
          _AddressStep(
            title: 'Pickup address',
            subtitle: 'Choose where the rider should collect your package.',
            hint: 'Enter pickup address',
            icon: Icons.store_mall_directory_outlined,
            fieldController: controller.pickupController,
            primaryText: 'Continue',
            onPrimaryTap: controller.continueFromPickup,
            secondaryText: 'Auto detect',
            onSecondaryTap: controller.useAutoDetectedPickup,
            onBackTap: controller.goBackStep,
          ),
        if (controller.currentStep.value == PackageStep.drop)
          _AddressStep(
            title: 'Drop address',
            subtitle: 'Set the destination for this package order.',
            hint: 'Enter drop address',
            icon: Icons.location_on_outlined,
            fieldController: controller.dropController,
            primaryText: 'Continue',
            onPrimaryTap: controller.continueFromDrop,
            secondaryText: 'Use suggested address',
            onSecondaryTap: controller.useSuggestedDrop,
            onBackTap: controller.goBackStep,
          ),
        if (controller.currentStep.value == PackageStep.type)
          _TypeStep(controller: controller),
        if (controller.currentStep.value == PackageStep.review)
          _ReviewStep(controller: controller),
      ],
    );
  }
}

class _InitialStep extends StatelessWidget {
  _InitialStep({required this.controller});

  final PackageController controller;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      child: Column(
        children: [
          Container(
            width: 74.wpx,
            height: 74.hpx,
            decoration: BoxDecoration(
              color: Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(24.rpx),
            ),
            child: Icon(
              Icons.local_shipping_outlined,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 16.hpx),
          Text(
            'Send Package',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.hpx),
          Text(
            'Pickup, drop, package type aur review ke simple flow ke sath booking ready hai.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          SizedBox(height: 20.hpx),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => controller.startFlow('send'),
              icon: Icon(Icons.add_rounded),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.rpx),
                ),
              ),
              label: Text(
                'Start Package Flow',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressStep extends StatelessWidget {
  _AddressStep({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.icon,
    required this.fieldController,
    required this.primaryText,
    required this.onPrimaryTap,
    required this.secondaryText,
    required this.onSecondaryTap,
    required this.onBackTap,
  });

  final String title;
  final String subtitle;
  final String hint;
  final IconData icon;
  final TextEditingController fieldController;
  final String primaryText;
  final VoidCallback onPrimaryTap;
  final String secondaryText;
  final VoidCallback onSecondaryTap;
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackChip(onTap: onBackTap),
          SizedBox(height: 12.hpx),
          Center(
            child: Container(
              width: 74.wpx,
              height: 74.hpx,
              decoration: BoxDecoration(
                color: Color(0xFFEEF4FF),
                borderRadius: BorderRadius.circular(24.rpx),
              ),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
          ),
          SizedBox(height: 18.hpx),
          Center(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(height: 8.hpx),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          SizedBox(height: 20.hpx),
          TextField(
            controller: fieldController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.rpx),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.rpx),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
          SizedBox(height: 12.hpx),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onSecondaryTap,
              icon: Icon(Icons.my_location_rounded),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: Color(0xFFEEF4FF),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.rpx),
                ),
              ),
              label: Text(
                secondaryText,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SizedBox(height: 12.hpx),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimaryTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.rpx),
                ),
              ),
              child: Text(
                primaryText,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeStep extends StatelessWidget {
  _TypeStep({required this.controller});

  final PackageController controller;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackChip(onTap: controller.goBackStep),
          SizedBox(height: 14.hpx),
          Center(
            child: Text(
              'Package Type',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(height: 8.hpx),
          Text(
            'Select what you are sending so the rider flow stays clear.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          SizedBox(height: 20.hpx),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: controller.packageTypes.map((type) {
              final isSelected = controller.selectedPackageType.value == type;
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 56) / 2,
                child: InkWell(
                  onTap: () => controller.selectPackageType(type),
                  borderRadius: BorderRadius.circular(16.rpx),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 20),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Color(0xFFF4F8FF),
                      borderRadius: BorderRadius.circular(16.rpx),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.08),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: isSelected
                              ? AppColors.white
                              : AppColors.primary,
                        ),
                        SizedBox(height: 8.hpx),
                        Text(
                          type,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.white
                                : AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 18.hpx),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: controller.continueFromType,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.rpx),
                ),
              ),
              child: Text(
                'Review Package',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  _ReviewStep({required this.controller});

  final PackageController controller;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackChip(onTap: controller.goBackStep),
          SizedBox(height: 14.hpx),
          Text(
            'Review package order',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 14.hpx),
          _ReviewTile(
            icon: Icons.store_mall_directory_outlined,
            label: 'Pickup',
            value: controller.pickupController.text.trim(),
          ),
          _ReviewTile(
            icon: Icons.location_on_outlined,
            label: 'Drop',
            value: controller.dropController.text.trim(),
          ),
          _ReviewTile(
            icon: Icons.inventory_2_outlined,
            label: 'Package Type',
            value: controller.selectedPackageType.value ?? 'Not selected',
          ),
          SizedBox(height: 16.hpx),
          Container(
            padding: EdgeInsets.all(16.rpx),
            decoration: BoxDecoration(
              color: Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(18.rpx),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                _ChargeRow(
                  label: 'Estimated distance',
                  value: '${controller.distanceKm.toStringAsFixed(1)} km',
                ),
                SizedBox(height: 10.hpx),
                _ChargeRow(
                  label: 'Delivery charge',
                  value: 'Rs ${controller.deliveryCharge.toStringAsFixed(0)}',
                ),
                SizedBox(height: 10.hpx),
                Divider(height: 1, color: AppColors.border),
                SizedBox(height: 10.hpx),
                _ChargeRow(
                  label: 'Grand total',
                  value: 'Rs ${controller.totalPrice.toStringAsFixed(0)}',
                  strong: true,
                ),
              ],
            ),
          ),
          SizedBox(height: 16.hpx),
          InkWell(
            onTap: controller.toggleAgreement,
            borderRadius: BorderRadius.circular(16.rpx),
            child: Container(
              padding: EdgeInsets.all(16.rpx),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16.rpx),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20.wpx,
                    height: 20.hpx,
                    margin: EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: controller.agreementChecked.value
                          ? AppColors.primary
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(4.rpx),
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: controller.agreementChecked.value
                        ? Icon(Icons.check, size: 14, color: AppColors.white)
                        : null,
                  ),
                  SizedBox(width: 12.wpx),
                  Expanded(
                    child: Text(
                      'I confirm the package details are correct and ready for booking.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.hpx),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: controller.submitOrder,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.rpx),
                ),
              ),
              child: controller.isSubmitting.value
                  ? SizedBox(
                      width: 18.wpx,
                      height: 18.hpx,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(
                      'Confirm Package Order',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersPane extends StatelessWidget {
  _OrdersPane({required this.controller});

  final PackageController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingOrders.value && controller.orders.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

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
                    Icons.inventory_2_outlined,
                    size: 42,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 18.hpx),
                Text(
                  'No package orders yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8.hpx),
                Text(
                  'Your booked package deliveries will appear here.',
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
      padding: EdgeInsets.fromLTRB(16.wpx, 8.hpx, 16.wpx, 24.hpx),
      itemCount: controller.orders.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.hpx),
      itemBuilder: (context, index) {
        final order = controller.orders[index];
        return InkWell(
          onTap: () => controller.openOrder(order),
          borderRadius: BorderRadius.circular(20.rpx),
          child: Container(
            padding: EdgeInsets.all(16.rpx),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20.rpx),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.07),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.packageType,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
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
                SizedBox(height: 10.hpx),
                Text(
                  order.id,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12.hpx),
                _MiniInfo(label: 'Pickup', value: order.pickupAddress),
                SizedBox(height: 8.hpx),
                _MiniInfo(label: 'Drop', value: order.dropAddress),
                SizedBox(height: 12.hpx),
                Row(
                  children: [
                    Expanded(
                      child: _StatPill(
                        label: 'Distance',
                        value: '${order.distanceKm.toStringAsFixed(1)} km',
                      ),
                    ),
                    SizedBox(width: 10.wpx),
                    Expanded(
                      child: _StatPill(
                        label: 'Charge',
                        value: 'Rs ${order.totalPrice.toStringAsFixed(0)}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StepCard extends StatelessWidget {
  _StepCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.rpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BackChip extends StatelessWidget {
  _BackChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999.rpx),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 12.wpx, vertical: 8.hpx),
          decoration: BoxDecoration(
            color: Color(0xFFEEF4FF),
            borderRadius: BorderRadius.circular(999.rpx),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chevron_left_rounded, color: AppColors.primary),
              SizedBox(width: 4.wpx),
              Text(
                'Back',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  _ReviewTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          SizedBox(width: 10.wpx),
          Expanded(
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
                    height: 1.4,
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

class _ChargeRow extends StatelessWidget {
  _ChargeRow({required this.label, required this.value, this.strong = false});

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

class _MiniInfo extends StatelessWidget {
  _MiniInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.rpx),
      decoration: BoxDecoration(
        color: Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(14.rpx),
      ),
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
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
