import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;

import '../../core/services/location_lookup_service.dart';
import '../../core/utils/phone_dialer.dart';
import '../../data/models/package_order_model.dart';
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
      padding: EdgeInsets.all(7.rpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Color(0x10092774),
            blurRadius: 6,
            offset: Offset(0, 2),
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
          SizedBox(width: 7.wpx),
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
            color: active ? const Color(0xFFEEF4FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(9.rpx),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15.spx,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
              SizedBox(width: 6.wpx),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.spx,
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
              title: 'Pickup Location',
              subtitle:
                  controller.packageOrderType.value == PackageOrderType.receive
                  ? 'Where should we pick up the package from?'
                  : 'Where should we pick up your package?',
              hint: 'Enter pickup location',
              icon: Icons.home_outlined,
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
              title: 'Drop Location',
              subtitle:
                  controller.packageOrderType.value == PackageOrderType.receive
                  ? 'Where should we deliver the package to you?'
                  : 'Where should we deliver your package?',
              hint: 'Enter drop location',
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
            'Choose whether you want to send or receive a package.',
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
            subtitle: 'Send Your Package To Any Location',
            onTap: () => controller.startFlow('send'),
          ),
          SizedBox(height: 12.hpx),
          _FlowOption(
            icon: Icons.download_outlined,
            title: 'Receive Package',
            subtitle: 'Receive A Package At Your Location',
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
          SizedBox(
            width: double.infinity,
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
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
              padding: EdgeInsets.all(18.rpx),
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
                    icon: Icons.home_outlined,
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
                              fontSize: 14.spx,
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
                    margin: EdgeInsets.only(top: 12.hpx),
                    padding: EdgeInsets.only(top: 17.hpx),
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
                                  fontSize: 17.spx,
                                ),
                          ),
                        ),
                        Text(
                          '₹${controller.deliveryCharge.round()}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 24.spx,
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
                padding: EdgeInsets.all(18.rpx),
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
                      width: 22.wpx,
                      height: 22.hpx,
                      margin: EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: controller.agreementChecked.value
                            ? AppColors.primary
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(4.rpx),
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: controller.agreementChecked.value
                          ? Icon(
                              Icons.check,
                              size: 15.spx,
                              color: AppColors.white,
                            )
                          : null,
                    ),
                    SizedBox(width: 12.wpx),
                    Expanded(
                      child: Text(
                        'I declare that this package does not contain any prohibited, illegal, or restricted items including cash, jewellery, liquor, drugs, or hazardous materials.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          fontSize: 15.spx,
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
                  padding: EdgeInsets.symmetric(vertical: 16.hpx),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.rpx),
                  ),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.spx,
                  ),
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
                  padding: EdgeInsets.symmetric(vertical: 16.hpx),
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
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.spx,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _PackageMapPreview extends StatefulWidget {
  const _PackageMapPreview({required this.controller});

  final PackageController controller;

  @override
  State<_PackageMapPreview> createState() => _PackageMapPreviewState();
}

class _PackageMapPreviewState extends State<_PackageMapPreview> {
  maps.GoogleMapController? _mapController;

