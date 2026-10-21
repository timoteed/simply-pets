import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class StorageService {
  static const _tokenKey = 'simplypets-token';
  static const _userKey = 'simplypets-user';
  static const _themeKey = 'simplypets-theme';
  static const _baseUrlKey = 'simplypets-api-base-url';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  String? getToken() => _prefs.getString(_tokenKey);

  Future<void> setToken(String token) async {
    await _prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    await _prefs.remove(_tokenKey);
  }

  User? getUser() {
    final raw = _prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return User.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> setUser(User user) async {
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> clearUser() async {
    await _prefs.remove(_userKey);
  }

  Future<void> clearAuth() async {
    await clearToken();
    await clearUser();
  }

  String getThemeMode() => _prefs.getString(_themeKey) ?? 'system';

  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(_themeKey, mode);
  }

  String? getApiBaseUrl() => _prefs.getString(_baseUrlKey);

  Future<void> setApiBaseUrl(String url) async {
    await _prefs.setString(_baseUrlKey, url);
  }
}
