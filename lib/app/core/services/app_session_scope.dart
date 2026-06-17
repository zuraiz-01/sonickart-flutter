import 'package:get_storage/get_storage.dart';

class AppSessionScope {
  AppSessionScope._();

  static const _sessionIdKey = 'appSessionId';
  static const selectedServiceLocationSessionKey =
      'selectedServiceLocationSessionId';

  static String get id {
    final box = GetStorage();
    final existing = box.read<String>(_sessionIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final fresh = DateTime.now().microsecondsSinceEpoch.toString();
    box.write(_sessionIdKey, fresh);
    return fresh;
  }

  static bool isCurrentSession(Object? value) {
    return value?.toString() == id;
  }
}
