import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_first_app/models/aww_model.dart';
import 'package:my_first_app/services/local_db_service.dart';
import 'package:my_first_app/core/constants/app_constants.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  static const String _awcCodeKey = 'awc_code';
  static final RegExp _awcCodePattern = RegExp(r'^(AWW|AWS)_DEMO_\d{3,4}$');

  String _awcComparableKey(String value) {
    final normalized = value.trim().toUpperCase();
    final match = RegExp(r'^(AWW|AWS)_DEMO_(\d{3,4})$').firstMatch(normalized);
    if (match == null) {
      return normalized;
    }
    final suffix = int.tryParse(match.group(2) ?? '');
    if (suffix == null) {
      return normalized;
    }
    return 'DEMO_$suffix';
  }

  bool _awcCodesMatch(String left, String right) {
    final a = left.trim().toUpperCase();
    final b = right.trim().toUpperCase();
    if (a.isEmpty || b.isEmpty) {
      return a == b;
    }
    if (a == b) {
      return true;
    }
    return _awcComparableKey(a) == _awcComparableKey(b);
  }

  AWWModel _withMappedLocationIfMissing(AWWModel aww) {
    final mapping = AppConstants.getAwcMapping(aww.awcCode);
    final district = aww.district.trim().isNotEmpty
        ? aww.district.trim()
        : (mapping['district'] ?? '');
    final mandal = aww.mandal.trim().isNotEmpty
        ? aww.mandal.trim()
        : (mapping['mandal'] ?? '');
    return aww.copyWith(
      awcCode: aww.awcCode.trim().toUpperCase(),
      district: district,
      mandal: mandal,
      updatedAt: DateTime.now(),
    );
  }

  AWWModel _buildFallbackAww(String awcCode) {
    final normalizedAwcCode = awcCode.trim().toUpperCase();
    final mapping = AppConstants.getAwcMapping(normalizedAwcCode);
    final now = DateTime.now();
    return AWWModel(
      awwId: 'aww_$normalizedAwcCode',
      name: normalizedAwcCode,
      mobileNumber: '0000000000',
      awcCode: normalizedAwcCode,
      mandal: mapping['mandal'] ?? '',
      district: mapping['district'] ?? '',
      password: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  AWWModel? _tryDecodeAww(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return _withMappedLocationIfMissing(AWWModel.fromJson(decoded));
      }
      if (decoded is Map) {
        return _withMappedLocationIfMissing(
          AWWModel.fromJson(Map<String, dynamic>.from(decoded)),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistAwwContext(AWWModel aww) async {
    final normalized = _withMappedLocationIfMissing(aww);
    await _storage.write(key: _awcCodeKey, value: normalized.awcCode);
    await _storage.write(
      key: _userDataKey,
      value: jsonEncode(normalized.toJson()),
    );
    final localDb = LocalDBService();
    await localDb.initialize();
    await localDb.saveAWW(normalized);
  }

  /// Login AWW
  Future<bool> login(String awcCode, String password) async {
    try {
      // TODO: Replace with actual API call
      // For now, mock login
      final normalizedAwcCode = awcCode.trim().toUpperCase();
      if (_awcCodePattern.hasMatch(normalizedAwcCode) && password.isNotEmpty) {
        // Simulate token generation
        String mockToken = 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}';
        String mockRefreshToken = 'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}';

        await _storage.write(key: _tokenKey, value: mockToken);
        await _storage.write(key: _refreshTokenKey, value: mockRefreshToken);
        
        // Get district and mandal for the AWC code
        final awcMapping = AppConstants.getAwcMapping(normalizedAwcCode);
        final district = awcMapping['district'] ?? '';
        final mandal = awcMapping['mandal'] ?? '';
        
        await _persistAwwContext(
          AWWModel(
            awwId: 'aww_$normalizedAwcCode',
            name: normalizedAwcCode,
            mobileNumber: '0000000000',
            awcCode: normalizedAwcCode,
            mandal: mandal,
            district: district,
            password: password,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

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
      final normalizedAwcCode = aww.awcCode.trim().toUpperCase();
      final password = aww.password.trim();
      if (!_awcCodePattern.hasMatch(normalizedAwcCode) || password.isEmpty) {
        return false;
      }

      final normalizedAww = _withMappedLocationIfMissing(
        aww.copyWith(
          awcCode: normalizedAwcCode,
          name: aww.name.trim().isNotEmpty
              ? aww.name.trim()
              : 'aww_$normalizedAwcCode',
          mobileNumber: aww.mobileNumber.trim(),
          password: password,
          updatedAt: DateTime.now(),
        ),
      );

      String mockToken = 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}';
      String mockRefreshToken = 'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}';

      await _storage.write(key: _tokenKey, value: mockToken);
      await _storage.write(key: _refreshTokenKey, value: mockRefreshToken);
      await _persistAwwContext(normalizedAww);

      return true;
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
      await _storage.delete(key: _awcCodeKey);
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

  /// Save current logged-in AWW code for dashboard display.
  Future<void> saveLoggedInAwcCode(String awcCode) async {
    final normalizedAwcCode = awcCode.trim().toUpperCase();
    await _storage.write(key: _awcCodeKey, value: normalizedAwcCode);

    final localDb = LocalDBService();
    await localDb.initialize();
    final currentAww = localDb.getCurrentAWW();
    if (currentAww != null &&
        _awcCodesMatch(currentAww.awcCode, normalizedAwcCode)) {
      await _persistAwwContext(currentAww.copyWith(awcCode: normalizedAwcCode));
      return;
    }

    final storedAww = _tryDecodeAww(await _storage.read(key: _userDataKey));
    if (storedAww != null &&
        _awcCodesMatch(storedAww.awcCode, normalizedAwcCode)) {
      await _persistAwwContext(storedAww.copyWith(awcCode: normalizedAwcCode));
      return;
    }

    await _persistAwwContext(_buildFallbackAww(normalizedAwcCode));
  }

  /// Save/merge logged-in AWW profile details resolved from backend.
  Future<void> saveLoggedInAwwProfile({
    required String awcCode,
    String? awwId,
    String? name,
    String? mobileNumber,
    String? district,
    String? mandal,
    String? password,
  }) async {
    final normalizedAwcCode = awcCode.trim().toUpperCase();
    if (normalizedAwcCode.isEmpty) {
      return;
    }

    final localDb = LocalDBService();
    await localDb.initialize();
    final localAww = localDb.getCurrentAWW();
    final storedAww = _tryDecodeAww(await _storage.read(key: _userDataKey));

    AWWModel? baseline;
    if (localAww != null &&
        _awcCodesMatch(localAww.awcCode, normalizedAwcCode)) {
      baseline = localAww;
    } else if (storedAww != null &&
        _awcCodesMatch(storedAww.awcCode, normalizedAwcCode)) {
      baseline = storedAww;
    }

    final now = DateTime.now();
    final merged = AWWModel(
      awwId: (awwId ?? '').trim().isNotEmpty
          ? awwId!.trim()
          : (baseline?.awwId ?? 'aww_$normalizedAwcCode'),
      name: (name ?? '').trim().isNotEmpty
          ? name!.trim()
          : (baseline?.name ?? normalizedAwcCode),
      mobileNumber: (mobileNumber ?? '').trim().isNotEmpty
          ? mobileNumber!.trim()
          : (baseline?.mobileNumber ?? '0000000000'),
      awcCode: normalizedAwcCode,
      mandal: (mandal ?? '').trim().isNotEmpty
          ? mandal!.trim()
          : (baseline?.mandal ?? ''),
      district: (district ?? '').trim().isNotEmpty
          ? district!.trim()
          : (baseline?.district ?? ''),
      password: (password ?? '').isNotEmpty
          ? password!
          : (baseline?.password ?? ''),
      createdAt: baseline?.createdAt ?? now,
      updatedAt: now,
    );

    await _persistAwwContext(merged);
  }

  /// Get current logged-in AWW code.
  Future<String?> getLoggedInAwcCode() async {
    try {
      return await _storage.read(key: _awcCodeKey);
    } catch (e) {
      print('Get awc_code error: $e');
      return null;
    }
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

  /// Get the currently logged-in AWW's full information (including district and mandal)
  Future<AWWModel?> getCurrentUserAww() async {
    try {
      final localDb = LocalDBService();
      await localDb.initialize();
      final savedAwcCode =
          (await _storage.read(key: _awcCodeKey) ?? '').trim().toUpperCase();

      final localAww = localDb.getCurrentAWW();
      if (localAww != null &&
          (savedAwcCode.isEmpty ||
              _awcCodesMatch(localAww.awcCode, savedAwcCode))) {
        return _withMappedLocationIfMissing(localAww);
      }

      final storedAww = _tryDecodeAww(await _storage.read(key: _userDataKey));
      if (storedAww != null &&
          (savedAwcCode.isEmpty ||
              _awcCodesMatch(storedAww.awcCode, savedAwcCode))) {
        final resolved = savedAwcCode.isNotEmpty
            ? _withMappedLocationIfMissing(
                storedAww.copyWith(awcCode: savedAwcCode),
              )
            : storedAww;
        await localDb.saveAWW(resolved);
        return resolved;
      }

      if (savedAwcCode.isNotEmpty) {
        final fallback = _buildFallbackAww(savedAwcCode);
        await _persistAwwContext(fallback);
        return fallback;
      }

      return localAww;
    } catch (e) {
      print('Get current user AWW error: $e');
      return null;
    }
  }
}
