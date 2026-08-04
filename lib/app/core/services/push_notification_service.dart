import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../modules/package/controllers/package_controller.dart';
import '../../routes/app_routes.dart';
import '../constants/api_constants.dart';
import '../network/api_service.dart';
import 'firebase_bootstrap.dart';
import 'local_notification_service.dart';
import 'notification_service.dart';
import 'package_notification_policy.dart';
import 'status_notification_copy.dart';

typedef DeviceTokenRegistrar =
    Future<void> Function(Map<String, String> payload);

abstract interface class PushMessagingClient {
  Future<void> initialize();

  Future<AuthorizationStatus> requestPermission();

  Future<AuthorizationStatus> getAuthorizationStatus();

  Future<void> setForegroundPresentationOptions();

  Stream<RemoteMessage> get onMessage;

  Stream<RemoteMessage> get onMessageOpenedApp;

  Stream<String> get onTokenRefresh;

  Future<RemoteMessage?> getInitialMessage();

  Future<String?> getToken();

  Future<String?> getApnsToken();
}

class FirebasePushMessagingClient implements PushMessagingClient {
  @override
  Future<void> initialize() => FirebaseBootstrap.initialize();

  @override
  Future<AuthorizationStatus> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus;
  }

  @override
  Future<AuthorizationStatus> getAuthorizationStatus() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus;
  }

  @override
  Future<void> setForegroundPresentationOptions() {
    return FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: false,
        );
  }

  @override
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  @override
  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  @override
  Future<RemoteMessage?> getInitialMessage() {
    return FirebaseMessaging.instance.getInitialMessage();
  }

  @override
  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  @override
  Future<String?> getApnsToken() => FirebaseMessaging.instance.getAPNSToken();
}

abstract interface class PushLocalTapSource {
  Stream<Map<String, dynamic>>? get taps;

  Map<String, dynamic>? takePendingLaunchData();
}

class GetxPushLocalTapSource implements PushLocalTapSource {
  LocalNotificationService? get _service {
    if (!Get.isRegistered<LocalNotificationService>()) return null;
    return Get.find<LocalNotificationService>();
  }

  @override
  Stream<Map<String, dynamic>>? get taps => _service?.taps;

  @override
  Map<String, dynamic>? takePendingLaunchData() {
    return _service?.takePendingLaunchData();
  }
}

class PushNotificationService extends GetxService {
  PushNotificationService({
    GetStorage? storage,
    PushMessagingClient? messaging,
    PushLocalTapSource? localTapSource,
    DeviceTokenRegistrar? tokenRegistrar,
  }) : _storage = storage ?? GetStorage(),
       _messaging = messaging ?? FirebasePushMessagingClient(),
       _localTapSource = localTapSource ?? GetxPushLocalTapSource(),
       _tokenRegistrar = tokenRegistrar;

  static const notificationsDisabledStorageKey = 'pushNotificationsDisabled';
  static const _tokenStorageKey = 'fcmToken';
  static const _tokenOwnerStorageKey = 'fcmTokenRegistrationOwner';
  static const _apnsTokenStorageKey = 'registeredApnsToken';

  final GetStorage _storage;
  final PushMessagingClient _messaging;
  final PushLocalTapSource _localTapSource;
  final DeviceTokenRegistrar? _tokenRegistrar;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<Map<String, dynamic>>? _localTapSub;
  Future<PushNotificationService>? _initializationInFlight;
  Future<void>? _tokenRegistrationInFlight;
  bool _listenersInitialized = false;
  bool _tokenRegistrationRequested = false;
  String? _queuedRegistrationToken;
  String? _registrationTokenInProgress;
  String? _registrationOwnerInProgress;
  int _tokenCacheGeneration = 0;
  final _recentRecords = <String, DateTime>{};
  bool _notificationNavigationInFlight = false;
  Map<String, dynamic>? _pendingNotificationNavigation;
  String? _lastNotificationNavigationSignature;
  DateTime? _lastNotificationNavigationAt;

