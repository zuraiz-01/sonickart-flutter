import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_snackbar.dart';

class PhoneDialer {
  const PhoneDialer._();

  static String normalize(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';

    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return '';

    return raw.startsWith('+') ? '+$digits' : digits;
  }

  static Future<void> open(String value) async {
    final dialable = normalize(value);
    if (dialable.isEmpty) {
      AppSnackBar.show('Call failed', 'Phone number is not available.');
      return;
    }

    final uri = Uri(scheme: 'tel', path: dialable);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      AppSnackBar.show('Call failed', 'Unable to open phone dialer.');
    }
  }
}
