import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  Timer? _trackingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOrder());
    _startTracking();
  }

  void _startTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      final order = widget.controller.activeProductOrder.value ??
          widget.controller.selectedOrder.value;
      if (order != null && !order.isInactive && mounted) {
        unawaited(_refreshOrder());
      }
    });
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
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
        backgroundColor: AppColors.lightPrimary,
        body: SafeArea(
          child: Column(
            children: [
              _LiveTrackingHeader(order: order, refreshing: _refreshing),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: AppColors.white,
                  child: order == null
                      ? Center(child: Text('No Active Order Found.'))
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _refreshOrder,
                          child: _TrackingBody(
                            order: order,
                            controller: widget.controller,
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

class _LiveTrackingHeader extends StatelessWidget {
  const _LiveTrackingHeader({required this.order, required this.refreshing});

  final OrderModel? order;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final status = order?.status ?? '';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.wpx, vertical: 8.hpx),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Get.offNamed(AppRoutes.dashboard),
              icon: Icon(
                Icons.chevron_left_rounded,
                color: Colors.white,
                size: 22.spx,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _headerTitle(status),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.spx,
                ),
              ),
              SizedBox(height: 2.hpx),
              Text(
                order == null
                    ? 'Live Tracking'
                    : _headerSubtitle(status, order!.raw['etaMinutes']),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22.spx,
                ),
              ),
            ],
          ),
          if (refreshing)
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 18.rpx,
                height: 18.rpx,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _headerTitle(String status) {
    final lower = status.toLowerCase();
    if (lower == 'cancelled') return 'Order Cancelled';
    if (lower == 'delivered') return 'Order Delivered';
    if (lower == 'confirmed' || lower == 'accepted' || lower == 'assigned') {
      return 'Arriving Soon';
    }
    if (lower == 'arriving' ||
        lower == 'picked' ||
        lower == 'out_for_delivery') {
      return 'Order Picked Up';
    }
    return 'Packing your order';
  }

  static String _headerSubtitle(String status, Object? etaValue) {
    final lower = status.toLowerCase();
    if (lower == 'cancelled') return 'Cancelled';
    if (lower == 'delivered') return 'Fastest Delivery';
    final eta = etaValue is num ? etaValue.toInt() : int.tryParse('$etaValue');
    if (eta == null || eta <= 0) {
      return lower == 'pending' ? 'Getting things ready' : 'Tracking live';
    }
    if (eta <= 1) return 'Arriving any moment';
    return 'Arriving in $eta minutes';
  }
}

class _TrackingBody extends StatelessWidget {
  const _TrackingBody({required this.order, required this.controller});

  final OrderModel order;
  final OrderController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(18.wpx, 18.hpx, 18.wpx, 150.hpx),
      children: [
        _LiveMapCard(
          order: order,
          etaLabel: _LiveTrackingHeader._headerSubtitle(
            order.status,
            order.raw['etaMinutes'],
          ),
        ),
        SizedBox(height: 16.hpx),
        if (order.status.toLowerCase() != 'cancelled' &&
            order.status.toLowerCase() != 'delivered') ...[
          _LiveStatusCard(order: order),
          SizedBox(height: 16.hpx),
        ],
        _OrderSummaryCard(order: order),
        SizedBox(height: 16.hpx),
        _OrderedItemsCard(order: order),
        SizedBox(height: 16.hpx),
        _DeliveryAddressCard(order: order),
        SizedBox(height: 16.hpx),
        _BillDetailsCard(order: order),
        SizedBox(height: 20.hpx),
        if (order.status.toLowerCase() != 'cancelled' &&
            order.status.toLowerCase() != 'delivered')
          Container(
            margin: EdgeInsets.symmetric(vertical: 8.hpx),
            child: FilledButton.icon(
              onPressed: () => _cancelOrder(context),
              icon: Icon(Icons.cancel_outlined, size: 22.spx),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(vertical: 17.hpx),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.rpx),
                ),
              ),
              label: Text(
                'Cancel Order',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.spx),
              ),
            ),
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
}

