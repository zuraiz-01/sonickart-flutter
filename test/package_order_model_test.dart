import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cart/app/data/models/package_order_model.dart';

void main() {
  group('PackageOrderModel status parsing', () {
    test('keeps primary status when stale delivery status says cancelled', () {
      final order = PackageOrderModel.fromJson({
        'id': 'PKG123',
        'status': 'pending',
        'deliveryStatus': 'cancelled',
      });

      expect(order.status, 'pending');
    });

    test('accepts explicit cancellation status', () {
      final order = PackageOrderModel.fromJson({
        'id': 'PKG123',
        'status': 'cancelled',
        'deliveryStatus': 'cancelled',
        'cancellationReason': 'Cancelled by customer',
      });

      expect(order.status, 'cancelled');
    });
  });
}
