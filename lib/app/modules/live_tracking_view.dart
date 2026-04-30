import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/order_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'order_controller.dart';

class LiveTrackingView extends GetView<OrderController> {
  const LiveTrackingView({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = Get.arguments;
    final argId = arguments is Map ? arguments['orderId']?.toString() : null;
    return _LiveTrackingScaffold(orderId: argId, controller: controller);
  }
}

class _LiveTrackingScaffold extends StatefulWidget {
  const _LiveTrackingScaffold({
    required this.orderId,
    required this.controller,
  });

  final String? orderId;
  final OrderController controller;

  @override
  State<_LiveTrackingScaffold> createState() => _LiveTrackingScaffoldState();
}

class _LiveTrackingScaffoldState extends State<_LiveTrackingScaffold> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOrder());
  }

  Future<void> _refreshOrder() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await widget.controller.refreshTrackingOrder(widget.orderId);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final order = _resolveOrder();
      return Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          title: Text('Live Tracking'),
          centerTitle: true,
          actions: [
            if (_refreshing)
              Padding(
                padding: EdgeInsets.only(right: 16.wpx),
                child: SizedBox(
                  width: 18.rpx,
                  height: 18.rpx,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        body: order == null
            ? Center(child: Text('No active order found.'))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refreshOrder,
                child: _TrackingBody(
                  order: order,
                  controller: widget.controller,
                ),
              ),
      );
    });
  }

  OrderModel? _resolveOrder() {
    final orderId = widget.orderId;
    if (orderId == null || orderId.trim().isEmpty) {
      return widget.controller.activeProductOrder.value ??
          widget.controller.selectedOrder.value ??
          widget.controller.latestOrder.value;
    }

    return widget.controller.findOrderById(orderId) ??
        widget.controller.selectedOrder.value ??
        widget.controller.activeProductOrder.value;
  }
}

class _TrackingBody extends StatelessWidget {
  const _TrackingBody({required this.order, required this.controller});

  final OrderModel order;
  final OrderController controller;

  @override
  Widget build(BuildContext context) {
    final eta = controller.etaFor(order);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16.rpx),
      children: [
        _LiveMapCard(order: order, etaLabel: _etaLabel(order.status, eta)),
        SizedBox(height: 16.hpx),
        _InfoCard(
          title: _statusTitle(order.status),
          rows: [
            ('Order', order.id),
            ('Status', order.status),
            ('Payment', order.paymentMode),
            ('Address', order.deliveryAddress),
            ('Total', 'Rs ${order.totalPrice.toStringAsFixed(0)}'),
          ],
        ),
        SizedBox(height: 16.hpx),
        _LiveStatusCard(order: order, controller: controller),
        SizedBox(height: 16.hpx),
        _PartnerCard(order: order),
        SizedBox(height: 16.hpx),
        _InfoCard(
          title: 'Ordered Items (${order.items.length})',
          rows: order.items
              .map(
                (item) => (
                  item.product.name,
                  '${item.quantity} x Rs ${item.product.price}',
                ),
              )
              .toList(),
        ),
        SizedBox(height: 16.hpx),
        if (order.status.toLowerCase() != 'cancelled' &&
            order.status.toLowerCase() != 'delivered')
          FilledButton.icon(
            onPressed: () => _cancelOrder(context),
            icon: Icon(Icons.cancel_outlined),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(vertical: 14),
            ),
            label: Text(
              'Cancel Order',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        SizedBox(height: 8.hpx),
        OutlinedButton(
          onPressed: () => Get.toNamed(
            AppRoutes.customerOrderDetails,
            arguments: {'orderId': order.id},
          ),
          child: Text('View Order Details'),
        ),
      ],
    );
  }

  Future<void> _cancelOrder(BuildContext context) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.rpx)),
      ),
      builder: (context) => _CancellationReasonSheet(),
    );

    if (reason == null || reason.trim().isEmpty) return;
    await controller.cancelOrder(order, reason: reason);
  }

  String _statusTitle(String status) {
    final lower = status.toLowerCase();
    if (lower == 'cancelled') return 'Order Cancelled';
    if (lower == 'delivered') return 'Order Delivered';
    if (lower == 'confirmed' || lower == 'accepted') return 'Arriving Soon';
    if (lower == 'assigned') return 'Arriving Soon';
    if (lower == 'prepared' || lower == 'ready') return 'Preparing order';
    if (lower == 'arriving' || lower == 'out_for_delivery') {
      return 'Order Picked Up';
    }
    if (lower == 'picked') return 'Order Picked Up';
    return 'Packing your order';
  }

  String _etaLabel(String status, int? eta) {
    final lower = status.toLowerCase();
    if (lower == 'cancelled') return 'Cancelled';
    if (lower == 'delivered') return 'Fastest Delivery';
    if (eta == null) {
      return lower == 'pending' ? 'Getting things ready' : 'Tracking live';
    }
    if (eta <= 1) return 'ETA Arriving now';
    return 'ETA $eta mins';
  }
}