class _DeliveryAddressCard extends StatelessWidget {
  const _DeliveryAddressCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final address = order.deliveryAddress.trim().isEmpty
        ? 'Delivery Address unavailable'
        : order.deliveryAddress.trim();
    final recipient = order.customerName.trim().isEmpty
        ? 'Delivery Address'
        : order.customerName.trim();
    return Container(
      padding: EdgeInsets.all(20.rpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18.rpx),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoundIcon(icon: Icons.location_on_outlined),
          SizedBox(width: 14.wpx),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivering to',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.spx,
                  ),
                ),
                SizedBox(height: 5.hpx),
                Text(
                  recipient,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18.spx,
                  ),
                ),
                SizedBox(height: 6.hpx),
                Text(
                  address,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.spx,
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

class _LiveStatusCard extends StatelessWidget {
  const _LiveStatusCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final data = _TrackingMapData.fromOrder(order);
    final eta = order.raw['etaMinutes'] is num
        ? (order.raw['etaMinutes'] as num).toInt()
        : int.tryParse('${order.raw['etaMinutes']}');
    final distance = data.liveDistanceKm;
    return _SectionCard(
      padding: EdgeInsets.all(16.rpx),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.route_outlined,
                size: 18.rpx,
                color: AppColors.price,
              ),
              SizedBox(width: 8.wpx),
              Text(
                'Live Tracking',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16.spx,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.hpx),
          if (eta != null)
            _LiveStatusRow(
              icon: Icons.schedule_outlined,
              label: 'ETA',
              value: eta <= 0
                  ? 'Arriving now'
                  : '$eta ${eta == 1 ? 'min' : 'mins'}',
            ),
          if (distance != null)
            _LiveStatusRow(
              icon: Icons.near_me_outlined,
              label: 'Distance',
              value: '${distance.toStringAsFixed(2)} km',
            ),
          _LiveStatusRow(
            icon: Icons.info_outline,
            label: 'Status',
            value: _statusText(order.status),
          ),
        ],
      ),
    );
  }

  static String _statusText(String status) {
    final normalized = status.trim().toLowerCase();
    return switch (normalized) {
      'pending' => 'Waiting for pickup',
      'assigned' => 'On the way to pickup',
      'picked' => 'On the way to delivery',
      'confirmed' || 'accepted' => 'On the way',
      'out_for_delivery' => 'Out for delivery',
      'prepared' => 'Preparing order',
      'ready' => 'Ready for pickup',
      _ => normalized.replaceAll('_', ' ').capitalizeFirst ?? 'Tracking live',
    };
  }
}

class _LiveStatusRow extends StatelessWidget {
  const _LiveStatusRow({
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
      padding: EdgeInsets.only(bottom: 10.hpx),
      child: Row(
        children: [
          Icon(icon, size: 17.rpx, color: AppColors.accent),
          SizedBox(width: 10.wpx),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13.spx,
            ),
          ),
          SizedBox(width: 10.wpx),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 14.spx,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final orderId = order.id.isEmpty ? '--' : order.id;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.receipt_long_outlined,
            title: 'Order Summary',
            subtitle: 'Order #$orderId',
          ),
          SizedBox(height: 10.hpx),
          _SummaryRow(label: 'Status', value: _statusLabel(order.status)),
          _SummaryRow(label: 'Payment', value: order.paymentMode),
          _SummaryRow(
            label: 'Items',
            value:
                '${order.resolvedItemCount} item${order.resolvedItemCount == 1 ? '' : 's'}',
          ),
          _SummaryRow(
            label: 'Total',
            value: '₹${order.totalPrice.toStringAsFixed(2)}',
            strong: true,
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String status) {
    final normalized = status.trim().replaceAll('_', ' ');
    if (normalized.isEmpty) return 'Tracking live';
    return normalized.capitalizeFirst ?? normalized;
  }
}

class _OrderedItemsCard extends StatelessWidget {
  const _OrderedItemsCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      padding: EdgeInsets.symmetric(vertical: 14.hpx),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.wpx),
            child: _SectionHeader(
              icon: Icons.shopping_bag_outlined,
              title: 'Ordered Items (${order.items.length})',
              subtitle: 'Items In Your Order',
            ),
          ),
          SizedBox(height: 14.hpx),
          ...order.items.map((item) => _OrderedItemTile(item: item)),
        ],
      ),
    );
  }
}

