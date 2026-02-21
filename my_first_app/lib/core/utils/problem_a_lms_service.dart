import 'dart:math' as math;
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;

class LmsPoint {
  final double l;
  final double m;
  final double s;

  const LmsPoint({
    required this.l,
    required this.m,
    required this.s,
  });
}

class ProblemALmsService {
  ProblemALmsService._();
  static final ProblemALmsService instance = ProblemALmsService._();

  final Map<int, LmsPoint> _boysWfaByMonth = {};
  final Map<int, LmsPoint> _girlsWfaByMonth = {};
  final Map<int, LmsPoint> _boysHfaByDay = {};
  final Map<int, LmsPoint> _girlsHfaByDay = {};
  final Map<int, LmsPoint> _boysWfhByHeightCm = {};
  final Map<int, LmsPoint> _girlsWfhByHeightCm = {};

  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    _boysWfaByMonth.addAll(await _loadMonthlyLms('backend/data/boys_wfa.csv'));
    _girlsWfaByMonth.addAll(await _loadMonthlyLms('backend/data/girls_wfa.csv'));
    _boysHfaByDay.addAll(await _loadDailyLms('backend/data/boys_hfa.csv'));
    _girlsHfaByDay.addAll(await _loadDailyLms('backend/data/girls_hfa.csv'));
    _boysWfhByHeightCm.addAll(await _loadHeightLmsOptional('backend/data/boys_wfh.csv'));
    _girlsWfhByHeightCm.addAll(await _loadHeightLmsOptional('backend/data/girls_wfh.csv'));
    _initialized = true;
  }

  Future<Map<int, LmsPoint>> _loadMonthlyLms(String assetPath) async {
    final bytes = await _loadAssetBytes(assetPath);
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;
    final rows = sheet.rows;
    final out = <int, LmsPoint>{};
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.length < 4) continue;
      final month = _asInt(r[0]?.value);
      final l = _asDouble(r[1]?.value);
      final m = _asDouble(r[2]?.value);
      final s = _asDouble(r[3]?.value);
      if (month == null || l == null || m == null || s == null) continue;
      out[month] = LmsPoint(l: l, m: m, s: s);
    }
    return out;
  }

  Future<Map<int, LmsPoint>> _loadDailyLms(String assetPath) async {
    final bytes = await _loadAssetBytes(assetPath);
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;
    final rows = sheet.rows;
    final out = <int, LmsPoint>{};
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.length < 4) continue;
      final day = _asInt(r[0]?.value);
      final l = _asDouble(r[1]?.value);
      final m = _asDouble(r[2]?.value);
      final s = _asDouble(r[3]?.value);
      if (day == null || l == null || m == null || s == null) continue;
      out[day] = LmsPoint(l: l, m: m, s: s);
    }
    return out;
  }

  Future<Map<int, LmsPoint>> _loadHeightLmsOptional(String assetPath) async {
    try {
      final bytes = await _loadAssetBytes(assetPath);
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;
      final rows = sheet.rows;
      final out = <int, LmsPoint>{};
      for (var i = 1; i < rows.length; i++) {
        final r = rows[i];
        if (r.length < 4) continue;
        final height = _asDouble(r[0]?.value);
        final l = _asDouble(r[1]?.value);
        final m = _asDouble(r[2]?.value);
        final s = _asDouble(r[3]?.value);
        if (height == null || l == null || m == null || s == null) continue;
        out[height.round()] = LmsPoint(l: l, m: m, s: s);
      }
      return out;
    } catch (_) {
      return <int, LmsPoint>{};
    }
  }

  Future<Uint8List> _loadAssetBytes(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString().trim());
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  bool _isFemale(String genderCode) => genderCode.trim().toUpperCase().startsWith('F');

  LmsPoint? wfaByAgeMonths({
    required int ageMonths,
    required String genderCode,
  }) {
    final map = _isFemale(genderCode) ? _girlsWfaByMonth : _boysWfaByMonth;
    if (map.isEmpty) return null;
    final clamped = ageMonths.clamp(0, 60);
    return map[clamped] ?? map[_nearestKey(map.keys, clamped)];
  }

  LmsPoint? hfaByAgeMonths({
    required int ageMonths,
    required String genderCode,
  }) {
    final map = _isFemale(genderCode) ? _girlsHfaByDay : _boysHfaByDay;
    if (map.isEmpty) return null;
    final targetDay = (ageMonths * 30.4375).round().clamp(0, 1856);
    return map[targetDay] ?? map[_nearestKey(map.keys, targetDay)];
  }

  LmsPoint? wfhByHeightCm({
    required double heightCm,
    required String genderCode,
  }) {
    final map = _isFemale(genderCode) ? _girlsWfhByHeightCm : _boysWfhByHeightCm;
    if (map.isEmpty) return null;
    final target = heightCm.round();
    return map[target] ?? map[_nearestKey(map.keys, target)];
  }

  int _nearestKey(Iterable<int> keys, int target) {
    var best = keys.first;
    var bestDiff = (best - target).abs();
    for (final k in keys) {
      final d = (k - target).abs();
      if (d < bestDiff) {
        best = k;
        bestDiff = d;
      }
    }
    return best;
  }

  // WHO LMS z-score:
  // z = (((x/M)^L) - 1) / (L*S), and if L==0 then z = ln(x/M)/S
  double zScore({
    required double x,
    required LmsPoint point,
  }) {
    if (x <= 0 || point.m <= 0 || point.s <= 0) return 0;
    if (point.l == 0) {
      return math.log(x / point.m) / point.s;
    }
    return (math.pow(x / point.m, point.l) - 1) / (point.l * point.s);
  }
}
