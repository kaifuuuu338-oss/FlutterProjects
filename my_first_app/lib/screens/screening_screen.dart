import 'package:flutter/material.dart';
import 'package:my_first_app/core/constants/app_constants.dart';
import 'package:my_first_app/core/constants/question_bank.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/widgets/domain_card.dart';
import 'package:my_first_app/widgets/custom_button.dart';
import 'package:my_first_app/screens/dashboard_screen.dart';
import 'package:my_first_app/screens/result_screen.dart';
import 'package:my_first_app/screens/behavioral_psychosocial_screen.dart';
import 'package:my_first_app/screens/settings_screen.dart';
import 'package:my_first_app/services/local_db_service.dart';
import 'package:my_first_app/services/api_service.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'package:my_first_app/widgets/language_menu_button.dart';
import 'package:my_first_app/core/utils/delay_summary.dart';
import 'package:my_first_app/core/utils/weighted_scoring_engine.dart';



class ScreeningScreen extends StatefulWidget {
  final String childId;
  final int ageMonths;
  final String awwId;
  final bool consentGiven;
  final DateTime consentTimestamp;

  const ScreeningScreen({
    super.key,
    required this.childId,
    required this.ageMonths,
    required this.awwId,
    required this.consentGiven,
    required this.consentTimestamp,
  });

  @override
  State<ScreeningScreen> createState() => _ScreeningScreenState();
}

class _ScreeningScreenState extends State<ScreeningScreen> {
  final LocalDBService _localDb = LocalDBService();

  // domain -> index -> response (1=yes, 0=no)
  Map<String, Map<int,int>> domainResponses = {};
  bool submitting = false;
  late final String _draftScreeningId;
  Map<String, List<String>> _displayQuestions = {};
  Locale? _currentLocale;

  @override
  void initState() {
    super.initState();
    _draftScreeningId = 'draft_${widget.childId}';
    _displayQuestions = QuestionBank.byAgeMonths(widget.ageMonths);
    for (var d in AppConstants.domains) {
      domainResponses[d] = {};
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_currentLocale?.languageCode != locale.languageCode) {
      _currentLocale = locale;
      setState(() {
        _displayQuestions = QuestionBank.byAgeMonths(
          widget.ageMonths,
          languageCode: locale.languageCode,
        );
      });
    }
  }

  bool _allQuestionsAnswered() {
    for (final domain in AppConstants.domains) {
      final total = (_displayQuestions[domain] ?? []).length;
      final answered = (domainResponses[domain] ?? {}).length;
      if (total == 0 || answered != total) return false;
    }
    return true;
  }

  void _onDomainChanged(String domain, Map<int,int> responses) {
    setState(() {
      domainResponses[domain] = responses;
    });
  }

  Map<String,double> _computeDomainScores() {
    final Map<String,double> scores = {};
    
    domainResponses.forEach((domain, respMap) {
      if (respMap.isEmpty) {
        scores[domain] = 0.5; // neutral if no responses
        return;
      }
      
      // Convert map responses to list (0=No, 1=Yes) - use directly
      final responseList = List<int>.filled(respMap.length, 0);
      respMap.forEach((index, value) {
        responseList[index] = value; // 0 or 1 directly
      });
      
      // Use weighted scoring engine with exact formula:
      // S = Σ(aᵢ × wᵢ)
      // T = 0.5 × Σ(wᵢ)
      // P = 1 / (1 + e^(-(S-T)))
      final weightedScore = WeightedScoringEngine.computeDomainScore(
        domain,
        responseList,
        widget.ageMonths,
      );
      
      scores[domain] = weightedScore;
    });
    
    return scores;
  }

