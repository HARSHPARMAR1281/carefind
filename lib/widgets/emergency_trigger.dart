import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/emergency_service.dart';
import '../data/repositories/emergency_repository.dart';
import '../providers/hospital_provider.dart';

class EmergencyTriggerButton extends StatelessWidget {
  const EmergencyTriggerButton({
    super.key,
    this.label = 'EMERGENCY',
    this.icon = Icons.emergency,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final bool compact;

  Future<void> _trigger(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.emergency, color: Colors.red.shade700, size: 40),
        title: const Text('Trigger emergency?'),
        content: const Text(
          'This will call your selected emergency number and open an SMS '
          'to your saved contacts with your location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Call & Alert'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final repo = context.read<EmergencyRepository>();
    final hospitals = context.read<HospitalProvider>();
    final service = EmergencyService(repo);

    final result = await service.triggerEmergency(
      location: hospitals.position,
    );

    if (!context.mounted) return;

    final parts = <String>[];
    if (result.callLaunched) {
      parts.add('Calling ${result.callPhone}…');
    } else {
      parts.add('Could not start call.');
    }
    if (result.smsRecipientCount > 0) {
      parts.add(
        result.smsLaunched
            ? 'SMS opened for ${result.smsRecipientCount} contact(s). Tap Send.'
            : 'Could not open SMS app.',
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(parts.join(' '))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return FloatingActionButton.large(
        heroTag: 'home_emergency_fab',
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        onPressed: () => _trigger(context),
        child: Icon(icon, size: 36),
      );
    }

    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.red.shade700,
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: () => _trigger(context),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
