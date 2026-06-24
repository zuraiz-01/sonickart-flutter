import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cart/app/data/models/order_model.dart';
import 'package:sonic_cart/app/modules/live_tracking_view.dart';

void main() {
  test('in-transit distance reads GeoJSON rider coordinates as lng-lat', () {
    final order = _trackingOrder(
      deliveryPersonLocation: {
        'type': 'Point',
        'coordinates': [67.3344, 25.1122],
      },
    );

    final distance = liveTrackingDistanceKmForTesting(order);

    expect(distance, isNotNull);
    expect(distance!, greaterThan(30));
    expect(distance, lessThan(60));
  });

  test('impossible tracking distances are hidden', () {
    final order = _trackingOrder(
      deliveryPersonLocation: {'latitude': 0, 'longitude': 0},
    );

    expect(liveTrackingDistanceKmForTesting(order), isNull);
  });

  test('accepted order shows delivery partner name and number', () {
    final order = _trackingOrder(
      status: 'accepted',
      deliveryPersonLocation: const {'latitude': 24.9, 'longitude': 67.1},
      extra: const {
        'delivery_partner_name': 'Ahmed Rider',
        'delivery_partner_phone': '03001234567',
      },
    );

    final contact = deliveryPartnerContact(order);

    expect(shouldShowDeliveryPartnerContact(order), isTrue);
    expect(contact.name, 'Ahmed Rider');
    expect(contact.phone, '03001234567');
  });

  test('pending order keeps delivery partner contact hidden', () {
    final order = _trackingOrder(
      status: 'pending',
      deliveryPersonLocation: const {'latitude': 24.9, 'longitude': 67.1},
      extra: const {
        'deliveryPartner': {'name': 'Ahmed Rider', 'phone': '03001234567'},
      },
    );

    expect(shouldShowDeliveryPartnerContact(order), isFalse);
  });
}

OrderModel _trackingOrder({
  required Object deliveryPersonLocation,
  String status = 'in_transit',
  Map<String, dynamic> extra = const {},
}) {
  return OrderModel(
    id: 'ORD1',
    items: const [],
    customerName: 'Customer',
    customerPhone: '03000000000',
    deliveryAddress: 'Customer drop address',
    paymentMode: 'COD',
    totalPrice: 500,
    status: status,
    createdAt: DateTime.utc(2026, 1, 1),
    raw: {
      'id': 'ORD1',
      'status': status,
      'deliveryLocation': {
        'address': 'Customer drop address',
        'latitude': 24.8607,
        'longitude': 67.0011,
      },
      'deliveryPersonLocation': deliveryPersonLocation,
      ...extra,
    },
  );
}
