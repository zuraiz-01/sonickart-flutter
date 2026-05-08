import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';

import '../data/models/cart_item_model.dart';
import '../data/models/order_model.dart';
import '../theme/app_colors.dart';
import 'order_controller.dart';

class CustomerOrderDetailsView extends StatefulWidget {
  const CustomerOrderDetailsView({super.key});

  @override
  State<CustomerOrderDetailsView> createState() =>
      _CustomerOrderDetailsViewState();
}

class _CustomerOrderDetailsViewState extends State<CustomerOrderDetailsView> {
  late final OrderController controller;
  late final String orderId;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    controller = Get.find<OrderController>();
    orderId = Get.arguments?['orderId']?.toString() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshDetails());
  }

  Future<void> _refreshDetails() async {
    final localOrder = _resolveOrder();
    if (localOrder == null && orderId.trim().isEmpty) return;
    setState(() => _isRefreshing = true);
    try {
      if (localOrder != null) {
        await controller.refreshOrderDetails(localOrder);
      } else {
        await controller.refreshTrackingOrder(orderId);
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  OrderModel? _resolveOrder() {
    final byId = controller.findOrderById(orderId);
    final selected = controller.selectedOrder.value;
    final selectedMatches =
        selected != null &&
        (orderId.trim().isEmpty ||
            controller.orderIdentifiers(selected).contains(orderId.trim()));
    if (byId != null && selected != null) {
      final byIdHasItems = byId.items.isNotEmpty;
      final selectedHasItems = selected.items.isNotEmpty;
      if (selectedMatches && selectedHasItems && !byIdHasItems) {
        return selected;
      }
    }
    return byId ?? (selectedMatches ? selected : null);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final order = _resolveOrder();

      if (order == null) {
        return Scaffold(
          backgroundColor: AppColors.primary,
          body: SafeArea(
            child: Column(
              children: [
                _LiveHeader(
                  title: 'Order Details',
                  secondTitle: _isRefreshing
                      ? 'Loading Order'
                      : 'Order Not Found',
                  onBack: Get.back,
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: AppColors.white,
                    child: Center(
                      child: _isRefreshing
                          ? const CircularProgressIndicator(
                              color: AppColors.primary,
                            )
                          : Text(
                              'Order Not Found.',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16.rpx,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final status = _normalizedStatus(order);
      final statusLabel = _statusLabel(status);
      final etaText = _etaText(order, status);
      final itemCount = order.items.length;
      final canCancel = !order.isInactive;

      return Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: Column(
            children: [
              _LiveHeader(
                title: statusLabel,
                secondTitle: etaText,
                onBack: Get.back,
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: AppColors.white,
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _refreshDetails,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        15.rpx,
                        15.rpx,
                        15.rpx,
                        28.rpx,
                      ),
                      children: [
                        if (_isRefreshing && order.items.isEmpty)
                          const LinearProgressIndicator(
                            color: AppColors.primary,
                            minHeight: 2,
                          ),
                        if (status != 'cancelled' && status != 'delivered')
                          _LiveStatusCard(order: order, status: status),
                        _PartnerCard(order: order, status: status),
                        _OrderSummaryCard(order: order, status: status),
                        if (order.items.isNotEmpty)
                          _OrderedItemsCard(
                            items: order.items,
                            itemCount: itemCount,
                          )
                        else
                          _OrderedItemsLoadingCard(isLoading: _isRefreshing),
                        _DeliveryDetailsCard(order: order),
                        _BillDetailsCard(order: order),
                        if (canCancel)
                          _CancelButton(
                            onPressed: () => controller.cancelOrder(order),
                          ),
                      ],
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
}

class _LiveHeader extends StatelessWidget {
  const _LiveHeader({
    required this.title,
    required this.secondTitle,
    required this.onBack,
  });

  final String title;
  final String secondTitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 68.hpx,
      color: AppColors.primary,
      child: Row(
        children: [
          SizedBox(
            width: 56.rpx,
            child: Center(
              child: IconButton(
                onPressed: onBack,
                icon: Icon(
                  Icons.chevron_left,
                  color: AppColors.white,
                  size: 24.rpx,
                ),
                style: IconButton.styleFrom(
                  fixedSize: Size(40.rpx, 40.rpx),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.rpx,
                  ),
                ),
                SizedBox(height: 3.hpx),
                Text(
                  secondTitle,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18.rpx,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 56.rpx),
        ],
      ),
    );
  }
}

class _LiveStatusCard extends StatelessWidget {
  const _LiveStatusCard({required this.order, required this.status});

  final OrderModel order;
  final String status;

  @override
  Widget build(BuildContext context) {
    return _Card(
      margin: EdgeInsets.only(bottom: 10.hpx),
      padding: EdgeInsets.all(15.rpx),
      border: true,
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.route, color: AppColors.primary, size: 18.rpx),
              SizedBox(width: 8.rpx),
              Text(
                'Live Tracking',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.rpx,
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10.hpx),
            child: Divider(height: 1, color: AppColors.border),
          ),
          _StatusInfoRow(
            icon: Icons.schedule,
            label: 'ETA',
            value: _etaText(order, status),
          ),
          SizedBox(height: 8.hpx),
          _StatusInfoRow(
            icon: Icons.info_outline,
            label: 'Status',
            value: _movementStatus(status),
          ),
        ],
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.order, required this.status});

  final OrderModel order;
  final String status;

  @override
  Widget build(BuildContext context) {
    final partner = _deliveryPartner(order);
    final partnerName = _string(
      partner['name'] ??
          partner['fullName'] ??
          partner['full_name'] ??
          partner['driverName'],
    );
    final partnerPhone = _string(
      partner['phone'] ?? partner['contactNumber'] ?? partner['mobile'],
    );
    final assigned = partnerName.isNotEmpty;

    return _IconInfoCard(
      icon: assigned ? Icons.phone : Icons.shopping_bag_outlined,
      title: assigned ? partnerName : 'We Will Soon Assign Delivery Partner',
      subtitle: assigned
          ? 'For Delivery instructions you can contact here'
          : _partnerMessage(status),
      linkText: partnerPhone,
      margin: EdgeInsets.only(top: 15.hpx),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order, required this.status});

  final OrderModel order;
  final String status;

  @override
  Widget build(BuildContext context) {
    return _Card(
      margin: EdgeInsets.only(top: 15.hpx, bottom: 5.hpx),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(10.rpx),
            child: Row(
              children: [
                const _CircleIcon(icon: Icons.shopping_bag_outlined),
                SizedBox(width: 10.rpx),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Order Summary',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 14.rpx,
                              ),
                            ),
                          ),
                          if (status == 'cancelled') ...[
                            SizedBox(width: 8.rpx),
                            const _CancelledBadge(),
                          ],
                        ],
                      ),
                      SizedBox(height: 3.hpx),
                      Text(
                        'Order ID - #${order.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.black.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w600,
                          fontSize: 11.rpx,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }
}

class _OrderedItemsCard extends StatelessWidget {
  const _OrderedItemsCard({required this.items, required this.itemCount});

  final List<CartItemModel> items;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return _Card(
      margin: EdgeInsets.only(top: 5.hpx, bottom: 15.hpx),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(10.rpx),
            child: Row(
              children: [
                const _CircleIcon(icon: Icons.shopping_bag_outlined),
                SizedBox(width: 10.rpx),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ordered Items ($itemCount)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.rpx,
                        ),
                      ),
                      SizedBox(height: 2.hpx),
                      Text(
                        'Items in your order',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11.rpx,
                          color: AppColors.black.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          SizedBox(height: 10.hpx),
          ...items.map(_OrderedItemRow.new),
          SizedBox(height: 5.hpx),
        ],
      ),
    );
  }
}

class _OrderedItemsLoadingCard extends StatelessWidget {
  const _OrderedItemsLoadingCard({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return _Card(
      margin: EdgeInsets.only(top: 5.hpx, bottom: 15.hpx),
      padding: EdgeInsets.all(16.rpx),
      border: true,
      child: Row(
        children: [
          const _CircleIcon(icon: Icons.shopping_bag_outlined),
          SizedBox(width: 12.rpx),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoading ? 'Loading Ordered Items' : 'Ordered Items',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.rpx,
                  ),
                ),
                SizedBox(height: 4.hpx),
                Text(
                  isLoading
                      ? 'Please wait while order details sync.'
                      : 'Items will appear when order details sync.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.rpx,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            SizedBox(
              width: 18.rpx,
              height: 18.rpx,
              child: const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderedItemRow extends StatelessWidget {
  const _OrderedItemRow(this.item);

  final CartItemModel item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.product.resolvedImageUrl;
    final mrp = double.tryParse(item.product.mrp) ?? 0;
    final price = item.unitPrice;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10.rpx, vertical: 5.hpx),
      padding: EdgeInsets.all(10.rpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12.rpx),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60.rpx,
            height: 60.rpx,
            margin: EdgeInsets.only(right: 12.rpx),
            padding: EdgeInsets.all(10.rpx),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(15.rpx),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.image_outlined,
                      color: AppColors.textSecondary,
                    ),
                  )
                : Center(
                    child: Text(
                      item.product.emoji.isNotEmpty ? item.product.emoji : '',
                      style: TextStyle(fontSize: 22.rpx),
                    ),
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleCase(
                    item.product.name.isEmpty ? 'Item' : item.product.name,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.rpx,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 4.hpx),
                Row(
                  children: [
                    Text(
                      '₹${_money(price)}',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.rpx,
                      ),
                    ),
                    if (mrp > price && price > 0) ...[
                      SizedBox(width: 8.rpx),
                      Text(
                        '₹${_money(mrp)}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.rpx,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 12.rpx),
          SizedBox(
            width: 50.rpx,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.rpx,
                    vertical: 6.hpx,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(16.rpx),
                  ),
                  child: Text(
                    '${item.quantity <= 0 ? 1 : item.quantity}',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.rpx,
                    ),
                  ),
                ),
                SizedBox(height: 4.hpx),
                Text(
                  'Qty',
                  style: TextStyle(
                    color: AppColors.black.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                    fontSize: 10.rpx,
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

class _DeliveryDetailsCard extends StatelessWidget {
  const _DeliveryDetailsCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return _IconInfoCard(
      icon: Icons.location_on_outlined,
      title: order.deliveryAddress.trim().isNotEmpty
          ? 'Delivery Address'
          : 'Delivery At Home',
      subtitle: order.deliveryAddress.trim().isNotEmpty
          ? order.deliveryAddress.trim()
          : 'Address unavailable',
      margin: EdgeInsets.symmetric(vertical: 15.hpx),
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

    return _Card(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.only(top: 18.hpx, bottom: 18.hpx),
      border: true,
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.rpx),
            child: Text(
              'Bill Details',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 17.rpx,
              ),
            ),
          ),
          SizedBox(height: 14.hpx),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.rpx),
            child: Column(
              children: [
                _BillRow(
                  icon: Icons.article_outlined,
                  title: 'Items Total (Incl. GST)',
                  price: itemsTotal,
                ),
                _BillRow(
                  icon: Icons.pedal_bike,
                  title: 'Delivery Charge',
                  price: deliveryCharge,
                ),
              ],
            ),
          ),
          Divider(height: 16.hpx, color: AppColors.border),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.rpx),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Grand Total',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 17.rpx,
                    ),
                  ),
                ),
                Text(
                  '₹${_money(grandTotal)}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 17.rpx,
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

class _IconInfoCard extends StatelessWidget {
  const _IconInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.linkText = '',
    this.margin,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String linkText;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return _Card(
      margin: margin,
      padding: EdgeInsets.all(10.rpx),
      bottomBorder: true,
      child: Row(
        children: [
          _CircleIcon(icon: icon),
          SizedBox(width: 10.rpx),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.rpx,
                  ),
                ),
                if (linkText.trim().isNotEmpty) ...[
                  SizedBox(height: 2.hpx),
                  Text(
                    linkText.trim(),
                    style: TextStyle(
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.rpx,
                    ),
                  ),
                ],
                SizedBox(height: 3.hpx),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.black.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                    fontSize: 11.rpx,
                    height: 1.35,
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

class _StatusInfoRow extends StatelessWidget {
  const _StatusInfoRow({
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
        Icon(icon, color: AppColors.accent, size: 17.rpx),
        SizedBox(width: 10.rpx),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.black.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w600,
                  fontSize: 11.rpx,
                ),
              ),
              SizedBox(height: 1.hpx),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.rpx,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.icon,
    required this.title,
    required this.price,
  });

  final IconData icon;
  final String title;
  final double price;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.hpx),
      child: Row(
        children: [
          Icon(icon, size: 16.rpx, color: AppColors.accent),
          SizedBox(width: 7.rpx),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.rpx),
            ),
          ),
          Text(
            '₹${_money(price)}',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.rpx),
          ),
        ],
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16.hpx),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.cancel, color: AppColors.white, size: 20.rpx),
        label: Text(
          'Cancel Order',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14.rpx,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          elevation: 5,
          padding: EdgeInsets.symmetric(vertical: 12.hpx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.rpx),
          ),
        ),
      ),
    );
  }
}

