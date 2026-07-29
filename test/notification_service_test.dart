import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sonic_cart/app/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageContainer = 'notification_service_test';
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late GetStorage storage;
  late NotificationService service;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async {
          return '.dart_tool/test_storage/notification_service';
        });
    await GetStorage.init(storageContainer);
  });

  setUp(() async {
    storage = GetStorage(storageContainer);
    await storage.erase();
    service = NotificationService(storage)..onInit();
  });

  tearDown(() async {
    await storage.erase();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test('stable dedupe key suppresses delayed duplicate records', () async {
    await NotificationService.recordStored(
      storage: storage,
      title: 'Order Picked Up',
      message: 'Your Order Has Been Picked Up.',
      category: 'order',
      dedupeKey: 'order|picked_up|717|customer-1',
      now: DateTime.utc(2026, 1, 1),
    );
    await NotificationService.recordStored(
      storage: storage,
      title: 'Order Picked Up',
      message: 'Your Order Has Been Picked Up.',
      category: 'order',
      dedupeKey: 'order|picked_up|717|customer-1',
      now: DateTime.utc(2026, 1, 2),
    );

    service.onInit();

    expect(service.notifications, hasLength(1));
  });

  test('same title body with different entity keys records both', () async {
    await service.record(
      title: 'Partner Assigned',
      message: 'A Delivery Partner Has Been Assigned.',
      category: 'order',
      dedupeKey: 'order|assigned|717|customer-1',
    );
    await service.record(
      title: 'Partner Assigned',
      message: 'A Delivery Partner Has Been Assigned.',
      category: 'order',
      dedupeKey: 'order|assigned|718|customer-1',
    );

    expect(service.notifications, hasLength(2));
  });

  test('same entity with different status records both', () async {
    await service.record(
      title: 'Partner Assigned',
      message: 'A Delivery Partner Has Been Assigned.',
      category: 'package',
      dedupeKey: 'package|assigned|212|customer-1',
    );
    await service.record(
      title: 'Package Picked Up',
      message: 'Your Package Has Been Picked Up.',
      category: 'package',
      dedupeKey: 'package|picked_up|212|customer-1',
    );

    expect(service.notifications, hasLength(2));
  });

  test('concurrent record calls insert one history item', () async {
    await Future.wait([
      service.record(
        title: 'Order Delivered',
        message: 'Your Order Has Been Delivered.',
        category: 'order',
        dedupeKey: 'order|delivered|717|customer-1',
      ),
      service.record(
        title: 'Order Delivered',
        message: 'Your Order Has Been Delivered.',
        category: 'order',
        dedupeKey: 'order|delivered|717|customer-1',
      ),
    ]);

    expect(service.notifications, hasLength(1));
  });
}
