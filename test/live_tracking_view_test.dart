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
}

OrderModel _trackingOrder({required Object deliveryPersonLocation}) {
  return OrderModel(
    id: 'ORD1',
    items: const [],
    customerName: 'Customer',
    customerPhone: '03000000000',
    deliveryAddress: 'Customer drop address',
    paymentMode: 'COD',
    totalPrice: 500,
    status: 'in_transit',
    createdAt: DateTime.utc(2026, 1, 1),
    raw: {
      'id': 'ORD1',
      'status': 'in_transit',
      'deliveryLocation': {
        'address': 'Customer drop address',
        'latitude': 24.8607,
        'longitude': 67.0011,
      },
      'deliveryPersonLocation': deliveryPersonLocation,
    },
  );
}
