import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';

import '../../theme/app_colors.dart';
import '../services/service_area_gate_controller.dart';
import '../services/service_area_gate_service.dart';

class ServiceAreaGateOverlay extends StatelessWidget {
  const ServiceAreaGateOverlay({super.key, required this.controller});

  final ServiceAreaGateController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final result = controller.blockedResult.value;
      if (result == null) return const SizedBox.shrink();
      return Positioned.fill(
        child: Material(
          color: const Color(0xFF001B42),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _CityBackdropPainter()),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        14.wpx,
                        12.hpx,
                        14.wpx,
                        18.hpx,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 30.hpx,
                        ),
                        child: Column(
                          children: [
                            _TopLocationChip(
                              locationLabel: _locationLabel(result),
                              onTap: () => _showLocationSheet(context),
                            ),
                            SizedBox(height: 24.hpx),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10.wpx),
                              child: Column(
                                children: [
                                  Text(
                                    'HANG',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.white,
                                      fontSize: 46.spx,
                                      height: 0.9,
                                      fontWeight: FontWeight.w900,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  Text(
                                    'TIGHT!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 50.spx,
                                      height: 0.95,
                                      fontWeight: FontWeight.w900,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  Container(
                                    margin: EdgeInsets.only(top: 7.hpx),
                                    width: 148.wpx,
                                    height: 2.hpx,
                                    color: AppColors.accent,
                                  ),
                                  SizedBox(height: 12.hpx),
                                  Text(
                                    result.message.isNotEmpty
                                        ? result.message
                                        : 'We are currently live in select areas and expanding quickly to more neighbourhoods and cities.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.white.withValues(
                                        alpha: 0.84,
                                      ),
                                      fontSize: 12.spx,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4.hpx),
                                  Text(
                                    'Change location to continue if we serve that area.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 13.spx,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 18.hpx),
                            _InfoSteps(reason: result.reason),
                            SizedBox(height: 12.hpx),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10.wpx,
                              runSpacing: 8.hpx,
                              children: [
                                _GateButton(
                                  icon: Icons.edit_location_alt_outlined,
                                  label: 'Change Location',
                                  onPressed: () => _showLocationSheet(context),
                                ),
                                _GateButton(
                                  icon: Icons.my_location_rounded,
                                  label: controller.isChecking.value
                                      ? 'Checking...'
                                      : 'Use Current',
                                  onPressed: controller.isChecking.value
                                      ? null
                                      : controller.checkCurrentLocation,
                                ),
                              ],
                            ),
                            if (controller.statusMessage.value != null) ...[
                              SizedBox(height: 12.hpx),
                              Text(
                                controller.statusMessage.value!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.white.withValues(
                                    alpha: 0.86,
                                  ),
                                  fontSize: 11.spx,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (controller.isChecking.value ||
                  controller.isResolvingLocation.value)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.18),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  String _locationLabel(ServiceAreaGateResult result) {
    final label = result.locationLabel.trim();
    return label.isEmpty ? 'Live location unavailable' : label;
  }

  void _showLocationSheet(BuildContext context) {
    Get.bottomSheet<void>(
      _LocationSheet(controller: controller),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

class _LocationSheet extends StatelessWidget {
  const _LocationSheet({required this.controller});

  final ServiceAreaGateController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        padding: EdgeInsets.fromLTRB(16.wpx, 14.hpx, 16.wpx, 16.hpx),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.rpx)),
        ),
        child: Obx(() {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Change service location',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18.spx,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: Get.back,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              SizedBox(height: 10.hpx),
              TextField(
                controller: controller.addressController,
                onChanged: controller.onAddressChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => controller.submitTypedAddress(),
                decoration: InputDecoration(
                  hintText: 'Search your address',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: controller.isSearching.value
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.rpx),
                  ),
                ),
              ),
              SizedBox(height: 10.hpx),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: controller.isChecking.value
                      ? null
                      : () {
                          Get.back<void>();
                          controller.checkCurrentLocation();
                        },
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('Use current location'),
                ),
              ),
              if (controller.statusMessage.value != null) ...[
                SizedBox(height: 8.hpx),
                Text(
                  controller.statusMessage.value!,
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.spx,
                  ),
                ),
              ],
              SizedBox(height: 8.hpx),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: controller.placeSuggestions.length,
                  separatorBuilder: (_, _) => Divider(color: AppColors.border),
                  itemBuilder: (context, index) {
                    final suggestion = controller.placeSuggestions[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.place_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        suggestion.primaryText.isNotEmpty
                            ? suggestion.primaryText
                            : suggestion.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: suggestion.secondaryText.isEmpty
                          ? null
                          : Text(
                              suggestion.secondaryText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () async {
                        await controller.selectSuggestion(suggestion);
                        if (!controller.isBlocked) Get.back<void>();
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: 10.hpx),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: controller.isResolvingLocation.value
                      ? null
                      : () async {
                          await controller.submitTypedAddress();
                          if (!controller.isBlocked) Get.back<void>();
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    minimumSize: Size.fromHeight(46.hpx),
                  ),
                  child: Text(
                    controller.isResolvingLocation.value
                        ? 'Checking...'
                        : 'Check Service Area',
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _TopLocationChip extends StatelessWidget {
  const _TopLocationChip({required this.locationLabel, required this.onTap});

  final String locationLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12.rpx),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12.wpx,
                  vertical: 10.hpx,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF061E49),
                  borderRadius: BorderRadius.circular(12.rpx),
                  border: Border.all(color: const Color(0xFF12346F)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 31.rpx,
                      height: 31.rpx,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16.rpx),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 8.wpx),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unserviceable area',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 13.spx,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2.hpx),
                          Text(
                            locationLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.82),
                              fontSize: 10.spx,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.accent,
                          size: 18,
                        ),
                        Text(
                          'Change',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 9.spx,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 12.wpx),
        Container(
          width: 38.rpx,
          height: 38.rpx,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accent),
            borderRadius: BorderRadius.circular(20.rpx),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: AppColors.accent,
            size: 20,
          ),
        ),
      ],
    );
  }
}

