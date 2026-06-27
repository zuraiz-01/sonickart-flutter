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
  });
}
