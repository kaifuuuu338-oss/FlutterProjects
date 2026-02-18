import 'package:flutter/material.dart';
import 'package:my_first_app/models/referral_model.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'package:my_first_app/services/local_db_service.dart';

class AwcInterventionMonitorScreen extends StatefulWidget {
  const AwcInterventionMonitorScreen({super.key});

  @override
  State<AwcInterventionMonitorScreen> createState() => _AwcInterventionMonitorScreenState();
}

class _AwcInterventionMonitorScreenState extends State<AwcInterventionMonitorScreen> {
  final LocalDBService _localDb = LocalDBService();
  bool _loading = true;
  int _totalChildrenWithInterventions = 0;
  int _highIntensity = 0;
  int _referralPending = 0;
  int _improvementRate = 0;
  int _followupCompliance = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _localDb.initialize();
    final children = _localDb.getAllChildren();
    final referrals = _localDb.getAllReferrals();
    final now = DateTime.now();

    var interventionChildren = 0;
    var highIntensity = 0;
    var improved = 0;
    var eligibleForFollowup = 0;
    var completedFollowup = 0;

    for (final child in children) {
      final screenings = _localDb.getChildScreenings(child.childId)
        ..sort((a, b) => b.screeningDate.compareTo(a.screeningDate));
      if (screenings.isEmpty) continue;
      final latest = screenings.first;
      final hasRisk = latest.overallRisk == RiskLevel.high || latest.overallRisk == RiskLevel.critical;
      if (hasRisk) interventionChildren += 1;
      if (latest.overallRisk == RiskLevel.critical) highIntensity += 1;
      if (screenings.length > 1) {
        eligibleForFollowup += 1;
        completedFollowup += 1;
        final baseline = screenings[1].delayMonths;
        final followup = screenings[0].delayMonths;
        if (baseline > followup) improved += 1;
      } else if (now.difference(latest.screeningDate).inDays >= 30) {
        eligibleForFollowup += 1;
      }
    }

    final pending = referrals.where((r) => r.status == ReferralStatus.pending || r.status == ReferralStatus.scheduled).length;
    final improvementRate = interventionChildren == 0 ? 0 : ((improved / interventionChildren) * 100).round();
    final compliance = eligibleForFollowup == 0 ? 0 : ((completedFollowup / eligibleForFollowup) * 100).round();

    if (!mounted) return;
    setState(() {
      _totalChildrenWithInterventions = interventionChildren;
      _highIntensity = highIntensity;
      _referralPending = pending;
      _improvementRate = improvementRate;
      _followupCompliance = compliance;
      _loading = false;
    });
  }

  Widget _metric(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E8F0)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF5D6B78), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AWC Intervention Monitor'),
        backgroundColor: const Color(0xFF145FA8),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _metric('Total children with interventions', '$_totalChildrenWithInterventions', Icons.groups, const Color(0xFF1E88E5)),
                const SizedBox(height: 10),
                _metric('High intensity count', '$_highIntensity', Icons.priority_high, const Color(0xFFE53935)),
                const SizedBox(height: 10),
                _metric('Referral pending count', '$_referralPending', Icons.pending_actions, const Color(0xFFF9A825)),
                const SizedBox(height: 10),
                _metric('Improvement rate', '$_improvementRate%', Icons.trending_up, const Color(0xFF43A047)),
                const SizedBox(height: 10),
                _metric('Follow-up compliance rate', '$_followupCompliance%', Icons.fact_check, const Color(0xFF6A1B9A)),
              ],
            ),
    );
  }
}
