import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/emergency_repository.dart';
import '../providers/auth_provider.dart';
import '../providers/hospital_provider.dart';
import '../widgets/emergency_trigger.dart';
import 'hospital_detail_screen.dart';
import '../data/models/hospital.dart';
import '../widgets/hospital_card.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  List<EmergencyContact> _contacts = [];
  String _callPhone = EmergencyRepository.nationalEmergencyPhone;
  String _callLabel = EmergencyRepository.nationalEmergencyLabel;
  bool _loading = true;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<EmergencyRepository>();
    final contacts = await repo.getContacts();
    final phone = await repo.getPreferredCallPhone();
    final label = await repo.getPreferredCallLabel();
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _callPhone = phone;
        _callLabel = label;
        _loading = false;
      });
    }
  }

  Future<void> _addContact() async {
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      return;
    }
    final repo = context.read<EmergencyRepository>();
    await repo.addContact(
      name: _nameController.text,
      phone: _phoneController.text,
    );
    _nameController.clear();
    _phoneController.clear();
    await _load();

    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      await repo.syncToUserAccount(auth.user!.id);
    }
  }

  Future<void> _removeContact(EmergencyContact contact) async {
    final repo = context.read<EmergencyRepository>();
    await repo.removeContact(contact.id);
    await _load();

    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      await repo.syncToUserAccount(auth.user!.id);
    }
  }

  Future<void> _setCallPreference(String phone, String label) async {
    final repo = context.read<EmergencyRepository>();
    await repo.setPreferredCall(phone: phone, label: label);
    setState(() {
      _callPhone = phone;
      _callLabel = label;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hospitals = context.watch<HospitalProvider>();
    final emergencyHospitals =
        hospitals.filterEmergencyOnly(hospitals.nearby);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Emergency Mode'),
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Mode'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.emergency, size: 48, color: Colors.red.shade700),
                  const SizedBox(height: 8),
                  Text(
                    'Tap below to call your chosen emergency number and send an SMS alert to all saved contacts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                  const SizedBox(height: 16),
                  const EmergencyTriggerButton(
                    label: 'EMERGENCY — Call & Alert',
                    icon: Icons.emergency,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Will call: $_callLabel',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_contacts.isNotEmpty)
                    Text(
                      'SMS will be sent to ${_contacts.length} contact(s)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Who to call in emergency',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          RadioListTile<String>(
            title: const Text('112 (National Emergency)'),
            value: EmergencyRepository.nationalEmergencyPhone,
            groupValue: _callPhone,
            onChanged: (_) => _setCallPreference(
              EmergencyRepository.nationalEmergencyPhone,
              EmergencyRepository.nationalEmergencyLabel,
            ),
          ),
          ..._contacts.map(
            (c) => RadioListTile<String>(
              title: Text('${c.name} (${c.phone})'),
              value: c.phone,
              groupValue: _callPhone,
              onChanged: (_) => _setCallPreference(c.phone, c.name),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '24/7 Emergency Hospitals Nearby',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (emergencyHospitals.isEmpty)
            const Text('No emergency hospitals found in current results.')
          else
            ...emergencyHospitals.map((Hospital h) => HospitalCard(
                  hospital: h,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HospitalDetailScreen(hospitalId: h.id),
                    ),
                  ),
                )),
          const SizedBox(height: 24),
          Text(
            'Personal Emergency Contacts (SMS alerts)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Contact name'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addContact,
            icon: const Icon(Icons.add),
            label: const Text('Add Contact'),
          ),
          ..._contacts.map(
            (c) => ListTile(
              leading: const Icon(Icons.contact_phone),
              title: Text(c.name),
              subtitle: Text(c.phone),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _removeContact(c),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
