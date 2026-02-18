import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_first_app/core/constants/app_constants.dart';
import 'package:my_first_app/models/aww_model.dart';
import 'package:my_first_app/models/child_model.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'package:my_first_app/models/referral_model.dart';

class LocalDBService {
  late Box<Map> _awwBox;
  late Box<Map> _childBox;
  late Box<ScreeningModel> _screeningBox;
  late Box<Map> _referralBox;

  /// Initialize Hive and open boxes
  Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters used by ScreeningModel.
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RiskLevelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AssessmentTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ScreeningModelAdapter());
    }

    // Open boxes after registering adapters.
    _awwBox = await Hive.openBox<Map>(AppConstants.awwBoxName);
    _childBox = await Hive.openBox<Map>(AppConstants.childBoxName);
    _screeningBox = await Hive.openBox<ScreeningModel>(AppConstants.screeningBoxName);
    _referralBox = await Hive.openBox<Map>(AppConstants.referralBoxName);
  }

  Future<void> saveAWW(AWWModel aww) async {
    await _awwBox.put('current_aww', aww.toJson());
  }

  AWWModel? getCurrentAWW() {
    final data = _awwBox.get('current_aww');
    if (data == null) {
      return null;
    }
    return AWWModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> saveChild(ChildModel child) async {
    await _childBox.put(child.childId, child.toJson());
  }

  ChildModel? getChild(String childId) {
    final data = _childBox.get(childId);
    if (data == null) {
      return null;
    }
    return ChildModel.fromJson(Map<String, dynamic>.from(data));
  }

  List<ChildModel> getAllChildren() {
    return _childBox.values
        .map((e) => ChildModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> deleteChild(String childId) async {
    await _childBox.delete(childId);
  }

  Future<void> saveScreening(ScreeningModel screening) async {
    await _screeningBox.put(screening.screeningId, screening);
  }

  ScreeningModel? getScreening(String screeningId) {
    return _screeningBox.get(screeningId);
  }

  List<ScreeningModel> getChildScreenings(String childId) {
    return _screeningBox.values.where((s) => s.childId == childId).toList();
  }

  List<ScreeningModel> getUnsyncedScreenings() {
    return _screeningBox.values.where((s) => s.submittedAt == null).toList();
  }

  Future<void> saveReferral(ReferralModel referral) async {
    await _referralBox.put(referral.referralId, referral.toJson());
  }

  ReferralModel? getReferral(String referralId) {
    final data = _referralBox.get(referralId);
    if (data == null) {
      return null;
    }
    return ReferralModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> updateReferralStatus(String referralId, ReferralStatus status) async {
    final existing = getReferral(referralId);
    if (existing == null) return;
    final updated = existing.copyWith(
      status: status,
      completedAt: status == ReferralStatus.completed ? DateTime.now() : existing.completedAt,
    );
    await saveReferral(updated);
  }

  List<ReferralModel> getChildReferrals(String childId) {
    return _safeReferralList().where((r) => r.childId == childId).toList();
  }

  List<ReferralModel> getUnsyncedReferrals() {
    return _safeReferralList().where((r) => r.metadata?['sync_status'] == 'not_synced').toList();
  }

  List<ReferralModel> getAllReferrals() {
    return _safeReferralList();
  }

  List<ReferralModel> _safeReferralList() {
    final items = <ReferralModel>[];
    for (final entry in _referralBox.values) {
      try {
        items.add(ReferralModel.fromJson(Map<String, dynamic>.from(entry)));
      } catch (_) {
        // Skip malformed records to avoid breaking the whole list.
      }
    }
    return items;
  }

  Future<void> clearAll() async {
    await _awwBox.clear();
    await _childBox.clear();
    await _screeningBox.clear();
    await _referralBox.clear();
  }
}