class _CancelledBadge extends StatelessWidget {
  const _CancelledBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.rpx, vertical: 2.hpx),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(4.rpx),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel, color: AppColors.error, size: 12.rpx),
          SizedBox(width: 4.rpx),
          Text(
            'Cancelled',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w800,
              fontSize: 10.rpx,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10.rpx),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.primary, size: 20.rpx),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding,
    this.margin,
    this.border = false,
    this.bottomBorder = false,
    this.shadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool border;
  final bool bottomBorder;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding ?? EdgeInsets.symmetric(vertical: 10.hpx),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(border ? 18.rpx : 15.rpx),
        border: border || bottomBorder
            ? Border(
                bottom: bottomBorder
                    ? BorderSide(color: AppColors.border, width: 0.7)
                    : BorderSide.none,
                top: border
                    ? BorderSide(color: AppColors.border)
                    : BorderSide.none,
                left: border
                    ? BorderSide(color: AppColors.border)
                    : BorderSide.none,
                right: border
                    ? BorderSide(color: AppColors.border)
                    : BorderSide.none,
              )
            : null,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

String _normalizedStatus(OrderModel order) {
  return (order.raw['deliveryStatus'] ??
          order.raw['delivery_status'] ??
          order.status)
      .toString()
      .trim()
      .toLowerCase();
}

