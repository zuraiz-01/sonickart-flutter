import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class NotificationService extends GetxService {
  NotificationService(this._storage);

  static const _storageKey = 'app_notifications';
  static const _maxItems = 100;

  final GetStorage _storage;
  final notifications = <AppNotification>[].obs;
  Future<void> _recordQueue = Future<void>.value();

  int get unreadCount =>
      notifications.where((notification) => !notification.isRead).length;

  @override
  void onInit() {
    super.onInit();
    _restore();
  }

  Future<void> record({
    required String title,
    required String message,
    String category = 'general',
    String? dedupeKey,
    Duration dedupeWindow = const Duration(minutes: 2),
  }) async {
    final operation = _recordQueue.then(
      (_) => _recordNow(
        title: title,
        message: message,
        category: category,
        dedupeKey: dedupeKey,
        dedupeWindow: dedupeWindow,
      ),
    );
    _recordQueue = operation.catchError((_) {});
    return operation;
  }

  Future<void> _recordNow({
    required String title,
    required String message,
    required String category,
    required String? dedupeKey,
    required Duration dedupeWindow,
  }) async {
    final notification = await recordStored(
      storage: _storage,
      title: title,
      message: message,
      category: category,
      dedupeKey: dedupeKey,
      dedupeWindow: dedupeWindow,
    );
    if (notification == null) return;
    _restore();
  }

  static Future<AppNotification?> recordStored({
    required GetStorage storage,
    required String title,
    required String message,
    String category = 'general',
    String? dedupeKey,
    Duration dedupeWindow = const Duration(minutes: 2),
    DateTime? now,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedMessage = message.trim();
    final normalizedCategory = category.trim().isEmpty
        ? 'general'
        : category.trim();
    final normalizedDedupeKey = dedupeKey?.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final signature = normalizedDedupeKey?.isNotEmpty == true
        ? normalizedDedupeKey!
        : _notificationSignature(
            title: normalizedTitle,
            message: normalizedMessage,
            category: normalizedCategory,
          );
    final currentTime = now ?? DateTime.now();
    final storedNotifications =
        (storage.read<List<dynamic>>(_storageKey) ?? <dynamic>[])
            .whereType<Map>()
            .map(
              (item) =>
                  AppNotification.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final duplicate = storedNotifications.firstWhereOrNull((item) {
      final itemDedupeKey = item.dedupeKey?.trim().toLowerCase();
      if (normalizedDedupeKey?.isNotEmpty == true &&
          itemDedupeKey == signature) {
        return true;
      }
      if (currentTime.difference(item.createdAt) > dedupeWindow) return false;
      return (itemDedupeKey ??
              _notificationSignature(
                title: item.title,
                message: item.message,
                category: item.category,
              )) ==
          signature;
    });
    if (duplicate != null) return null;

    final notification = AppNotification(
      id: currentTime.microsecondsSinceEpoch.toString(),
      title: normalizedTitle,
      message: normalizedMessage,
      category: normalizedCategory,
      createdAt: currentTime,
      dedupeKey: signature,
    );
    storedNotifications.insert(0, notification);
    if (storedNotifications.length > _maxItems) {
      storedNotifications.removeRange(_maxItems, storedNotifications.length);
    }
    await storage.write(
      _storageKey,
      storedNotifications.map((item) => item.toJson()).toList(),
    );
    return notification;
  }

  Future<void> markAllRead() async {
    notifications.assignAll(
      notifications.map((item) => item.copyWith(isRead: true)).toList(),
    );
    await _persist();
  }

  Future<void> clearAll() async {
    notifications.clear();
    await _storage.remove(_storageKey);
  }

  void _restore() {
    final raw = _storage.read<List<dynamic>>(_storageKey) ?? <dynamic>[];
    notifications.assignAll(
      raw
          .whereType<Map>()
          .map(
            (item) => AppNotification.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList()
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt)),
    );
  }

  Future<void> _persist() async {
    await _storage.write(
      _storageKey,
      notifications.map((item) => item.toJson()).toList(),
    );
  }

  static String _notificationSignature({
    required String title,
    required String message,
    required String category,
  }) {
    return [category, title, message]
        .map((value) {
          return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        })
        .join('|');
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.createdAt,
    this.isRead = false,
    this.dedupeKey,
  });

  final String id;
  final String title;
  final String message;
  final String category;
  final DateTime createdAt;
  final bool isRead;
  final String? dedupeKey;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      category: category,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      dedupeKey: dedupeKey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      if (dedupeKey != null && dedupeKey!.isNotEmpty) 'dedupeKey': dedupeKey,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] == true,
      dedupeKey: json['dedupeKey']?.toString(),
    );
  }
}
