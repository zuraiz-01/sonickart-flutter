import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cart/app/core/services/local_notification_service.dart';

void main() {
  group('LocalNotificationService status dedupe keys', () {
    test('normalizes prefixed and numeric order ids to same accepted key', () {
      final prefixed = LocalNotificationService.statusDedupeKey(
        package: false,
        status: 'accepted',
        trackingNumber: 'ORDR00640',
      );
      final numeric = LocalNotificationService.statusDedupeKey(
        package: false,
        status: 'accepted',
        trackingNumber: '640',
      );

      expect(prefixed, isNotNull);
      expect(prefixed, numeric);
    });

    test(
      'normalizes order status aliases and display ids to one picked-up key',
      () {
        final numeric = LocalNotificationService.statusDedupeKey(
          package: false,
          status: 'picked_up',
          trackingNumber: '717',
        );
        final prefixed = LocalNotificationService.statusDedupeKey(
          package: false,
          status: 'order_picked_up',
          trackingNumber: 'ORDR00717',
        );

        expect(prefixed, isNotNull);
        expect(prefixed, numeric);
        expect(
          LocalNotificationService.notificationIdForDedupeKey(prefixed),
          LocalNotificationService.notificationIdForDedupeKey(numeric),
        );
        expect(
          LocalNotificationService.statusDedupeKey(
            package: false,
            status: 'order_on_the_way',
            trackingNumber: 'ORDR00717',
          ),
          numeric,
        );
        expect(
          LocalNotificationService.statusDedupeKey(
            package: false,
            status: 'in_transit',
            trackingNumber: '717',
          ),
          numeric,
        );
      },
    );

    test('infers accepted status and order id from notification copy', () {
      final explicit = LocalNotificationService.statusDedupeKey(
        package: false,
        status: 'accepted',
        trackingNumber: 'ORDR00640',
      );
      final inferred = LocalNotificationService.statusDedupeKey(
        package: false,
        title: 'Order Accepted',
        body: 'Your order 640 is accepted.',
      );

      expect(inferred, explicit);
      expect(
        LocalNotificationService.notificationIdForDedupeKey(inferred),
        LocalNotificationService.notificationIdForDedupeKey(explicit),
      );
    });

    test('package local and remote status updates share one key', () {
      final local = LocalNotificationService.statusDedupeKey(
        package: true,
        status: 'picked_up',
        identifiers: const ['PKG000158'],
        title: 'Package Picked Up',
        body: 'Your package order PKG000158 is picked up.',
      );
      final remote = LocalNotificationService.statusDedupeKey(
        package: true,
        status: 'picked_up',
        trackingNumber: '158',
      );

      expect(local, isNotNull);
      expect(local, remote);
      expect(
        LocalNotificationService.notificationIdForDedupeKey(local),
        LocalNotificationService.notificationIdForDedupeKey(remote),
      );
    });

    test('package assigned aliases share one accepted key', () {
      final assigned = LocalNotificationService.statusDedupeKey(
        package: true,
        status: 'assigned',
        trackingNumber: 'PKG000158',
      );
      final partnerAssigned = LocalNotificationService.statusDedupeKey(
        package: true,
        status: 'delivery_partner_assigned',
        trackingNumber: '158',
      );
      final inferred = LocalNotificationService.statusDedupeKey(
        package: true,
        title: 'Partner Assigned',
        body: 'A delivery partner has been assigned to your package #158.',
      );

      expect(assigned, isNotNull);
      expect(partnerAssigned, assigned);
      expect(inferred, assigned);
    });

    test('package dedupe prefers numeric package code across aliases', () {
      final fromIdList = LocalNotificationService.statusDedupeKey(
        package: true,
        status: 'delivery_partner_assigned',
        identifiers: const ['package-object-without-number', 'PKG000158'],
      );
      final fromTracking = LocalNotificationService.statusDedupeKey(
        package: true,
        status: 'assigned',
        trackingNumber: '158',
      );

      expect(fromIdList, fromTracking);
    });

    test('package booked aliases share one booked key', () {
      final placed = LocalNotificationService.statusDedupeKey(
        package: true,
        status: 'placed',
        trackingNumber: 'PKG000212',
      );
      final booked = LocalNotificationService.statusDedupeKey(
        package: true,
        status: 'package_booked',
        trackingNumber: '212',
      );

      expect(placed, booked);
      expect(placed, startsWith('package|booked|'));
    });

    test(
      'recipient id separates the same entity status for different users',
      () {
        final firstUser = LocalNotificationService.statusDedupeKey(
          package: false,
          status: 'accepted',
          trackingNumber: 'ORDR00717',
          recipientId: 'customer-1',
        );
        final secondUser = LocalNotificationService.statusDedupeKey(
          package: false,
          status: 'partner_assigned',
          trackingNumber: '717',
          recipientId: 'customer-2',
        );
        final firstUserAlias = LocalNotificationService.statusDedupeKey(
          package: false,
          status: 'assigned',
          trackingNumber: '717',
          recipientId: 'customer-1',
        );

        expect(firstUser, firstUserAlias);
        expect(firstUser, isNot(secondUser));
      },
    );
  });
}