class _InfoSteps extends StatelessWidget {
  const _InfoSteps({required this.reason});

  final ServiceAreaBlockReason reason;

  @override
  Widget build(BuildContext context) {
    final permissionCopy = reason == ServiceAreaBlockReason.locationUnavailable;
    final items = [
      (
        Icons.location_on_outlined,
        permissionCopy ? 'Location Needed' : 'Expanding Quickly',
        permissionCopy
            ? 'Allow location access or search your address.'
            : 'More areas, more soon!',
      ),
      (
        Icons.map_outlined,
        'Try Another Address',
        'Select a serviced location to enter the app.',
      ),
      (
        Icons.verified_user_outlined,
        'Secure Check',
        'Service opens only after a valid area match.',
      ),
    ];

    return Padding(
      padding: EdgeInsets.only(left: 9.wpx),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.hpx),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36.rpx,
                  height: 36.rpx,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accent),
                    borderRadius: BorderRadius.circular(18.rpx),
                  ),
                  child: Icon(item.$1, color: AppColors.accent, size: 19),
                ),
                SizedBox(width: 10.wpx),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 12.spx,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2.hpx),
                      Text(
                        item.$3,
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.78),
                          fontSize: 10.spx,
                          height: 1.22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GateButton extends StatelessWidget {
  const _GateButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.accent),
        padding: EdgeInsets.symmetric(horizontal: 16.wpx, vertical: 11.hpx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999.rpx),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: TextStyle(fontSize: 12.spx, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _CityBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF123A75).withValues(alpha: 0.22)
      ..strokeWidth = 1;
    for (var y = size.height * 0.72; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 38), gridPaint);
    }
    for (var x = -size.width; x < size.width * 1.5; x += 34) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.width * 0.38, size.height * 0.72),
        gridPaint,
      );
    }

    final buildingPaint = Paint()
      ..color = const Color(0xFF092B61).withValues(alpha: 0.9);
    final litPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.48)
      ..style = PaintingStyle.fill;
    final baseY = size.height * 0.76;
    final widths = [24.0, 34.0, 28.0, 42.0, 24.0, 36.0];
    var x = size.width * 0.52;
    for (var i = 0; i < widths.length; i += 1) {
      final height = (58 + (i % 3) * 28).toDouble();
      final rect = Rect.fromLTWH(x, baseY - height, widths[i], height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        buildingPaint,
      );
      for (var wy = rect.top + 12; wy < rect.bottom - 8; wy += 16) {
        canvas.drawRect(Rect.fromLTWH(x + 7, wy, 3, 6), litPaint);
        if (widths[i] > 30) {
          canvas.drawRect(Rect.fromLTWH(x + 20, wy + 4, 3, 6), litPaint);
        }
      }
      x += widths[i] + 8;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
