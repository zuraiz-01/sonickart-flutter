class AppSessionScope {
  AppSessionScope._();

  static final String id = DateTime.now().microsecondsSinceEpoch.toString();
  static const selectedServiceLocationSessionKey =
      'selectedServiceLocationSessionId';

  static bool isCurrentSession(Object? value) {
    return value?.toString() == id;
  }
}
