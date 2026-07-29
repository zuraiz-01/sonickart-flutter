import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cart/app/core/services/status_notification_copy.dart';

void main() {
  group('status notification allow-list', () {
    test(
      'keeps only placed assigned picked-up and delivered order notifications',
      () {
        for (final entry in const {
          'placed': 'placed',
          'pending': 'placed',
          'accepted': 'assigned',
          'assigned': 'assigned',
          'confirmed': 'assigned',
          'picked': 'picked_up',
          'pickup': 'picked_up',
          'pickedup': 'picked_up',
          'picked_up': 'picked_up',
          'order picked up': 'picked_up',
          'in_transit': 'picked_up',
          'on_the_way': 'picked_up',
          'on the way to delivery': 'picked_up',
          'out_for_delivery': 'picked_up',
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
      'keeps only booked assigned picked-up and delivered package notifications',
      () {
        for (final entry in const {
          'pending': 'booked',
          'placed': 'booked',
          'booked': 'booked',
          'package booked': 'booked',
          'assigned': 'assigned',
          'partner_assigned': 'assigned',
          'delivery_partner_assigned': 'assigned',
          'assigned to partner': 'assigned',
          'accepted': 'assigned',
          'confirmed': 'assigned',
          'picked_up': 'picked_up',
          'package picked up': 'picked_up',
          'on_the_way': 'picked_up',
          'out_for_delivery': 'picked_up',
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
        'assigned',
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

    test(
      'infers picked-up stage from on-the-way text when status is missing',
      () {
        expect(
          notificationDisplayStatus(
            package: false,
            text: const ['Order update', 'Your order is on the way.'],
          ),
          'picked_up',
        );
      },
    );

    test('infers package status from text when status is missing', () {
      expect(
        notificationDisplayStatus(
          package: true,
          text: const ['Package Booked', 'Your Package Has Been Booked.'],
        ),
        'booked',
      );
      expect(
        notificationDisplayStatus(
          package: true,
          text: const [
            'Partner Assigned',
            'A delivery partner has been assigned.',
          ],
        ),
        'assigned',
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
        isFalse,
      );
      expect(
        notificationDisplayStatus(
          package: false,
          status: 'in_transit',
          text: const ['Order update', 'Your order is on the way.'],
        ),
        'picked_up',
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
        'Order Placed',
      );
      expect(
        orderStatusNotificationCopy(status: 'placed', orderNumber: '123')?.body,
        'Your Order Has Been Placed.',
      );
      expect(
        orderStatusNotificationCopy(
          status: 'accepted',
          orderNumber: '123',
        )?.title,
        'Partner Assigned',
      );
      expect(
        orderStatusNotificationCopy(
          status: 'accepted',
          orderNumber: '123',
        )?.body,
        'A Delivery Partner Has Been Assigned.',
      );
      expect(
        orderStatusNotificationCopy(
          status: 'picked_up',
          orderNumber: '123',
        )?.title,
        'Order Picked Up',
      );
      expect(
        orderStatusNotificationCopy(
          status: 'on_the_way',
          orderNumber: '123',
        )?.title,
        'Order Picked Up',
      );
      expect(
        orderStatusNotificationCopy(
          status: 'delivered',
          orderNumber: '123',
        )?.title,
        'Order Delivered',
      );
      expect(
        orderStatusNotificationCopy(
          status: 'delivered',
          orderNumber: '123',
        )?.body,
        'Your Order Has Been Delivered.',
      );

      expect(
        orderStatusNotificationCopy(status: 'prepared', orderNumber: '123'),
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
        )?.title,
        'Package Booked',
      );
      expect(
        orderStatusNotificationCopy(
          status: 'pending',
          orderNumber: '123',
          package: true,
        )?.body,
        'Your Package Has Been Booked.',
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
        'Package Picked Up',
      );
      expect(
        orderStatusNotificationCopy(
          status: 'out_for_delivery',
          orderNumber: '123',
          package: true,
        )?.title,
        'Package Picked Up',
      );
      expect(
        orderStatusNotificationCopy(
          status: 'delivered',
          orderNumber: '123',
          package: true,
        )?.title,
        'Package Delivered',
      );

      expect(
        orderStatusNotificationCopy(
          status: 'cancelled',
          orderNumber: '123',
          package: true,
        ),
        isNull,
      );
    });
  });
}
