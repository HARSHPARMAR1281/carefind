import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repositories/emergency_repository.dart';

class EmergencyService {
  const EmergencyService(this._repository);

  final EmergencyRepository _repository;

  static const emergencyMessagePrefix =
      'EMERGENCY! I need help urgently. Please contact me or alert services.';

  Future<EmergencyTriggerResult> triggerEmergency({
    Position? location,
  }) async {
    final callPhone = await _repository.getPreferredCallPhone();
    final contacts = await _repository.getContacts();
    final message = _buildMessage(location);

    final callOk = await _dial(callPhone);

    var smsOk = false;
    if (contacts.isNotEmpty) {
      smsOk = await _sendSmsToContacts(
        contacts.map((c) => c.phone).toList(),
        message,
      );
    }

    return EmergencyTriggerResult(
      callLaunched: callOk,
      smsLaunched: smsOk,
      callPhone: callPhone,
      smsRecipientCount: contacts.length,
    );
  }

  String _buildMessage(Position? location) {
    if (location == null) {
      return '$emergencyMessagePrefix Location unavailable.';
    }
    final mapsLink =
        'https://www.openstreetmap.org/?mlat=${location.latitude}&mlon=${location.longitude}'
        '#map=17/${location.latitude}/${location.longitude}';
    return '$emergencyMessagePrefix My location: $mapsLink '
        '(${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)})';
  }

  Future<bool> _dial(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> _sendSmsToContacts(List<String> phones, String message) async {
    final cleaned = phones
        .map((p) => p.replaceAll(RegExp(r'[^\d+]'), ''))
        .where((p) => p.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) return false;

    // Opens SMS app with all recipients and pre-filled emergency message.
    final uri = Uri(
      scheme: 'sms',
      path: cleaned.join(','),
      queryParameters: {'body': message},
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class EmergencyTriggerResult {
  const EmergencyTriggerResult({
    required this.callLaunched,
    required this.smsLaunched,
    required this.callPhone,
    required this.smsRecipientCount,
  });

  final bool callLaunched;
  final bool smsLaunched;
  final String callPhone;
  final int smsRecipientCount;
}
