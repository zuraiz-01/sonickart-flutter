import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cart/app/core/services/service_area_gate_service.dart';

void main() {
  group('ServiceAreaRule', () {
    test('parses admin working-area payload used by Firestore', () {
      final rule = ServiceAreaRule.fromFirestore(
        id: 'fallback-id',
        fields: const {
          'id': 'gulshan-karachi',
          'name': 'Gulshan',
          'city': 'Karachi',
          'state': 'Sindh',
          'province': 'Sindh',
          'country': 'India',
          'areaType': 'working_area',
          'appEnabled': true,
          'latitude': 24.8607,
          'longitude': 67.0011,
          'radiusKm': 5,
          'searchKeywords': ['gulshan', 'karachi', 'sindh', 'india'],
        },
      );

      expect(rule.id, 'gulshan-karachi');
      expect(rule.name, 'Gulshan');
      expect(rule.city, 'Karachi');
      expect(rule.province, 'Sindh');
      expect(rule.status, 'working');
      expect(rule.isActive, isTrue);
      expect(rule.hasCoordinateRule, isTrue);
      expect(rule.latitude, 24.8607);
      expect(rule.longitude, 67.0011);
      expect(rule.radiusKm, 5);
    });

    test('disables app when appEnabled is false', () {
      final rule = ServiceAreaRule.fromFirestore(
        id: 'gulshan-karachi',
        fields: const {
          'areaType': 'working_area',
          'appEnabled': false,
          'latitude': 24.8607,
          'longitude': 67.0011,
          'radiusKm': 5,
        },
      );

      expect(rule.status, 'working');
      expect(rule.isActive, isFalse);
      expect(rule.hasCoordinateRule, isTrue);
    });

    test('keeps backward compatibility with old status payload', () {
      final rule = ServiceAreaRule.fromFirestore(
        id: 'old-blocked-area',
        fields: const {
          'status': 'not_working',
          'isActive': true,
          'latitude': 24.8607,
          'longitude': 67.0011,
          'radiusKm': 5,
        },
      );

      expect(rule.status, 'not_working');
      expect(rule.isActive, isTrue);
    });
  });
}
