import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NavigationStateService {
  NavigationStateService._internal();

  static final NavigationStateService instance = NavigationStateService._internal();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _storageKey = 'last_navigation_state';

  static const String screenLogin = 'login';
  static const String screenDashboard = 'dashboard';
  static const String screenConsent = 'consent';
  static const String screenScreening = 'screening';
  static const String screenResult = 'result';
  static const String screenReferral = 'referral';
  static const String screenReferralBatchSummary = 'referral_batch_summary';
  static const String screenReferralDetails = 'referral_details';
  static const String screenChildRegistration = 'child_registration';
  static const String screenRegisteredChildren = 'registered_children';
  static const String screenSettings = 'settings';
  static const String screenBehavioralPsychosocial = 'behavioral_psychosocial';
  static const String screenBehavioralPsychosocialSummary = 'behavioral_psychosocial_summary';
  static const String screenFollowUp = 'follow_up';
  static const String screenFollowUpComplete = 'follow_up_complete';

  Future<void> saveState({
    required String screen,
    Map<String, dynamic> args = const <String, dynamic>{},
  }) async {
    final payload = <String, dynamic>{
      'screen': screen,
      'args': args,
      'saved_at': DateTime.now().toIso8601String(),
    };
    await _storage.write(key: _storageKey, value: jsonEncode(payload));
  }

  Future<Map<String, dynamic>?> loadState() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearState() async {
    await _storage.delete(key: _storageKey);
  }
}
