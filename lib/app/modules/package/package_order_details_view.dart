import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/package_socket_service.dart';
import '../../data/models/package_order_model.dart';
import '../../theme/app_colors.dart';
import 'controllers/package_controller.dart';

class PackageOrderDetailsView extends StatefulWidget {
  const PackageOrderDetailsView({super.key});

  @override
  State<PackageOrderDetailsView> createState() =>
      _PackageOrderDetailsViewState();
}

class _PackageOrderDetailsViewState extends State<PackageOrderDetailsView> {
  late final PackageController controller = Get.find<PackageController>();
  late final PackageSocketService? socketService =
      Get.isRegistered<PackageSocketService>()
      ? Get.find<PackageSocketService>()
      : null;
  late final String orderId = Get.arguments?['orderId']?.toString() ?? '';
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (orderId.trim().isNotEmpty) {
        socketService?.connectToOrder(controller, orderId);
      }
      unawaited(_refreshOrder());
    });
  }

  @override
  void dispose() {
    socketService?.disconnect();
    super.dispose();
  }

  Future<void> _refreshOrder() async {
    if (_refreshing || orderId.trim().isEmpty) return;
    setState(() => _refreshing = true);
    try {
      await controller.refreshOrderDetails(orderId);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text('Package Order'),
        centerTitle: true,
        actions: [
          _refreshing
              ? Padding(
                  padding: EdgeInsets.only(right: 16.wpx),
                  child: SizedBox(
                    width: 18.rpx,
                    height: 18.rpx,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : IconButton(
                  onPressed: _refreshOrder,
                  icon: const Icon(Icons.refresh_rounded),
                ),
        ],
      ),
      body: Obx(() {
        final PackageOrderModel? order =
            controller.findOrderById(orderId) ?? controller.selectedOrder.value;
        return order == null
            ? Center(
                child: Text(
                  'Package order not found.',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _refreshOrder,
                color: AppColors.primary,
                child: ListView(
                  padding: EdgeInsets.all(16.rpx),
                  children: [
                    _PackageSummaryCard(order: order),
                    SizedBox(height: 16.hpx),
                    _PackagePartnerCard(order: order),
                    SizedBox(height: 16.hpx),
                    _PackageLiveMapCard(order: order),
                    SizedBox(height: 16.hpx),
                    _PackageBillCard(order: order),
                    if (!_isTerminal(order.status)) ...[
                      SizedBox(height: 16.hpx),
                      FilledButton.icon(
                        onPressed: () => _confirmCancel(order),
                        icon: const Icon(Icons.cancel_outlined),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(vertical: 14.hpx),
                        ),
                        label: const Text(
                          'Cancel Package',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
              );
      }),
    );
  }

  void _confirmCancel(PackageOrderModel order) {
    Get.dialog(
      AlertDialog(
        title: const Text('Cancel package?'),
        content: const Text(
          'Are you sure you want to cancel this package order?',
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('No')),
          FilledButton(
            onPressed: () {
              Get.back();
              controller.cancelPackageOrder(order);
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}

class _PackageSummaryCard extends StatelessWidget {
  const _PackageSummaryCard({required this.order});

  final PackageOrderModel order;

  @override
  Widget build(BuildContext context) {
    final status = _normalizedStatus(order.status);
    return _CardShell(
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
                      'Packing your package order',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.hpx),
                    Text(
                      'Order #${order.id}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12.wpx,
                  vertical: 8.hpx,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(status),
                  borderRadius: BorderRadius.circular(999.rpx),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.hpx),
          Row(
            children: [
              _MetaChip(
                icon: Icons.inventory_2_outlined,
                label: order.packageType.isEmpty
                    ? 'Package'
                    : order.packageType,
              ),
              SizedBox(width: 10.wpx),
              _MetaChip(
                icon: Icons.swap_horiz_rounded,
                label: order.packageOrderType == 'receive'
                    ? 'Receive Package'
                    : 'Send Package',
              ),
            ],
          ),
          SizedBox(height: 16.hpx),
          _LocationRow(
            icon: Icons.location_on_rounded,
            color: AppColors.success,
            label: 'Pickup',
            value: order.pickupAddress.isNotEmpty ? order.pickupAddress : 'N/A',
          ),
          SizedBox(height: 12.hpx),
          _LocationRow(
            icon: Icons.flag_rounded,
            color: AppColors.error,
            label: 'Drop',
            value: order.dropAddress.isNotEmpty ? order.dropAddress : 'N/A',
          ),
          SizedBox(height: 12.hpx),
          _DetailRow(
            label: 'Booked At',
            value: order.createdAt.toLocal().toString().substring(0, 16),
          ),
        ],
      ),
    );
  }
}

class _PackagePartnerCard extends StatelessWidget {
  const _PackagePartnerCard({required this.order});

  final PackageOrderModel order;

  @override
  Widget build(BuildContext context) {
    final status = _normalizedStatus(order.status);
    if (!_hasAssignedPartner(order, status)) return const SizedBox.shrink();

    final partner = _mapFrom(order.raw['deliveryPartner']);
    final name = _firstString([
      partner['name'],
      partner['fullName'],
      partner['firstName'],
      partner['lastName'],
      order.raw['deliveryPartnerName'],
      order.raw['deliveryPersonName'],
      order.raw['riderName'],
      order.raw['driverName'],
    ]);
    final phone = _firstString([
      partner['phone'],
      partner['contactNumber'],
      partner['mobile'],
      partner['phoneNumber'],
      order.raw['deliveryPartnerPhone'],
      order.raw['deliveryPersonPhone'],
      order.raw['riderPhone'],
      order.raw['driverPhone'],
    ]);

    if (name.isEmpty && phone.isEmpty) return const SizedBox.shrink();

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent_rounded, color: AppColors.primary),
              SizedBox(width: 10.wpx),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Partner',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _hasPickedUp(status) ? 'Package picked up' : 'On the way',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (name.isNotEmpty) ...[
            SizedBox(height: 12.hpx),
            _InfoLine(icon: Icons.person_outline_rounded, value: name),
          ],
          if (phone.isNotEmpty) ...[
            SizedBox(height: 10.hpx),
            InkWell(
              onTap: () => _callPartner(phone),
              borderRadius: BorderRadius.circular(8.rpx),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.hpx),
                child: _InfoLine(
                  icon: Icons.phone_rounded,
                  value: phone,
                  valueColor: AppColors.secondaryBlue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PackageLiveMapCard extends StatefulWidget {
  const _PackageLiveMapCard({required this.order});

  final PackageOrderModel order;

  @override
  State<_PackageLiveMapCard> createState() => _PackageLiveMapCardState();
}

class _PackageLiveMapCardState extends State<_PackageLiveMapCard> {
  GoogleMapController? _mapController;

  @override
  void didUpdateWidget(covariant _PackageLiveMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.raw != widget.order.raw ||
        oldWidget.order.status != widget.order.status) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _PackageTrackingMapData.fromOrder(widget.order);
    final etaText = data.liveEtaMinutes == null
        ? widget.order.durationText
        : '${data.liveEtaMinutes} min';
    final distanceText = data.liveDistanceKm == null
        ? widget.order.distanceText
        : '${data.liveDistanceKm!.toStringAsFixed(1)} km away';

    return _CardShell(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SizedBox(
            height: 285.hpx,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18.rpx)),
              child: data.points.isEmpty
                  ? _MapFallback(
                      etaLabel: etaText.isEmpty ? 'Tracking' : etaText,
                    )
                  : Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: data.initialTarget,
                            zoom: 14,
                          ),
                          markers: data.markers,
                          polylines: data.polylines,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          compassEnabled: false,
                          mapToolbarEnabled: false,
                          onMapCreated: (controller) {
                            _mapController = controller;
                            _fitBounds();
                          },
                        ),
                        Positioned(
                          top: 12.hpx,
                          left: 12.wpx,
                          child: _MapStatusPill(
                            label: etaText.isEmpty ? 'Live tracking' : etaText,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.rpx),
            child: Row(
              children: [
                Icon(Icons.route_rounded, color: AppColors.primary),
                SizedBox(width: 10.wpx),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _trackingLabel(_normalizedStatus(widget.order.status)),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      SizedBox(height: 3.hpx),
                      Text(
                        distanceText.isEmpty
                            ? 'Tracking updates will appear here.'
                            : distanceText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
        ],
      ),
    );
  }

  Future<void> _fitBounds() async {
    final controller = _mapController;
    if (controller == null) return;
    final data = _PackageTrackingMapData.fromOrder(widget.order);
    final points = data.focusPoints;
    if (points.length < 2) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(_boundsFor(points), 56.rpx),
    );
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }
    if (minLat == maxLat) {
      minLat -= 0.005;
      maxLat += 0.005;
    }
    if (minLng == maxLng) {
      minLng -= 0.005;
      maxLng += 0.005;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}

class _PackageBillCard extends StatelessWidget {
  const _PackageBillCard({required this.order});

  final PackageOrderModel order;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 14.hpx),
          _BillRow(
            label: 'Distance',
            value: order.distanceText.isNotEmpty
                ? order.distanceText
                : '${order.distanceKm.toStringAsFixed(1)} km',
          ),
          if (order.durationText.isNotEmpty) ...[
            SizedBox(height: 10.hpx),
            _BillRow(label: 'Estimated Time', value: order.durationText),
          ],
          SizedBox(height: 10.hpx),
          _BillRow(
            label: 'Delivery Charge',
            value: 'Rs ${order.deliveryCharge.round()}',
          ),
          SizedBox(height: 10.hpx),
          Divider(height: 1, color: AppColors.border),
          SizedBox(height: 10.hpx),
          _BillRow(
            label: 'Grand Total',
            value: 'Rs ${order.totalPrice.round()}',
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.all(16.rpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.wpx, vertical: 9.hpx),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF4FF),
          borderRadius: BorderRadius.circular(12.rpx),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18.rpx, color: AppColors.primary),
            SizedBox(width: 7.wpx),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.spx,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19.rpx, color: color),
        SizedBox(width: 10.wpx),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3.hpx),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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
        SizedBox(height: 4.hpx),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.value,
    this.valueColor = AppColors.primary,
  });

  final IconData icon;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17.rpx, color: AppColors.textSecondary),
        SizedBox(width: 8.wpx),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w700,
              fontSize: 14.spx,
            ),
          ),
        ),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

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