  @override
  void didUpdateWidget(covariant _PackageMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.pickupLatitude.value !=
            widget.controller.pickupLatitude.value ||
        oldWidget.controller.pickupLongitude.value !=
            widget.controller.pickupLongitude.value ||
        oldWidget.controller.dropLatitude.value !=
            widget.controller.dropLatitude.value ||
        oldWidget.controller.dropLongitude.value !=
            widget.controller.dropLongitude.value) {
      unawaited(_fitRoute());
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickupLat = widget.controller.pickupLatitude.value;
    final pickupLng = widget.controller.pickupLongitude.value;
    final dropLat = widget.controller.dropLatitude.value;
    final dropLng = widget.controller.dropLongitude.value;
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
        child: Stack(
          children: [
            maps.GoogleMap(
              initialCameraPosition: maps.CameraPosition(
                target: center,
                zoom: _zoomForDistance(widget.controller.distanceKm),
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                unawaited(_fitRoute());
              },
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
                  geodesic: true,
                ),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              scrollGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              buildingsEnabled: false,
              indoorViewEnabled: false,
              trafficEnabled: false,
            ),
            Positioned(
              left: 12.wpx,
              top: 12.hpx,
              child: _PackageRoutePill(
                label:
                    '${widget.controller.distanceText} - ${widget.controller.durationText}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fitRoute() async {
    final controller = _mapController;
    if (controller == null) return;

    final pickupLat = widget.controller.pickupLatitude.value;
    final pickupLng = widget.controller.pickupLongitude.value;
    final dropLat = widget.controller.dropLatitude.value;
    final dropLng = widget.controller.dropLongitude.value;
    if (pickupLat == null ||
        pickupLng == null ||
        dropLat == null ||
        dropLng == null) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    await controller.animateCamera(
      maps.CameraUpdate.newLatLngBounds(
        _boundsFor([
          maps.LatLng(pickupLat, pickupLng),
          maps.LatLng(dropLat, dropLng),
        ]),
        52.rpx,
      ),
    );
  }

  maps.LatLngBounds _boundsFor(List<maps.LatLng> points) {
    var south = points.first.latitude;
    var north = points.first.latitude;
    var west = points.first.longitude;
    var east = points.first.longitude;

    for (final point in points.skip(1)) {
      south = min(south, point.latitude);
      north = max(north, point.latitude);
      west = min(west, point.longitude);
      east = max(east, point.longitude);
    }

    if ((north - south).abs() < 0.0001) {
      north += 0.001;
      south -= 0.001;
    }
    if ((east - west).abs() < 0.0001) {
      east += 0.001;
      west -= 0.001;
    }

    return maps.LatLngBounds(
      southwest: maps.LatLng(south, west),
      northeast: maps.LatLng(north, east),
    );
  }

  double _zoomForDistance(double distanceKm) {
    if (distanceKm <= 2) return 13;
    if (distanceKm <= 8) return 11;
    if (distanceKm <= 18) return 10;
    return 9;
  }
}

class _PackageRoutePill extends StatelessWidget {
  const _PackageRoutePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.wpx, vertical: 7.hpx),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999.rpx),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 14.spx,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
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
            padding: EdgeInsets.all(30.rpx),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 60.rpx,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: 20.hpx),
                Text(
                  'No Package Orders',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 10.hpx),
                Text(
                  "You haven't sent any packages yet. Start by creating a new package order.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return ListView.separated(
        padding: EdgeInsets.fromLTRB(10.wpx, 6.hpx, 10.wpx, 120.hpx),
        itemCount: controller.orders.length,
        separatorBuilder: (_, index) => SizedBox(height: 8.hpx),
        itemBuilder: (context, index) {
          final order = controller.orders[index];
          return _PackageOrderListCard(
            order: order,
            onTap: () => controller.openOrder(order),
          );
        },
      );
    });
  }
}

class _PackageOrderListCard extends StatelessWidget {
  const _PackageOrderListCard({required this.order, required this.onTap});

