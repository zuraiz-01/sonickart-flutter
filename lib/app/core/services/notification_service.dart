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
  }) async {
    final notification = AppNotification(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim(),
      message: message.trim(),
      category: category.trim().isEmpty ? 'general' : category.trim(),
      createdAt: DateTime.now(),
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
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String message;
  final String category;
  final DateTime createdAt;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      category: category,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
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
    );
  }
}
