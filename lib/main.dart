import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sizer/sizer.dart';

import 'app/core/services/firebase_bootstrap.dart';
import 'app/core/services/session_controller.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await _clearLaunchAddressSelection();
  if (!Get.isRegistered<SessionController>()) {
    Get.put(SessionController(GetStorage()), permanent: true);
  }
  await _initializeFirebase();
  runApp(const SonicCartApp());
}

Future<void> _clearLaunchAddressSelection() async {
  final storage = GetStorage();
  await storage.remove('selectedAddress');
  await storage.remove('selectedVendorId');

  final rawAddresses = storage.read<List<dynamic>>('saved_addresses');
  if (rawAddresses == null || rawAddresses.isEmpty) return;

  final cleanedAddresses = rawAddresses
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item)..['isSelected'] = false)
      .toList();
  await storage.write('saved_addresses', cleanedAddresses);
}

Future<void> _initializeFirebase() async {
  try {
    await FirebaseBootstrap.initialize();
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
  }
}

class SonicCartApp extends StatelessWidget {
  const SonicCartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return GetMaterialApp(
          title: 'sonickart',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          initialRoute: AppRoutes.splash,
          getPages: AppPages.routes,
          builder: (context, child) => SessionExpiredOverlay(child: child),
        );
      },
    );
  }
}
