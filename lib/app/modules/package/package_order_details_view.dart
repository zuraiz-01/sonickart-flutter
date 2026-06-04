import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';

import '../../core/services/package_socket_service.dart';
import '../../core/utils/phone_dialer.dart';
import '../../core/widgets/delivery_rating_dialog.dart';
import '../../core/widgets/live_tracking_bike_marker_icon.dart';
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
  Timer? _trackingTimer;
  Worker? _ratingWorker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (orderId.trim().isNotEmpty) {
        socketService?.connectToOrder(controller, orderId);
      }
      unawaited(_refreshOrder());
      _startTracking();
      _setupRatingWorker();
    });
  }

  void _setupRatingWorker() {
    _ratingWorker = ever(controller.needsRatingForOrder, (order) {
      if (order == null || !mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _trackingTimer?.cancel();
        Get.dialog(
          DeliveryRatingDialog(
            orderId: order.id,
            deliveryPartnerName: controller.deliveryPartnerNameFor(order),
            onSubmitRating:
                ({required orderId, required rating, required feedback}) =>
                    controller.submitDeliveryRating(
                      orderId: orderId,
                      rating: rating,
                      feedback: feedback,
                    ),
          ),
          barrierColor: Colors.black.withValues(alpha: 0.5),
        );
      });
    });
  }

  void _startTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && orderId.trim().isNotEmpty) unawaited(_refreshOrder());
    });
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _ratingWorker?.dispose();
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
      backgroundColor: AppColors.white,
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
                    if (order.hasDeliveryRating) ...[
                      SizedBox(height: 16.hpx),
                      _PackageRatingCard(order: order),
                    ],
                  ],
                ),
              );
      }),
    );
  }
}

class _PackageSummaryCard extends StatelessWidget {
  const _PackageSummaryCard({required this.order});

  final PackageOrderModel order;