  final PackageOrderModel order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isReceive = order.packageOrderType.trim().toLowerCase() == 'receive';
    final statusColor = _packageListStatusColor(order.status);
    final createdAt = order.createdAt.toLocal().toString().substring(0, 16);
    final partnerPhone = _packagePartnerPhone(order);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9.rpx),
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(vertical: 8.hpx),
            padding: EdgeInsets.fromLTRB(9.wpx, 12.hpx, 9.wpx, 10.hpx),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(9.rpx),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.12),
                width: 0.8,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6.wpx,
                        runSpacing: 4.hpx,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            order.id.isEmpty ? 'Order details' : order.id,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.spx,
                                ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.wpx,
                              vertical: 2.hpx,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF6D8),
                              borderRadius: BorderRadius.circular(999.rpx),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 10.rpx,
                                  color: AppColors.accent,
                                ),
                                SizedBox(width: 3.wpx),
                                Text(
                                  order.packageType.isEmpty
                                      ? 'Package'
                                      : order.packageType,
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.spx,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _displayPackageStatus(order.status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.spx,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.hpx),
                _PackageLocationLine(
                  icon: Icons.location_on_rounded,
                  color: AppColors.success,
                  text:
                      'Pickup: ${order.pickupAddress.isEmpty ? 'N/A' : order.pickupAddress}',
                ),
                SizedBox(height: 5.hpx),
                _PackageLocationLine(
                  icon: Icons.location_on_outlined,
                  color: AppColors.error,
                  text:
                      'Drop: ${order.dropAddress.isEmpty ? 'N/A' : order.dropAddress}',
                ),
                if (order.distanceKm > 0) ...[
                  SizedBox(height: 8.hpx),
                  Text(
                    'Distance: ${order.distanceKm.toStringAsFixed(1)} km',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15.spx,
                    ),
                  ),
                ],
                if (partnerPhone.isNotEmpty) ...[
                  SizedBox(height: 6.hpx),
                  _PackageLocationLine(
                    icon: Icons.phone_rounded,
                    color: AppColors.secondaryBlue,
                    text: 'Delivery Partner: $partnerPhone',
                    onTap: () => PhoneDialer.open(partnerPhone),
                  ),
                ],
                SizedBox(height: 8.hpx),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.dropAddress.isEmpty
                                ? 'N/A'
                                : order.dropAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 15.spx,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          SizedBox(height: 3.hpx),
                          Wrap(
                            spacing: 8.wpx,
                            runSpacing: 4.hpx,
                            children: [
                              Text(
                                createdAt,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontSize: 14.spx),
                              ),
                              if (order.totalPrice > 0)
                                Text(
                                  '₹${order.totalPrice.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15.spx,
                                      ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_circle_right_rounded,
                      color: AppColors.accent,
                      size: 25.rpx,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0.hpx,
          right: 12.wpx,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8.wpx, vertical: 3.hpx),
            decoration: BoxDecoration(
              color: isReceive ? AppColors.secondaryBlue : AppColors.primary,
              borderRadius: BorderRadius.circular(999.rpx),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              isReceive ? 'RECEIVE PACKAGE' : 'SEND PACKAGE',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
                fontSize: 7.5.spx,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PackageLocationLine extends StatelessWidget {
  const _PackageLocationLine({
    required this.icon,
    required this.color,
    required this.text,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final line = Row(
      children: [
        Icon(icon, size: 12.rpx, color: color),
        SizedBox(width: 5.wpx),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 14.spx,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return line;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: line,
    );
  }
}

Color _packageListStatusColor(String status) {
  switch (status.trim().toLowerCase().replaceAll(RegExp(r'[-\s]+'), '_')) {
    case 'available':
    case 'pending':
      return AppColors.success;
    case 'confirmed':
    case 'assigned':
    case 'accepted':
      return AppColors.secondaryBlue;
    case 'picked':
    case 'picked_up':
      return AppColors.accent;
    case 'delivered':
    case 'completed':
      return const Color(0xFF00A8C8);
    case 'cancel':
    case 'canceled':
    case 'cancelled':
      return AppColors.error;
    default:
      return AppColors.textSecondary;
  }
}

String _displayPackageStatus(String status) {
  final normalizedStatus = status.trim().toLowerCase().replaceAll(
    RegExp(r'[-\s]+'),
    '_',
  );
  final normalized = switch (normalizedStatus) {
    'cancel' || 'canceled' || 'cancelled' => 'cancelled',
    _ => normalizedStatus,
  }.replaceAll('_', ' ');
  if (normalized.isEmpty) return 'Pending';
  return normalized
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map(
        (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _packagePartnerPhone(PackageOrderModel order) {
  final partner = _packageMapFrom(order.raw['deliveryPartner']);
  return _firstPackageString([
    partner['phone'],
    partner['contactNumber'],
    partner['mobile'],
    partner['phoneNumber'],
    order.raw['deliveryPartnerPhone'],
    order.raw['deliveryPersonPhone'],
    order.raw['riderPhone'],
    order.raw['driverPhone'],
  ]);
}

Map<String, dynamic> _packageMapFrom(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return const {};
    }
  }
  return const {};
}

String _firstPackageString(List<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text != '{}') return text;
  }
  return '';
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
      padding: EdgeInsets.only(bottom: 14.hpx),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 21.spx),
          SizedBox(width: 12.wpx),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.spx,
                  ),
                ),
                SizedBox(height: 4.hpx),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.spx,
                    height: 1.45,
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
