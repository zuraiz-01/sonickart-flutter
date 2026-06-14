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

    test('keeps primary status when stale delivery status says delivered', () {
      final order = PackageOrderModel.fromJson({
        'id': 'PKG123',
        'status': 'pending',
        'deliveryStatus': 'delivered',
        'packageStatus': 'delivered',
      });

      expect(order.status, 'pending');
    });

    test('accepts delivered status when completion evidence exists', () {
      final order = PackageOrderModel.fromJson({
        'id': 'PKG123',
        'status': 'pending',
        'deliveryStatus': 'delivered',
        'deliveredAt': '2026-06-09T10:00:00Z',
      });

      expect(order.status, 'delivered');
    });

    test('does not treat partial completed drops as delivered', () {
      final order = PackageOrderModel.fromJson({
        'id': 'PKG123',
        'status': 'pending',
        'deliveryStatus': 'delivered',
        'totalDrops': 2,
        'dropLocations': [
          {'status': 'completed'},
        ],
      });

      expect(order.status, 'pending');
    });

    test('ignores API wrapper success status', () {
      final order = PackageOrderModel.fromJson({
        'id': 'PKG123',
        'status': 'success',
        'deliveryStatus': 'pending',
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

  group('PackageOrderModel multi-drop contacts', () {
    test('parses every receiver from dropLocations and preserves them', () {
      final order = PackageOrderModel.fromJson({
        'id': 'PKG122',
        'status': 'pending',
        'dropLocations': [
          {
            'address': 'Drop A',
            'latitude': 15.1,
            'longitude': 74.1,
            'receiverName': 'Ali',
            'receiverPhone': '9000000000',
            'status': 'completed',
            'paymentAmount': 0,
            'paymentStatus': 'not_required',
          },
          {
            'address': 'Drop B',
            'latitude': 15.2,
            'longitude': 74.2,
            'receiverName': 'Zuri',
            'receiverPhone': '8000000000',
            'status': 'active',
            'paymentAmount': 120,
            'paymentStatus': 'pending',
          },
        ],
      });

      expect(order.totalDrops, 2);
      expect(order.dropReceiverNames, ['Ali', 'Zuri']);
      expect(order.dropReceiverPhones, ['9000000000', '8000000000']);
      expect(order.dropStatuses, ['completed', 'active']);
      expect(order.dropPaymentAmounts, [0, 120]);
      expect(order.dropPaymentStatuses, ['not_required', 'pending']);

      final json = order.toJson();
      final drops = json['dropLocations'] as List<dynamic>;
      final contacts = json['receiverContacts'] as List<dynamic>;
      expect(drops[1]['receiverName'], 'Zuri');
      expect(drops[1]['receiverPhone'], '8000000000');
      expect(drops[1]['paymentAmount'], 120);
      expect(drops[1]['paymentStatus'], 'pending');
      expect(drops[1]['status'], 'active');
      expect(contacts[1]['name'], 'Zuri');
      expect(contacts[1]['phone'], '8000000000');
    });

    test('merges receiverContacts with parallel drop arrays', () {
      final order = PackageOrderModel.fromJson({
        'id': 'PKG123',
        'status': 'pending',
        'dropAddresses': ['Drop A', 'Drop B'],
        'receiverContacts': [
          {'name': 'First', 'phone': '111'},
          {'name': 'Second', 'phone': '222'},
        ],
      });

      expect(order.totalDrops, 2);
      expect(order.dropReceiverNames, ['First', 'Second']);
      expect(order.dropReceiverPhones, ['111', '222']);
      expect(
        (order.toJson()['dropLocations'] as List<dynamic>)[1]['receiverName'],
        'Second',
      );
    });
  });
}
