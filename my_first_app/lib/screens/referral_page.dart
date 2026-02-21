import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:my_first_app/services/api_service.dart';
import 'package:my_first_app/screens/followup_complete_screen.dart';

class ReferralPage extends StatefulWidget {
  final String childId;
  final String awwId;
  final int ageMonths;
  final String overallRisk;
  final Map<String, double> domainScores;

  const ReferralPage({
    super.key,
    required this.childId,
    required this.awwId,
    required this.ageMonths,
    required this.overallRisk,
    required this.domainScores,
  });

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  final APIService _api = APIService();
  Map<String, dynamic>? _bootstrapReferral;
  final TextEditingController _remarksController = TextEditingController();

  bool _loading = true;
  bool _updating = false;
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _ensureReferralExists();
      final details = await _fetchReferralDetails();
      if (!mounted) return;
      setState(() => _data = details);
    } catch (e) {
      if (!mounted) return;
      String message = 'Unable to load referral. Please retry.';
      if (e is DioException) {
        final code = e.response?.statusCode;
        if (code != null) {
          message = 'Unable to load referral (HTTP $code).';
        }
        final detail = e.response?.data;
        if (detail is Map && detail['detail'] is String) {
          message = '${message} ${detail['detail']}';
        }
      } else if (e is Exception) {
        message = e.toString().replaceFirst('Exception: ', '');
      }
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ensureReferralExists() async {
    final risk = widget.overallRisk.trim().toLowerCase();
    final isHigh = risk == 'high' || risk.contains('high');
    final isCritical = risk == 'critical' || risk.contains('critical');
    final isMedium = risk == 'medium' || risk.contains('medium');
    if (!isHigh && !isCritical && !isMedium) {
      throw Exception('No referral required for low risk.');
    }

    try {
      _bootstrapReferral = await _api.getReferralByChild(widget.childId);
      return;
    } catch (_) {
      // Create if missing / endpoint unavailable.
    }

    final policy = _policyForRisk(widget.overallRisk);
    final now = DateTime.now();
    final created = await _api.createReferral({
      'child_id': widget.childId,
      'aww_id': widget.awwId,
      'age_months': widget.ageMonths,
      'overall_risk': widget.overallRisk,
      'domain_scores': widget.domainScores,
      'referral_type': policy.type,
      'urgency': policy.urgency,
      'expected_follow_up': now
          .add(Duration(days: policy.followUpDays))
          .toIso8601String(),
      'notes': 'Auto-created from risk classification',
      'referral_timestamp': now.toIso8601String(),
    });
    _bootstrapReferral = {
      'referral_id': created['referral_id'],
      'status': created['status'] ?? 'Pending',
      'created_on': now.toIso8601String().split('T').first,
      'followup_by': now
          .add(Duration(days: policy.followUpDays))
          .toIso8601String()
          .split('T')
          .first,
      'urgency': policy.urgency,
      'referral_type_label': policy.type == 'RBSK'
          ? 'Enhanced Monitoring'
          : (policy.urgency.toLowerCase() == 'immediate'
                ? 'Immediate Specialist Referral'
                : 'Specialist Evaluation'),
    };
  }

  Future<Map<String, dynamic>> _fetchReferralDetails() async {
    try {
      return await _api.getReferralDetailsByChild(widget.childId);
    } on DioException catch (_) {
      if (_bootstrapReferral != null) {
        return _buildFallbackDetails(_bootstrapReferral!);
      }
      try {
        final legacy = await _api.getReferralByChild(widget.childId);
        return _buildFallbackDetails(legacy);
      } catch (_) {
        return _buildFallbackDetails(const <String, dynamic>{});
      }
    } catch (_) {
      if (_bootstrapReferral != null) {
        return _buildFallbackDetails(_bootstrapReferral!);
      }
      try {
        final legacy = await _api.getReferralByChild(widget.childId);
        return _buildFallbackDetails(legacy);
      } catch (_) {
        return _buildFallbackDetails(const <String, dynamic>{});
      }
    }
  }

  Future<Map<String, dynamic>> _buildFallbackDetails(
    Map<String, dynamic> legacy,
  ) async {
    final riskScore = _computeRiskScore(widget.domainScores);
    final delayedDomains = _delayedDomains(widget.domainScores);
    final urgency =
        '${legacy['urgency'] ?? _policyForRisk(widget.overallRisk).urgency}'
            .toUpperCase();
    final createdOn =
        '${legacy['created_on'] ?? DateTime.now().toIso8601String().split('T').first}';
    final deadline =
        '${legacy['followup_by'] ?? DateTime.now().toIso8601String().split('T').first}';
    final referralTypeLabel = '${legacy['referral_type_label'] ?? ''}';
    final facility = referralTypeLabel == 'Enhanced Monitoring'
        ? 'AWW / Block level'
        : (urgency == 'IMMEDIATE'
              ? 'District specialist'
              : 'Block / District specialist');

    return {
      'referral_id': '${legacy['referral_id'] ?? ''}',
      'child_info': {
        'name': widget.childId,
        'child_id': widget.childId,
        'age': widget.ageMonths,
        'gender': 'Unknown',
        'village_or_awc_id': 'N/A',
        'assigned_worker': widget.awwId,
      },
      'risk_summary': {
        'severity': widget.overallRisk.trim().toUpperCase(),
        'risk_score': riskScore,
        'delayed_domains': delayedDomains,
        'autism_risk': 'No Significant Risk',
        'adhd_risk': 'No Significant Risk',
        'behavior_flags': const ['No behavioral red flags observed.'],
      },
      'decision': {
        'urgency': urgency,
        'facility': facility,
        'created_on': createdOn,
        'deadline': deadline,
        'escalation_level': legacy['escalation_level'] ?? 0,
        'escalated_to': legacy['escalated_to'] ?? '',
      },
      'status': _normalizeStatus('${legacy['status'] ?? 'PENDING'}'),
      'appointment_date': null,
      'completion_date': null,
      'last_updated': DateTime.now().toIso8601String().split('T').first,
    };
  }

  _ReferralPolicy _policyForRisk(String risk) {
    final normalized = risk.trim().toLowerCase();
    if (normalized == 'critical' || normalized.contains('critical')) {
      return const _ReferralPolicy(
        type: 'PHC',
        urgency: 'Immediate',
        followUpDays: 2,
      );
    }
    if (normalized == 'high' || normalized.contains('high')) {
      return const _ReferralPolicy(
        type: 'PHC',
        urgency: 'Priority',
        followUpDays: 10,
      );
    }
    return const _ReferralPolicy(type: '', urgency: '', followUpDays: 0);
  }

  List<String> _delayedDomains(Map<String, double> scores) {
    const domainLabel = {
      'GM': 'Gross Motor',
      'FM': 'Fine Motor',
      'LC': 'Speech & Language',
      'COG': 'Cognitive',
      'SE': 'Social-Emotional',
    };
    final out = <String>[];
    scores.forEach((k, v) {
      if (domainLabel.containsKey(k) && v <= 0.8) {
        out.add(domainLabel[k]!);
      }
    });
    return out;
  }

  int _computeRiskScore(Map<String, double> scores) {
    var total = 0;
    for (final score in scores.values) {
      if (score <= 0.4) {
        total += 4;
      } else if (score <= 0.6) {
        total += 3;
      } else if (score <= 0.8) {
        total += 2;
      } else {
        total += 1;
      }
    }
    return total * 2;
  }

  String _normalizeStatus(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'pending') return 'PENDING';
    if (value == 'appointment scheduled' || value == 'scheduled') {
      return 'SCHEDULED';
    }
    if (value == 'under treatment' || value == 'visited') return 'VISITED';
    if (value == 'completed') return 'COMPLETED';
    if (value == 'missed') return 'MISSED';
    return 'PENDING';
  }

  Color _severityColor(String severity) {
    final s = severity.trim().toUpperCase();
    if (s == 'CRITICAL') return const Color(0xFFD32F2F);
    if (s == 'HIGH') return const Color(0xFFF57C00);
    if (s == 'MEDIUM') return const Color(0xFFF9A825);
    return const Color(0xFF2E7D32);
  }

  bool _canMarkScheduled(String status) {
    final s = _normalizeStatus(status);
    return s == 'PENDING' || s == 'MISSED';
  }

  bool _canMarkCompleted(String status) {
    final s = _normalizeStatus(status);
    return s == 'SCHEDULED' || s == 'VISITED';
  }

  bool _canMarkMissed(String status) {
    final s = _normalizeStatus(status);
    return s == 'PENDING' || s == 'SCHEDULED' || s == 'VISITED';
  }

  bool _canEscalate(String status) {
    final s = _normalizeStatus(status);
    return s == 'MISSED';
  }

  bool _isOverdue(String status, String deadlineRaw) {
    final s = _normalizeStatus(status);
    if (s == 'COMPLETED' || s == 'MISSED') return false;
    final deadline = DateTime.tryParse(deadlineRaw);
    if (deadline == null) return false;
    final today = DateTime.now();
    final d = DateTime(deadline.year, deadline.month, deadline.day);
    final t = DateTime(today.year, today.month, today.day);
    return t.isAfter(d);
  }

  Future<void> _setStatus(String status) async {
    final referralId = '${_data?['referral_id'] ?? ''}';
    if (referralId.isEmpty) return;
    setState(() => _updating = true);
    final today = DateTime.now().toIso8601String().split('T').first;
    try {
      await _api.updateReferralStatus(
        referralId: referralId,
        status: status,
        appointmentDate: status == 'SCHEDULED' || status == 'VISITED'
            ? today
            : null,
        completionDate: status == 'COMPLETED' ? today : null,
      );
      await _load();
    } catch (e) {
      // Keep page functional even when backend route differs.
      if (mounted) {
        setState(() {
          _data ??= <String, dynamic>{};
          _data!['status'] = status;
          _data!['last_updated'] = today;
          if (status == 'SCHEDULED' || status == 'VISITED') {
            _data!['appointment_date'] = today;
          }
          if (status == 'COMPLETED') {
            _data!['completion_date'] = today;
          }
          if (status == 'MISSED') {
            final deadline =
                DateTime.now().add(const Duration(days: 2)).toIso8601String();
            _data!['decision'] ??= <String, dynamic>{};
            _data!['decision']['deadline'] = deadline.split('T').first;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Status saved locally. Backend update failed.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _escalate() async {
    final referralId = '${_data?['referral_id'] ?? ''}';
    if (referralId.isEmpty) return;
    setState(() => _updating = true);
    try {
      await _api.escalateReferral(referralId: referralId);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Escalation failed on backend.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Referral')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final child = Map<String, dynamic>.from(_data?['child_info'] ?? {});
    final risk = Map<String, dynamic>.from(_data?['risk_summary'] ?? {});
    final decision = Map<String, dynamic>.from(_data?['decision'] ?? {});
    final delayedDomains = (risk['delayed_domains'] as List? ?? const [])
        .map((e) => '$e')
        .toList();
    final behaviorFlags = (risk['behavior_flags'] as List? ?? const [])
        .map((e) => '$e')
        .toList();
    final status = _normalizeStatus('${_data?['status'] ?? 'PENDING'}');
    final severity = '${risk['severity'] ?? 'LOW'}';
    final deadline = '${decision['deadline'] ?? ''}';
    final overdue = _isOverdue(status, deadline);
    final lastUpdated =
        '${_data?['last_updated'] ?? _data?['completion_date'] ?? _data?['appointment_date'] ?? _data?['decision']?['created_on'] ?? '-'}';
    final escalationLevel = '${decision['escalation_level'] ?? '0'}';
    final escalatedTo = '${decision['escalated_to'] ?? ''}';

    return Scaffold(
      appBar: AppBar(title: const Text('Referral')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (overdue)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD32F2F)),
              ),
              child: const Text(
                'Referral overdue: follow-up deadline has passed.',
                style: TextStyle(
                  color: Color(0xFFB71C1C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          _sectionCard(
            title: '1) Child Information',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Referral ID: ${_data?['referral_id'] ?? '-'}'),
                Text('Child Name: ${child['name'] ?? widget.childId}'),
                Text('Child ID: ${child['child_id'] ?? widget.childId}'),
                Text('Age: ${child['age'] ?? widget.ageMonths} months'),
                Text('Gender: ${child['gender'] ?? 'Unknown'}'),
                Text(
                  'Village / Anganwadi ID: ${child['village_or_awc_id'] ?? 'N/A'}',
                ),
                Text(
                  'Assigned Worker: ${child['assigned_worker'] ?? widget.awwId}',
                ),
              ],
            ),
          ),
          _sectionCard(
            title: '2) Risk Summary',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Severity Level: ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _severityColor(severity),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        severity,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Total Risk Score: ${risk['risk_score'] ?? 0}'),
                const SizedBox(height: 6),
                const Text(
                  'Delayed Domains:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                if (delayedDomains.isEmpty)
                  const Text('No delayed domains identified.'),
                for (final d in delayedDomains) Text('- $d'),
                const SizedBox(height: 6),
                Text(
                  'Autism Risk: ${risk['autism_risk'] ?? 'No Significant Risk'}',
                ),
                Text(
                  'ADHD Risk: ${risk['adhd_risk'] ?? 'No Significant Risk'}',
                ),
                const SizedBox(height: 6),
                const Text(
                  'Behavioral Red Flags:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final f in behaviorFlags) Text('- $f'),
              ],
            ),
          ),
          _sectionCard(
            title: '3) Referral Decision',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Urgency: ${decision['urgency'] ?? 'N/A'}'),
                Text('Recommended Facility: ${decision['facility'] ?? 'N/A'}'),
                Text('Referral Created On: ${decision['created_on'] ?? 'N/A'}'),
                Text('Follow-up Deadline: ${decision['deadline'] ?? 'N/A'}'),
                Text('Escalation Level: $escalationLevel'),
                if (escalatedTo.trim().isNotEmpty)
                  Text('Escalated To: $escalatedTo'),
              ],
            ),
          ),
          _sectionCard(
            title: '4) Status Tracker',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Status: $status'),
                Text('Last Updated: $lastUpdated'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Update Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                    DropdownMenuItem(
                      value: 'SCHEDULED',
                      child: Text('SCHEDULED'),
                    ),
                    DropdownMenuItem(value: 'VISITED', child: Text('VISITED')),
                    DropdownMenuItem(
                      value: 'COMPLETED',
                      child: Text('COMPLETED'),
                    ),
                    DropdownMenuItem(value: 'MISSED', child: Text('MISSED')),
                  ],
                  onChanged: _updating
                      ? null
                      : (value) {
                          if (value != null) {
                            _setStatus(value);
                          }
                        },
                ),
                const SizedBox(height: 8),
                Text('Appointment Date: ${_data?['appointment_date'] ?? '-'}'),
                Text('Completion Date: ${_data?['completion_date'] ?? '-'}'),
                const SizedBox(height: 8),
                TextField(
                  controller: _remarksController,
                  decoration: const InputDecoration(
                    labelText: 'Worker Remarks (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onChanged: (value) {
                    _data ??= <String, dynamic>{};
                    _data!['worker_remarks'] = value;
                  },
                ),
                const SizedBox(height: 6),
                Text('Current Remarks: ${_data?['worker_remarks'] ?? '-'}'),
              ],
            ),
          ),
          _sectionCard(
            title: '5) Actions',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: (_updating || !_canMarkScheduled(status))
                      ? null
                      : () => _setStatus('SCHEDULED'),
                  child: const Text('Mark Appointment Scheduled'),
                ),
                ElevatedButton(
                  onPressed: (_updating || !_canMarkCompleted(status))
                      ? null
                      : () => _setStatus('COMPLETED'),
                  child: const Text('Mark Visit Completed'),
                ),
                ElevatedButton(
                  onPressed: (_updating || !_canMarkMissed(status))
                      ? null
                      : () => _setStatus('MISSED'),
                  child: const Text('Mark Missed'),
                ),
                OutlinedButton(
                  onPressed: (_updating || !_canEscalate(status))
                      ? null
                      : _escalate,
                  child: const Text('Escalate Further'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final referralId = _data?['referral_id'] ?? '';
                    final childId = widget.childId;
                    if (referralId.isNotEmpty) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FollowupCompleteScreen(
                            referralId: referralId,
                            childId: childId,
                            userRole: 'AWW',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.assignment_turned_in),
                  label: const Text('View Follow-Up Activities'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReferralPolicy {
  final String type;
  final String urgency;
  final int followUpDays;

  const _ReferralPolicy({
    required this.type,
    required this.urgency,
    required this.followUpDays,
  });
}
