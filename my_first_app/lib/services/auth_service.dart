import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_first_app/models/aww_model.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';

  /// Login AWW
  Future<bool> login(String phone, String password) async {
    try {
      // TODO: Replace with actual API call
      // For now, mock login
      if (phone.length == 10 && password.isNotEmpty) {
        // Simulate token generation
        String mockToken = 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}';
        String mockRefreshToken = 'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}';

        await _storage.write(key: _tokenKey, value: mockToken);
        await _storage.write(key: _refreshTokenKey, value: mockRefreshToken);

        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  /// Register new AWW
  Future<bool> register(AWWModel aww) async {
    try {
      // TODO: Replace with actual API call
      if (aww.name.isNotEmpty && aww.mobileNumber.length == 10) {
        String mockToken = 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}';
        String mockRefreshToken = 'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}';

        await _storage.write(key: _tokenKey, value: mockToken);
        await _storage.write(key: _refreshTokenKey, value: mockRefreshToken);
        await _storage.write(key: _userDataKey, value: aww.toString());

        return true;
      }
      return false;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _userDataKey);
    } catch (e) {
      print('Logout error: $e');
    }
  }

  /// Get auth token
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (e) {
      print('Get token error: $e');
      return null;
    }
  }

  /// Save auth token from backend login response
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    try {
      String? token = await getToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      print('Auth check error: $e');
      return false;
    }
  }

  /// Refresh token
  Future<bool> refreshToken() async {
    try {
      String? refreshToken = await _storage.read(key: _refreshTokenKey);
      if (refreshToken == null) return false;

      // TODO: Replace with actual API call
      String newToken = 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}';
      await _storage.write(key: _tokenKey, value: newToken);

      return true;
    } catch (e) {
      print('Refresh token error: $e');
      return false;
    }
  }
}