class _OrderedItemTile extends StatelessWidget {
  const _OrderedItemTile({required this.item});

  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final image = item.product.resolvedImageUrl;
    return Container(
      margin: EdgeInsets.fromLTRB(14.wpx, 0, 14.wpx, 12.hpx),
      padding: EdgeInsets.all(13.rpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15.rpx),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72.wpx,
            height: 72.wpx,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(17.rpx),
            ),
            clipBehavior: Clip.antiAlias,
            child: image.isNotEmpty
                ? Image.network(
                    image,
                    width: 52.wpx,
                    height: 52.wpx,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.image_outlined,
                      color: AppColors.textSecondary,
                      size: 24.spx,
                    ),
                  )
                : Icon(
                    Icons.image_outlined,
                    color: AppColors.textSecondary,
                    size: 24.spx,
                  ),
          ),
          SizedBox(width: 14.wpx),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name.isEmpty ? 'Item' : item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16.spx,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: 6.hpx),
                Text(
                  '₹${item.product.displayPrice}',
                  style: TextStyle(
                    color: AppColors.price,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.spx,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.wpx),
          Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 14.wpx,
                  vertical: 8.hpx,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(18.rpx),
                ),
                child: Text(
                  '${item.quantity}',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.spx,
                  ),
                ),
              ),
              SizedBox(height: 5.hpx),
              Text(
                'Qty',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.spx,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BillDetailsCard extends StatelessWidget {
  const _BillDetailsCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final itemsTotal = order.items.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );
    final deliveryCharge = _deliveryCharge(order, itemsTotal);
    final grandTotal = order.totalPrice > 0
        ? order.totalPrice
        : itemsTotal + deliveryCharge;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Details',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 20.spx,
            ),
          ),
          SizedBox(height: 18.hpx),
          _BillRowLine(
            icon: Icons.article_outlined,
            label: 'Items Total',
            value: '₹${itemsTotal.toStringAsFixed(2)}',
          ),
          SizedBox(height: 14.hpx),
          _BillRowLine(
            icon: Icons.pedal_bike_outlined,
            label: 'Delivery Charge',
            value: '₹${deliveryCharge.toStringAsFixed(2)}',
          ),
          Divider(height: 34.hpx, color: AppColors.border),
          _SummaryRow(
            label: 'Grand Total',
            value: '₹${grandTotal.toStringAsFixed(2)}',
            strong: true,
          ),
        ],
      ),
    );
  }

  static double _deliveryCharge(OrderModel order, double itemsTotal) {
    final explicit = _readNumber(order.raw, const [
      'deliveryFee',
      'delivery_fee',
      'deliveryCharge',
      'delivery_charge',
      'productDeliveryCharge',
      'product_delivery_charge',
      'shippingCharge',
      'shipping_charge',
      'shippingFee',
      'shipping_fee',
      'deliveryCost',
      'delivery_cost',
    ]);
    if (explicit > 0) return explicit;
    final inferred = order.totalPrice - itemsTotal;
    return inferred > 0 ? inferred : 0;
  }

  static double _readNumber(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final parsed = _number(raw[key]);
      if (parsed > 0) return parsed;
      for (final wrapper in const ['summary', 'totals', 'bill', 'pricing']) {
        final nested = raw[wrapper];
        if (nested is Map) {
          final nestedParsed = _number(nested[key]);
          if (nestedParsed > 0) return nestedParsed;
        }
      }
    }
    return 0;
  }

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.all(20.rpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18.rpx),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIcon(icon: icon),
        SizedBox(width: 12.wpx),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18.spx,
                ),
              ),
              SizedBox(height: 4.hpx),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.spx,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48.rpx,
      height: 48.rpx,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.accent, size: 24.spx),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 9.hpx),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? AppColors.primary : AppColors.textSecondary,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                fontSize: strong ? 17.spx : 15.spx,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
              fontSize: strong ? 17.spx : 15.spx,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillRowLine extends StatelessWidget {
  const _BillRowLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 20.spx),
        SizedBox(width: 10.wpx),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 15.spx,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.price,
            fontWeight: FontWeight.w800,
            fontSize: 15.spx,
          ),
        ),
      ],
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
  LatLng? _displayedPartnerLoc;
  LatLng? _targetPartnerLoc;
  Timer? _glideTimer;

  @override
  void didUpdateWidget(covariant _LiveMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final data = _TrackingMapData.fromOrder(widget.order);
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
      if (!mounted || _displayedPartnerLoc == null || _targetPartnerLoc == null) {
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

  Set<Marker> _animatedMarkers(_TrackingMapData data) {
    final partnerPos = _displayedPartnerLoc ?? data.deliveryPersonLocation;
    return {
      if (data.deliveryLocation != null)
        Marker(
          markerId: const MarkerId('deliveryLocation'),
          position: data.deliveryLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Delivery Address'),
        ),
      if (data.pickupLocation != null)
        Marker(
          markerId: const MarkerId('pickupLocation'),
          position: data.pickupLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      if (partnerPos != null)
        Marker(
          markerId: const MarkerId('deliveryPartner'),
          position: partnerPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
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
              },
              style: _mapStyleJson,
              markers: _animatedMarkers(data),
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
            if (data.deliveryPersonLocation != null)
              Positioned(
                right: 12.wpx,
                bottom: 12.hpx,
                child: _LivePulseDot(),
              ),
          ],
        ),
      ),
    );
  }

  double _distanceKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final x = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(a.latitude)) * cos(_rad(b.latitude)) *
        sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(x), sqrt(1 - x));
  }

  double _rad(double v) => v * pi / 180;
}

