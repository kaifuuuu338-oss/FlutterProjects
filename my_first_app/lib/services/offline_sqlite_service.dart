import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:my_first_app/models/aww_model.dart';
import 'package:my_first_app/models/child_model.dart';
import 'package:my_first_app/models/referral_model.dart';
import 'package:my_first_app/models/screening_model.dart';

class OfflineSQLiteService {
  OfflineSQLiteService._();
  static final OfflineSQLiteService instance = OfflineSQLiteService._();

  static const String _dbName = 'ecd_offline.db';
  static const int _dbVersion = 1;

  Database? _db;

  Future<void> initialize() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
    );
  }

  Future<String> databasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, _dbName);
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE users (
        aww_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        mobile_number TEXT NOT NULL,
        awc_code TEXT,
        mandal TEXT,
        district TEXT,
        role TEXT NOT NULL DEFAULT 'aww',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE child_profiles (
        child_id TEXT PRIMARY KEY,
        child_name TEXT NOT NULL,
        date_of_birth TEXT NOT NULL,
        age_months INTEGER NOT NULL,
        gender TEXT NOT NULL,
        awc_code TEXT,
        mandal TEXT,
        district TEXT,
        parent_name TEXT,
        parent_mobile TEXT,
        aadhaar TEXT,
        address TEXT,
        aww_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE child_sync (
        child_id TEXT PRIMARY KEY,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE screening_sessions (
        screening_id TEXT PRIMARY KEY,
        child_id TEXT NOT NULL,
        aww_id TEXT NOT NULL,
        assessment_type TEXT NOT NULL,
        age_months INTEGER NOT NULL,
        domain_responses_json TEXT NOT NULL,
        domain_scores_json TEXT NOT NULL,
        overall_risk TEXT NOT NULL,
        explainability TEXT,
        missed_milestones INTEGER NOT NULL DEFAULT 0,
        delay_months INTEGER NOT NULL DEFAULT 0,
        consent_given INTEGER NOT NULL DEFAULT 0,
        consent_timestamp TEXT,
        referral_triggered INTEGER NOT NULL DEFAULT 0,
        screening_date TEXT NOT NULL,
        submitted_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE risk_classifications (
        screening_id TEXT PRIMARY KEY,
        child_id TEXT NOT NULL,
        risk_category TEXT NOT NULL,
        risk_score REAL,
        explainability TEXT,
        classified_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE referrals (
        referral_id TEXT PRIMARY KEY,
        screening_id TEXT,
        child_id TEXT NOT NULL,
        aww_id TEXT NOT NULL,
        referral_type TEXT NOT NULL,
        urgency TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        expected_follow_up_date TEXT,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        referred_to TEXT,
        metadata_json TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE followups (
        followup_id TEXT PRIMARY KEY,
        child_id TEXT NOT NULL,
        screening_id TEXT,
        followup_date TEXT NOT NULL,
        followup_status TEXT,
        improvement_status TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE interventions (
        intervention_id TEXT PRIMARY KEY,
        child_id TEXT NOT NULL,
        intervention_type TEXT NOT NULL,
        intervention_plan_json TEXT,
        status TEXT,
        started_at TEXT NOT NULL,
        completed_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        payload_json TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> upsertUser(AWWModel aww) async {
    final db = _db;
    if (db == null) return;
    await db.insert(
      'users',
      {
        'aww_id': aww.awwId,
        'name': aww.name,
        'mobile_number': aww.mobileNumber,
        'awc_code': aww.awcCode,
        'mandal': aww.mandal,
        'district': aww.district,
        'role': 'aww',
        'created_at': aww.createdAt.toIso8601String(),
        'updated_at': aww.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _logSyncEvent('users', aww.awwId, 'upsert', aww.toJson(), 'local');
  }

  Future<void> upsertChild(ChildModel child) async {
    final db = _db;
    if (db == null) return;
    await db.insert(
      'child_profiles',
      {
        'child_id': child.childId,
        'child_name': child.childName,
        'date_of_birth': child.dateOfBirth.toIso8601String(),
        'age_months': child.ageMonths,
        'gender': child.gender,
        'awc_code': child.awcCode,
        'mandal': child.mandal,
        'district': child.district,
        'parent_name': child.parentName,
        'parent_mobile': child.parentMobile,
        'aadhaar': child.aadhaar,
        'address': child.address,
        'aww_id': child.awwId,
        'created_at': child.createdAt.toIso8601String(),
        'updated_at': child.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'child_sync',
      {
        'child_id': child.childId,
        'sync_status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _logSyncEvent('child_profiles', child.childId, 'upsert', child.toJson(), 'local');
  }

  Future<void> upsertScreening(ScreeningModel screening) async {
    final db = _db;
    if (db == null) return;
    final risk = screening.overallRisk.name;
    final payload = screening.toJson();

    await db.insert(
      'screening_sessions',
      {
        'screening_id': screening.screeningId,
        'child_id': screening.childId,
        'aww_id': screening.awwId,
        'assessment_type': screening.assessmentType.name,
        'age_months': screening.ageMonths,
        'domain_responses_json': jsonEncode(screening.domainResponses),
        'domain_scores_json': jsonEncode(screening.domainScores),
        'overall_risk': risk,
        'explainability': screening.explainability,
        'missed_milestones': screening.missedMilestones,
        'delay_months': screening.delayMonths,
        'consent_given': screening.consentGiven ? 1 : 0,
        'consent_timestamp': screening.consentTimestamp.toIso8601String(),
        'referral_triggered': screening.referralTriggered ? 1 : 0,
        'screening_date': screening.screeningDate.toIso8601String(),
        'submitted_at': screening.submittedAt?.toIso8601String(),
        'sync_status': screening.submittedAt == null ? 'pending' : 'synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.insert(
      'risk_classifications',
      {
        'screening_id': screening.screeningId,
        'child_id': screening.childId,
        'risk_category': risk,
        'risk_score': null,
        'explainability': screening.explainability,
        'classified_at': (screening.submittedAt ?? DateTime.now()).toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _logSyncEvent(
      'screening_sessions',
      screening.screeningId,
      'upsert',
      payload,
      screening.submittedAt == null ? 'pending' : 'synced',
    );
  }

  Future<void> upsertReferral(ReferralModel referral) async {
    final db = _db;
    if (db == null) return;
    final metadata = referral.metadata ?? const <String, dynamic>{};
    final syncStatus = '${metadata['sync_status'] ?? 'pending'}';

    await db.insert(
      'referrals',
      {
        'referral_id': referral.referralId,
        'screening_id': referral.screeningId,
        'child_id': referral.childId,
        'aww_id': referral.awwId,
        'referral_type': referral.referralType.name,
        'urgency': referral.urgency.name,
        'status': referral.status.name,
        'notes': referral.notes,
        'expected_follow_up_date': referral.expectedFollowUpDate.toIso8601String(),
        'created_at': referral.createdAt.toIso8601String(),
        'completed_at': referral.completedAt?.toIso8601String(),
        'referred_to': referral.referredTo,
        'metadata_json': jsonEncode(metadata),
        'sync_status': syncStatus == 'synced' ? 'synced' : 'pending',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _logSyncEvent(
      'referrals',
      referral.referralId,
      'upsert',
      referral.toJson(),
      syncStatus == 'synced' ? 'synced' : 'pending',
    );
  }

  AWWModel? getCurrentUser() {
    final db = _db;
    if (db == null) return null;
    // sqlite query API is async, so this sync helper is not used.
    return null;
  }

  Future<AWWModel?> fetchCurrentUser() async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query('users', orderBy: 'updated_at DESC', limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return AWWModel(
      awwId: '${r['aww_id'] ?? ''}',
      name: '${r['name'] ?? ''}',
      mobileNumber: '${r['mobile_number'] ?? ''}',
      awcCode: '${r['awc_code'] ?? ''}',
      mandal: '${r['mandal'] ?? ''}',
      district: '${r['district'] ?? ''}',
      password: '',
      createdAt: DateTime.tryParse('${r['created_at']}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${r['updated_at']}') ?? DateTime.now(),
    );
  }

  Future<ChildModel?> getChild(String childId) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query('child_profiles', where: 'child_id=?', whereArgs: [childId], limit: 1);
    if (rows.isEmpty) return null;
    return _childFromRow(rows.first);
  }

  Future<List<ChildModel>> getAllChildren() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('child_profiles', orderBy: 'created_at DESC');
    return rows.map(_childFromRow).toList();
  }

  Future<List<ChildModel>> getUnsyncedChildren() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.rawQuery('''
      SELECT cp.*
      FROM child_profiles cp
      LEFT JOIN child_sync cs ON cs.child_id = cp.child_id
      WHERE ifnull(cs.sync_status, 'pending') != 'synced'
      ORDER BY cp.created_at DESC
    ''');
    return rows.map(_childFromRow).toList();
  }

  Future<void> markChildSynced(String childId) async {
    final db = _db;
    if (db == null) return;
    await db.insert(
      'child_sync',
      {
        'child_id': childId,
        'sync_status': 'synced',
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteChild(String childId) async {
    final db = _db;
    if (db == null) return;
    await db.delete('child_profiles', where: 'child_id=?', whereArgs: [childId]);
    await db.delete('child_sync', where: 'child_id=?', whereArgs: [childId]);
  }

  Future<ScreeningModel?> getScreening(String screeningId) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query('screening_sessions', where: 'screening_id=?', whereArgs: [screeningId], limit: 1);
    if (rows.isEmpty) return null;
    return _screeningFromRow(rows.first);
  }

  Future<List<ScreeningModel>> getChildScreenings(String childId) async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('screening_sessions', where: 'child_id=?', whereArgs: [childId], orderBy: 'screening_date DESC');
    return rows.map(_screeningFromRow).toList();
  }

  Future<List<ScreeningModel>> getUnsyncedScreenings() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('screening_sessions', where: "ifnull(sync_status,'pending') != 'synced'");
    return rows.map(_screeningFromRow).toList();
  }

  Future<ReferralModel?> getReferral(String referralId) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query('referrals', where: 'referral_id=?', whereArgs: [referralId], limit: 1);
    if (rows.isEmpty) return null;
    return _referralFromRow(rows.first);
  }

  Future<List<ReferralModel>> getChildReferrals(String childId) async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('referrals', where: 'child_id=?', whereArgs: [childId], orderBy: 'created_at DESC');
    return rows.map(_referralFromRow).toList();
  }

  Future<List<ReferralModel>> getAllReferrals() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('referrals', orderBy: 'created_at DESC');
    return rows.map(_referralFromRow).toList();
  }

  Future<List<ReferralModel>> getUnsyncedReferrals() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('referrals', where: "ifnull(sync_status,'pending') != 'synced'");
    return rows.map(_referralFromRow).toList();
  }

  Future<void> updateReferralStatus(String referralId, ReferralStatus status) async {
    final db = _db;
    if (db == null) return;
    final completedAt = status == ReferralStatus.completed ? DateTime.now().toIso8601String() : null;
    await db.update(
      'referrals',
      {
        'status': status.name,
        'completed_at': completedAt,
      },
      where: 'referral_id=?',
      whereArgs: [referralId],
    );
  }

  ChildModel _childFromRow(Map<String, Object?> r) {
    return ChildModel(
      childId: '${r['child_id'] ?? ''}',
      childName: '${r['child_name'] ?? ''}',
      dateOfBirth: DateTime.tryParse('${r['date_of_birth']}') ?? DateTime.now(),
      ageMonths: (r['age_months'] as num?)?.toInt() ?? 0,
      gender: '${r['gender'] ?? 'M'}',
      awcCode: '${r['awc_code'] ?? ''}',
      mandal: '${r['mandal'] ?? ''}',
      district: '${r['district'] ?? ''}',
      parentName: '${r['parent_name'] ?? ''}',
      parentMobile: '${r['parent_mobile'] ?? ''}',
      aadhaar: r['aadhaar'] == null ? null : '${r['aadhaar']}',
      address: r['address'] == null ? null : '${r['address']}',
      awwId: '${r['aww_id'] ?? ''}',
      createdAt: DateTime.tryParse('${r['created_at']}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${r['updated_at']}') ?? DateTime.now(),
    );
  }

  ScreeningModel _screeningFromRow(Map<String, Object?> r) {
    final assessment = '${r['assessment_type'] ?? 'baseline'}';
    final risk = '${r['overall_risk'] ?? 'low'}';
    final responsesRaw = '${r['domain_responses_json'] ?? '{}'}';
    final scoresRaw = '${r['domain_scores_json'] ?? '{}'}';
    final responsesMap = (jsonDecode(responsesRaw) as Map).map(
      (k, v) => MapEntry('$k', (v as List).map((e) => (e as num).toInt()).toList()),
    );
    final scoresMap = (jsonDecode(scoresRaw) as Map).map(
      (k, v) => MapEntry('$k', (v as num).toDouble()),
    );
    return ScreeningModel(
      screeningId: '${r['screening_id'] ?? ''}',
      childId: '${r['child_id'] ?? ''}',
      awwId: '${r['aww_id'] ?? ''}',
      assessmentType: AssessmentType.values.firstWhere(
        (e) => e.name.toLowerCase() == assessment.toLowerCase(),
        orElse: () => AssessmentType.baseline,
      ),
      ageMonths: (r['age_months'] as num?)?.toInt() ?? 0,
      domainResponses: responsesMap,
      domainScores: scoresMap,
      overallRisk: RiskLevel.values.firstWhere(
        (e) => e.name.toLowerCase() == risk.toLowerCase(),
        orElse: () => RiskLevel.low,
      ),
      explainability: '${r['explainability'] ?? ''}',
      missedMilestones: (r['missed_milestones'] as num?)?.toInt() ?? 0,
      delayMonths: (r['delay_months'] as num?)?.toInt() ?? 0,
      consentGiven: ((r['consent_given'] as num?)?.toInt() ?? 0) == 1,
      consentTimestamp: DateTime.tryParse('${r['consent_timestamp']}') ?? DateTime.now(),
      referralTriggered: ((r['referral_triggered'] as num?)?.toInt() ?? 0) == 1,
      screeningDate: DateTime.tryParse('${r['screening_date']}') ?? DateTime.now(),
      submittedAt: r['submitted_at'] == null ? null : DateTime.tryParse('${r['submitted_at']}'),
    );
  }

  ReferralModel _referralFromRow(Map<String, Object?> r) {
    final metadataRaw = r['metadata_json'] == null ? '{}' : '${r['metadata_json']}';
    Map<String, dynamic> metadata = <String, dynamic>{};
    try {
      metadata = Map<String, dynamic>.from(jsonDecode(metadataRaw) as Map);
    } catch (_) {
      metadata = <String, dynamic>{};
    }
    metadata['sync_status'] = '${r['sync_status'] ?? 'pending'}';
    return ReferralModel(
      referralId: '${r['referral_id'] ?? ''}',
      screeningId: '${r['screening_id'] ?? ''}',
      childId: '${r['child_id'] ?? ''}',
      awwId: '${r['aww_id'] ?? ''}',
      referralType: ReferralType.values.firstWhere(
        (e) => e.name.toLowerCase() == '${r['referral_type'] ?? 'rbsk'}'.toLowerCase(),
        orElse: () => ReferralType.rbsk,
      ),
      urgency: ReferralUrgency.values.firstWhere(
        (e) => e.name.toLowerCase() == '${r['urgency'] ?? 'normal'}'.toLowerCase(),
        orElse: () => ReferralUrgency.normal,
      ),
      status: ReferralStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == '${r['status'] ?? 'pending'}'.toLowerCase(),
        orElse: () => ReferralStatus.pending,
      ),
      notes: r['notes'] == null ? null : '${r['notes']}',
      expectedFollowUpDate: DateTime.tryParse('${r['expected_follow_up_date']}') ?? DateTime.now(),
      createdAt: DateTime.tryParse('${r['created_at']}') ?? DateTime.now(),
      completedAt: r['completed_at'] == null ? null : DateTime.tryParse('${r['completed_at']}'),
      referredTo: r['referred_to'] == null ? null : '${r['referred_to']}',
      metadata: metadata,
    );
  }

  Future<void> _logSyncEvent(
    String entityType,
    String entityId,
    String eventType,
    Map<String, dynamic> payload,
    String status,
  ) async {
    final db = _db;
    if (db == null) return;
    await db.insert(
      'sync_events',
      {
        'entity_type': entityType,
        'entity_id': entityId,
        'event_type': eventType,
        'payload_json': jsonEncode(payload),
        'status': status,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> clearAll() async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      await txn.delete('users');
      await txn.delete('child_profiles');
      await txn.delete('screening_sessions');
      await txn.delete('risk_classifications');
      await txn.delete('referrals');
      await txn.delete('followups');
      await txn.delete('interventions');
      await txn.delete('sync_events');
    });
  }
}
