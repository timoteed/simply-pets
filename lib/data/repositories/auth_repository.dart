import '../models/user.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AuthRepository {
  final ApiService apiService;
  final StorageService storageService;

  AuthRepository({
    required this.apiService,
    required this.storageService,
  });

  bool get isAuthenticated => storageService.getToken() != null;

  User? get currentUser => storageService.getUser();

  Future<AuthResponse> signup({
    required String username,
    required String password,
    String displayName = '',
  }) async {
    final res = await apiService.post('/api/auth/signup', {
      'username': username.trim(),
      'password': password,
      'display_name': displayName.trim(),
    });

    final authRes = AuthResponse.fromJson(res as Map<String, dynamic>);
    await storageService.setToken(authRes.token);
    await storageService.setUser(authRes.user);
    return authRes;
  }

  Future<AuthResponse> login({
    required String username,
    required String password,
  }) async {
    final res = await apiService.post('/api/auth/login', {
      'username': username.trim(),
      'password': password,
    });

    final authRes = AuthResponse.fromJson(res as Map<String, dynamic>);
    await storageService.setToken(authRes.token);
    await storageService.setUser(authRes.user);
    return authRes;
  }

  Future<void> logout() async {
    try {
      await apiService.post('/api/auth/logout');
    } catch (_) {
      // Ignore network errors on logout
    } finally {
      await storageService.clearAuth();
    }
  }

  Future<User?> checkSession() async {
    final token = storageService.getToken();
    if (token == null || token.isEmpty) {
      await storageService.clearAuth();
      return null;
    }

    try {
      final res = await apiService.get('/api/auth/me');
      final user = User.fromJson(res as Map<String, dynamic>);
      await storageService.setUser(user);
      return user;
    } catch (_) {
      await storageService.clearAuth();
      return null;
    }
  }
}
