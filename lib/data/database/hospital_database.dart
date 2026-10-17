import 'dart:math' as math;

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/hospital.dart';

/// Database 1 — Hospital master data (API + enriched fields).
class HospitalDatabase {
  HospitalDatabase._();
  static final HospitalDatabase instance = HospitalDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'carefind_hospitals.db'),
      version: 1,
      onCreate: (db, version) => _createSchema(db),
      onOpen: _ensureCurrentSchema,
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE hospitals (
        id TEXT PRIMARY KEY,
        google_place_id TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        address TEXT,
        phone TEXT,
        rating REAL DEFAULT 0,
        total_reviews INTEGER DEFAULT 0,
        category TEXT DEFAULT 'hospital',
        emergency_available INTEGER DEFAULT 0,
        verified INTEGER DEFAULT 0,
        has_icu INTEGER DEFAULT 0,
        has_ambulance INTEGER DEFAULT 0,
        has_blood_bank INTEGER DEFAULT 0,
        opening_hours TEXT,
        cached_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE specialities (
        speciality_id INTEGER PRIMARY KEY AUTOINCREMENT,
        speciality_name TEXT UNIQUE NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE hospital_specialities (
        hospital_id TEXT NOT NULL,
        speciality_id INTEGER NOT NULL,
        PRIMARY KEY (hospital_id, speciality_id),
        FOREIGN KEY (hospital_id) REFERENCES hospitals(id),
        FOREIGN KEY (speciality_id) REFERENCES specialities(speciality_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE services (
        service_id INTEGER PRIMARY KEY AUTOINCREMENT,
        service_name TEXT UNIQUE NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE hospital_services (
        hospital_id TEXT NOT NULL,
        service_id INTEGER NOT NULL,
        PRIMARY KEY (hospital_id, service_id),
        FOREIGN KEY (hospital_id) REFERENCES hospitals(id),
        FOREIGN KEY (service_id) REFERENCES services(service_id)
      )
    ''');
  }

  /// Phones that ran an earlier build can still have a `hospitals` table
  /// without the `google_place_id` column, and the version number alone
  /// would never rebuild it. These tables only cache OSM data, so when the
  /// columns do not match they are dropped and created again.
  Future<void> _ensureCurrentSchema(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(hospitals)');
    final hasPlaceId = columns.any((c) => c['name'] == 'google_place_id');
    if (hasPlaceId) return;

    for (final table in const [
      'hospital_services',
      'hospital_specialities',
      'services',
      'specialities',
      'hospitals',
    ]) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
    await _createSchema(db);
  }

  Future<void> upsertHospital(Hospital hospital) async {
    final db = await database;
    await db.insert(
      'hospitals',
      hospital.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _syncTags(
      hospital.id,
      hospital.specialities,
      'specialities',
      'speciality_name',
      'hospital_specialities',
      'speciality_id',
    );
    await _syncTags(
      hospital.id,
      hospital.services,
      'services',
      'service_name',
      'hospital_services',
      'service_id',
    );
  }

  Future<void> _syncTags(
    String hospitalId,
    List<String> tags,
    String table,
    String nameColumn,
    String junctionTable,
    String idColumn,
  ) async {
    final db = await database;
    await db.delete(junctionTable, where: 'hospital_id = ?', whereArgs: [hospitalId]);
    for (final tag in tags) {
      final existing = await db.query(
        table,
        where: '$nameColumn = ?',
        whereArgs: [tag],
        limit: 1,
      );
      final int tagId;
      if (existing.isEmpty) {
        tagId = await db.insert(table, {nameColumn: tag});
      } else {
        tagId = existing.first[idColumn] as int;
      }
      await db.insert(junctionTable, {
        'hospital_id': hospitalId,
        idColumn: tagId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<String>> _getTagsForHospital(
    String hospitalId,
    String junctionTable,
    String table,
    String idColumn,
    String nameColumn,
  ) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT t.$nameColumn AS name
      FROM $junctionTable j
      JOIN $table t ON j.$idColumn = t.$idColumn
      WHERE j.hospital_id = ?
    ''', [hospitalId]);
    return rows.map((r) => r['name'] as String).toList();
  }

  Future<Hospital?> getById(String id) async {
    final db = await database;
    final rows = await db.query('hospitals', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final specialities = await _getTagsForHospital(
      id,
      'hospital_specialities',
      'specialities',
      'speciality_id',
      'speciality_name',
    );
    final services = await _getTagsForHospital(
      id,
      'hospital_services',
      'services',
      'service_id',
      'service_name',
    );
    return Hospital.fromMap(rows.first, specialities: specialities, services: services);
  }

  Future<Hospital?> getByPlaceId(String placeId) async {
    final db = await database;
    final rows = await db.query(
      'hospitals',
      where: 'google_place_id = ?',
      whereArgs: [placeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final id = rows.first['id'] as String;
    return getById(id);
  }

  Future<Hospital?> getByOsmId(String osmId) async {
    final byId = await getById(osmId);
    if (byId != null) return byId;
    return getByPlaceId(osmId);
  }

  /// Saved facilities inside a bounding box around the point (cheap SQL
  /// filter, tags are loaded only for the few rows returned). Demo seed rows
  /// are excluded.
  Future<List<Hospital>> getNear({
    required double latitude,
    required double longitude,
    required double radiusKm,
    int limit = 80,
  }) async {
    final db = await database;
    final latDelta = radiusKm / 111.0;
    final lngDelta = radiusKm /
        (111.0 * math.max(0.1, math.cos(latitude * math.pi / 180)));
    final rows = await db.query(
      'hospitals',
      where: 'latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ? '
          "AND google_place_id NOT LIKE 'demo%'",
      whereArgs: [
        latitude - latDelta,
        latitude + latDelta,
        longitude - lngDelta,
        longitude + lngDelta,
      ],
      limit: limit,
    );
    final hospitals = <Hospital>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final specialities = await _getTagsForHospital(
        id, 'hospital_specialities', 'specialities', 'speciality_id', 'speciality_name');
      final services = await _getTagsForHospital(
        id, 'hospital_services', 'services', 'service_id', 'service_name');
      hospitals.add(Hospital.fromMap(row, specialities: specialities, services: services));
    }
    return hospitals;
  }

  Future<List<Hospital>> getAll() async {
    final db = await database;
    final rows = await db.query('hospitals', orderBy: 'name ASC');
    final hospitals = <Hospital>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final specialities = await _getTagsForHospital(
        id,
        'hospital_specialities',
        'specialities',
        'speciality_id',
        'speciality_name',
      );
      final services = await _getTagsForHospital(
        id,
        'hospital_services',
        'services',
        'service_id',
        'service_name',
      );
      hospitals.add(Hospital.fromMap(row, specialities: specialities, services: services));
    }
    return hospitals;
  }

  Future<List<Hospital>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <Hospital>[];
    for (final id in ids) {
      final h = await getById(id);
      if (h != null) results.add(h);
    }
    return results;
  }

  Future<void> seedDemoHospitals() async {
    final count = Sqflite.firstIntValue(
      await (await database).rawQuery('SELECT COUNT(*) FROM hospitals'),
    );
    if ((count ?? 0) > 0) return;

    final demos = [
      Hospital(
        id: 'demo_city_general',
        googlePlaceId: 'demo_place_city_general',
        name: 'City General Hospital',
        latitude: 28.6139,
        longitude: 77.2090,
        address: 'Connaught Place, New Delhi',
        phone: '+91-11-23456789',
        rating: 4.2,
        totalReviews: 1280,
        emergencyAvailable: true,
        verified: true,
        hasIcu: true,
        hasAmbulance: true,
        hasBloodBank: true,
        openingHours: '24/7 Emergency',
        specialities: const ['Cardiology', 'Neurology', 'Orthopedics'],
        services: const ['Emergency', 'ICU', 'Ambulance', 'Blood Bank'],
        cachedAt: DateTime.now(),
      ),
      Hospital(
        id: 'demo_apollo',
        googlePlaceId: 'demo_place_apollo',
        name: 'Apollo Care Multispeciality',
        latitude: 28.5355,
        longitude: 77.3910,
        address: 'Sector 62, Noida',
        phone: '+91-120-4567890',
        rating: 4.6,
        totalReviews: 3420,
        emergencyAvailable: true,
        verified: true,
        hasIcu: true,
        hasAmbulance: true,
        specialities: const ['Oncology', 'Pediatrics', 'Gynecology'],
        services: const ['Emergency', 'ICU', 'Pharmacy', 'Diagnostics'],
        cachedAt: DateTime.now(),
      ),
      Hospital(
        id: 'demo_community',
        googlePlaceId: 'demo_place_community',
        name: 'Community Health Center',
        latitude: 28.4595,
        longitude: 77.0266,
        address: 'Gurgaon Sector 14',
        phone: '+91-124-9876543',
        rating: 3.9,
        totalReviews: 456,
        emergencyAvailable: false,
        verified: false,
        hasAmbulance: true,
        specialities: const ['General Medicine', 'Dermatology'],
        services: const ['OPD', 'Vaccination', 'Ambulance'],
        cachedAt: DateTime.now(),
      ),
    ];

    for (final h in demos) {
      await upsertHospital(h);
    }
  }
}
