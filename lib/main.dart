import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:sizer/sizer.dart';
import 'package:toastification/toastification.dart';

import 'app/core/services/firebase_bootstrap.dart';
import 'app/core/services/app_session_scope.dart';
import 'app/core/services/app_resume_reconciliation_service.dart';
import 'app/core/services/local_notification_service.dart';
import 'app/core/services/push_notification_service.dart';
import 'app/core/services/session_controller.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_controller.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    'Background notification received: '
    'systemPayload=${message.notification != null} '
    'dataFieldCount=${message.data.length}',
  );
  try {
    DartPluginRegistrant.ensureInitialized();
    await FirebaseBootstrap.initialize();
    await GetStorage.init();
    if (LocalNotificationService.shouldDisplayRemoteMessageFromBackground(
      message,
    )) {
      await LocalNotificationService.showRemoteMessageFromBackground(message);
    } else {
      await LocalNotificationService.recordRemoteMessageFromBackground(message);
      debugPrint(
        'Background local notification skipped; FCM/system notification handles this message or the payload is not displayable.',
      );
    }
  } catch (error) {
    debugPrint(
      'Background notification handling failed safely: ${error.runtimeType}',
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  AppSessionScope.startNewSession();
  await _initializeFirebase();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  if (!Get.isRegistered<AppThemeController>()) {
    Get.put(AppThemeController(GetStorage()), permanent: true);
  }
  if (!Get.isRegistered<SessionController>()) {
    Get.put(SessionController(GetStorage()), permanent: true);
  }
  if (!Get.isRegistered<AppResumeReconciliationService>()) {
    Get.put(
      AppResumeReconciliationService(GetStorage()),
      permanent: true,
    ).start();
  }
  if (!Get.isRegistered<LocalNotificationService>()) {
    await Get.putAsync(
      () => LocalNotificationService().init(),
      permanent: true,
    );
  }
  if (!Get.isRegistered<PushNotificationService>()) {
    await Get.putAsync(() => PushNotificationService().init(), permanent: true);
  }
  runApp(const SonicCartApp());
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
    if (!Get.isRegistered<AppThemeController>()) {
      Get.put(AppThemeController(GetStorage()), permanent: true);
    }
    final themeController = Get.find<AppThemeController>();
    return Sizer(
      builder: (context, orientation, deviceType) {
        return Obx(
          () => ToastificationWrapper(
            child: GetMaterialApp(
              title: 'SonicKart',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeController.themeMode,
              initialRoute: AppRoutes.splash,
              getPages: AppPages.routes,
              builder: (context, child) => SessionExpiredOverlay(child: child),
            ),
          ),
        );
      },
    );
  }
}
