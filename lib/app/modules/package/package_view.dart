import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;

import '../../core/services/location_lookup_service.dart';
import '../../theme/app_colors.dart';
import 'controllers/package_controller.dart';

class PackageView extends GetView<PackageController> {
  const PackageView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        color: Color(0xFFF5F8FF),
        child: Stack(
          children: [
            Column(
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
            if (controller.isMapPickerVisible.value)
              _MapPickerModal(controller: controller),
            if (controller.isDistanceExceededVisible.value)
              _DistanceExceededModal(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _TopTabs extends StatelessWidget {
  const _TopTabs({required this.selectedMode, required this.onSelected});

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
  const _TabButton({
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
  const _SendPane({required this.controller});

  final PackageController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ListView(
        padding: EdgeInsets.fromLTRB(16.wpx, 8.hpx, 16.wpx, 24.hpx),
        children: [
          if (controller.currentStep.value == PackageStep.initial)
            _InitialStep(controller: controller),
          if (controller.currentStep.value == PackageStep.pickup)
            _AddressStep(
              title: 'Pickup address',
              subtitle:
                  controller.packageOrderType.value == PackageOrderType.receive
                  ? 'Where should we pick up the package from?'
                  : 'Where should we pick up your package?',
              hint: 'Enter pickup address',
              icon: Icons.store_mall_directory_outlined,
              fieldController: controller.pickupController,
              onChanged: controller.onPickupChanged,
              suggestions: controller.pickupSuggestions,
              isLoading: controller.isResolvingPickup.value,
              onSuggestionTap: controller.selectPickupSuggestion,
              primaryText: 'Continue',
              onPrimaryTap: controller.continueFromPickup,
              isPrimaryEnabled: controller.canAttemptPickup,
              secondaryText: 'Auto Detect Location',
              onSecondaryTap: controller.useAutoDetectedPickup,
              showSecondary:
                  controller.packageOrderType.value != PackageOrderType.receive,
              onBackTap: controller.goBackStep,
            ),
          if (controller.currentStep.value == PackageStep.drop)
            _AddressStep(
              title: 'Drop address',
              subtitle:
                  controller.packageOrderType.value == PackageOrderType.receive
                  ? 'Where should we deliver the package to you?'
                  : 'Where should we deliver your package?',
              hint: 'Enter drop address',
              icon: Icons.location_on_outlined,
              fieldController: controller.dropController,
              onChanged: controller.onDropChanged,
              suggestions: controller.dropSuggestions,
              isLoading: controller.isResolvingDrop.value,
              onSuggestionTap: controller.selectDropSuggestion,
              primaryText: 'Continue',
              onPrimaryTap: controller.continueFromDrop,
              isPrimaryEnabled: controller.canAttemptDrop,
              secondaryText: 'Auto Detect Location',
              onSecondaryTap: controller.useSuggestedDrop,
              showSecondary:
                  controller.packageOrderType.value == PackageOrderType.receive,
              onBackTap: controller.goBackStep,
            ),
          if (controller.currentStep.value == PackageStep.type)
            _TypeStep(controller: controller),
          if (controller.currentStep.value == PackageStep.review)
            _ReviewStep(controller: controller),
        ],
      ),
    );
  }
}

class _InitialStep extends StatelessWidget {
  const _InitialStep({required this.controller});

  final PackageController controller;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      child: Column(
        children: [
          Text(
            'Package Delivery',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.hpx),
          Text(
            'Send ya receive package flow select karo.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          SizedBox(height: 20.hpx),
          _FlowOption(
            icon: Icons.send_outlined,
            title: 'Send Package',
            subtitle: 'Send your package to any location',
            onTap: () => controller.startFlow('send'),
          ),
          SizedBox(height: 12.hpx),
          _FlowOption(
            icon: Icons.download_outlined,
            title: 'Receive Package',
            subtitle: 'Receive a package at your location',
            onTap: () => controller.startFlow('receive'),
          ),
        ],
      ),
    );
  }
}

class _FlowOption extends StatelessWidget {
  const _FlowOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.rpx),
      decoration: BoxDecoration(
        color: Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(18.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Container(
            width: 68.wpx,
            height: 68.hpx,
            decoration: BoxDecoration(
              color: Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(22.rpx),
            ),
            child: Icon(icon, size: 34, color: AppColors.primary),
          ),
          SizedBox(height: 12.hpx),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4.hpx),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          SizedBox(height: 14.hpx),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.rpx),
                ),
              ),
              child: Text(
                'Get Started',
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
  const _AddressStep({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.icon,
    required this.fieldController,
    required this.onChanged,
    required this.suggestions,
    required this.isLoading,
    required this.onSuggestionTap,
    required this.primaryText,
    required this.onPrimaryTap,
    required this.isPrimaryEnabled,
    required this.secondaryText,
    required this.onSecondaryTap,
    this.showSecondary = true,
    required this.onBackTap,
  });

  final String title;
  final String subtitle;
  final String hint;
  final IconData icon;
  final TextEditingController fieldController;
  final ValueChanged<String> onChanged;
  final List<PlaceSuggestion> suggestions;
  final bool isLoading;
  final ValueChanged<PlaceSuggestion> onSuggestionTap;
  final String primaryText;
  final VoidCallback onPrimaryTap;
  final bool isPrimaryEnabled;
  final String secondaryText;
  final VoidCallback onSecondaryTap;
  final bool showSecondary;
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
            onChanged: onChanged,
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
          if (isLoading) ...[
            SizedBox(height: 10.hpx),
            Row(
              children: [
                SizedBox(
                  width: 16.wpx,
                  height: 16.hpx,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 8.wpx),
                Text(
                  'Resolving location...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (suggestions.isNotEmpty) ...[
            SizedBox(height: 10.hpx),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14.rpx),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                children: suggestions.take(5).map((item) {
                  return InkWell(
                    onTap: () => onSuggestionTap(item),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.wpx,
                        vertical: 12.hpx,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 10.wpx),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.primaryText.isNotEmpty
                                      ? item.primaryText
                                      : item.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (item.secondaryText.isNotEmpty)
                                  Text(
                                    item.secondaryText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          if (showSecondary) ...[
            SizedBox(height: 12.hpx),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onSecondaryTap,
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
          ],
          SizedBox(height: 12.hpx),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading || !isPrimaryEnabled ? null : onPrimaryTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.45,
                ),
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
  const _TypeStep({required this.controller});

  final PackageController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
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
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 260.wpx),
                child: Text(
                  "Select the type of package you're sending",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.hpx),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final itemWidth = (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: 15.hpx,
                  children: controller.packageTypes.map((type) {
                    final isSelected =
                        controller.selectedPackageType.value == type;
                    return SizedBox(
                      width: itemWidth,
                      height: 88.hpx,
                      child: InkWell(
                        onTap: () => controller.selectPackageType(type),
                        borderRadius: BorderRadius.circular(16.rpx),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.wpx,
                            vertical: 14.hpx,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : Color(0xFFF4F8FF),
                            borderRadius: BorderRadius.circular(16.rpx),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.1),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _packageTypeIcon(type),
                                size: 28,
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.primary,
                              ),
                              SizedBox(height: 8.hpx),
                              Flexible(
                                child: Text(
                                  type,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.white
                                        : AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            SizedBox(height: 18.hpx),
            Center(
              child: Text(
                'Please ensure items are suitable for safe delivery.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 20.hpx),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: controller.canMoveFromType
                    ? controller.continueFromType
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.45,
                  ),
                  foregroundColor: AppColors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.rpx),
                  ),
                ),
                child: Text(
                  'Next',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  IconData _packageTypeIcon(String type) {
    final normalized = type.trim().toLowerCase();
    if (normalized.contains('document')) return Icons.description_outlined;
    if (normalized.contains('food') ||
        normalized.contains('grocery') ||
        normalized.contains('grocer')) {
      return Icons.restaurant_outlined;
    }
    if (normalized.contains('medicine') ||
        normalized.contains('medical') ||
        normalized.contains('pharma')) {
      return Icons.medical_services_outlined;
    }
    return Icons.inventory_2_outlined;
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.controller});

  final PackageController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return _StepCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BackChip(onTap: controller.goBackStep),
            SizedBox(height: 14.hpx),
            Text(
              'Review & Confirm',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 14.hpx),
            _PackageMapPreview(controller: controller),
            SizedBox(height: 20.hpx),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReviewTile(
                    icon:
                        controller.packageOrderType.value ==
                            PackageOrderType.receive
                        ? Icons.download_outlined
                        : Icons.send_outlined,
                    label: 'Order Type',
                    value:
                        controller.packageOrderType.value ==
                            PackageOrderType.receive
                        ? 'Receive Package'
                        : 'Send Package',
                  ),
                  _ReviewTile(
                    icon: Icons.store_mall_directory_outlined,
                    label: 'Pickup',
                    value: controller.pickupController.text.trim(),
                  ),
                  _ReviewTile(
                    icon: Icons.location_on,
                    label: 'Drop',
                    value: controller.dropController.text.trim(),
                  ),
                  _ReviewTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Package Type',
                    value:
                        controller.selectedPackageType.value ?? 'Not selected',
                  ),
                  if (controller.isCalculatingRoute.value)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 15.hpx),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18.wpx,
                            height: 18.hpx,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 10.wpx),
                          Text(
                            'Calculating route...',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (controller.distanceKm > 0) ...[
                    _ReviewTile(
                      icon: Icons.navigation_outlined,
                      label: 'Distance',
                      value: controller.distanceText,
                    ),
                    _ReviewTile(
                      icon: Icons.access_time_rounded,
                      label: 'Estimated Time',
                      value: controller.durationText,
                    ),
                  ],
                  Container(
                    margin: EdgeInsets.only(top: 10.hpx),
                    padding: EdgeInsets.only(top: 15.hpx),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFD9E6FF))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Delivery Charge',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        Text(
                          'Rs ${controller.deliveryCharge.round()}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.hpx),
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
                        'I declare that this package does not contain any prohibited, illegal, or restricted items including cash, jewellery, liquor, drugs, or hazardous materials.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          height: 1.45,
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
              child: OutlinedButton(
                onPressed: controller.goBackStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.white,
                  backgroundColor: AppColors.textSecondary,
                  padding: EdgeInsets.symmetric(vertical: 14.hpx),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.rpx),
                  ),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            SizedBox(height: 10.hpx),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    controller.distanceKm > 0 &&
                        !controller.isCalculatingRoute.value &&
                        !controller.isSubmitting.value &&
                        controller.agreementChecked.value
                    ? controller.submitOrder
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.45,
                  ),
                  foregroundColor: AppColors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.hpx),
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
                        controller.packageOrderType.value ==
                                PackageOrderType.receive
                            ? 'Confirm & Receive'
                            : 'Confirm & Send',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _PackageMapPreview extends StatelessWidget {
  const _PackageMapPreview({required this.controller});

  final PackageController controller;

  @override
  Widget build(BuildContext context) {
    final pickupLat = controller.pickupLatitude.value;
    final pickupLng = controller.pickupLongitude.value;
    final dropLat = controller.dropLatitude.value;
    final dropLng = controller.dropLongitude.value;
    if (pickupLat == null ||
        pickupLng == null ||
        dropLat == null ||
        dropLng == null) {
      return SizedBox.shrink();
    }

    final pickup = maps.LatLng(pickupLat, pickupLng);
    final drop = maps.LatLng(dropLat, dropLng);
    final center = maps.LatLng(
      (pickup.latitude + drop.latitude) / 2,
      (pickup.longitude + drop.longitude) / 2,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18.rpx),
      child: SizedBox(
        height: 250.hpx,
        child: maps.GoogleMap(
          initialCameraPosition: maps.CameraPosition(
            target: center,
            zoom: _zoomForDistance(controller.distanceKm),
          ),
          markers: {
            maps.Marker(
              markerId: maps.MarkerId('pickup'),
              position: pickup,
              infoWindow: maps.InfoWindow(title: 'Pickup Location'),
              icon: maps.BitmapDescriptor.defaultMarkerWithHue(
                maps.BitmapDescriptor.hueYellow,
              ),
            ),
            maps.Marker(
              markerId: maps.MarkerId('drop'),
              position: drop,
              infoWindow: maps.InfoWindow(title: 'Drop Location'),
              icon: maps.BitmapDescriptor.defaultMarkerWithHue(
                maps.BitmapDescriptor.hueAzure,
              ),
            ),
          },
          polylines: {
            maps.Polyline(
              polylineId: maps.PolylineId('package-route'),
              points: [pickup, drop],
              width: 4,
              color: AppColors.primary,
            ),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          scrollGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
        ),
      ),
    );
  }

  double _zoomForDistance(double distanceKm) {
    if (distanceKm <= 2) return 13;
    if (distanceKm <= 8) return 11;
    if (distanceKm <= 18) return 10;
    return 9;
  }
}

class _MapPickerModal extends StatelessWidget {
  const _MapPickerModal({required this.controller});

  final PackageController controller;

  @override
  Widget build(BuildContext context) {
    final latitude = controller.mapDraftLatitude.value;
    final longitude = controller.mapDraftLongitude.value;
    final hasCoordinate = latitude != null && longitude != null;
    final screenSize = MediaQuery.of(context).size;
    final maxModalHeight = max(320.0, screenSize.height - 52.hpx);
    final mapHeight = max(170.0, min(260.hpx, screenSize.height * 0.38));

    return Positioned.fill(
      child: Material(
        color: Color(0x59092774),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxModalHeight),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 18.wpx),
              padding: EdgeInsets.all(16.rpx),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20.rpx),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            controller.mapPickerTitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        InkWell(
                          onTap: controller.closeMapPicker,
                          borderRadius: BorderRadius.circular(18.rpx),
                          child: Container(
                            width: 36.wpx,
                            height: 36.hpx,
                            decoration: BoxDecoration(
                              color: Color(0xFFEEF4FF),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.hpx),
                    Text(
                      controller.mapDraftAddress.value.isNotEmpty
                          ? controller.mapDraftAddress.value
                          : controller.mapPickerFallbackText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12.hpx),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16.rpx),
                      child: Container(
                        height: mapHeight,
                        decoration: BoxDecoration(
                          color: Color(0xFFF4F8FF),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: hasCoordinate
                            ? Stack(
                                children: [
                                  maps.GoogleMap(
                                    key: ValueKey('$latitude-$longitude'),
                                    initialCameraPosition: maps.CameraPosition(
                                      target: maps.LatLng(latitude, longitude),
                                      zoom: 16,
                                    ),
                                    onCameraMove: (position) {
                                      controller.onMapCameraMove(
                                        position.target.latitude,
                                        position.target.longitude,
                                      );
                                    },
                                    myLocationEnabled: true,
                                    myLocationButtonEnabled: false,
                                    zoomControlsEnabled: false,
                                    mapToolbarEnabled: false,
                                  ),
                                  Center(
                                    child: Transform.translate(
                                      offset: Offset(0, -20.hpx),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 36.wpx,
                                            height: 36.hpx,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.white,
                                                width: 4,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Color(0x40000000),
                                                  blurRadius: 6,
                                                  offset: Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Container(
                                                width: 12.wpx,
                                                height: 12.hpx,
                                                decoration: BoxDecoration(
                                                  color: AppColors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Transform.translate(
                                            offset: Offset(0, -6.hpx),
                                            child: Container(
                                              width: 6.wpx,
                                              height: 22.hpx,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                      bottom: Radius.circular(
                                                        3.rpx,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 14.hpx),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed:
                            hasCoordinate && !controller.isMapConfirming.value
                            ? controller.confirmMapLocation
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          padding: EdgeInsets.symmetric(vertical: 12.hpx),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.rpx),
                          ),
                        ),
                        child: controller.isMapConfirming.value
                            ? SizedBox(
                                width: 18.wpx,
                                height: 18.hpx,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : Text(
                                'Set Location',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DistanceExceededModal extends StatelessWidget {
  const _DistanceExceededModal({required this.controller});

  final PackageController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Color(0x80000000),
        child: Center(
          child: Container(
            width: min(MediaQuery.of(context).size.width * 0.8, 320.wpx),
            padding: EdgeInsets.all(24.rpx),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16.rpx),
              boxShadow: [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.wpx,
                    vertical: 20.hpx,
                  ),
                  decoration: BoxDecoration(color: AppColors.primary),
                  child: Column(
                    children: [
                      Container(
                        width: 64.wpx,
                        height: 64.hpx,
                        decoration: BoxDecoration(
                          color: Color(0xFF38BDF8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_off,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 10.hpx),
                      Text(
                        'Delivery Range Exceeded',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.hpx),
                Text(
                  'The delivery distance of ${controller.exceedingDistanceKm.value.toStringAsFixed(1)} km exceeds our maximum delivery range of ${controller.maxPackageDistanceKm.toStringAsFixed(0)} km.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 8.hpx),
                Text(
                  'Please choose locations within our delivery area.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 8.hpx),
                Text(
                  'Delivery available only within ${controller.maxPackageDistanceKm.toStringAsFixed(0)}km',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 20.hpx),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: controller.closeDistanceExceededModal,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: EdgeInsets.symmetric(vertical: 13.hpx),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.rpx),
                      ),
                    ),
                    child: Text(
                      'OK, Got it',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrdersPane extends StatelessWidget {
  const _OrdersPane({required this.controller});

  final PackageController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingOrders.value && controller.orders.isEmpty) {
        return Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
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
        separatorBuilder: (_, index) => SizedBox(height: 12.hpx),
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
    });
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.child});

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
  const _BackChip({required this.onTap});

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
  const _ReviewTile({
    required this.icon,
    required this.label,
    required this.value,
  });

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

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.label, required this.value});

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
  const _StatPill({required this.label, required this.value});

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
