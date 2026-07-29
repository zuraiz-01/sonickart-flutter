String normalizeNotificationStatus(String? status) {
  final normalized = (status ?? '').trim().toLowerCase().replaceAll(
    RegExp(r'[-\s]+'),
    '_',
  );
  final compact = normalized.replaceAll('_', '');

  if (compact == 'orderplaced') return 'placed';
  if (compact == 'waitingpickup' ||
      compact == 'waitingforpickup' ||
      compact == 'orderwaitingforpickup' ||
      compact == 'packagewaitingforpickup') {
    return 'placed';
  }
  if (compact == 'packageplaced' || compact == 'packagebooked') {
    return 'placed';
  }
  if (compact == 'orderaccepted') return 'accepted';
  if (compact == 'packageaccepted') return 'accepted';
  if (compact == 'onthewaytopickup' ||
      compact == 'orderonthewaytopickup' ||
      compact == 'packageonthewaytopickup') {
    return 'accepted';
  }
  if (compact == 'orderassigned') return 'assigned';
  if (compact == 'packageassigned' ||
      compact == 'partnerassigned' ||
      compact == 'deliveryassigned' ||
      compact == 'deliverypartnerassigned' ||
      compact == 'assignedtopartner') {
    return 'assigned';
  }
  if (compact == 'orderconfirmed') return 'confirmed';
  if (compact == 'packageconfirmed') return 'confirmed';
  if (compact == 'orderdelivered') return 'delivered';
  if (compact == 'packagedelivered') return 'delivered';
  if (compact == 'ordercompleted') return 'completed';
  if (compact == 'packagecompleted') return 'completed';
  if (compact == 'picked' ||
      compact == 'pickup' ||
      compact == 'pickedup' ||
      compact == 'orderpickedup' ||
      compact == 'packagepickedup' ||
      compact == 'arriving' ||
      compact == 'orderarriving' ||
      compact == 'packagearriving') {
    return 'picked_up';
  }
  if (compact == 'intransit' ||
      compact == 'transit' ||
      compact == 'orderintransit' ||
      compact == 'packageintransit') {
    return 'in_transit';
  }
  if (compact == 'ontheway' ||
      compact == 'orderontheway' ||
      compact == 'packageontheway' ||
      compact == 'onthewaytodelivery' ||
      compact == 'orderonthewaytodelivery' ||
      compact == 'packageonthewaytodelivery') {
    return 'on_the_way';
  }
  if (compact == 'outfordelivery' ||
      compact == 'orderoutfordelivery' ||
      compact == 'packageoutfordelivery') {
    return 'out_for_delivery';
  }
  if (normalized == 'complete') return 'completed';
  if (normalized == 'canceled') return 'cancelled';
  return normalized;
}

bool shouldSuppressOrderStatusNotification({
  required bool package,
  String? status,
  Iterable<String?> text = const [],
}) {
  return notificationDisplayStatus(
        package: package,
        status: status,
        text: text,
      ) ==
      null;
}

String? notificationDisplayStatus({
  required bool package,
  String? status,
  Iterable<String?> text = const [],
}) {
  final normalizedStatus = normalizeNotificationStatus(status);
  final explicit = package
      ? _allowedPackageNotificationStatus(status)
      : _allowedOrderNotificationStatus(status);
  if (explicit != null) return explicit;
  if (normalizedStatus.isNotEmpty) return null;

  return package
      ? _allowedPackageStatusFromText(text)
      : _allowedOrderStatusFromText(text);
}

String? _allowedOrderNotificationStatus(String? status) {
  return switch (normalizeNotificationStatus(status)) {
    'placed' || 'pending' => 'placed',
    'accepted' || 'assigned' || 'confirmed' => 'assigned',
    'picked_up' ||
    'in_transit' ||
    'on_the_way' ||
    'out_for_delivery' => 'picked_up',
    'delivered' || 'completed' => 'delivered',
    _ => null,
  };
}

String? _allowedPackageNotificationStatus(String? status) {
  return switch (normalizeNotificationStatus(status)) {
    'placed' || 'pending' || 'booked' => 'booked',
    'accepted' ||
    'assigned' ||
    'confirmed' ||
    'partner_assigned' ||
    'delivery_assigned' ||
    'delivery_partner_assigned' ||
    'assigned_to_partner' ||
    'rider_assigned' ||
    'driver_assigned' => 'assigned',
    'picked_up' ||
    'in_transit' ||
    'on_the_way' ||
    'out_for_delivery' => 'picked_up',
    'delivered' || 'completed' => 'delivered',
    _ => null,
  };
}

String? _allowedOrderStatusFromText(Iterable<String?> values) {
  final text = values
      .whereType<String>()
      .join(' ')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.isEmpty) return null;

  if (text.contains('delivered') || text.contains('completed')) {
    return 'delivered';
  }
  if (text.contains('accepted') ||
      text.contains('confirmed') ||
      text.contains('assigned')) {
    return 'assigned';
  }
  if (text.contains('picked up') ||
      text.contains('pickup') ||
      text.contains('pickedup') ||
      text.contains('on the way') ||
      text.contains('out for delivery') ||
      text.contains('in transit')) {
    return 'picked_up';
  }
  if (text.contains('placed') || text.contains('pending')) {
    return 'placed';
  }
  return null;
}

String? _allowedPackageStatusFromText(Iterable<String?> values) {
  final text = values
      .whereType<String>()
      .join(' ')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.isEmpty) return null;

  if (text.contains('delivered') || text.contains('completed')) {
    return 'delivered';
  }
  if (text.contains('picked up') ||
      text.contains('pickup') ||
      text.contains('pickedup') ||
      text.contains('on the way') ||
      text.contains('out for delivery') ||
      text.contains('in transit')) {
    return 'picked_up';
  }
  if (text.contains('accepted') ||
      text.contains('confirmed') ||
      text.contains('assigned') ||
      text.contains('partner assigned')) {
    return 'assigned';
  }
  if (text.contains('booked') || text.contains('placed')) {
    return 'booked';
  }
  return null;
}

({String title, String body})? orderStatusNotificationCopy({
  required String status,
  required String orderNumber,
  bool package = false,
}) {
  final normalized = notificationDisplayStatus(
    package: package,
    status: status,
  );
  if (normalized == null) return null;

  if (package) {
    return switch (normalized) {
      'booked' => (
        title: 'Package Booked',
        body: 'Your Package Has Been Booked.',
      ),
      'assigned' => (
        title: 'Partner Assigned',
        body: 'A Delivery Partner Has Been Assigned.',
      ),
      'picked_up' => (
        title: 'Package Picked Up',
        body: 'Your Package Has Been Picked Up.',
      ),
      'delivered' => (
        title: 'Package Delivered',
        body: 'Your Package Has Been Delivered.',
      ),
      _ => null,
    };
  }

  return switch (normalized) {
    'placed' => (title: 'Order Placed', body: 'Your Order Has Been Placed.'),
    'assigned' => (
      title: 'Partner Assigned',
      body: 'A Delivery Partner Has Been Assigned.',
    ),
    'picked_up' => (
      title: 'Order Picked Up',
      body: 'Your Order Has Been Picked Up.',
    ),
    'delivered' => (
      title: 'Order Delivered',
      body: 'Your Order Has Been Delivered.',
    ),
    _ => null,
  };
}
