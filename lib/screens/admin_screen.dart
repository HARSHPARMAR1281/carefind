import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/models/hospital.dart';
import '../providers/auth_provider.dart';
import '../providers/hospital_provider.dart';
import 'login_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const _uuid = Uuid();
  final _formKey = GlobalKey<FormState>();

  final _placeIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _hoursController = TextEditingController();
  final _specialitiesController = TextEditingController();
  final _servicesController = TextEditingController();

  bool _emergency = false;
  bool _verified = false;
  bool _icu = false;
  bool _ambulance = false;
  bool _bloodBank = false;
  bool _saving = false;

  String? _selectedId;
  List<Hospital> _hospitals = [];

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    final list = await context.read<HospitalProvider>().getAllCachedHospitals();
    if (mounted) setState(() => _hospitals = list);
  }

  void _selectHospitalById(String? id) {
    if (id == null) {
      setState(() => _clearForm());
      return;
    }
    Hospital? h;
    for (final item in _hospitals) {
      if (item.id == id) {
        h = item;
        break;
      }
    }
    if (h == null) return;
    final hospital = h;
    setState(() {
      _selectedId = id;
      _placeIdController.text = hospital.googlePlaceId;
      _nameController.text = hospital.name;
      _addressController.text = hospital.address;
      _phoneController.text = hospital.phone;
      _latController.text = hospital.latitude.toString();
      _lngController.text = hospital.longitude.toString();
      _hoursController.text = hospital.openingHours;
      _specialitiesController.text = hospital.specialities.join(', ');
      _servicesController.text = hospital.services.join(', ');
      _emergency = hospital.emergencyAvailable;
      _verified = hospital.verified;
      _icu = hospital.hasIcu;
      _ambulance = hospital.hasAmbulance;
      _bloodBank = hospital.hasBloodBank;
    });
  }

  void _clearForm() {
    _placeIdController.clear();
    _nameController.clear();
    _addressController.clear();
    _phoneController.clear();
    _latController.clear();
    _lngController.clear();
    _hoursController.clear();
    _specialitiesController.clear();
    _servicesController.clear();
    _emergency = false;
    _verified = false;
    _icu = false;
    _ambulance = false;
    _bloodBank = false;
    _selectedId = null;
  }

  void _newHospital() {
    setState(() {
      _clearForm();
      _placeIdController.text = 'manual_${_uuid.v4().substring(0, 8)}';
      _latController.text = '28.6139';
      _lngController.text = '77.2090';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final placeId = _placeIdController.text.trim();
      final hospital = Hospital(
        id: _selectedId ?? placeId,
        googlePlaceId: placeId,
        name: _nameController.text.trim(),
        latitude: double.parse(_latController.text.trim()),
        longitude: double.parse(_lngController.text.trim()),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        emergencyAvailable: _emergency,
        verified: _verified,
        hasIcu: _icu,
        hasAmbulance: _ambulance,
        hasBloodBank: _bloodBank,
        openingHours: _hoursController.text.trim(),
        specialities: _splitCsv(_specialitiesController.text),
        services: _splitCsv(_servicesController.text),
        cachedAt: DateTime.now(),
      );

      await context.read<HospitalProvider>().saveEnrichedHospital(hospital);
      await context.read<HospitalProvider>().refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved "${hospital.name}"')),
        );
        await _loadHospitals();
        setState(() => _selectedId = hospital.id);
        _selectHospitalById(hospital.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _splitCsv(String value) {
    return value
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    _placeIdController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _hoursController.dispose();
    _specialitiesController.dispose();
    _servicesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 48),
              const SizedBox(height: 12),
              const Text('Admin access only'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Sign in as admin'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin — Enrich Hospitals'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Select hospital to edit',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: _selectedId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Choose cached hospital',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— New / none —'),
                        ),
                        ..._hospitals.map(
                          (h) => DropdownMenuItem(
                            value: h.id,
                            child: Text(
                              h.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: _selectHospitalById,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _newHospital,
                      icon: const Icon(Icons.add),
                      label: const Text('New hospital entry'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _placeIdController,
              decoration: const InputDecoration(
                labelText: 'Google Place ID *',
                helperText: 'Stable master identifier',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Place ID required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Hospital name *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    decoration: const InputDecoration(labelText: 'Latitude *'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) => double.tryParse(v ?? '') == null
                        ? 'Valid latitude required'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lngController,
                    decoration: const InputDecoration(labelText: 'Longitude *'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) => double.tryParse(v ?? '') == null
                        ? 'Valid longitude required'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hoursController,
              decoration: const InputDecoration(labelText: 'Opening hours'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _specialitiesController,
              decoration: const InputDecoration(
                labelText: 'Specialities',
                helperText: 'Comma-separated, e.g. Cardiology, Neurology',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _servicesController,
              decoration: const InputDecoration(
                labelText: 'Services',
                helperText: 'Comma-separated, e.g. ICU, Ambulance',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Emergency available'),
              value: _emergency,
              onChanged: (v) => setState(() => _emergency = v),
            ),
            SwitchListTile(
              title: const Text('Verified listing'),
              value: _verified,
              onChanged: (v) => setState(() => _verified = v),
            ),
            SwitchListTile(
              title: const Text('ICU'),
              value: _icu,
              onChanged: (v) => setState(() => _icu = v),
            ),
            SwitchListTile(
              title: const Text('Ambulance'),
              value: _ambulance,
              onChanged: (v) => setState(() => _ambulance = v),
            ),
            SwitchListTile(
              title: const Text('Blood bank'),
              value: _bloodBank,
              onChanged: (v) => setState(() => _bloodBank = v),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving…' : 'Save to Hospital DB'),
            ),
          ],
        ),
      ),
    );
  }
}
