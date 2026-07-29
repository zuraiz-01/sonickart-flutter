enum PackageRecipientMatch { matched, mismatched, unspecified }

const storedPackageOrdersKey = 'package_orders';

PackageRecipientMatch packageRecipientMatch({
  required Map<String, dynamic> data,
  required String currentUserId,
  required String currentUserPhone,
}) {
  final recipientIds = <String>{
    ..._values(data, const [
      'recipientUserId',
      'recipient_user_id',
      'recipientId',
      'recipient_id',
      'targetUserId',
      'target_user_id',
      'customerId',
      'customer_id',
      'userId',
      'user_id',
    ]),
    ..._nestedValues(
      data,
      const ['recipient', 'customer'],
      const ['id', '_id', 'userId', 'user_id'],
    ),
  };
  final participantIds = <String>{
    ..._values(data, const [
      'senderUserId',
      'sender_user_id',
      'receiverUserId',
      'receiver_user_id',
    ]),
    ..._nestedValues(
      data,
      const ['sender', 'receiver'],
      const ['id', '_id', 'userId', 'user_id'],
    ),
  };
  final participantPhones = <String>{
    ..._values(data, const [
      'senderPhone',
      'sender_phone',
      'receiverPhone',
      'receiver_phone',
    ]),
    ..._nestedValues(
      data,
      const ['sender', 'receiver'],
      const ['phone', 'phoneNumber', 'phone_number', 'mobile'],
    ),
  };

  final hasExplicitIdentity =
      recipientIds.isNotEmpty ||
      participantIds.isNotEmpty ||
      participantPhones.isNotEmpty;
  if (!hasExplicitIdentity) return PackageRecipientMatch.unspecified;

  final normalizedUserId = _normalizeIdentity(currentUserId);
  if (normalizedUserId.isNotEmpty &&
      {
        ...recipientIds,
        ...participantIds,
      }.map(_normalizeIdentity).contains(normalizedUserId)) {
    return PackageRecipientMatch.matched;
  }

  final normalizedPhone = _normalizePhone(currentUserPhone);
  if (normalizedPhone.isNotEmpty &&
      participantPhones.map(_normalizePhone).contains(normalizedPhone)) {
    return PackageRecipientMatch.matched;
  }

  return PackageRecipientMatch.mismatched;
}

bool packageNotificationBelongsToKnownOrder({
  required Map<String, dynamic> data,
  required Iterable<Object?> storedOrders,
}) {
  final incomingIds = packageNotificationIdentifiers(data).toSet();
  if (incomingIds.isEmpty) return false;

  for (final value in storedOrders) {
    if (value is! Map) continue;
    final orderIds = packageNotificationIdentifiers(
      Map<String, dynamic>.from(value),
    );
    if (orderIds.any(incomingIds.contains)) return true;
  }
  return false;
}

List<String> packageNotificationIdentifiers(Map<String, dynamic> data) {
  return _values(data, const [
        'packageOrderId',
        'package_order_id',
        'packageId',
        'package_id',
        'delivery_code',
        'orderId',
        'order_id',
        'orderNumber',
        'order_number',
        'id',
        '_id',
      ])
      .map(_normalizePackageId)
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

Iterable<String> _values(Map<String, dynamic> data, List<String> keys) sync* {
  for (final key in keys) {
    final value = data[key];
    if (value is Iterable && value is! String) {
      for (final item in value) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) yield text;
      }
      continue;
    }
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text != '{}') yield text;
  }
}

Iterable<String> _nestedValues(
  Map<String, dynamic> data,
  List<String> parents,
  List<String> keys,
) sync* {
  for (final parent in parents) {
    final value = data[parent];
    if (value is Map) {
      yield* _values(Map<String, dynamic>.from(value), keys);
    }
  }
}

String _normalizeIdentity(String value) {
  return value.trim().toLowerCase();
}

String _normalizePhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 10) return digits;
  return digits.substring(digits.length - 10);
}

String _normalizePackageId(String value) {
  var normalized = value.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '',
  );
  normalized = normalized.replaceFirst(RegExp(r'^pkg'), '');
  if (RegExp(r'^\d+$').hasMatch(normalized)) {
    normalized = normalized.replaceFirst(RegExp(r'^0+'), '');
    return normalized.isEmpty ? '0' : normalized;
  }
  return normalized;
}
