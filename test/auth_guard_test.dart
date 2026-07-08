import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sizer/sizer.dart';
import 'package:sonic_cart/app/core/network/api_service.dart';
import 'package:sonic_cart/app/core/utils/auth_guard.dart';
import 'package:sonic_cart/app/data/repositories/auth_repository.dart';
import 'package:sonic_cart/app/modules/auth/controllers/auth_controller.dart';
import 'package:sonic_cart/app/routes/app_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageContainer = 'auth_guard_test';
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (methodCall) async {
          return switch (methodCall.method) {
            'getExternalCacheDirectories' => <String>[
              '.dart_tool/test_storage',
            ],
            'getExternalStorageDirectories' => <String>[
              '.dart_tool/test_storage',
            ],
            _ => '.dart_tool/test_storage',
          };
        });

    await GetStorage.init(storageContainer);
  });

  setUp(() async {
    Get.reset();
    await GetStorage(storageContainer).erase();
  });

  tearDown(() {
    Get.reset();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets('requireAuth keeps one login dialog for repeated guarded taps', (
    tester,
  ) async {
    final storage = GetStorage(storageContainer);
    final api = ApiService(storage: storage);
    Get.put(AuthController(AuthRepository(api, storage: storage)));

    await tester.pumpWidget(
      Sizer(
        builder: (context, orientation, deviceType) {
          return GetMaterialApp(
            getPages: [
              GetPage(
                name: '/',
                page: () => const Scaffold(body: SizedBox.shrink()),
              ),
              GetPage(
                name: AppRoutes.login,
                page: () => const Scaffold(body: Text('Login screen')),
              ),
            ],
          );
        },
      ),
    );

    expect(requireAuth(), isFalse);
    expect(requireAuth(), isFalse);
    await tester.pumpAndSettle();

    expect(find.text('Login Required'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Login screen'), findsOneWidget);
  });
}
