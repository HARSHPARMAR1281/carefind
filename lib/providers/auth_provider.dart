import 'package:flutter/foundation.dart';

import '../data/models/user_model.dart';
import '../data/repositories/user_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._userRepository);

  final UserRepository _userRepository;
  AppUser? _user;
  bool _loading = false;
  String? _error;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> initialize() async {
    _loading = true;
    notifyListeners();
    _user = await _userRepository.getCurrentUser();
    _loading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      _user = await _userRepository.login(email, password);
      if (_user == null) {
        _error = 'Invalid email or password.';
        notifyListeners();
        return false;
      }
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    _setLoading(true);
    try {
      _user = await _userRepository.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _userRepository.logout();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