  @visibleForTesting
  bool get listenersInitialized => _listenersInitialized;

  Future<PushNotificationService> init() {
    if (_listenersInitialized) {
      unawaited(registerCurrentToken());
      return Future<PushNotificationService>.value(this);
    }
    final active = _initializationInFlight;
    if (active != null) return active;

    final initialization = _initializeListeners();
    _initializationInFlight = initialization;
    unawaited(
      initialization.whenComplete(() {
        if (identical(_initializationInFlight, initialization)) {
          _initializationInFlight = null;
        }
      }),
    );
    return initialization;
  }

  Future<PushNotificationService> _initializeListeners() async {
    StreamSubscription<RemoteMessage>? foregroundMessageSub;
    StreamSubscription<RemoteMessage>? messageOpenedSub;
    StreamSubscription<String>? tokenRefreshSub;
    StreamSubscription<Map<String, dynamic>>? localTapSub;
    try {
      await _messaging.initialize();

      final authorizationStatus = await _messaging.requestPermission();
      if (authorizationStatus == AuthorizationStatus.denied) {
        debugPrint(
          'PushNotificationService: Notifications permission denied by user',
        );
      }

      await _messaging.setForegroundPresentationOptions();

      foregroundMessageSub = _messaging.onMessage.listen(
        _showForegroundNotification,
      );
      messageOpenedSub = _messaging.onMessageOpenedApp.listen(_handleTap);
      tokenRefreshSub = _messaging.onTokenRefresh.listen(
        (token) => unawaited(registerCurrentToken(token: token)),
      );
      localTapSub = _localTapSource.taps?.listen(_handleLocalTap);

      final initialMessage = await _messaging.getInitialMessage();
      final pendingLocalTap = _localTapSource.takePendingLaunchData();

      _foregroundMessageSub = foregroundMessageSub;
      _messageOpenedSub = messageOpenedSub;
      _tokenRefreshSub = tokenRefreshSub;
      _localTapSub = localTapSub;
      _listenersInitialized = true;

      if (initialMessage != null) {
        _handleTap(initialMessage);
      }
      if (pendingLocalTap != null) {
        _handleLocalTap(pendingLocalTap);
      }

      unawaited(registerCurrentToken());
    } catch (error, stackTrace) {
      _listenersInitialized = false;
      _foregroundMessageSub = null;
      _messageOpenedSub = null;
      _tokenRefreshSub = null;
      _localTapSub = null;
      await _cancelSubscriptions([
        foregroundMessageSub,
        messageOpenedSub,
        tokenRefreshSub,
        localTapSub,
      ]);
      debugPrint('PushNotificationService.init skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    return this;
  }

  Future<void> registerCurrentToken({String? token}) {
    final normalizedToken = token?.trim();
    final active = _tokenRegistrationInFlight;
    if (active != null &&
        normalizedToken != null &&
        normalizedToken.isNotEmpty &&
        normalizedToken == _registrationTokenInProgress &&
        _authenticatedRegistrationOwner() == _registrationOwnerInProgress) {
      return active;
    }

    _tokenRegistrationRequested = true;
    if (normalizedToken != null && normalizedToken.isNotEmpty) {
      _queuedRegistrationToken = normalizedToken;
    }
    if (active != null) return active;

    final registration = _drainTokenRegistrations();
    _tokenRegistrationInFlight = registration;
    unawaited(
      registration.whenComplete(() {
        if (!identical(_tokenRegistrationInFlight, registration)) return;
        _tokenRegistrationInFlight = null;
        if (_tokenRegistrationRequested) {
          unawaited(registerCurrentToken());
        }
      }),
    );
    return registration;
  }

  Future<void> _drainTokenRegistrations() async {
    while (_tokenRegistrationRequested) {
      _tokenRegistrationRequested = false;
      final token = _queuedRegistrationToken;
      _queuedRegistrationToken = null;
      _registrationTokenInProgress = token;
      try {
        await _registerToken(token: token);
      } finally {
        _registrationTokenInProgress = null;
        _registrationOwnerInProgress = null;
      }
    }
  }

  Future<void> _registerToken({String? token}) async {
    final owner = _authenticatedRegistrationOwner();
    _registrationOwnerInProgress = owner;
    if (owner == null) return;

    try {
      await _messaging.initialize();
      if (!await areNotificationsEnabled()) return;

      String? fcmToken;
      try {
        fcmToken = (token ?? await _messaging.getToken())?.trim();
      } catch (e) {
        if (e.toString().contains('apns-token-not-set') ||
            e.toString().contains('APNS token has not been set')) {
          debugPrint(
            'PushNotificationService: APNS token not ready, will retry token registration',
          );
          _tokenRegistrationRequested = true;
          return;
        }
        rethrow;
      }
      if (fcmToken == null || fcmToken.isEmpty) return;
      final apnsToken = await _currentApnsToken();
      if (_isRegistrationCurrent(
        owner: owner,
        fcmToken: fcmToken,
        apnsToken: apnsToken,
      )) {
        return;
      }
      debugPrint(
        'PushNotificationService: FCM token fetched ${_describeToken(fcmToken)}',
      );

      final payload = <String, String>{
        'fcmToken': fcmToken,
        'fcm_token': fcmToken,
        'deviceToken': fcmToken,
        'device_token': fcmToken,
      };
      if (apnsToken != null) {
        payload['apnsToken'] = apnsToken;
        payload['apns_token'] = apnsToken;
      }

      final cacheGeneration = _tokenCacheGeneration;
      await _registerTokenWithBackend(payload);
      if (cacheGeneration != _tokenCacheGeneration ||
          owner != _authenticatedRegistrationOwner()) {
        return;
      }
      await _storage.write(_tokenStorageKey, fcmToken);
      await _storage.write(_tokenOwnerStorageKey, owner);
      if (apnsToken == null) {
        await _storage.remove(_apnsTokenStorageKey);
      } else {
        await _storage.write(_apnsTokenStorageKey, apnsToken);
      }
      debugPrint(
        'PushNotificationService: FCM token registered ${_describeToken(fcmToken)}',
      );
    } catch (error) {
      debugPrint('PushNotificationService.registerCurrentToken failed: $error');
    }
  }

  Future<bool> areNotificationsEnabled() async {
    if (_notificationsDisabledByUser) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return _isAllowed(await _messaging.getAuthorizationStatus());
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _isAllowed(await _messaging.getAuthorizationStatus());
    }
    return true;
  }

  Future<bool> enableNotifications() async {
    try {
      await _messaging.initialize();
      await _messaging.setForegroundPresentationOptions();
      await _storage.write(notificationsDisabledStorageKey, false);
      final allowed = _isAllowed(await _messaging.requestPermission());
      if (!allowed) {
        await _storage.write(notificationsDisabledStorageKey, true);
        return false;
      }
      if (!_listenersInitialized) {
        await init();
      }
      await registerCurrentToken();
      return true;
    } catch (error) {
      debugPrint('PushNotificationService.enableNotifications failed: $error');
      return false;
    }
  }

  Future<void> disableNotifications() async {
    await _storage.write(notificationsDisabledStorageKey, true);
    await clearTokenCache();
    final accessToken = _storage.read<String>('accessToken');
    if (accessToken == null || accessToken.trim().isEmpty) return;
    try {
      await _api.patch(
        endpoint: ApiConstants.user,
        data: const {
          'fcmToken': '',
          'fcm_token': '',
          'deviceToken': '',
          'device_token': '',
          'apnsToken': '',
          'apns_token': '',
        },
      );
    } catch (error) {
      debugPrint(
        'PushNotificationService.disableNotifications token clear failed: $error',
      );
    }
  }

  Future<void> clearTokenCache() async {
    _tokenCacheGeneration += 1;
    await _storage.remove(_tokenStorageKey);
    await _storage.remove(_tokenOwnerStorageKey);
    await _storage.remove(_apnsTokenStorageKey);
  }

  bool get _notificationsDisabledByUser {
    return _storage.read<bool>(notificationsDisabledStorageKey) == true;
  }

  bool _isAllowed(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  String? _authenticatedRegistrationOwner() {
    final accessToken = _storage.read<String>('accessToken')?.trim() ?? '';
    if (accessToken.isEmpty || _storage.read('isLoggedIn') != true) return null;

    final rawUser = _storage.read('currentUser');
    if (rawUser is! Map) return null;
    final user = Map<String, dynamic>.from(rawUser);
    String firstValue(List<String> keys) {
      for (final key in keys) {
        final value = user[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final userIdentifier = firstValue(const [
      'id',
      '_id',
      'userId',
      'phone',
      'phoneNumber',
      'email',
    ]);
    if (userIdentifier.isEmpty) return null;
    return '${userIdentifier.toLowerCase()}|${accessToken.hashCode}';
  }

  bool _isRegistrationCurrent({
    required String owner,
    required String fcmToken,
    required String? apnsToken,
  }) {
    if (_storage.read<String>(_tokenOwnerStorageKey) != owner ||
        _storage.read<String>(_tokenStorageKey) != fcmToken) {
      return false;
    }
    if (apnsToken == null) return true;
    return _storage.read<String>(_apnsTokenStorageKey) == apnsToken;
  }

  Future<String?> _currentApnsToken() async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return null;
    }
    try {
      final token = await _messaging.getApnsToken();
      if (token == null || token.trim().isEmpty) return null;
      return token.trim();
    } catch (error) {
      debugPrint(
        'PushNotificationService: APNs token is not available yet: $error',
      );
      return null;
    }
  }

  Future<void> _registerTokenWithBackend(Map<String, String> payload) {
    final registrar = _tokenRegistrar;
    if (registrar != null) return registrar(payload);
    return _api
        .patch(endpoint: ApiConstants.user, data: payload)
        .then<void>((_) {});
  }

  Future<void> _cancelSubscriptions(
    Iterable<StreamSubscription<dynamic>?> subscriptions,
  ) async {
    for (final subscription in subscriptions) {
      if (subscription == null) continue;
      try {
        await subscription.cancel();
      } catch (error) {
        debugPrint(
          'PushNotificationService: listener cleanup failed safely: $error',
        );
      }
    }
  }

  ApiService get _api {
    if (Get.isRegistered<ApiService>()) return Get.find<ApiService>();
    return ApiService(storage: _storage);
  }

  String _describeToken(String token) {
    final trimmed = token.trim();
    return 'length=${trimmed.length}';
  }

  void _showForegroundNotification(RemoteMessage message) {
    unawaited(_processForegroundNotification(message));
  }

  Future<void> _processForegroundNotification(RemoteMessage message) async {
    final data = _notificationData(message.data);
    final isPackage = _isPackagePayload(data);
    if (isPackage && !_packageRecipientAllowed(data)) return;
    if (isPackage) {
      await _updatePackageState(data);
    }
    final status = _status(data);
    final trackingNumber = _trackingNumber(data, package: isPackage);
    final copy = status == null
        ? null
        : orderStatusNotificationCopy(
            status: status,
            orderNumber: trackingNumber,
            package: isPackage,
          );
    final title =
        copy?.title ??
        message.notification?.title ??
        _firstText(data, ['title', 'notificationTitle', 'notification_title']);
    final body =
        copy?.body ??
        message.notification?.body ??
        _firstText(data, [
          'body',
          'message',
          'notificationBody',
          'notification_body',
        ]);
    if (shouldSuppressOrderStatusNotification(
      package: isPackage,
      status: status,
      text: [title, body],
    )) {
      return;
    }
    if (title == null && body == null) return;

    final dedupeKey = LocalNotificationService.statusDedupeKey(
      package: isPackage,
      status: status,
      trackingNumber: trackingNumber,
      identifiers: _trackingIdentifiers(data, package: isPackage),
      recipientId: _recipientIdentifier(data),
      title: title,
      body: body,
    );

    _recordInAppNotification(
      title: title ?? (isPackage ? 'Package update' : 'Order update'),
      body: body ?? 'You have a new ${isPackage ? 'package' : 'order'} update.',
      package: isPackage,
      dedupeKey: dedupeKey,
    );

    if (Get.isRegistered<LocalNotificationService>()) {
      Get.find<LocalNotificationService>().show(
        title: title ?? (isPackage ? 'Package update' : 'Order update'),
        body:
            body ?? 'You have a new ${isPackage ? 'package' : 'order'} update.',
        payload: _encodePayload(data, package: isPackage),
        notificationId: LocalNotificationService.notificationIdForDedupeKey(
          dedupeKey,
        ),
        dedupeKey: dedupeKey,
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Get.isRegistered<LocalNotificationService>()) {
          Get.find<LocalNotificationService>().show(
            title: title ?? (isPackage ? 'Package update' : 'Order update'),
            body:
                body ??
                'You have a new ${isPackage ? 'package' : 'order'} update.',
            payload: _encodePayload(data, package: isPackage),
            notificationId: LocalNotificationService.notificationIdForDedupeKey(
              dedupeKey,
            ),
            dedupeKey: dedupeKey,
          );
        }
      });
    }
  }

  void _handleTap(RemoteMessage message) {
    _handleNotificationData(_notificationData(message.data));
  }

  void _handleLocalTap(Map<String, dynamic> data) {
    _handleNotificationData(
      _notificationData(data),
      packageRecipientAlreadyValidated: true,
    );
  }

  void _handleNotificationData(
    Map<String, dynamic> data, {
    bool packageRecipientAlreadyValidated = false,
  }) {
    final isPackage = _isPackagePayload(data);
    if (isPackage &&
        !packageRecipientAlreadyValidated &&
        !_packageRecipientAllowed(data)) {
      return;
    }
    if (isPackage) {
      unawaited(_updatePackageState(data));
    }
    final status = _navigationStatus(data);
    final displayStatus = _status(data);
    final trackingNumber = _trackingNumber(data, package: isPackage);
    final copy = displayStatus == null
        ? null
        : orderStatusNotificationCopy(
            status: displayStatus,
            orderNumber: trackingNumber,
            package: isPackage,
          );
    final dedupeKey = LocalNotificationService.statusDedupeKey(
      package: isPackage,
      status: status,
      trackingNumber: trackingNumber,
      identifiers: _trackingIdentifiers(data, package: isPackage),
      recipientId: _recipientIdentifier(data),
      title: data['title']?.toString(),
      body: data['body']?.toString() ?? data['message']?.toString(),
    );
    final title =
        copy?.title ??
        _firstText(data, const [
          'title',
          'notificationTitle',
          'notification_title',
        ]) ??
        (isPackage ? 'Package update' : 'Order update');
    final body =
        copy?.body ??
        _firstText(data, const [
          'body',
          'message',
          'notificationBody',
          'notification_body',
        ]) ??
        'You have a new ${isPackage ? 'package' : 'order'} update.';
    if (!shouldSuppressOrderStatusNotification(
      package: isPackage,
      status: displayStatus,
      text: [title, body],
    )) {
      _recordInAppNotification(
        title: title,
        body: body,
        package: isPackage,
        dedupeKey: dedupeKey,
      );
    }

    _queueNotificationNavigation(data);
  }

  void _queueNotificationNavigation(Map<String, dynamic> data) {
    _pendingNotificationNavigation = Map<String, dynamic>.from(data);
    if (_notificationNavigationInFlight) return;

    _notificationNavigationInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_drainNotificationNavigationQueue());
    });
  }

  Future<void> _drainNotificationNavigationQueue() async {
    try {
      while (_pendingNotificationNavigation != null) {
        final data = _pendingNotificationNavigation!;
        _pendingNotificationNavigation = null;

        if (_isDuplicateNotificationNavigation(data)) {
          continue;
        }

        await _routeWhenReady(data);
        _lastNotificationNavigationSignature = _navigationSignature(data);
        _lastNotificationNavigationAt = DateTime.now();
      }
    } catch (error, stackTrace) {
      debugPrint('PushNotificationService navigation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _notificationNavigationInFlight = false;
      if (_pendingNotificationNavigation != null) {
        _queueNotificationNavigation(_pendingNotificationNavigation!);
      }
    }
  }

  void _recordInAppNotification({
    required String title,
    required String body,
    required bool package,
    String? dedupeKey,
  }) {
    if (!Get.isRegistered<NotificationService>()) return;
    final now = DateTime.now();
    _recentRecords.removeWhere(
      (_, recordedAt) => now.difference(recordedAt).inMinutes >= 2,
    );
    final normalizedDedupeKey = dedupeKey?.trim().toLowerCase();
    final signature = normalizedDedupeKey?.isNotEmpty == true
        ? normalizedDedupeKey!
        : '${package ? 'package' : 'order'}|$title|$body';
    if (_recentRecords.containsKey(signature)) return;
    _recentRecords[signature] = now;

    unawaited(
      Get.find<NotificationService>().record(
        title: title,
        message: body,
        category: package ? 'package' : 'order',
        dedupeKey: dedupeKey,
      ),
    );
  }

  Future<void> _routeWhenReady(Map<String, dynamic> data) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (Get.key.currentState == null) continue;
      if (Get.currentRoute == AppRoutes.splash) continue;
      await _routeFromData(data);
      return;
    }

    if (Get.key.currentState == null) {
      debugPrint('PushNotificationService: navigator not ready for tap route');
      return;
    }

    await _routeFromData(data);
  }

  Future<void> _routeFromData(Map<String, dynamic> data) async {
    await _closeBlockingNavigationOverlays();

    final type = data['type']?.toString().toLowerCase();
    final isPackage = _isPackagePayload(data);
    final orderId = _trackingNumber(data, package: isPackage);
    final status = _navigationStatus(data);

    if (isPackage || type == 'package') {
      _pushNotificationRoute(
        AppRoutes.packageDetails,
        arguments: orderId.isEmpty ? null : {'orderId': orderId},
      );
      return;
    }

    if (type == 'order' || status != null || orderId.isNotEmpty) {
      if (_opensLiveTracking(status)) {
        _pushNotificationRoute(
          AppRoutes.liveTracking,
          arguments: orderId.isEmpty ? null : {'orderId': orderId},
        );
        return;
      }
      _pushNotificationRoute(
        AppRoutes.customerOrderDetails,
        arguments: orderId.isEmpty ? null : {'orderId': orderId},
      );
      return;
    }

    _pushNotificationRoute(AppRoutes.notifications);
  }

  Future<void> _closeBlockingNavigationOverlays() async {
    for (var attempt = 0; attempt < 2; attempt += 1) {
      var closed = false;
      if (Get.isDialogOpen == true) {
        Get.back<void>();
        closed = true;
      }
      if (Get.isBottomSheetOpen == true) {
        Get.back<void>();
        closed = true;
      }
      if (!closed) return;
      await Future<void>.delayed(const Duration(milliseconds: 160));
    }
  }

  void _pushNotificationRoute(String route, {Object? arguments}) {
    if (Get.currentRoute == route) {
      Get.offNamed(route, arguments: arguments);
      return;
    }
    Get.toNamed(route, arguments: arguments);
  }

  bool _isDuplicateNotificationNavigation(Map<String, dynamic> data) {
    final lastAt = _lastNotificationNavigationAt;
    if (lastAt == null) return false;

    final signature = _navigationSignature(data);
    if (_lastNotificationNavigationSignature != signature) return false;

    return DateTime.now().difference(lastAt) < const Duration(seconds: 3);
  }

  String _navigationSignature(Map<String, dynamic> data) {
    final isPackage = _isPackagePayload(data);
    final explicitDedupeKey =
        _firstText(data, const ['dedupeKey', 'dedupe_key']) ?? '';
    if (explicitDedupeKey.trim().isNotEmpty) {
      return explicitDedupeKey.trim().toLowerCase();
    }
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    final status = _navigationStatus(data)?.trim().toLowerCase() ?? '';
    final orderId = _trackingNumber(
      data,
      package: isPackage,
    ).trim().toLowerCase();
    final recipientId = _recipientIdentifier(data).trim().toLowerCase();
    return '${isPackage ? 'package' : 'order'}|$type|$status|$orderId|$recipientId';
  }

  String? _navigationStatus(Map<String, dynamic> data) {
    final explicit = _status(data);
    if (explicit != null && explicit.trim().isNotEmpty) return explicit;

    final typeStatus = _firstText(data, const [
      'type',
      'notificationType',
      'notification_type',
      'event',
      'eventType',
      'event_type',
    ]);
    if (typeStatus != null && typeStatus.trim().isNotEmpty) {
      return typeStatus;
    }

    final textStatus = [
      _firstText(data, const ['title', 'notificationTitle']),
      _firstText(data, const ['body', 'message', 'notificationBody']),
    ].whereType<String>().join(' ');
    return textStatus.trim().isEmpty ? null : textStatus;
  }

  bool _opensLiveTracking(String? status) {
    final raw = status?.trim().toLowerCase() ?? '';
    final compact = raw.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final normalized = normalizeNotificationStatus(raw);
    if (compact.contains('accept')) return true;
    if (compact.contains('confirmed')) return true;
    if (compact.contains('assigned')) return true;
    if (compact.contains('pickedup')) return true;
    if (compact.contains('outfordelivery')) return true;
    if (compact.contains('ontheway')) return true;
    if (compact.contains('intransit')) return true;
    return const {
      'accepted',
      'assigned',
      'confirmed',
      'picked_up',
      'in_transit',
      'out_for_delivery',
      'on_the_way',
    }.contains(normalized);
  }

  Map<String, dynamic> _notificationData(Map<String, dynamic> data) {
    final merged = Map<String, dynamic>.from(data);
    for (final key in const [
      'data',
      'payload',
      'order',
      'package',
      'packageOrder',
    ]) {
      final child = _asMap(data[key]);
      if (child != null) merged.addAll(child);
    }
    return merged;
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? _firstText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _status(Map<String, dynamic> data) {
    return _firstText(data, const [
      'status',
      'deliveryStatus',
      'delivery_status',
      'orderStatus',
      'order_status',
      'packageStatus',
      'package_status',
    ]);
  }

  bool _isPackagePayload(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase();
    if (type?.contains('package') == true) return true;
    return const [
      'packageOrderId',
      'package_order_id',
      'packageId',
      'package_id',
      'packageStatus',
      'package_status',
    ].any((key) => data[key] != null);
  }

  String _trackingNumber(Map<String, dynamic> data, {required bool package}) {
    const packageKeys = [
      'packageOrderId',
      'package_order_id',
      'packageId',
      'package_id',
      'delivery_code',
    ];
    const orderKeys = [
      'orderNumber',
      'order_number',
      'orderId',
      'order_id',
      'id',
      '_id',
    ];
    return _firstText(
          data,
          package ? [...packageKeys, ...orderKeys] : orderKeys,
        ) ??
        '';
  }

  List<String> _trackingIdentifiers(
    Map<String, dynamic> data, {
    required bool package,
  }) {
    const packageKeys = [
      'packageOrderId',
      'package_order_id',
      'packageId',
      'package_id',
      'delivery_code',
    ];
    const orderKeys = [
      'orderNumber',
      'order_number',
      'orderId',
      'order_id',
      'id',
      '_id',
    ];
    return (package ? [...packageKeys, ...orderKeys] : orderKeys)
        .map((key) => data[key]?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  String _recipientIdentifier(Map<String, dynamic> data) {
    final explicit = _firstText(data, const [
      'recipientUserId',
      'recipient_user_id',
      'recipientId',
      'recipient_id',
      'targetUserId',
      'target_user_id',
      'customerId',
      'customer_id',
      'userId',
      'user_id',
    ]);
    if (explicit != null && explicit.isNotEmpty) return explicit;

    if (_storage.read('isLoggedIn') != true ||
        (_storage.read<String>('accessToken')?.trim().isEmpty ?? true)) {
      return '';
    }
    final rawUser = _storage.read('currentUser');
    if (rawUser is! Map) return '';
    final user = Map<String, dynamic>.from(rawUser);
    return _firstText(user, const [
          'id',
          '_id',
          'userId',
          'user_id',
          'phone',
          'phoneNumber',
          'mobile',
          'email',
        ]) ??
        '';
  }

  String _encodePayload(Map<String, dynamic> data, {required bool package}) {
    final status = _status(data);
    final trackingNumber = _trackingNumber(data, package: package);
    final recipientId = _recipientIdentifier(data);
    final payload = <String, String>{
      'type': package ? 'package' : 'order',
      if (trackingNumber.isNotEmpty)
        (package ? 'packageOrderId' : 'orderId'): trackingNumber,
      if (status?.trim().isNotEmpty == true) 'status': status!.trim(),
      if (recipientId.isNotEmpty) 'recipientUserId': recipientId,
    };
    return jsonEncode(payload);
  }

  bool _packageRecipientAllowed(Map<String, dynamic> data) {
    if (_storage.read('isLoggedIn') != true ||
        (_storage.read<String>('accessToken')?.trim().isEmpty ?? true)) {
      return false;
    }
    final rawUser = _storage.read('currentUser');
    if (rawUser is! Map) return false;
    final user = Map<String, dynamic>.from(rawUser);
    final match = packageRecipientMatch(
      data: data,
      currentUserId:
          (user['id'] ?? user['_id'] ?? user['userId'])?.toString() ?? '',
      currentUserPhone:
          (user['phone'] ?? user['phoneNumber'] ?? user['mobile'])
              ?.toString() ??
          '',
    );
    if (match == PackageRecipientMatch.matched) return true;
    if (match == PackageRecipientMatch.mismatched) return false;

    final liveOrders = Get.isRegistered<PackageController>()
        ? Get.find<PackageController>().orders.map((order) => order.toJson())
        : const <Map<String, dynamic>>[];
    final storedOrders =
        _storage.read<List<dynamic>>(
          PackageController.packageOrdersStorageKey,
        ) ??
        const <dynamic>[];
    return packageNotificationBelongsToKnownOrder(
      data: data,
      storedOrders: [...liveOrders, ...storedOrders],
    );
  }

  Future<void> _updatePackageState(Map<String, dynamic> data) async {
    if (!Get.isRegistered<PackageController>()) return;
    final trackingNumber = _trackingNumber(data, package: true);
    await Get.find<PackageController>().handleRealtimePackagePayload(
      data,
      fallbackOrderId: trackingNumber.isEmpty ? null : trackingNumber,
      notifyStatusChange: false,
    );
  }

  @override
  void onClose() {
    _listenersInitialized = false;
    _foregroundMessageSub?.cancel();
    _messageOpenedSub?.cancel();
    _tokenRefreshSub?.cancel();
    _localTapSub?.cancel();
    super.onClose();
  }
}
