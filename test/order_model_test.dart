import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cart/app/data/models/order_model.dart';

void main() {
  group('OrderModel inactive status parsing', () {
    test('treats completed-style statuses as inactive', () {
      for (final status in [
        'delivered',
        'completed',
        'complete',
        'finished',
        'done',
        'cancelled',
        'canceled',
      ]) {
        final order = OrderModel.fromJson({'id': 'ORD1', 'status': status});

        expect(order.isInactive, isTrue, reason: status);
      }
    });

    test('keeps active statuses active', () {
      for (final status in ['placed', 'pending', 'confirmed', 'assigned']) {
        final order = OrderModel.fromJson({'id': 'ORD1', 'status': status});

        expect(order.isInactive, isFalse, reason: status);
      }
    });
  });

  group('OrderModel delivery rating parsing', () {
    test('reads submitted rating fields from product order payloads', () {
      final order = OrderModel.fromJson({
        'id': 'ORD1',
        'status': 'delivered',
        'rating': 5,
        'ratingFeedback': 'Good delivery',
        'ratedAt': '2026-05-26T12:00:00.000Z',
      });

      expect(order.deliveryRating, 5);
      expect(order.deliveryRatingFeedback, 'Good delivery');
      expect(order.deliveryRatedAt, isNotNull);
      expect(order.hasDeliveryRating, isTrue);
    });

    test('reads legacy delivery rating aliases', () {
      final order = OrderModel.fromJson({
        'id': 'ORD1',
        'status': 'delivered',
        'delivery_rating': '4',
        'delivery_feedback': 'Fast handoff',
      });

      expect(order.deliveryRating, 4);
      expect(order.deliveryRatingFeedback, 'Fast handoff');
      expect(order.hasDeliveryRating, isTrue);
    });
  });
}