String _statusLabel(String status) {
  if (status == 'cancelled') return 'Order Cancelled';
  if (status == 'delivered' || status == 'completed') return 'Order Delivered';
  if (status == 'confirmed' || status == 'accepted' || status == 'assigned') {
    return 'Order Confirmed';
  }
  if (status == 'arriving' || status == 'out_for_delivery') {
    return 'On The Way';
  }
  return 'Getting Things Ready';
}

String _etaText(OrderModel order, String status) {
  if (status == 'cancelled') return 'Cancelled';
  if (status == 'delivered' || status == 'completed') return 'Delivered';
  final eta = _readNumber(order.raw, const [
    'eta',
    'etaMinutes',
    'eta_minutes',
    'estimatedMinutes',
    'estimated_minutes',
  ]);
  if (eta > 0) {
    final minutes = eta.round();
    return '$minutes ${minutes == 1 ? 'min' : 'mins'}';
  }
  return 'Delivery In 10 Minutes';
}

String _movementStatus(String status) {
  if (status == 'pending') return 'Waiting For Pickup';
  if (status == 'assigned') return 'On The Way To Pickup';
  if (status == 'picked') return 'On The Way To Delivery';
  if (status == 'confirmed') return 'On The Way';
  if (status == 'out_for_delivery') return 'Out For Delivery';
  if (status == 'prepared') return 'Preparing Order';
  if (status == 'ready') return 'Ready For Pickup';
  return _titleCase(status.isEmpty ? 'Preparing Order' : status);
}

