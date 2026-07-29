import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cart/app/data/models/package_order_model.dart';
import 'package:sonic_cart/app/modules/package/package_order_details_view.dart';

void main() {
  PackageOrderModel packageOrder({required String status}) {
    return PackageOrderModel(
      id: 'PKG1',
      customerName: 'Customer',
      customerPhone: '03000000000',
      packageType: 'Parcel',
      pickupAddress: 'Pickup',
      pickupLatitude: 24.86,
      pickupLongitude: 67.01,
      dropAddress: 'Drop',
      dropLatitude: 24.9,
      dropLongitude: 67.08,
      distanceKm: 5,
      deliveryCharge: 50,
      totalPrice: 50,
      status: status,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  test(
    'package tracking map reads snake case delivery partner coordinates',
    () {
      final order = PackageOrderModel(
        id: 'PKG1',
        customerName: 'Customer',
        customerPhone: '03000000000',
        packageType: 'Parcel',
        pickupAddress: 'Pickup',
        pickupLatitude: 24.86,
        pickupLongitude: 67.01,
        dropAddress: 'Drop',
        dropLatitude: 24.9,
        dropLongitude: 67.08,
        distanceKm: 5,
        deliveryCharge: 50,
        totalPrice: 50,
        status: 'accepted',
        createdAt: DateTime.utc(2026, 1, 1),
        raw: const {
          'delivery_person_location': {'latitude': 24.87, 'longitude': 67.02},
        },
      );

      final data = packageTrackingMapDataForTesting(order);

      expect(data.hasPickup, isTrue);
      expect(data.hasDrop, isTrue);
      expect(data.hasDeliveryPartner, isTrue);
      expect(data.focusPointCount, 2);
      expect(data.liveDistanceKm, isNotNull);
    },
  );

  test(
    'booked package map shows only user location even if partner location exists',
    () {
      final order = PackageOrderModel(
        id: 'PKG1',
        customerName: 'Customer',
        customerPhone: '03000000000',
        packageType: 'Parcel',
        pickupAddress: 'Pickup',
        pickupLatitude: 24.86,
        pickupLongitude: 67.01,
        dropAddress: 'Drop',
        dropLatitude: 24.9,
        dropLongitude: 67.08,
        distanceKm: 5,
        deliveryCharge: 50,
        totalPrice: 50,
        status: 'pending',
        createdAt: DateTime.utc(2026, 1, 1),
        raw: const {
          'delivery_person_location': {'latitude': 24.87, 'longitude': 67.02},
        },
      );

      final data = packageTrackingMapDataForTesting(order);

      expect(data.hasUserLocation, isTrue);
      expect(data.hasDeliveryPartner, isFalse);
      expect(data.displayPointCount, 1);
      expect(data.focusPointCount, 1);
      expect(data.polylineCount, 0);
      expect(data.liveDistanceKm, isNull);
    },
  );

  test('package live map stays visible before delivery completes', () {
    final order = packageOrder(status: 'out_for_delivery');

    expect(packageShouldShowLiveMapForTesting(order), isTrue);
  });

  test('package live map is hidden after delivery completes', () {
    final order = packageOrder(status: 'delivered');

    expect(packageShouldShowLiveMapForTesting(order), isFalse);
  });

  test('package status headings use customer-facing copy', () {
    expect(packageStatusHeadingForTesting('pending'), 'Package Booked');
    expect(packageStatusHeadingForTesting('assigned'), 'Partner Assigned');
    expect(packageStatusHeadingForTesting('accepted'), 'Partner Assigned');
    expect(packageStatusHeadingForTesting('confirmed'), 'Partner Assigned');
    expect(
      packageStatusHeadingForTesting('delivery_partner_assigned'),
      'Partner Assigned',
    );
    expect(
      packageStatusHeadingForTesting('assigned to partner'),
      'Partner Assigned',
    );
    expect(
      packageStatusHeadingForTesting('out for delivery'),
      'Package Picked Up',
    );
    expect(
      packageStatusHeadingForTesting('package picked up'),
      'Package Picked Up',
    );
    expect(packageStatusHeadingForTesting('delivered'), 'Package Delivered');
  });
}
