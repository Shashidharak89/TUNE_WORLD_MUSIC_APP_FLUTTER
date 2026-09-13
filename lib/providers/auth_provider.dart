import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String _tokenKey = 'tune_world_jwt_token';

  String? _token;
  UserModel? _user;
  bool _isVerifying = true;
  bool _isLoading = false;
  String? _errorMessage;

  String? get token => _token;
  UserModel? get user => _user;
  bool get isVerifying => _isVerifying;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty && _user != null;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    initAuth();
  }

  Future<void> initAuth() async {
    _isVerifying = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_tokenKey);

      if (savedToken != null && savedToken.isNotEmpty) {
        _token = savedToken;
        // Verify token against backend GET /api/auth/me
        _user = await ApiService.getMe(savedToken);
      }
    } catch (e) {
      print('Auto-verification error: $e');
      // Token is invalid/expired - clear token
      await logout();
    } finally {
      _isVerifying = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await ApiService.login(email, password);
      _token = result['token'];
      _user = UserModel.fromJson(result['user']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await ApiService.register(name, email, password);
      _token = result['token'];
      _user = UserModel.fromJson(result['user']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _errorMessage = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);

    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
