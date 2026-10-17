import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the device phone dialer with the number pre-filled (like Flipkart delivery call).
class PhoneLauncher {
  PhoneLauncher._();

  /// Strips formatting while keeping country code digits.
  static String normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      final char = trimmed[i];
      if (char == '+' && buffer.isEmpty) {
        buffer.write(char);
      } else if (RegExp(r'\d').hasMatch(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  static bool isCallable(String? phone) => normalize(phone ?? '').isNotEmpty;

  static Future<bool> dial(String phone) async {
    final normalized = normalize(phone);
    if (normalized.isEmpty) return false;

    final uri = Uri(scheme: 'tel', path: normalized);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return launched;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('PhoneLauncher.dial failed: $e');
      }
      return false;
    }
  }
}
