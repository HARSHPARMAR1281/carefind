import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../database/user_database.dart';

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
  });

  final String id;
  final String name;
  final String phone;

  Map<String, String> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
      };

  factory EmergencyContact.fromMap(Map<String, dynamic> map) => EmergencyContact(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String,
      );
}

/// Local emergency contacts + call preference (SharedPreferences, works for guests).
class EmergencyRepository {
  EmergencyRepository({UserDatabase? userDb}) : _userDb = userDb ?? UserDatabase.instance;

  final UserDatabase _userDb;
  static const _uuid = Uuid();
  static const _contactsKey = 'carefind_emergency_contacts';
  static const _callPhoneKey = 'carefind_emergency_call_phone';
  static const _callLabelKey = 'carefind_emergency_call_label';
  static const nationalEmergencyPhone = '112';
  static const nationalEmergencyLabel = '112 (National Emergency)';

  Future<List<EmergencyContact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contactsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => EmergencyContact.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveContacts(List<EmergencyContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _contactsKey,
      jsonEncode(contacts.map((c) => c.toMap()).toList()),
    );
  }

  Future<EmergencyContact> addContact({
    required String name,
    required String phone,
  }) async {
    final contacts = await getContacts();
    final contact = EmergencyContact(
      id: _uuid.v4(),
      name: name.trim(),
      phone: phone.trim(),
    );
    contacts.add(contact);
    await saveContacts(contacts);
    return contact;
  }

  Future<void> removeContact(String id) async {
    final contacts = await getContacts();
    final removed = contacts.where((c) => c.id == id).firstOrNull;
    contacts.removeWhere((c) => c.id == id);
    await saveContacts(contacts);

    if (removed != null) {
      final callPhone = await getPreferredCallPhone();
      if (callPhone == removed.phone) {
        await setPreferredCall(
          phone: nationalEmergencyPhone,
          label: nationalEmergencyLabel,
        );
      }
    }
  }

  Future<String> getPreferredCallPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_callPhoneKey) ?? nationalEmergencyPhone;
  }

  Future<String> getPreferredCallLabel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_callLabelKey) ?? nationalEmergencyLabel;
  }

  Future<void> setPreferredCall({
    required String phone,
    required String label,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_callPhoneKey, phone);
    await prefs.setString(_callLabelKey, label);
  }

  /// Sync logged-in user's DB contacts into local prefs on login.
  Future<void> importFromUserAccount(String userId) async {
    final dbContacts = await _userDb.getEmergencyContacts(userId);
    if (dbContacts.isEmpty) return;

    final contacts = dbContacts
        .map((c) => EmergencyContact(
              id: c['id']!,
              name: c['name']!,
              phone: c['phone']!,
            ))
        .toList();
    await saveContacts(contacts);
  }

  /// Push local contacts to user DB when logged in.
  Future<void> syncToUserAccount(String userId) async {
    final contacts = await getContacts();
    await _userDb.saveEmergencyContacts(
      userId,
      contacts.map((c) => c.toMap()).toList(),
    );
  }
}
