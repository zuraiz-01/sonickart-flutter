import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class NotificationService extends GetxService {
  NotificationService(this._storage);

  static const _storageKey = 'app_notifications';
  static const _maxItems = 100;

  final GetStorage _storage;
  final notifications = <AppNotification>[].obs;

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
    final normalizedTitle = title.trim();
    final normalizedMessage = message.trim();
    final normalizedCategory = category.trim().isEmpty
        ? 'general'
        : category.trim();
    final normalizedDedupeKey =
        dedupeKey?.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final signature = normalizedDedupeKey?.isNotEmpty == true
        ? normalizedDedupeKey!
        : _notificationSignature(
            title: normalizedTitle,
            message: normalizedMessage,
            category: normalizedCategory,
          );
    final now = DateTime.now();
    final duplicate = notifications.firstWhereOrNull((item) {
      if (now.difference(item.createdAt) > dedupeWindow) return false;
      return (item.dedupeKey ??
              _notificationSignature(
                title: item.title,
                message: item.message,
                category: item.category,
              )) ==
          signature;
    });
    if (duplicate != null) return;

    final notification = AppNotification(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: normalizedTitle,
      message: normalizedMessage,
      category: normalizedCategory,
      createdAt: now,
      dedupeKey: signature,
    );
    notifications.insert(0, notification);
    if (notifications.length > _maxItems) {
      notifications.removeRange(_maxItems, notifications.length);
    }
    await _persist();
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

  String _notificationSignature({
    required String title,
    required String message,
    required String category,
  }) {
    return [
      category,
      title,
      message,
    ].map((value) {
      return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    }).join('|');
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