String _partnerMessage(String status) {
  if (status == 'cancelled') return 'This order has been cancelled';
  if (status == 'delivered') return 'This order has been delivered';
  return 'Your order is being prepared';
}

Map<String, dynamic> _deliveryPartner(OrderModel order) {
  final values = [
    order.raw['deliveryPartner'],
    order.raw['delivery_partner'],
    order.raw['driver'],
    order.raw['partner'],
  ];
  for (final value in values) {
    if (value is Map) return Map<String, dynamic>.from(value);
  }
  return const {};
}

double _deliveryCharge(OrderModel order, double itemsTotal) {
  final explicit = _readNumber(order.raw, const [
    'deliveryCharge',
    'delivery_charge',
    'productDeliveryCharge',
    'product_delivery_charge',
    'shippingCharge',
    'shipping_charge',
  ]);
  if (explicit > 0) return explicit;
  final inferred = order.totalPrice - itemsTotal;
  return inferred > 0 ? inferred : 0;
}

double _readNumber(Map<String, dynamic> raw, List<String> keys) {
  for (final key in keys) {
    final value = raw[key];
    if (value is num && value.isFinite) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null && parsed.isFinite) return parsed;
  }
  return 0;
}

String _string(Object? value) => value?.toString().trim() ?? '';

String _money(double value) {
  return value.isFinite ? value.toStringAsFixed(2) : '0.00';
}

String _titleCase(String value) {
  return value
      .trim()
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) {
        final lower = word.toLowerCase();
        if (lower.length <= 1) return lower.toUpperCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}
