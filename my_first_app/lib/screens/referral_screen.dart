import 'package:flutter/material.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/models/referral_model.dart';
import 'package:my_first_app/screens/referral_details_screen.dart';
import 'package:my_first_app/services/api_service.dart';
import 'package:my_first_app/services/local_db_service.dart';

class ReferralScreen extends StatefulWidget {
  final String childId;
  final String awwId;
  final int ageMonths;
  final String overallRisk; // low | medium | high | critical
  final Map<String, double> domainScores;
  final Map<String, String>? domainRiskLevels;

  // Review-driven escalation flags for medium-risk referral.
  final bool noImprovementAfterTwoReviews;
  final bool persistentComplianceBelow40;
  final bool worseningDelayTrend;
  final bool multipleCriticalDomains;

  const ReferralScreen({
    super.key,
    required this.childId,
    required this.awwId,
    required this.ageMonths,
    required this.overallRisk,
    required this.domainScores,
    this.domainRiskLevels,
    this.noImprovementAfterTwoReviews = false,
    this.persistentComplianceBelow40 = false,
    this.worseningDelayTrend = false,
    this.multipleCriticalDomains = false,
  });

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  bool _submitting = false;

  late final _DomainRisk _highestDomain;
  late final String _effectiveRisk;
  late final _ReferralPolicy _policy;
  late final List<String> _reviewEscalationReasons;
  late final bool _canGenerateReferral;

  @override
  void initState() {
    super.initState();
    final domainRisks = _buildDomainRisks();
    _highestDomain = domainRisks.isEmpty
        ? const _DomainRisk(key: 'N/A', risk: 'low', severity: 0)
        : domainRisks.reduce((a, b) => a.severity >= b.severity ? a : b);

    final overall = _normalizeRisk(widget.overallRisk);
    _effectiveRisk = _severity(overall) >= _highestDomain.severity
        ? overall
        : _highestDomain.risk;

    _reviewEscalationReasons = _buildReviewEscalationReasons();
    _policy = _policyForRisk(_effectiveRisk);
    _canGenerateReferral = _shouldGenerateReferral();
  }

  List<_DomainRisk> _buildDomainRisks() {
    final out = <_DomainRisk>[];
    final labels = widget.domainRiskLevels ?? {};
    for (final entry in widget.domainScores.entries) {
      final label = labels[entry.key] ?? _riskFromScore(entry.value);
      out.add(
        _DomainRisk(
          key: entry.key,
          risk: _normalizeRisk(label),
          severity: _severity(label),
        ),
      );
    }
    for (final entry in labels.entries) {
      if (out.any((d) => d.key == entry.key)) continue;
      out.add(
        _DomainRisk(
          key: entry.key,
          risk: _normalizeRisk(entry.value),
          severity: _severity(entry.value),
        ),
      );
    }
    return out;
  }

  List<String> _buildReviewEscalationReasons() {
    final reasons = <String>[];
    if (widget.noImprovementAfterTwoReviews) {
      reasons.add('No improvement after 2 review cycles');
    }
    if (widget.persistentComplianceBelow40) {
      reasons.add('Compliance below 40% persistently');
    }
    if (widget.worseningDelayTrend) {
      reasons.add('Delay trend worsening');
    }
    if (widget.multipleCriticalDomains) {
      reasons.add('Multiple domains marked critical');
    }
    return reasons;
  }

  _ReferralPolicy _policyForRisk(String risk) {
    switch (_normalizeRisk(risk)) {
      case 'critical':
        return _ReferralPolicy(
          referralTypeLabel: 'Immediate Specialist Referral',
          type: ReferralType.immediateSpecialistReferral,
          urgency: ReferralUrgency.immediate,
          urgencyLabel: 'Immediate',
          followUpDays: 2,
          handledAt: 'District specialist',
        );
      case 'high':
        return _ReferralPolicy(
          referralTypeLabel: 'Specialist Evaluation',
          type: ReferralType.specialistEvaluation,
          urgency: ReferralUrgency.priority,
          urgencyLabel: 'Priority',
          followUpDays: 10,
          handledAt: 'Block / District specialist',
        );
      case 'medium':
        return _ReferralPolicy(
          referralTypeLabel: 'Enhanced Monitoring',
          type: ReferralType.enhancedMonitoring,
          urgency: ReferralUrgency.normal,
          urgencyLabel: 'Normal',
          followUpDays: 30,
          handledAt: 'AWW / Block level',
        );
      default:
        return _ReferralPolicy(
          referralTypeLabel: 'Not Required',
          type: ReferralType.enhancedMonitoring,
          urgency: ReferralUrgency.normal,
          urgencyLabel: 'Normal',
          followUpDays: 30,
          handledAt: 'AWW level',
        );
    }
  }

