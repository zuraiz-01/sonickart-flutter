import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sonic_cart/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getApplicationDocumentsDirectory':
        case 'getTemporaryDirectory':
        case 'getApplicationSupportDirectory':
        case 'getLibraryDirectory':
        case 'getExternalStorageDirectory':
          return '.dart_tool/test_storage';
        case 'getExternalCacheDirectories':
        case 'getExternalStorageDirectories':
          return <String>['.dart_tool/test_storage'];
        default:
          return '.dart_tool/test_storage';
      }
    });

    await GetStorage.init();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets('SonicCartApp loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const SonicCartApp());
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(SonicCartApp), findsOneWidget);
  });
}