  Future<void> _saveDomainDraft(String domain) async {
    final domainScores = _computeDomainScores();
    final l10n = AppLocalizations.of(context);
    final localDb = LocalDBService();
    await localDb.initialize();

    final draft = ScreeningModel(
      screeningId: _draftScreeningId,
      childId: widget.childId,
      awwId: widget.awwId,
      assessmentType: AssessmentType.baseline,
      ageMonths: widget.ageMonths,
      domainResponses: domainResponses.map((k, v) => MapEntry(k, v.values.toList())),
      domainScores: domainScores,
      overallRisk: RiskLevel.low,
      explainability: l10n.t('draft_saved_for_domain', {'domain': _domainLabel(domain, l10n)}),
      missedMilestones: domainResponses.values.fold<int>(0, (acc, m) => acc + m.values.where((v) => v == 0).length),
      delayMonths: 0,
      consentGiven: widget.consentGiven,
      consentTimestamp: widget.consentTimestamp,
      referralTriggered: false,
      screeningDate: DateTime.now(),
      submittedAt: null,
    );
    await localDb.saveScreening(draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_domainLabel(domain, l10n)} ${l10n.t('responses_saved')}')),
    );
  }

  String _normalizeRisk(String value) => value.trim().toLowerCase();

  double _riskLabelToScore(String riskLabel) {
    switch (_normalizeRisk(riskLabel)) {
      case 'critical':
        return 0.3;
      case 'high':
        return 0.5;
      case 'medium':
        return 0.7;
      default:
        return 0.9;
    }
  }

  Map<String, double> _domainRiskToScoreMap(dynamic rawDomainScores) {
    if (rawDomainScores is! Map) return {};
    final mapped = <String, double>{};
    rawDomainScores.forEach((key, value) {
      if (value is num) {
        mapped['$key'] = value.toDouble();
      } else {
        mapped['$key'] = _riskLabelToScore('$value');
      }
    });
    return mapped;
  }

  Map<String, String> _domainRiskLabelMap(dynamic rawDomainScores) {
    if (rawDomainScores is! Map) return {};
    final mapped = <String, String>{};
    rawDomainScores.forEach((key, value) {
      final label = '$value';
      final n = _normalizeRisk(label);
      mapped['$key'] = n.isEmpty ? label : '${n[0].toUpperCase()}${n.substring(1)}';
    });
    return mapped;
  }

  void _onSubmit() async {
    final l10n = AppLocalizations.of(context);
    if (!_allQuestionsAnswered()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('please_answer_all_questions'))),
      );
      return;
    }

    setState(() => submitting = true);
    final domainScores = _computeDomainScores();

    // Convert weighted scores to risk labels using sigmoidal thresholds
    final domainRiskLevels = <String, String>{};
    for (final domain in AppConstants.domains) {
      final score = domainScores[domain] ?? 0.5;
      domainRiskLevels[domain] = WeightedScoringEngine.domainScoreToRiskLabel(score);
    }

    // Calculate overall risk from domain scores
    var overallRisk = WeightedScoringEngine.overallRiskFromDomains(domainScores);
    var explainability = '';
    var finalDomainScores = Map<String, double>.from(domainScores);
    final localDelaySummary = buildDelaySummaryFromResponses(
      domainResponses.map((k, v) => MapEntry(k, v.values.toList())),
      ageMonths: widget.ageMonths,
    );
    Map<String, int> delaySummary = localDelaySummary ?? {};

    // Load child + save locally (best effort)
    final localDb = LocalDBService();
    dynamic child;
    try {
      await localDb.initialize();
      child = localDb.getChild(widget.childId);
    } catch (e) {
      debugPrint('Local DB init/get error: $e');
    }

    // Build payload same as API contract
    final payload = {
      'child_id': widget.childId,
      'assessment_type': 'baseline',
      'assessment_cycle': 'Baseline',
      'age_months': widget.ageMonths,
      'gender': child?.gender ?? 'M',
      'mandal': child?.mandal ?? 'Demo Mandal',
      'district': child?.district ?? 'Demo District',
      'aws_code': child?.awcCode ?? 'AWS_DEMO_001',
      'domain_responses': domainResponses.map((k,v) => MapEntry(k, v.values.toList())),
      'domain_scores': domainScores,
      'overall_risk': overallRisk,
      'consent_given': widget.consentGiven,
      'consent_timestamp': widget.consentTimestamp.toIso8601String(),
    };

    final screening = ScreeningModel(
      screeningId: 'scr_${DateTime.now().millisecondsSinceEpoch}',
      childId: widget.childId,
      awwId: widget.awwId,
      assessmentType: AssessmentType.baseline,
      ageMonths: widget.ageMonths,
      domainResponses: domainResponses.map((k, v) => MapEntry(k, v.values.toList())),
      domainScores: domainScores,
      overallRisk: RiskLevel.values.firstWhere(
        (e) => e.toString().split('.').last == overallRisk,
        orElse: () => RiskLevel.low,
      ),
      explainability: l10n.t('rule_based_scoring_placeholder'),
      missedMilestones: domainResponses.values.fold<int>(0, (acc, m) => acc + m.values.where((v) => v == 0).length),
      delayMonths: 0,
      consentGiven: widget.consentGiven,
      consentTimestamp: widget.consentTimestamp,
      referralTriggered: false,
      screeningDate: DateTime.now(),
      submittedAt: null,
    );

    try {
      await localDb.saveScreening(screening);
    } catch (e) {
      debugPrint('Local save error: $e');
    }

    // AI API prediction is the source of truth for risk (best effort)
    final api = APIService();
    try {
      final response = await api.submitScreening(payload);
      overallRisk = _normalizeRisk('${response['risk_level'] ?? overallRisk}');
      if (response['domain_scores'] != null) {
        finalDomainScores = _domainRiskToScoreMap(response['domain_scores']);
        domainRiskLevels.clear();
        domainRiskLevels.addAll(_domainRiskLabelMap(response['domain_scores']));
      }
      final expRaw = response['explanation'];
      if (expRaw is List) {
        explainability = expRaw.map((e) => '- $e').join('\n');
      } else if (expRaw != null) {
        explainability = '$expRaw';
      }
      final delayRaw = response['delay_summary'];
      if (delayRaw is Map) {
        final apiSummary = delayRaw.map((k, v) => MapEntry('$k', (v as num).toInt()));
        for (final entry in apiSummary.entries) {
          delaySummary.putIfAbsent(entry.key, () => entry.value);
        }
      }

      final riskEnum = RiskLevel.values.firstWhere(
        (e) => e.toString().split('.').last == overallRisk,
        orElse: () => RiskLevel.low,
      );
      final updated = screening.copyWith(
        domainScores: finalDomainScores,
        overallRisk: riskEnum,
        explainability: explainability,
        submittedAt: DateTime.now(),
      );

      try {
        await localDb.saveScreening(updated);
      } catch (e) {
        debugPrint('Local update error: $e');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('screening_saved_not_synced'))),
        );
      }
      // Continue to next step with local results even if API is unreachable.
    } finally {
      if (mounted) setState(() => submitting = false);
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BehavioralPsychosocialScreen(
          prevDomainScores: finalDomainScores,
          domainRiskLevels: domainRiskLevels,
          overallRisk: overallRisk,
          missedMilestones: domainResponses.values.fold<int>(0, (acc, m) => acc + m.values.where((v) => v == 0).length),
          explainability: explainability,
          childId: widget.childId,
          awwId: widget.awwId,
          ageMonths: widget.ageMonths,
          delaySummary: delaySummary,
        ),
      ),
    );
  }

  Future<void> _goDashboard() async {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  Future<void> _showChildrenCount() async {
    await _localDb.initialize();
    final count = _localDb.getAllChildren().length;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.t('children')),
        content: Text(l10n.t('total_registered_children', {'count': '$count'})),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.t('ok'))),
        ],
      ),
    );
  }

  Future<void> _showRiskStatus() async {
    await _localDb.initialize();
    final children = _localDb.getAllChildren();
    final all = <ScreeningModel>[];
    for (final c in children) {
      all.addAll(_localDb.getChildScreenings(c.childId));
    }

    final low = all.where((s) => s.overallRisk == RiskLevel.low).length;
    final medium = all.where((s) => s.overallRisk == RiskLevel.medium).length;
    final high = all.where((s) => s.overallRisk == RiskLevel.high).length;
    final critical = all.where((s) => s.overallRisk == RiskLevel.critical).length;

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.t('risk_status')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('risk_count_low', {'count': '$low'})),
            Text(l10n.t('risk_count_medium', {'count': '$medium'})),
            Text(l10n.t('risk_count_high', {'count': '$high'})),
            Text(l10n.t('risk_count_critical', {'count': '$critical'})),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.t('ok'))),
        ],
      ),
    );
  }

  Future<void> _openPastResults() async {
    await _localDb.initialize();
    final children = _localDb.getAllChildren();
    final past = <ScreeningModel>[];
    for (final c in children) {
      past.addAll(_localDb.getChildScreenings(c.childId));
    }
    past.sort((a, b) => b.screeningDate.compareTo(a.screeningDate));

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (past.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('no_past_results'))),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: past.length,
        itemBuilder: (context, index) {
          final s = past[index];
          final risk = s.overallRisk.toString().split('.').last;
          final delaySummary = buildDelaySummaryFromResponses(
            s.domainResponses,
            ageMonths: s.ageMonths,
          );
          return ListTile(
            title: Text('${s.childId} - ${l10n.t(risk.toLowerCase()).toUpperCase()}'),
            subtitle: Text(l10n.t('date_label', {'date': '${s.screeningDate.toLocal()}'})),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ResultScreen(
                    domainScores: s.domainScores,
                    overallRisk: risk,
                    missedMilestones: s.missedMilestones,
                    explainability: s.explainability,
                    childId: s.childId,
                    awwId: s.awwId,
                    ageMonths: s.ageMonths,
                    delaySummary: delaySummary,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
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

  Widget _buildNavDrawer() {
    final l10n = AppLocalizations.of(context);
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            ListTile(
              title: Text(l10n.t('navigation'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(leading: const Icon(Icons.home_outlined), title: Text(l10n.t('dashboard')), onTap: _goDashboard),
            ListTile(leading: const Icon(Icons.people_outline), title: Text(l10n.t('children')), onTap: () { Navigator.of(context).pop(); _showChildrenCount(); }),
            ListTile(leading: const Icon(Icons.dataset_outlined), title: Text(l10n.t('risk_status')), onTap: () { Navigator.of(context).pop(); _showRiskStatus(); }),
            ListTile(leading: const Icon(Icons.query_stats_outlined), title: Text(l10n.t('view_past_results')), onTap: () { Navigator.of(context).pop(); _openPastResults(); }),
            ListTile(leading: const Icon(Icons.settings_outlined), title: Text(l10n.t('settings')), onTap: () { Navigator.of(context).pop(); _openSettings(); }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totalQuestions = _displayQuestions.values.fold<int>(0, (a, b) => a + b.length);
    final answeredQuestions = domainResponses.values.fold<int>(0, (a, b) => a + b.length);
    final progress = totalQuestions == 0 ? 0.0 : answeredQuestions / totalQuestions;
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    final headerCard = Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF46C39D), Color(0xFF2CA38C)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.t('assessment_for', {'childId': widget.childId}),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              ClipOval(
                child: Image.asset(
                  'assets/images/ap_logo.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    alignment: Alignment.center,
                    child: Text(AppLocalizations.of(context).t('ap_short'), style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold)),

                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.35),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D5BA7)),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            l10n.t(
              'questions_answered_summary',
              {
                'answered': '$answeredQuestions',
                'total': '$totalQuestions',
                'age': '${widget.ageMonths}',
              },
            ),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 12),
          ),
        ],
      ),
    );

    final domainsList = ListView(
      children: AppConstants.domains.map((d) {
        final questions = _displayQuestions[d] ?? [];
        return DomainCard(
          domainKey: d,
          title: _domainLabel(d, l10n),
          questions: questions,
          responses: domainResponses[d] ?? {},
          onChanged: (map) => _onDomainChanged(d, map),
          onSave: () => _saveDomainDraft(d),
          saveLabel: l10n.t('save_topic'),
          yesLabel: l10n.t('yes'),
          noLabel: l10n.t('no'),
        );
      }).toList(),
    );

    if (!isDesktop) {
      return Scaffold(
        drawer: _buildNavDrawer(),
        appBar: AppBar(
          title: Text(l10n.t('screening_assessment'), style: const TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFF0D5BA7),
          foregroundColor: Colors.white,
          actions: [
            const LanguageMenuButton(iconColor: Colors.white),
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            headerCard,
            Expanded(child: domainsList),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: CustomButton(
                  label: submitting ? l10n.t('submitting') : l10n.t('submit_assessment'),
                  onPressed: submitting ? () {} : _onSubmit,
                  elevated: true,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      body: Column(
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1C86DF), Color(0xFF2A9AF5)]),
            ),
            child: Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/ap_logo.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(AppLocalizations.of(context).t('ap_short'), style: const TextStyle(fontSize: 9, color: Color(0xFF1976D2), fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context).t('govt_andhra_pradesh'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                const LanguageMenuButton(iconColor: Colors.white, iconSize: 18),
                const Icon(Icons.search, color: Colors.white, size: 18),
                const SizedBox(width: 14),
                const Icon(Icons.power_settings_new, color: Colors.white, size: 18),
                const SizedBox(width: 14),
                const Icon(Icons.menu, color: Colors.white, size: 18),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 220,
                  color: Colors.white,
                  child: ListView(
                    children: [
                      _ScreenSideItem(icon: Icons.home_outlined, label: l10n.t('dashboard'), onTap: _goDashboard),
                      _ScreenSideItem(icon: Icons.people_outline, label: l10n.t('children'), onTap: _showChildrenCount),
                      _ScreenSideItem(icon: Icons.dataset_outlined, label: l10n.t('risk_status'), onTap: _showRiskStatus),
                      _ScreenSideItem(icon: Icons.query_stats_outlined, label: l10n.t('view_past_results'), onTap: _openPastResults),
                      _ScreenSideItem(icon: Icons.settings_outlined, label: l10n.t('settings'), onTap: _openSettings),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    child: Column(
                      children: [
                        headerCard,
                        Expanded(child: domainsList),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          child: SizedBox(
                            width: 420,
                            child: CustomButton(
                              label: submitting ? l10n.t('submitting') : l10n.t('submit_assessment'),
                              onPressed: submitting ? () {} : _onSubmit,
                              elevated: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenSideItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ScreenSideItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE7EDF3))),
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Icon(icon, size: 18, color: const Color(0xFF6A7580)),
        title: Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF58636F), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
