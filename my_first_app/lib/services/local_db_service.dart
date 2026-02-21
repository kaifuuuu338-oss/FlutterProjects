import 'package:flutter/foundation.dart';
import 'package:my_first_app/models/aww_model.dart';
import 'package:my_first_app/models/child_model.dart';
import 'package:my_first_app/models/referral_model.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'package:my_first_app/services/offline_sqlite_service.dart';

class LocalDBService {
  final OfflineSQLiteService _offlineDb = OfflineSQLiteService.instance;
  bool _initialized = false;

  AWWModel? _currentAww;
  final Map<String, ChildModel> _children = <String, ChildModel>{};
  final Map<String, ScreeningModel> _screenings = <String, ScreeningModel>{};
  final Map<String, ReferralModel> _referrals = <String, ReferralModel>{};
  final Set<String> _unsyncedChildIds = <String>{};

  Future<void> initialize() async {
    if (_initialized) return;
    if (!kIsWeb) {
      await _offlineDb.initialize();
      _currentAww = await _offlineDb.fetchCurrentUser();
      final children = await _offlineDb.getAllChildren();
      final referrals = await _offlineDb.getAllReferrals();
      final unsyncedChildren = await _offlineDb.getUnsyncedChildren();
      _children
        ..clear()
        ..addEntries(children.map((e) => MapEntry(e.childId, e)));
      _referrals
        ..clear()
        ..addEntries(referrals.map((e) => MapEntry(e.referralId, e)));
      _unsyncedChildIds
        ..clear()
        ..addAll(unsyncedChildren.map((e) => e.childId));

      _screenings.clear();
      for (final child in children) {
        final rows = await _offlineDb.getChildScreenings(child.childId);
        for (final row in rows) {
          _screenings[row.screeningId] = row;
        }
      }
    }
    _initialized = true;
  }

  Future<void> saveAWW(AWWModel aww) async {
    _currentAww = aww;
    if (!kIsWeb) {
      await _offlineDb.upsertUser(aww);
    }
  }

  AWWModel? getCurrentAWW() => _currentAww;

  Future<void> saveChild(ChildModel child) async {
    _children[child.childId] = child;
    _unsyncedChildIds.add(child.childId);
    if (!kIsWeb) {
      await _offlineDb.upsertChild(child);
    }
  }

  ChildModel? getChild(String childId) => _children[childId];

  List<ChildModel> getAllChildren() => _children.values.toList();

  List<ChildModel> getUnsyncedChildren() =>
      _children.values.where((c) => _unsyncedChildIds.contains(c.childId)).toList();

  Future<void> markChildSynced(String childId) async {
    _unsyncedChildIds.remove(childId);
    if (!kIsWeb) {
      await _offlineDb.markChildSynced(childId);
    }
  }

  Future<void> deleteChild(String childId) async {
    _children.remove(childId);
    _unsyncedChildIds.remove(childId);
    if (!kIsWeb) {
      await _offlineDb.deleteChild(childId);
    }
  }

  Future<void> saveScreening(ScreeningModel screening) async {
    _screenings[screening.screeningId] = screening;
    if (!kIsWeb) {
      await _offlineDb.upsertScreening(screening);
    }
  }

  ScreeningModel? getScreening(String screeningId) => _screenings[screeningId];

  List<ScreeningModel> getChildScreenings(String childId) {
    final rows = _screenings.values.where((s) => s.childId == childId).toList();
    rows.sort((a, b) => b.screeningDate.compareTo(a.screeningDate));
    return rows;
  }

  List<ScreeningModel> getUnsyncedScreenings() =>
      _screenings.values.where((s) => s.submittedAt == null).toList();

  Future<void> saveReferral(ReferralModel referral) async {
    _referrals[referral.referralId] = referral;
    if (!kIsWeb) {
      await _offlineDb.upsertReferral(referral);
    }
  }

  ReferralModel? getReferral(String referralId) => _referrals[referralId];

  List<ReferralModel> getChildReferrals(String childId) =>
      _referrals.values.where((r) => r.childId == childId).toList();

  List<ReferralModel> getUnsyncedReferrals() =>
      _referrals.values.where((r) => r.metadata?['sync_status'] == 'not_synced').toList();

  List<ReferralModel> getAllReferrals() => _referrals.values.toList();

  Future<void> updateReferralStatus(String referralId, ReferralStatus status) async {
    final current = _referrals[referralId];
    if (current == null) return;
    final updated = current.copyWith(
      status: status,
      completedAt: status == ReferralStatus.completed ? DateTime.now() : current.completedAt,
      metadata: {
        ...(current.metadata ?? <String, dynamic>{}),
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
    await saveReferral(updated);
    if (!kIsWeb) {
      await _offlineDb.updateReferralStatus(referralId, status);
    }
  }

  Future<void> clearAll() async {
    _currentAww = null;
    _children.clear();
    _screenings.clear();
    _referrals.clear();
    _unsyncedChildIds.clear();
    if (!kIsWeb) {
      await _offlineDb.clearAll();
    }
  }

  Future<String?> getOfflineDatabasePath() async {
    if (kIsWeb) return null;
    return _offlineDb.databasePath();
  }
}
