import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cart/app/core/services/status_notification_copy.dart';

void main() {
  group('status notification allow-list', () {
    test(
      'keeps only placed accepted picked-up and delivered order notifications',
      () {
        for (final entry in const {
          'placed': 'placed',
          'pending': 'placed',
          'accepted': 'accepted',
          'assigned': 'accepted',
          'confirmed': 'accepted',
          'picked': 'picked_up',
          'pickup': 'picked_up',
          'pickedup': 'picked_up',
          'picked_up': 'picked_up',
          'order picked up': 'picked_up',
          'delivered': 'delivered',
          'completed': 'delivered',
        }.entries) {
          expect(
            shouldSuppressOrderStatusNotification(
              package: false,
              status: entry.key,
            ),
            isFalse,
            reason: entry.key,
          );
          expect(
            notificationDisplayStatus(package: false, status: entry.key),
            entry.value,
          );
        }
      },
    );

    test('suppresses order statuses outside the allow-list', () {
      for (final status in [
        'prepared',
        'ready',
        'in_transit',
        'on_the_way',
        'on the way',
        'out_for_delivery',
        'arriving',
        'cancelled',
        'rejected',
        'failed',
      ]) {
        expect(
          shouldSuppressOrderStatusNotification(package: false, status: status),
          isTrue,
          reason: status,
        );
      }
    });

    test(
      'keeps only assigned picked-up and delivered package notifications',
      () {
        for (final entry in const {
          'assigned': 'accepted',
          'partner_assigned': 'accepted',
          'delivery_partner_assigned': 'accepted',
          'assigned to partner': 'accepted',
          'accepted': 'accepted',
          'confirmed': 'accepted',
          'picked_up': 'picked_up',
          'package picked up': 'picked_up',
          'delivered': 'delivered',
          'completed': 'delivered',
        }.entries) {
          expect(
            shouldSuppressOrderStatusNotification(
              package: true,
              status: entry.key,
            ),
            isFalse,
            reason: entry.key,
          );
          expect(
            notificationDisplayStatus(package: true, status: entry.key),
            entry.value,
          );
        }
      },
    );

    test('suppresses package booked notifications', () {
      for (final status in const [
        'pending',
        'placed',
        'booked',
        'package booked',
      ]) {
        expect(
          shouldSuppressOrderStatusNotification(package: true, status: status),
          isTrue,
          reason: status,
        );
        expect(
          notificationDisplayStatus(package: true, status: status),
          isNull,
          reason: status,
        );
      }
    });

    test('suppresses generic notifications', () {
      expect(
        shouldSuppressOrderStatusNotification(
          package: false,
          text: const ['New offer', 'Tap to view latest deals'],
        ),
        isTrue,
      );
    });

    test('infers allowed order status from text when status is missing', () {
      expect(
        notificationDisplayStatus(
          package: false,
          text: const ['Order Placed', 'Your order #123 has been placed.'],
        ),
        'placed',
      );
      expect(
        notificationDisplayStatus(
          package: false,
          text: const ['Order Accepted', 'Your order #123 has been accepted.'],
        ),
        'accepted',
      );
      expect(
        notificationDisplayStatus(
          package: false,
          text: const [
            'Order Picked Up',
            'Your order #123 has been picked up.',
          ],
        ),
        'picked_up',
      );
      expect(
        notificationDisplayStatus(
          package: false,
          text: const [
            'Order Delivered',
            'Your order #123 has been delivered.',
          ],
        ),
        'delivered',
      );
    });

    test('suppresses disallowed order status text when status is missing', () {
      expect(
        shouldSuppressOrderStatusNotification(
          package: false,
          text: const ['Order update', 'Your order is on the way.'],
        ),
        isTrue,
      );
    });

    test('infers package status from text when status is missing', () {
      expect(
        notificationDisplayStatus(
          package: true,
          text: const ['Package Booked', 'Your package #123 has been booked.'],
        ),
        isNull,
      );
      expect(
        notificationDisplayStatus(
          package: true,
          text: const [
            'Partner Assigned',
            'A delivery partner has been assigned.',
          ],
        ),
        'accepted',
      );
      expect(
        notificationDisplayStatus(
          package: true,
          text: const [
            'Package Picked Up',
            'Your package #123 has been picked up.',
          ],
        ),
        'picked_up',
      );
      expect(
        notificationDisplayStatus(
          package: true,
          text: const [
            'Package Delivered',
            'Your package #123 has been delivered.',
          ],
        ),
        'delivered',
      );
    });

    test('explicit status wins over conflicting text', () {
      expect(
        shouldSuppressOrderStatusNotification(
          package: false,
          status: 'in_transit',
          text: const ['Order Picked Up', 'Your order has been picked up.'],
        ),
        isTrue,
      );
      expect(
        notificationDisplayStatus(
          package: false,
          status: 'picked_up',
          text: const ['Order update', 'Your order is on the way.'],
        ),
        'picked_up',
      );
    });

    test('builds copy only for allowed order statuses', () {
      expect(
        orderStatusNotificationCopy(
          status: 'placed',
          orderNumber: '123',
        )?.title,
        'Order #123 Placed',
      );
      expect(
        orderStatusNotificationCopy(
          status: 'accepted',
          orderNumber: '123',
        )?.title,
        'Order #123 Accepted',
      );
      expect(
        orderStatusNotificationCopy(
          status: 'picked_up',
          orderNumber: '123',
        )?.title,
        'Order #123 Picked Up',
      );
      expect(
        orderStatusNotificationCopy(
          status: 'delivered',
          orderNumber: '123',
        )?.title,
        'Order #123 Delivered',
      );

      expect(
        orderStatusNotificationCopy(status: 'prepared', orderNumber: '123'),
        isNull,
      );
      expect(
        orderStatusNotificationCopy(status: 'in_transit', orderNumber: '123'),
        isNull,
      );
      expect(
        orderStatusNotificationCopy(status: 'cancelled', orderNumber: '123'),
        isNull,
      );
    });

    test('builds copy for allowed package statuses', () {
      expect(
        orderStatusNotificationCopy(
          status: 'pending',
          orderNumber: '123',
          package: true,
        ),
        isNull,
      );
      expect(
        orderStatusNotificationCopy(
          status: 'delivery_partner_assigned',
          orderNumber: '123',
          package: true,
        )?.title,
        'Partner Assigned',
      );
      expect(
        orderStatusNotificationCopy(
          status: 'picked_up',
          orderNumber: '123',
          package: true,
        )?.title,
        'Package #123 Picked Up',
      );
      expect(
        orderStatusNotificationCopy(
          status: 'delivered',
          orderNumber: '123',
          package: true,
        )?.title,
        'Package #123 Delivered',
      );

      expect(
        orderStatusNotificationCopy(
          status: 'out_for_delivery',
          orderNumber: '123',
          package: true,
        ),
        isNull,
      );
    });
  });
}
