String normalizeNotificationStatus(String? status) {
  final normalized = (status ?? '').trim().toLowerCase().replaceAll(
    RegExp(r'[-\s]+'),
    '_',
  );
  final compact = normalized.replaceAll('_', '');

  if (compact == 'picked' ||
      compact == 'pickup' ||
      compact == 'pickedup' ||
      compact == 'orderpickedup') {
    return 'picked_up';
  }
  if (compact == 'intransit' ||
      compact == 'transit' ||
      compact == 'orderintransit') {
    return 'in_transit';
  }
  if (compact == 'outfordelivery') return 'out_for_delivery';
  if (normalized == 'complete') return 'completed';
  if (normalized == 'canceled') return 'cancelled';
  return normalized;
}

({String title, String body})? orderStatusNotificationCopy({
  required String status,
  required String orderNumber,
  bool package = false,
}) {
  final normalized = normalizeNotificationStatus(status);
  final cleanNumber = orderNumber.trim().replaceFirst(RegExp(r'^#+'), '');
  final code = cleanNumber.isEmpty ? '' : '#$cleanNumber';
  final subject = package ? 'Package' : 'Order';
  final object = package ? 'package order' : 'order';
  String text(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

  return switch (normalized) {
    'placed' || 'pending' || 'assigned' || 'confirmed' || 'available' => (
      title: text('$subject $code Placed'),
      body: text('Your $object $code has been placed.'),
    ),
    'accepted' => (
      title: text('$subject $code Accepted'),
      body: text('Your $object $code has been accepted.'),
    ),
    'picked_up' || 'prepared' || 'ready' => (
      title: text('$subject $code Picked Up'),
      body: text('Your $object $code has been picked up.'),
    ),
    'in_transit' || 'out_for_delivery' || 'arriving' => (
      title: text('$subject $code On The Way'),
      body: text('Your $object $code is on the way.'),
    ),
    'delivered' || 'completed' => (
      title: text('$subject $code Delivered'),
      body: text('Your $object $code has been delivered.'),
    ),
    'cancelled' || 'rejected' || 'failed' => (
      title: text('$subject $code Cancelled'),
      body: text('Your $object $code was cancelled.'),
    ),
    _ => null,
  };
}