class _MapStatusPill extends StatelessWidget {
  const _MapStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.wpx, vertical: 7.hpx),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 16.rpx, color: AppColors.accent),
            SizedBox(width: 6.wpx),
            Text(
              label,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12.spx,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapFallback extends StatelessWidget {
  const _MapFallback({required this.etaLabel});

  final String etaLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEEF4FF),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 66.rpx, color: AppColors.primary),
          SizedBox(height: 10.hpx),
          Text(
            etaLabel,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 16.spx,
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageTrackingMapData {
  const _PackageTrackingMapData({
    required this.dropLocation,
    required this.pickupLocation,
    required this.deliveryPersonLocation,
    required this.hasAssigned,
    required this.hasPickedUp,
  });

  final LatLng? dropLocation;
  final LatLng? pickupLocation;
  final LatLng? deliveryPersonLocation;
  final bool hasAssigned;
  final bool hasPickedUp;

  factory _PackageTrackingMapData.fromOrder(PackageOrderModel order) {
    final raw = order.raw;
    final partner = _mapFrom(raw['deliveryPartner']);
    final status = _normalizedStatus(order.status);
    return _PackageTrackingMapData(
      dropLocation:
          _coordinateFrom(raw['dropLocation']) ??
          _coordinateFrom(raw['deliveryLocation']) ??
          _coordinateFrom({
            'latitude': order.dropLatitude,
            'longitude': order.dropLongitude,
          }),
      pickupLocation:
          _coordinateFrom(raw['pickupLocation']) ??
          _coordinateFrom({
            'latitude': order.pickupLatitude,
            'longitude': order.pickupLongitude,
          }),
      deliveryPersonLocation:
          _coordinateFrom(raw['deliveryPersonLocation']) ??
          _coordinateFrom(partner['liveLocation']) ??
          _coordinateFrom(raw['riderLocation']) ??
          _coordinateFrom(raw['driverLocation']) ??
          _coordinateFrom(raw['partnerLocation']) ??
          _coordinateFrom(raw['liveLocation']),
      hasAssigned: _hasAssignedPartner(order, status),
      hasPickedUp: _hasPickedUp(status),
    );
  }

  List<LatLng> get points => [
    dropLocation,
    pickupLocation,
    deliveryPersonLocation,
  ].whereType<LatLng>().toList();

  List<LatLng> get focusPoints {
    final route = [
      deliveryPersonLocation,
      hasPickedUp ? dropLocation : pickupLocation,
    ].whereType<LatLng>().toList();
    return route.length >= 2 ? route : points;
  }

  LatLng get initialTarget =>
      deliveryPersonLocation ?? pickupLocation ?? dropLocation!;

  LatLng? get routeTarget {
    if (!hasAssigned) return null;
    return hasPickedUp ? dropLocation : pickupLocation;
  }

  double? get liveDistanceKm {
    final origin = deliveryPersonLocation;
    final target = routeTarget;
    if (origin == null || target == null) return null;
    return _distanceKm(origin, target);
  }

  int? get liveEtaMinutes {
    final distance = liveDistanceKm;
    if (distance == null) return null;
    return max(1, ((distance / 25) * 60).round());
  }

  Set<Marker> get markers {
    return {
      if (pickupLocation != null)
        Marker(
          markerId: const MarkerId('pickupLocation'),
          position: pickupLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      if (dropLocation != null)
        Marker(
          markerId: const MarkerId('dropLocation'),
          position: dropLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: const InfoWindow(title: 'Drop'),
        ),
      if (deliveryPersonLocation != null)
        Marker(
          markerId: const MarkerId('deliveryPartner'),
          position: deliveryPersonLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'Delivery partner'),
        ),
    };
  }

  Set<Polyline> get polylines {
    final lines = <Polyline>{};
    final target = routeTarget;
    if (deliveryPersonLocation != null && target != null) {
      lines.add(
        Polyline(
          polylineId: const PolylineId('partnerRoute'),
          points: [deliveryPersonLocation!, target],
          color: AppColors.secondaryBlue,
          width: 5,
          geodesic: true,
        ),
      );
    }
    if (!hasPickedUp && pickupLocation != null && dropLocation != null) {
      lines.add(
        Polyline(
          polylineId: const PolylineId('pickupToDrop'),
          points: [pickupLocation!, dropLocation!],
          color: AppColors.textSecondary,
          width: 2,
          geodesic: true,
          patterns: [PatternItem.dash(12), PatternItem.gap(10)],
        ),
      );
    }
    return lines;
  }

  static LatLng? _coordinateFrom(Object? source) {
    if (source == null) return null;
    if (source is String) {
      final trimmed = source.trim();
      if (trimmed.isEmpty) return null;
      try {
        return _coordinateFrom(jsonDecode(trimmed));
      } catch (_) {
        return null;
      }
    }
    if (source is List && source.length >= 2) {
      final first = _double(source[0]);
      final second = _double(source[1]);
      if (first == null || second == null) return null;
      final latitude = first.abs() <= 90 && second.abs() <= 180
          ? first
          : second;
      final longitude = latitude == first ? second : first;
      return _valid(latitude, longitude) ? LatLng(latitude, longitude) : null;
    }
    if (source is! Map) return null;

    final map = Map<String, dynamic>.from(source);
    for (final key in [
      'coordinates',
      'location',
      'liveLocation',
      'geo',
      'position',
    ]) {
      final nested = map[key];
      if (nested != null && !identical(nested, source)) {
        final coordinate = _coordinateFrom(nested);
        if (coordinate != null) return coordinate;
      }
    }

    final latitude = _double(map['latitude'] ?? map['lat'] ?? map['_latitude']);
    final longitude = _double(
      map['longitude'] ?? map['lng'] ?? map['long'] ?? map['_longitude'],
    );
    if (latitude == null || longitude == null) return null;
    return _valid(latitude, longitude) ? LatLng(latitude, longitude) : null;
  }

  static double? _double(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static bool _valid(double latitude, double longitude) {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  static double _distanceKm(LatLng origin, LatLng destination) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(destination.latitude - origin.latitude);
    final dLng = _radians(destination.longitude - origin.longitude);
    final lat1 = _radians(origin.latitude);
    final lat2 = _radians(destination.latitude);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        sin(dLng / 2) * sin(dLng / 2) * cos(lat1) * cos(lat2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _radians(double value) => value * pi / 180;
}

String _normalizedStatus(String status) {
  final normalized = status.trim().toLowerCase().replaceAll(
    RegExp(r'[-\s]+'),
    '_',
  );
  return normalized.isEmpty ? 'pending' : normalized;
}

bool _hasAssignedPartner(PackageOrderModel order, String status) {
  return order.raw['acceptedAt'] != null ||
      order.raw['accepted_at'] != null ||
      order.raw['isAcceptedByDeliveryPartner'] == true ||
      const {
        'assigned',
        'confirmed',
        'accepted',
        'picked',
        'picked_up',
        'arriving',
        'out_for_delivery',
        'delivered',
      }.contains(status);
}

bool _hasPickedUp(String status) {
  return const {
    'picked',
    'picked_up',
    'arriving',
    'out_for_delivery',
  }.contains(status);
}

bool _isTerminal(String status) {
  final normalized = _normalizedStatus(status);
  return normalized == 'delivered' ||
      normalized == 'completed' ||
      normalized == 'cancelled';
}

Color _statusColor(String status) {
  switch (status) {
    case 'pending':
      return AppColors.accent;
    case 'assigned':
    case 'confirmed':
    case 'accepted':
      return AppColors.secondaryBlue;
    case 'picked':
    case 'picked_up':
    case 'out_for_delivery':
    case 'delivered':
      return AppColors.success;
    case 'cancelled':
      return AppColors.error;
    default:
      return AppColors.textSecondary;
  }
}

String _trackingLabel(String status) {
  if (_hasPickedUp(status)) return 'Delivery partner is heading to drop';
  if (const {'assigned', 'confirmed', 'accepted'}.contains(status)) {
    return 'Delivery partner is heading to pickup';
  }
  if (status == 'delivered') return 'Package delivered';
  return 'Waiting for delivery partner';
}

Map<String, dynamic> _mapFrom(Object? value) {
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

String _firstString(List<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text != '{}') return text;
  }
  return '';
}

Future<void> _callPartner(String phone) async {
  final dialable = _dialablePhone(phone);
  if (dialable.isEmpty) {
    Get.snackbar('Call failed', 'Phone number is not available.');
    return;
  }
  final uri = Uri(scheme: 'tel', path: dialable);
  if (!await launchUrl(uri)) {
    Get.snackbar('Call failed', 'Unable to open phone dialer.');
  }
}

String _dialablePhone(String value) {
  final sanitized = value.trim().replaceAll(RegExp(r'[^\d+]'), '');
  if (sanitized.isEmpty) return '';
  if (sanitized.startsWith('+')) {
    return '+${sanitized.substring(1).replaceAll('+', '')}';
  }
  return sanitized.replaceAll('+', '');
}