  bool _shouldGenerateReferral() {
    final risk = _normalizeRisk(_effectiveRisk);
    if (risk == 'critical' || risk == 'high' || risk == 'medium') return true;
    return false;
  }

  String _riskFromScore(double v) {
    if (v <= 0.4) return 'critical';
    if (v <= 0.6) return 'high';
    if (v <= 0.8) return 'medium';
    return 'low';
  }

  String _normalizeRisk(String risk) => risk.trim().toLowerCase();

  int _severity(String risk) {
    switch (_normalizeRisk(risk)) {
      case 'critical':
        return 3;
      case 'high':
        return 2;
      case 'medium':
        return 1;
      default:
        return 0;
    }
  }

  String _riskLabel(String risk, AppLocalizations l10n) {
    switch (_normalizeRisk(risk)) {
      case 'critical':
        return l10n.t('critical');
      case 'high':
        return l10n.t('high');
      case 'medium':
        return l10n.t('medium');
      default:
        return l10n.t('low');
    }
  }

  String _domainLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'GM':
        return l10n.t('domain_gm');
      case 'FM':
        return l10n.t('domain_fm');
      case 'LC':
        return l10n.t('domain_lc');
      case 'COG':
        return l10n.t('domain_cog');
      case 'SE':
        return l10n.t('domain_se');
      default:
        return key;
    }
  }

  String _backendReferralType(ReferralType type) {
    if (type == ReferralType.enhancedMonitoring) return 'RBSK';
    return 'PHC';
  }

  String _backendUrgency(ReferralUrgency urgency) {
    switch (urgency) {
      case ReferralUrgency.priority:
        return 'Priority';
      case ReferralUrgency.immediate:
        return 'Immediate';
      default:
        return 'Normal';
    }
  }

  Future<void> _createReferral() async {
    if (!_canGenerateReferral) return;
    setState(() => _submitting = true);
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();

    try {
      final api = APIService();
      final localDb = LocalDBService();
      await localDb.initialize();
      try {
        final serverReferral = await api.getReferralByChild(widget.childId);
        final serverReferralId = '${serverReferral['referral_id'] ?? ''}'
            .trim();
        if (serverReferralId.isNotEmpty) {
          final serverCreatedOn =
              DateTime.tryParse('${serverReferral['created_on'] ?? ''}') ?? now;
          final serverFollowUpBy =
              DateTime.tryParse('${serverReferral['followup_by'] ?? ''}') ??
              now.add(Duration(days: _policy.followUpDays));
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ReferralDetailsScreen(
                  referralId: serverReferralId,
                  childId: widget.childId,
                  awwId: widget.awwId,
                  ageMonths: widget.ageMonths,
                  overallRisk: _effectiveRisk,
                  referralType:
                      '${serverReferral['referral_type_label'] ?? _policy.referralTypeLabel}',
                  urgency:
                      '${serverReferral['urgency'] ?? _policy.urgencyLabel}',
                  status: '${serverReferral['status'] ?? 'Pending'}',
                  createdAt: serverCreatedOn,
                  expectedFollowUpDate: serverFollowUpBy,
                  notes: null,
                  reasons: <String>[
                    '${_domainLabel(_highestDomain.key, l10n)} (${_riskLabel(_highestDomain.risk, l10n)})',
                  ],
                ),
              ),
            );
          }
          return;
        }
      } catch (_) {
        // Fallback to local lookup/create when backend lookup is unavailable.
      }

      final existing = localDb.getChildReferrals(widget.childId)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (existing.isNotEmpty) {
        final latest = existing.first;
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ReferralDetailsScreen(
                referralId: latest.referralId,
                childId: latest.childId,
                awwId: latest.awwId,
                ageMonths: widget.ageMonths,
                overallRisk: _effectiveRisk,
                referralType: _policy.referralTypeLabel,
                urgency: _policy.urgencyLabel,
                status: latest.status.toString().split('.').last,
                createdAt: latest.createdAt,
                expectedFollowUpDate: latest.expectedFollowUpDate,
                notes: latest.notes,
                reasons: <String>[
                  (latest.metadata?['domain_reason']
                              ?.toString()
                              .trim()
                              .isNotEmpty ??
                          false)
                      ? latest.metadata!['domain_reason'].toString()
                      : '${_domainLabel(_highestDomain.key, l10n)} (${_riskLabel(_highestDomain.risk, l10n)})',
                ],
              ),
            ),
          );
        }
        return;
      }

      final followUpBy = now.add(Duration(days: _policy.followUpDays));
      final domainReason =
          '${_domainLabel(_highestDomain.key, l10n)} (${_riskLabel(_highestDomain.risk, l10n)})';
      final notes = _reviewEscalationReasons.isEmpty
          ? domainReason
          : '$domainReason | ${_reviewEscalationReasons.join('; ')}';
      final payload = {
        'child_id': widget.childId,
        'aww_id': widget.awwId,
        'age_months': widget.ageMonths,
        'overall_risk': _effectiveRisk,
        'domain_scores': widget.domainScores,
        'referral_type': _backendReferralType(_policy.type),
        'urgency': _backendUrgency(_policy.urgency),
        'expected_follow_up': followUpBy.toIso8601String(),
        'notes': notes,
        'referral_timestamp': now.toIso8601String(),
      };

      String referralId;
      bool synced = true;
      try {
        final server = await api.createReferral(payload);
        referralId = (server['referral_id']?.toString().isNotEmpty ?? false)
            ? server['referral_id'].toString()
            : 'ref_${now.millisecondsSinceEpoch}';
      } catch (_) {
        referralId = 'ref_${now.millisecondsSinceEpoch}';
        synced = false;
      }

      final localReferral = ReferralModel(
        referralId: referralId,
        screeningId: synced
            ? 'problem_b_referral'
            : 'problem_b_referral_offline',
        childId: widget.childId,
        awwId: widget.awwId,
        referralType: _policy.type,
        urgency: _policy.urgency,
        status: ReferralStatus.pending,
        notes: notes,
        expectedFollowUpDate: followUpBy,
        createdAt: now,
        metadata: {
          'child_id': widget.childId,
          'risk_level': _effectiveRisk,
          'domain': _highestDomain.key,
          'domain_risk': _highestDomain.risk,
          'domain_reason': domainReason,
          'urgency': _policy.urgencyLabel,
          'created_on': now.toIso8601String(),
          'followup_by': followUpBy.toIso8601String(),
          'status': 'Pending',
          if (!synced) 'sync_status': 'not_synced',
        },
      );
      await localDb.saveReferral(localReferral);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ReferralDetailsScreen(
              referralId: referralId,
              childId: widget.childId,
              awwId: widget.awwId,
              ageMonths: widget.ageMonths,
              overallRisk: _effectiveRisk,
              referralType: _policy.referralTypeLabel,
              urgency: _policy.urgencyLabel,
              status: 'pending',
              createdAt: now,
              expectedFollowUpDate: followUpBy,
              notes: notes,
              reasons: <String>[domainReason],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating referrals: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final riskLabel = _riskLabel(_effectiveRisk, l10n).toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('create_referral'))),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Risk Level: $riskLabel',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Referral Required: ${_canGenerateReferral ? 'Yes' : 'No'}',
                  ),
                  Text(
                    'Domain Reason: ${_domainLabel(_highestDomain.key, l10n)}',
                  ),
                  Text('Referral Type: ${_policy.referralTypeLabel}'),
                  Text('Urgency: ${_policy.urgencyLabel}'),
                  Text('Handled At: ${_policy.handledAt}'),
                  Text('Follow-up By: ${_policy.followUpDays} days'),
                ],
              ),
            ),
          ),
          if (_reviewEscalationReasons.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Review Escalation Reasons',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    for (final reason in _reviewEscalationReasons)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('- $reason'),
                      ),
                  ],
                ),
              ),
            ),
          if (!_canGenerateReferral)
            Card(
              color: const Color(0xFFFFF8E1),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Referral is not required for low risk.'),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_submitting || !_canGenerateReferral)
                  ? null
                  : _createReferral,
              child: Text(
                _submitting
                    ? l10n.t('submitting')
                    : l10n.t('generate_referral'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DomainRisk {
  final String key;
  final String risk;
  final int severity;

  const _DomainRisk({
    required this.key,
    required this.risk,
    required this.severity,
  });
}

class _ReferralPolicy {
  final String referralTypeLabel;
  final ReferralType type;
  final ReferralUrgency urgency;
  final String urgencyLabel;
  final int followUpDays;
  final String handledAt;

  const _ReferralPolicy({
    required this.referralTypeLabel,
    required this.type,
    required this.urgency,
    required this.urgencyLabel,
    required this.followUpDays,
    required this.handledAt,
  });
}
