String normalizeNotificationStatus(String? status) {
  final normalized = (status ?? '').trim().toLowerCase().replaceAll(
    RegExp(r'[-\s]+'),
    '_',
  );
  final compact = normalized.replaceAll('_', '');

  if (compact == 'orderplaced') return 'placed';
  if (compact == 'packageplaced' || compact == 'packagebooked') {
    return 'placed';
  }
  if (compact == 'orderaccepted') return 'accepted';
  if (compact == 'packageaccepted') return 'accepted';
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
      compact == 'packagepickedup') {
    return 'picked_up';
  }
  if (compact == 'intransit' ||
      compact == 'transit' ||
      compact == 'orderintransit') {
    return 'in_transit';
  }
  if (compact == 'ontheway' || compact == 'orderontheway') {
    return 'on_the_way';
  }
  if (compact == 'outfordelivery') return 'out_for_delivery';
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
    'accepted' || 'assigned' || 'confirmed' => 'accepted',
    'picked_up' => 'picked_up',
    'delivered' || 'completed' => 'delivered',
    _ => null,
  };
}

String? _allowedPackageNotificationStatus(String? status) {
  return switch (normalizeNotificationStatus(status)) {
    'placed' || 'pending' || 'booked' => 'placed',
    'accepted' ||
    'assigned' ||
    'confirmed' ||
    'partner_assigned' ||
    'delivery_assigned' ||
    'delivery_partner_assigned' ||
    'assigned_to_partner' ||
    'rider_assigned' ||
    'driver_assigned' => 'accepted',
    'picked_up' => 'picked_up',
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
    return 'accepted';
  }
  if (text.contains('picked up') ||
      text.contains('pickup') ||
      text.contains('pickedup')) {
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
      text.contains('pickedup')) {
    return 'picked_up';
  }
  if (text.contains('accepted') ||
      text.contains('confirmed') ||
      text.contains('assigned') ||
      text.contains('partner assigned')) {
    return 'accepted';
  }
  if (text.contains('placed') ||
      text.contains('pending') ||
      text.contains('booked')) {
    return 'placed';
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

  final cleanNumber = orderNumber.trim().replaceFirst(RegExp(r'^#+'), '');
  final code = cleanNumber.isEmpty ? '' : '#$cleanNumber';
  String text(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (package) {
    return switch (normalized) {
      'placed' => (
        title: 'Package Booked',
        body: 'Your package has been booked.',
      ),
      'accepted' => (
        title: 'Partner Assigned',
        body: text(
          'A delivery partner has been assigned to your package $code.',
        ),
      ),
      'picked_up' => (
        title: text('Package $code Picked Up'),
        body: text('Your package $code has been picked up.'),
      ),
      'delivered' => (
        title: text('Package $code Delivered'),
        body: text('Your package $code has been delivered.'),
      ),
      _ => null,
    };
  }

  const subject = 'Order';
  const object = 'order';
  return switch (normalized) {
    'placed' => (
      title: text('$subject $code Placed'),
      body: text('Your $object $code has been placed.'),
    ),
    'accepted' => (
      title: text('$subject $code Accepted'),
      body: text('Your $object $code has been accepted.'),
    ),
    'picked_up' => (
      title: text('$subject $code Picked Up'),
      body: text('Your $object $code has been picked up.'),
    ),
    'delivered' => (
      title: text('$subject $code Delivered'),
      body: text('Your $object $code has been delivered.'),
    ),
    _ => null,
  };
}
