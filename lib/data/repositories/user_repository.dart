import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../database/user_database.dart';
import '../models/review.dart';
import '../models/user_model.dart';

class UserRepository {
  UserRepository({UserDatabase? userDb}) : _userDb = userDb ?? UserDatabase.instance;

  final UserDatabase _userDb;
  static const _sessionKey = 'carefind_user_id';

  Future<void> initialize() async {
    await _userDb.database;
  }

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    final user = await _userDb.register(
      name: name,
      email: email,
      password: password,
      phone: phone,
    );
    await _saveSession(user.id);
    return user;
  }

  Future<AppUser?> login(String email, String password) async {
    final id = email.trim().toLowerCase();
    if (id == AppConfig.adminId.toLowerCase() &&
        password == AppConfig.adminPassword) {
      final admin = AppUser.admin();
      await _saveSession(admin.id);
      return admin;
    }

    final user = await _userDb.login(email, password);
    if (user != null) await _saveSession(user.id);
    return user;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<AppUser?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_sessionKey);
    if (id == null) return null;
    if (id == AppConfig.adminUserId) return AppUser.admin();
    return _userDb.getUserById(id);
  }

  Future<void> _saveSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, userId);
  }

  Future<void> toggleFavorite(String userId, String hospitalId) async {
    final isFav = await _userDb.isFavorite(userId, hospitalId);
    if (isFav) {
      await _userDb.removeFavorite(userId, hospitalId);
    } else {
      await _userDb.addFavorite(userId, hospitalId);
    }
  }

  Future<bool> isFavorite(String userId, String hospitalId) =>
      _userDb.isFavorite(userId, hospitalId);

  Future<List<String>> getFavoriteIds(String userId) =>
      _userDb.getFavoriteHospitalIds(userId);

  Future<Review> addReview({
    required String userId,
    required String hospitalId,
    required int rating,
    required String reviewText,
  }) =>
      _userDb.addReview(
        userId: userId,
        hospitalId: hospitalId,
        rating: rating,
        reviewText: reviewText,
      );

  Future<List<Review>> getReviews(String hospitalId) =>
      _userDb.getReviewsForHospital(hospitalId);

  Future<double> getUserAverageRating(String hospitalId) =>
      _userDb.getAverageRating(hospitalId);

  Future<List<Map<String, String>>> getEmergencyContacts(String userId) =>
      _userDb.getEmergencyContacts(userId);

  Future<void> saveEmergencyContacts(
    String userId,
    List<Map<String, String>> contacts,
  ) =>
      _userDb.saveEmergencyContacts(userId, contacts);
}
