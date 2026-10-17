import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/review.dart';
import '../models/user_model.dart';

/// Database 2 — User accounts, favorites, reviews (isolated from hospital DB).
class UserDatabase {
  UserDatabase._();
  static final UserDatabase instance = UserDatabase._();
  Database? _db;
  static const _uuid = Uuid();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'carefind_users.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            phone TEXT,
            password_hash TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE favorites (
            user_id TEXT NOT NULL,
            hospital_id TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (user_id, hospital_id),
            FOREIGN KEY (user_id) REFERENCES users(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE reviews (
            review_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            hospital_id TEXT NOT NULL,
            rating INTEGER NOT NULL,
            review_text TEXT,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE emergency_contacts (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id)
          )
        ''');
      },
    );
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    final db = await database;
    final existing = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.toLowerCase().trim()],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw Exception('An account with this email already exists.');
    }

    final user = AppUser(
      id: _uuid.v4(),
      name: name.trim(),
      email: email.toLowerCase().trim(),
      phone: phone.trim(),
      createdAt: DateTime.now(),
    );

    await db.insert('users', {
      ...user.toMap(),
      'password_hash': _hashPassword(password),
    });
    return user;
  }

  Future<AppUser?> login(String email, String password) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'email = ? AND password_hash = ?',
      whereArgs: [email.toLowerCase().trim(), _hashPassword(password)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser?> getUserById(String id) async {
    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<void> addFavorite(String userId, String hospitalId) async {
    final db = await database;
    await db.insert(
      'favorites',
      {
        'user_id': userId,
        'hospital_id': hospitalId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(String userId, String hospitalId) async {
    final db = await database;
    await db.delete(
      'favorites',
      where: 'user_id = ? AND hospital_id = ?',
      whereArgs: [userId, hospitalId],
    );
  }

  Future<bool> isFavorite(String userId, String hospitalId) async {
    final db = await database;
    final rows = await db.query(
      'favorites',
      where: 'user_id = ? AND hospital_id = ?',
      whereArgs: [userId, hospitalId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<String>> getFavoriteHospitalIds(String userId) async {
    final db = await database;
    final rows = await db.query(
      'favorites',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => r['hospital_id'] as String).toList();
  }

  Future<Review> addReview({
    required String userId,
    required String hospitalId,
    required int rating,
    required String reviewText,
  }) async {
    final db = await database;
    final review = Review(
      id: _uuid.v4(),
      userId: userId,
      hospitalId: hospitalId,
      rating: rating.clamp(1, 5),
      reviewText: reviewText.trim(),
      createdAt: DateTime.now(),
    );
    await db.insert('reviews', {
      'review_id': review.id,
      'user_id': review.userId,
      'hospital_id': review.hospitalId,
      'rating': review.rating,
      'review_text': review.reviewText,
      'created_at': review.createdAt.millisecondsSinceEpoch,
    });
    return review;
  }

  Future<List<Review>> getReviewsForHospital(String hospitalId) async {
    final db = await database;
    final rows = await db.query(
      'reviews',
      where: 'hospital_id = ?',
      whereArgs: [hospitalId],
      orderBy: 'created_at DESC',
    );
    final reviews = <Review>[];
    for (final row in rows) {
      final user = await getUserById(row['user_id'] as String);
      reviews.add(Review.fromMap(
        {
          'id': row['review_id'],
          'user_id': row['user_id'],
          'hospital_id': row['hospital_id'],
          'rating': row['rating'],
          'review_text': row['review_text'],
          'created_at': row['created_at'],
        },
        userName: user?.name ?? 'User',
      ));
    }
    return reviews;
  }

  Future<double> getAverageRating(String hospitalId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT AVG(rating) as avg FROM reviews WHERE hospital_id = ?',
      [hospitalId],
    );
    final avg = result.first['avg'];
    if (avg == null) return 0;
    return (avg as num).toDouble();
  }

  Future<List<Map<String, String>>> getEmergencyContacts(String userId) async {
    final db = await database;
    final rows = await db.query(
      'emergency_contacts',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows
        .map((r) => {
              'id': r['id'] as String,
              'name': r['name'] as String,
              'phone': r['phone'] as String,
            })
        .toList();
  }

  Future<void> saveEmergencyContacts(
    String userId,
    List<Map<String, String>> contacts,
  ) async {
    final db = await database;
    await db.delete('emergency_contacts', where: 'user_id = ?', whereArgs: [userId]);
    for (final c in contacts) {
      await db.insert('emergency_contacts', {
        'id': c['id'] ?? _uuid.v4(),
        'user_id': userId,
        'name': c['name']!,
        'phone': c['phone']!,
      });
    }
  }
}
