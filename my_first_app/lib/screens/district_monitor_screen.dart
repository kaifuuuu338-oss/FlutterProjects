import 'package:flutter/material.dart';
import 'package:my_first_app/models/referral_model.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'package:my_first_app/services/local_db_service.dart';

class DistrictMonitorScreen extends StatefulWidget {
  const DistrictMonitorScreen({super.key});

  @override
  State<DistrictMonitorScreen> createState() => _DistrictMonitorScreenState();
}

class _DistrictMonitorScreenState extends State<DistrictMonitorScreen> {
  final LocalDBService _localDb = LocalDBService();
  bool _loading = true;
  int _improvedChildren = 0;
  int _totalTracked = 0;
  int _referralCompletion = 0;
  int _exitHighRisk = 0;
  final Map<String, int> _domainImprovement = <String, int>{'GM': 0, 'FM': 0, 'LC': 0, 'COG': 0, 'SE': 0};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _localDb.initialize();
    final children = _localDb.getAllChildren();
    final referrals = _localDb.getAllReferrals();

    var improved = 0;
    var tracked = 0;
    var exitHigh = 0;

    for (final child in children) {
      final screenings = _localDb.getChildScreenings(child.childId)
        ..sort((a, b) => b.screeningDate.compareTo(a.screeningDate));
      if (screenings.length < 2) continue;
      tracked += 1;
      final latest = screenings[0];
      final prev = screenings[1];
      if (prev.delayMonths > latest.delayMonths) improved += 1;
      if ((prev.overallRisk == RiskLevel.high || prev.overallRisk == RiskLevel.critical) &&
          (latest.overallRisk == RiskLevel.medium || latest.overallRisk == RiskLevel.low)) {
        exitHigh += 1;
      }
      for (final domain in _domainImprovement.keys) {
        final prevScore = prev.domainScores[domain] ?? 1.0;
        final currScore = latest.domainScores[domain] ?? 1.0;
        if (currScore > prevScore) {
          _domainImprovement[domain] = (_domainImprovement[domain] ?? 0) + 1;
        }
      }
    }

    final completed = referrals.where((r) => r.status == ReferralStatus.completed || r.status == ReferralStatus.underTreatment).length;
    final referralCompletion = referrals.isEmpty ? 0 : ((completed / referrals.length) * 100).round();

    if (!mounted) return;
    setState(() {
      _improvedChildren = improved;
      _totalTracked = tracked;
      _exitHighRisk = tracked == 0 ? 0 : ((exitHigh / tracked) * 100).round();
      _referralCompletion = referralCompletion;
      _loading = false;
    });
  }

  Widget _tile(String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E8F0)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(backgroundColor: color.withValues(alpha: 0.14), child: Icon(Icons.analytics, color: color, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final improvedPct = _totalTracked == 0 ? 0 : ((_improvedChildren / _totalTracked) * 100).round();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mandal / District View'),
        backgroundColor: const Color(0xFF145FA8),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _tile('% children improved', '$improvedPct%', const Color(0xFF2E7D32)),
                _tile('Referral completion rate', '$_referralCompletion%', const Color(0xFF1565C0)),
                _tile('Exit from high risk %', '$_exitHighRisk%', const Color(0xFFE53935)),
                const SizedBox(height: 8),
                const Text('Domain-wise improvement rate', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ..._domainImprovement.entries.map((e) {
                  final pct = _totalTracked == 0 ? 0 : ((e.value / _totalTracked) * 100).round();
                  return _tile('${e.key} improvement', '$pct%', const Color(0xFF6A1B9A));
                }),
              ],
            ),
    );
  }
}