class _LiveStatusCard extends StatelessWidget {
  const _LiveStatusCard({required this.order, required this.controller});

  final OrderModel order;
  final OrderController controller;

  @override
  Widget build(BuildContext context) {
    final mapData = _TrackingMapData.fromOrder(order);
    final eta = controller.etaFor(order);
    final distance = mapData.liveDistanceKm;
    return _InfoCard(
      title: 'Live Tracking',
      rows: [
        (
          'ETA',
          eta == null
              ? 'Tracking live'
              : eta <= 1
              ? 'Arriving now'
              : '$eta mins',
        ),
        if (distance != null) ('Distance', '${distance.toStringAsFixed(2)} km'),
        ('Status', _statusCopy(order.status)),
      ],
    );
  }

  static String _statusCopy(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'pending') return 'Waiting for pickup';
    if (normalized == 'assigned') return 'On the way to pickup';
    if (normalized == 'picked') return 'On the way to delivery';
    if (normalized == 'confirmed' || normalized == 'accepted') {
      return 'On the way';
    }
    if (normalized == 'out_for_delivery' || normalized == 'arriving') {
      return 'Out for delivery';
    }
    if (normalized == 'prepared' || normalized == 'ready') {
      return 'Preparing order';
    }
    if (normalized.isEmpty) return 'Tracking live';
    return normalized.replaceAll('_', ' ').capitalizeFirst ?? normalized;
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final partner = _deliveryPartner(order);
    final name =
        _firstString([
          partner['name'],
          partner['fullName'],
          partner['firstName'],
          partner['lastName'],
          order.raw['deliveryPartnerName'],
        ]) ??
        'We will soon assign delivery partner';
    final phone = _firstString([
      partner['phone'],
      partner['contactNumber'],
      partner['mobile'],
      partner['phoneNumber'],
      order.raw['deliveryPartnerPhone'],
    ]);
    return Container(
      padding: EdgeInsets.all(16.rpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 42.rpx,
            height: 42.rpx,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              phone == null ? Icons.shopping_bag_outlined : Icons.phone,
              color: AppColors.accent,
            ),
          ),
          SizedBox(width: 12.wpx),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.spx,
                  ),
                ),
                if (phone != null) ...[
                  SizedBox(height: 4.hpx),
                  InkWell(
                    onTap: () => _callPhone(phone),
                    child: Text(
                      phone,
                      style: TextStyle(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 4.hpx),
                Text(
                  phone == null
                      ? 'Delivery partner details will appear here.'
                      : 'For delivery instructions you can contact here.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.spx,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Map<String, dynamic> _deliveryPartner(OrderModel order) {
    final raw = order.raw['deliveryPartner'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  static String? _firstString(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static Future<void> _callPhone(String phone) async {
    final sanitized = phone.trim().replaceAll(RegExp(r'[^\d+]'), '');
    if (sanitized.isEmpty) {
      Get.snackbar('Call failed', 'Phone number is not available.');
      return;
    }
    final uri = Uri(scheme: 'tel', path: sanitized);
    if (!await canLaunchUrl(uri)) {
      Get.snackbar('Call failed', 'Your device cannot place calls right now.');
      return;
    }
    await launchUrl(uri);
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.rpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12.hpx),
          ...rows.map(
            (row) => Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92.wpx,
                    child: Text(
                      row.$1,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMapCard extends StatefulWidget {
  const _LiveMapCard({required this.order, required this.etaLabel});

  final OrderModel order;
  final String etaLabel;

  @override
  State<_LiveMapCard> createState() => _LiveMapCardState();
}

class _LiveMapCardState extends State<_LiveMapCard> {
  GoogleMapController? _mapController;

  @override
  void didUpdateWidget(covariant _LiveMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.raw != widget.order.raw ||
        oldWidget.order.status != widget.order.status) {
      unawaited(_fitMap());
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _TrackingMapData.fromOrder(widget.order);
    if (data.points.isEmpty) {
      return _MapFallback(etaLabel: widget.etaLabel);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(15.rpx),
      child: Container(
        height: 285.hpx,
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: data.initialTarget,
                zoom: data.points.length == 1 ? 15 : 13,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                unawaited(_fitMap());
              },
              style: _mapStyleJson,
              markers: data.markers,
              polylines: data.polylines,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              buildingsEnabled: false,
              indoorViewEnabled: false,
              trafficEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
            ),
            Positioned(
              left: 12.wpx,
              top: 12.hpx,
              child: _MapStatusPill(label: widget.etaLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fitMap() async {
    final controller = _mapController;
    if (controller == null) return;
    final data = _TrackingMapData.fromOrder(widget.order);
    if (data.points.isEmpty) return;

    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    if (data.points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: data.points.first, zoom: 15),
        ),
      );
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(_boundsFor(data.focusPoints), 52.rpx),
    );
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    final source = points.isEmpty
        ? _TrackingMapData.fromOrder(widget.order).points
        : points;
    var minLat = source.first.latitude;
    var maxLat = source.first.latitude;
    var minLng = source.first.longitude;
    var maxLng = source.first.longitude;

    for (final point in source.skip(1)) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
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

class _TrackingMapData {
  const _TrackingMapData({
    required this.deliveryLocation,
    required this.pickupLocation,
    required this.deliveryPersonLocation,
    required this.hasAccepted,
    required this.hasPickedUp,
  });

  final LatLng? deliveryLocation;
  final LatLng? pickupLocation;
  final LatLng? deliveryPersonLocation;
  final bool hasAccepted;
  final bool hasPickedUp;

  factory _TrackingMapData.fromOrder(OrderModel order) {
    final raw = order.raw;
    final deliveryPartner = raw['deliveryPartner'] is Map
        ? Map<String, dynamic>.from(raw['deliveryPartner'] as Map)
        : const <String, dynamic>{};
    final status = order.status.trim().toLowerCase();
    return _TrackingMapData(
      deliveryLocation:
          _coordinateFrom(raw['deliveryLocation']) ??
          _coordinateFrom({
            'latitude': raw['customerLatitude'],
            'longitude': raw['customerLongitude'],
          }),
      pickupLocation: _coordinateFrom(raw['pickupLocation']),
      deliveryPersonLocation:
          _coordinateFrom(raw['deliveryPersonLocation']) ??
          _coordinateFrom(deliveryPartner['liveLocation']),
      hasAccepted:
          status == 'confirmed' || status == 'accepted' || status == 'assigned',
      hasPickedUp:
          status == 'arriving' ||
          status == 'picked' ||
          status == 'out_for_delivery',
    );
  }

  List<LatLng> get points => [
    deliveryLocation,
    pickupLocation,
    deliveryPersonLocation,
  ].whereType<LatLng>().toList();

  List<LatLng> get focusPoints {
    final first = hasAccepted ? deliveryPersonLocation : deliveryLocation;
    final second = hasPickedUp ? deliveryPersonLocation : pickupLocation;
    final focused = [first, second].whereType<LatLng>().toList();
    return focused.length >= 2 ? focused : points;
  }

  LatLng get initialTarget =>
      deliveryPersonLocation ?? pickupLocation ?? deliveryLocation!;

  double? get liveDistanceKm {
    final origin = deliveryPersonLocation;
    final destination = deliveryLocation;
    if (origin == null || destination == null) return null;
    return _distanceKm(origin, destination);
  }

  Set<Marker> get markers {
    return {
      if (deliveryLocation != null)
        Marker(
          markerId: const MarkerId('deliveryLocation'),
          position: deliveryLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: const InfoWindow(title: 'Delivery address'),
        ),
      if (pickupLocation != null)
        Marker(
          markerId: const MarkerId('pickupLocation'),
          position: pickupLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Pickup'),
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
    final routeTarget = hasPickedUp
        ? deliveryLocation
        : hasAccepted
        ? pickupLocation
        : null;
    if (deliveryPersonLocation != null && routeTarget != null) {
      lines.add(
        Polyline(
          polylineId: const PolylineId('partnerRoute'),
          points: [deliveryPersonLocation!, routeTarget],
          color: AppColors.secondaryBlue,
          width: 5,
          geodesic: true,
        ),
      );
    }

    if (!hasPickedUp && pickupLocation != null && deliveryLocation != null) {
      lines.add(
        Polyline(
          polylineId: const PolylineId('pickupToDelivery'),
          points: [pickupLocation!, deliveryLocation!],
          color: AppColors.textSecondary,
          width: 2,
          geodesic: true,
          patterns: [PatternItem.dash(12), PatternItem.gap(10)],
        ),
      );
    }

    if (deliveryPersonLocation != null && deliveryLocation != null) {
      lines.add(
        Polyline(
          polylineId: const PolylineId('partnerToDelivery'),
          points: [deliveryPersonLocation!, deliveryLocation!],
          color: AppColors.white,
          width: 2,
          geodesic: true,
          patterns: [PatternItem.dash(6), PatternItem.gap(8)],
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
      height: 285.hpx,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(15.rpx),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 72.rpx, color: AppColors.primary),
          SizedBox(height: 12.hpx),
          Text(
            'Live map preview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.hpx),
          Text(
            etaLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

const _mapStyleJson = '''
[
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.business",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "road",
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "road.local",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit",
    "stylers": [{"visibility": "off"}]
  }
]
''';

class _CancellationReasonSheet extends StatefulWidget {
  const _CancellationReasonSheet();

  @override
  State<_CancellationReasonSheet> createState() =>
      _CancellationReasonSheetState();
}

class _CancellationReasonSheetState extends State<_CancellationReasonSheet> {
  static const _reasons = [
    (icon: Icons.error_outline, title: 'Ordered by mistake'),
    (
      icon: Icons.location_off_outlined,
      title: 'Wrong address or delivery location',
    ),
    (icon: Icons.local_offer_outlined, title: 'Found a better price or offer'),
    (icon: Icons.cancel_outlined, title: "Don't need the items anymore"),
    (icon: Icons.access_time, title: 'Delivery time is too long'),
  ];

  String? _selectedReason;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.rpx, 18.hpx, 20.rpx, 20.hpx),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42.wpx,
              height: 4.hpx,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            SizedBox(height: 18.hpx),
            Text(
              'Why are you cancelling?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4.hpx),
            Text(
              'Please select a reason for cancellation',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 18.hpx),
            ..._reasons.map(
              (reason) => _ReasonTile(
                icon: reason.icon,
                title: reason.title,
                selected: _selectedReason == reason.title,
                onTap: () => setState(() => _selectedReason = reason.title),
              ),
            ),
            SizedBox(height: 12.hpx),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedReason == null
                    ? null
                    : () => Navigator.of(context).pop(_selectedReason),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.textSecondary.withValues(
                    alpha: 0.35,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 14.hpx),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.rpx),
                  ),
                ),
                child: Text(
                  'Cancel Order',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.hpx),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.rpx),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.wpx, vertical: 12.hpx),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(10.rpx),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32.rpx,
                height: 32.rpx,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18.rpx,
                  color: selected ? AppColors.white : AppColors.primary,
                ),
              ),
              SizedBox(width: 10.wpx),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 20.rpx,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