  @override
  Widget build(BuildContext context) {
    final status = _normalizedStatus(order.status);
    final createdAt = order.createdAt.toLocal().toString().substring(0, 16);
    final showDropDetails = _dropDetailCount(order) > 1;

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
                      _displayStatusHeading(status),
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
              // Container(
              //   padding: EdgeInsets.symmetric(
              //     horizontal: 10.wpx,
              //     vertical: 6.hpx,
              //   ),
              //   decoration: BoxDecoration(
              //     color: _statusColor(status),
              //     borderRadius: BorderRadius.circular(999.rpx),
              //   ),
              //   child: Row(
              //     mainAxisSize: MainAxisSize.min,
              //     children: [
              //       Icon(
              //         Icons.schedule_rounded,
              //         size: 14.rpx,
              //         color: AppColors.white,
              //       ),
              //       SizedBox(width: 6.wpx),
              //       Text(
              //         status.replaceAll('_', ' '),
              //         style: TextStyle(
              //           color: AppColors.white,
              //           fontWeight: FontWeight.w800,
              //           fontSize: 12.spx,
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
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
              SizedBox(width: 12.wpx),
              _MetaChip(icon: Icons.calendar_month_outlined, label: createdAt),
            ],
          ),
          SizedBox(height: 14.hpx),
          _LocationRow(
            icon: Icons.location_on_rounded,
            color: AppColors.success,
            label: 'Pickup',
            value: order.pickupAddress.isNotEmpty ? order.pickupAddress : 'N/A',
          ),
          SizedBox(height: 12.hpx),
          _LocationRow(
            icon: Icons.location_on_outlined,
            color: AppColors.error,
            label: 'Drop',
            value: order.dropAddress.isNotEmpty ? order.dropAddress : 'N/A',
          ),
          if (order.totalDrops > 1) ...[
            SizedBox(height: 12.hpx),
            _LocationRow(
              icon: Icons.route_outlined,
              color: AppColors.secondaryBlue,
              label: 'Current Drop',
              value:
                  'Drop ${order.currentDropIndex + 1} of ${order.totalDrops}',
            ),
          ],
          if (showDropDetails) ...[
            SizedBox(height: 12.hpx),
            _DropDetailsList(order: order),
          ],
          if (order.senderName.isNotEmpty || order.senderPhone.isNotEmpty) ...[
            SizedBox(height: 12.hpx),
            _LocationRow(
              icon: Icons.person_pin_circle_outlined,
              color: AppColors.secondaryBlue,
              label: 'Sender',
              value: _contactValue(order.senderName, order.senderPhone),
            ),
          ],
          if (!showDropDetails &&
              (order.receiverName.isNotEmpty ||
                  order.receiverPhone.isNotEmpty)) ...[
            SizedBox(height: 12.hpx),
            _LocationRow(
              icon: Icons.person_add_alt_1_outlined,
              color: AppColors.primary,
              label: 'Receiver',
              value: _contactValue(order.receiverName, order.receiverPhone),
            ),
          ],
          SizedBox(height: 14.hpx),
          Row(
            children: [
              if (order.distanceKm > 0) ...[
                Expanded(
                  child: _QuickStatTile(
                    label: 'Distance',
                    value: '${order.distanceKm.toStringAsFixed(1)} km',
                  ),
                ),
                SizedBox(width: 12.wpx),
              ],
              Expanded(
                child: _QuickStatTile(
                  label: 'Delivery Charge',
                  value: '₹${order.deliveryCharge.toStringAsFixed(2)}',
                ),
              ),
              SizedBox(width: 12.wpx),
              Expanded(
                child: _QuickStatTile(
                  label: 'Total',
                  value: '₹${order.totalPrice.toStringAsFixed(2)}',
                  strong: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStatTile extends StatelessWidget {
  const _QuickStatTile({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10.rpx),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(10.rpx),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 11.spx,
            ),
          ),
          SizedBox(height: 4.hpx),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: strong ? AppColors.primary : AppColors.textPrimary,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
              fontSize: 13.spx,
            ),
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
                      _hasPickedUp(status) ? 'Package Picked Up' : 'On The Way',
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
              onTap: () => PhoneDialer.open(phone),
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
  LatLng? _displayedPartnerLoc;
  LatLng? _targetPartnerLoc;
  BitmapDescriptor? _partnerBikeIcon;
  Timer? _glideTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPartnerBikeIcon());
  }

  Future<void> _loadPartnerBikeIcon() async {
    try {
      final icon = await loadLiveTrackingBikeMarkerIcon();
      if (mounted) setState(() => _partnerBikeIcon = icon);
    } catch (_) {
      // Keep the default map marker if the asset cannot be loaded.
    }
  }

  @override
  void didUpdateWidget(covariant _PackageLiveMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final data = _PackageTrackingMapData.fromOrder(widget.order);
    final newLoc = data.deliveryPersonLocation;

    if (newLoc != null &&
        _displayedPartnerLoc != null &&
        _targetPartnerLoc != null &&
        newLoc != _targetPartnerLoc &&
        _distanceKm(newLoc, _targetPartnerLoc!) > 0.01) {
      _targetPartnerLoc = newLoc;
      _startGlide();
    } else if (data.deliveryPersonLocation != null &&
        _displayedPartnerLoc == null) {
      _displayedPartnerLoc = data.deliveryPersonLocation;
      _targetPartnerLoc = data.deliveryPersonLocation;
    }
  }

  void _startGlide() {
    _glideTimer?.cancel();
    _glideTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted ||
          _displayedPartnerLoc == null ||
          _targetPartnerLoc == null) {
        _glideTimer?.cancel();
        return;
      }
      final from = _displayedPartnerLoc!;
      final to = _targetPartnerLoc!;
      final newLat = from.latitude + (to.latitude - from.latitude) * 0.1;
      final newLng = from.longitude + (to.longitude - from.longitude) * 0.1;
      _displayedPartnerLoc = LatLng(newLat, newLng);
      if (_distanceKm(from, to) < 0.005) {
        _displayedPartnerLoc = to;
        _glideTimer?.cancel();
      }
      setState(() {});
    });
  }

  Set<Marker> _animatedMarkers(_PackageTrackingMapData data) {
    final partnerPos = _displayedPartnerLoc ?? data.deliveryPersonLocation;
    return {
      if (data.pickupLocation != null)
        Marker(
          markerId: const MarkerId('pickupLocation'),
          position: data.pickupLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      if (data.dropLocation != null)
        Marker(
          markerId: const MarkerId('dropLocation'),
          position: data.dropLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: const InfoWindow(title: 'Drop'),
        ),
      if (partnerPos != null)
        Marker(
          markerId: const MarkerId('deliveryPartner'),
          position: partnerPos,
          icon:
              _partnerBikeIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: liveTrackingBikeMarkerAnchor,
          flat: true,
          infoWindow: const InfoWindow(title: 'Delivery Partner'),
        ),
    };
  }

  @override
  void dispose() {
    _glideTimer?.cancel();
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
                          markers: _animatedMarkers(data),
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

  double _distanceKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final x =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(a.latitude)) *
            cos(_rad(b.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(x), sqrt(1 - x));
  }

  double _rad(double v) => v * pi / 180;

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

class _PackageRatingCard extends StatelessWidget {
  const _PackageRatingCard({required this.order});

  final PackageOrderModel order;

  @override
  Widget build(BuildContext context) {
    final rating = order.deliveryRating;
    if (rating == null) return const SizedBox.shrink();
    final feedback = order.deliveryRatingFeedback.trim();
    final ratedAt = order.deliveryRatedAt;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: AppColors.accent, size: 22.rpx),
              SizedBox(width: 10.wpx),
              Expanded(
                child: Text(
                  'Your Rating',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$rating/5',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.hpx),
          _PackageDetailRatingStars(rating: rating),
          if (feedback.isNotEmpty) ...[
            SizedBox(height: 12.hpx),
            Text(
              feedback,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ],
          if (ratedAt != null) ...[
            SizedBox(height: 10.hpx),
            Text(
              'Submitted ${ratedAt.toLocal().toString().substring(0, 16)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PackageDetailRatingStars extends StatelessWidget {
  const _PackageDetailRatingStars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final filled = index < rating;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          color: AppColors.accent,
          size: 24.rpx,
        );
      }),
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
            value: '₹${order.deliveryCharge.round()}',
          ),
          SizedBox(height: 10.hpx),
          Divider(height: 1, color: AppColors.border),
          SizedBox(height: 10.hpx),
          _BillRow(
            label: 'Grand Total',
            value: '₹${order.totalPrice.round()}',
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
          color: AppColors.muted,
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

class _DropDetailsList extends StatelessWidget {
  const _DropDetailsList({required this.order});

  final PackageOrderModel order;

  @override
  Widget build(BuildContext context) {
    final count = _dropDetailCount(order);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.route_outlined, size: 19.rpx, color: AppColors.primary),
        SizedBox(width: 10.wpx),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Drops',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.hpx),
              for (var i = 0; i < count; i++) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10.rpx),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10.rpx),
                    border: Border.all(
                      color: i == order.currentDropIndex
                          ? AppColors.primary.withValues(alpha: 0.28)
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i == order.currentDropIndex
                            ? 'Drop ${i + 1} (Current)'
                            : 'Drop ${i + 1}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_dropAddressAt(order, i).isNotEmpty) ...[
                        SizedBox(height: 4.hpx),
                        Text(
                          _dropAddressAt(order, i),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                        ),
                      ],
                      if (_dropContactValue(order, i).isNotEmpty) ...[
                        SizedBox(height: 4.hpx),
                        Text(
                          'Receiver: ${_dropContactValue(order, i)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                      if (_dropStatusAt(order, i).isNotEmpty ||
                          _dropPaymentLine(order, i).isNotEmpty) ...[
                        SizedBox(height: 6.hpx),
                        Wrap(
                          spacing: 8.wpx,
                          runSpacing: 6.hpx,
                          children: [
                            if (_dropStatusAt(order, i).isNotEmpty)
                              _DropMetaPill(
                                text: _titleStatus(_dropStatusAt(order, i)),
                                icon: Icons.check_circle_outline,
                              ),
                            if (_dropPaymentLine(order, i).isNotEmpty)
                              _DropMetaPill(
                                text: _dropPaymentLine(order, i),
                                icon: Icons.payments_outlined,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (i != count - 1) SizedBox(height: 8.hpx),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DropMetaPill extends StatelessWidget {
  const _DropMetaPill({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.wpx, vertical: 5.hpx),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(999.rpx),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.rpx, color: AppColors.primary),
          SizedBox(width: 4.wpx),
          Text(
            text,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 11.spx,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.value,
    this.valueColor = const Color(0xFF092774),
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
      color: AppColors.muted,
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
          _currentDropCoordinate(order, raw) ??
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
          infoWindow: const InfoWindow(title: 'Delivery Partner'),
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

  static LatLng? _currentDropCoordinate(
    PackageOrderModel order,
    Map<String, dynamic> raw,
  ) {
    var index = order.currentDropIndex;
    final maxIndex = max(order.totalDrops - 1, 0);
    if (index < 0) index = 0;
    if (index > maxIndex) index = maxIndex;

    final rawDrops = _listFrom(
      raw['dropLocations'] ?? raw['drop_locations'] ?? raw['drops'],
    );
    if (rawDrops.isNotEmpty && index < rawDrops.length) {
      final coordinate = _coordinateFrom(rawDrops[index]);
      if (coordinate != null) return coordinate;
    }

    if (index < order.dropLatitudes.length &&
        index < order.dropLongitudes.length) {
      final latitude = order.dropLatitudes[index];
      final longitude = order.dropLongitudes[index];
      if (latitude != null &&
          longitude != null &&
          _valid(latitude, longitude)) {
        return LatLng(latitude, longitude);
      }
    }

    return null;
  }

  static List<dynamic> _listFrom(Object? source) {
    if (source is List) return source;
    if (source is String) {
      try {
        final decoded = jsonDecode(source);
        return decoded is List ? decoded : const [];
      } catch (_) {
        return const [];
      }
    }
    return const [];
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
    'in_transit',
    'out_for_delivery',
    'delivered',
    'completed',
  }.contains(status);
}

String _trackingLabel(String status) {
  if (status == 'delivered' || status == 'completed') {
    return 'Package Delivered';
  }
  if (_hasPickedUp(status)) return 'Delivery Partner Is Heading To Drop';
  if (const {'assigned', 'confirmed', 'accepted'}.contains(status)) {
    return 'Delivery Partner Is Heading To Pickup';
  }
  return 'Waiting For Delivery Partner';
}

String _displayStatusHeading(String status) {
  if (status == 'pending') return 'Packing Your Package Order';
  final text = status.replaceAll(RegExp(r'[-_]+'), ' ').trim();
  if (text.isEmpty) return 'Package Order';
  return text
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map(
        (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _contactValue(String name, String phone) {
  final parts = [
    name.trim(),
    phone.trim(),
  ].where((value) => value.isNotEmpty).join(' | ');
  return parts.isEmpty ? 'N/A' : parts;
}

int _dropDetailCount(PackageOrderModel order) {
  return [
    order.totalDrops,
    order.dropAddresses.length,
    order.dropReceiverNames.length,
    order.dropReceiverPhones.length,
    order.dropPaymentAmounts.length,
    order.dropPaymentStatuses.length,
    order.dropStatuses.length,
  ].fold<int>(0, max);
}

String _dropAddressAt(PackageOrderModel order, int index) {
  if (index < 0 || index >= order.dropAddresses.length) return '';
  return order.dropAddresses[index].trim();
}

String _dropContactValue(PackageOrderModel order, int index) {
  final name = index >= 0 && index < order.dropReceiverNames.length
      ? order.dropReceiverNames[index].trim()
      : '';
  final phone = index >= 0 && index < order.dropReceiverPhones.length
      ? order.dropReceiverPhones[index].trim()
      : '';
  return [name, phone].where((value) => value.isNotEmpty).join(' | ');
}

String _dropStatusAt(PackageOrderModel order, int index) {
  if (index >= 0 && index < order.dropStatuses.length) {
    final status = order.dropStatuses[index].trim();
    if (status.isNotEmpty) return status;
  }
  final normalized = _normalizedStatus(order.status);
  if (normalized == 'delivered' || normalized == 'completed') {
    return 'completed';
  }
  if (!_hasPickedUp(normalized)) return 'pending';
  if (index < order.currentDropIndex) return 'completed';
  if (index == order.currentDropIndex) return 'active';
  return 'pending';
}

String _dropPaymentLine(PackageOrderModel order, int index) {
  final amount = index >= 0 && index < order.dropPaymentAmounts.length
      ? order.dropPaymentAmounts[index]
      : 0.0;
  final paymentStatus = index >= 0 && index < order.dropPaymentStatuses.length
      ? order.dropPaymentStatuses[index].trim()
      : '';
  if (amount <= 0 && paymentStatus.isEmpty) return '';
  final statusText = paymentStatus.isEmpty ? 'pending' : paymentStatus;
  if (amount <= 0) return _titleStatus(statusText);
  return 'Rs ${amount.toStringAsFixed(2)} ${_titleStatus(statusText)}';
}

String _titleStatus(String status) {
  final text = status.replaceAll(RegExp(r'[-_]+'), ' ').trim();
  if (text.isEmpty) return '';
  return text
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map(
        (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
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