class _LivePulseDot extends StatefulWidget {
  const _LivePulseDot();

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 8 + (6 * _animation.value),
              height: 8 + (6 * _animation.value),
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
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
          _coordinateFrom(raw['dropLocation']) ??
          _coordinateFrom({
            'latitude':
                raw['customerLatitude'] ??
                raw['latitude'] ??
                raw['deliveryLatitude'] ??
                raw['delivery_latitude'],
            'longitude':
                raw['customerLongitude'] ??
                raw['longitude'] ??
                raw['deliveryLongitude'] ??
                raw['delivery_longitude'],
          }),
      pickupLocation:
          _coordinateFrom(raw['pickupLocation']) ??
          _coordinateFrom(raw['vendorLocation']) ??
          _coordinateFrom(raw['storeLocation']),
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
          infoWindow: const InfoWindow(title: 'Delivery Address'),
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
          infoWindow: const InfoWindow(title: 'Delivery Partner'),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.rpx),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 72.rpx, color: AppColors.price),
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
            style: TextStyle(
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
    (icon: Icons.error_outline, title: 'Ordered By Mistake'),
    (
      icon: Icons.location_off_outlined,
      title: 'Wrong Address Or Delivery Location',
    ),
    (icon: Icons.local_offer_outlined, title: 'Found A Better Price Or Offer'),
    (icon: Icons.cancel_outlined, title: "Don't need the items anymore"),
    (icon: Icons.access_time, title: 'Delivery Time Is Too Long'),
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
