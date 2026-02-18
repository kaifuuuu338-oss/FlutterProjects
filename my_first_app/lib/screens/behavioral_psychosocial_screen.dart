import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/widgets/tri_state_question_card.dart';
import 'package:my_first_app/screens/behavioral_psychosocial_summary_screen.dart';
import 'package:my_first_app/services/local_db_service.dart';
import 'package:my_first_app/services/api_service.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'package:my_first_app/models/child_model.dart';
import 'package:my_first_app/core/constants/app_constants.dart';


class BehavioralPsychosocialScreen extends StatefulWidget {
  final Map<String, double> prevDomainScores;
  final Map<String, String>? domainRiskLevels;
  final Map<String, int>? delaySummary;
  final String overallRisk;
  final int missedMilestones;
  final String explainability;
  final String childId;
  final String awwId;
  final int ageMonths;

  const BehavioralPsychosocialScreen({
    super.key,
    required this.prevDomainScores,
    this.domainRiskLevels,
    this.delaySummary,
    required this.overallRisk,
    required this.missedMilestones,
    required this.explainability,
    required this.childId,
    required this.awwId,
    required this.ageMonths,
  });

  @override
  State<BehavioralPsychosocialScreen> createState() => _BehavioralPsychosocialScreenState();
}

class _BehavioralPsychosocialScreenState extends State<BehavioralPsychosocialScreen> {
  final LocalDBService _localDb = LocalDBService();
  final APIService _api = APIService();

  // Section state
  final Map<int, int> _autismAnswers = {};
  final Map<int, int> _adhdAnswers = {};
  final Map<int, int> _behaviorAnswers = {};
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _muacController = TextEditingController();
  final TextEditingController _hbController = TextEditingController();
  final TextEditingController _birthWeightController = TextEditingController();
  final TextEditingController _illnessHistoryController = TextEditingController();
  String? _immunizationStatus;
  bool _submitting = false;

  ChildModel? _child;
  void _showError(AppLocalizations l10n, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(message),
        backgroundColor: const Color(0xFFFFF8E1),
        actions: [
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: Text(l10n.t('close')),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadChild();
  }

  Future<void> _loadChild() async {
    if (kIsWeb) {
      setState(() => _child = null);
      return;
    }
    try {
      await _localDb.initialize();
      final c = _localDb.getChild(widget.childId);
      setState(() => _child = c);
    } catch (e) {
      debugPrint('Local DB init/get error: $e');
      setState(() => _child = null);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _muacController.dispose();
    _hbController.dispose();
    _birthWeightController.dispose();
    _illnessHistoryController.dispose();
    super.dispose();
  }

  // Questions (kept inline for easy review; can be localized later)
  static const List<String> _autismPositive = [
    'Responds to name?',
    'Makes eye contact?',
    'Points to show interest?',
    'Engages in pretend play?',
  ];
  static const List<String> _autismRedFlags = [
    'Repetitive hand/body movements?',
    'Limited social interaction?',
  ];

  static const List<String> _adhdQuestions = [
    'Difficulty sitting still?',
    'Easily distracted?',
    'Interrupts frequently?',
    'Trouble focusing?',
    'Very impulsive?',
  ];

  static const List<String> _behaviorQuestions = [
    'Frequent aggressive behaviour?',
    'Extreme tantrums?',
    'Withdrawn behaviour?',
    'Difficulty interacting with peers?',
    'Sleep disturbances?',
  ];

  // UI option labels
  static const List<String> _yesSometimesNo = ['Yes', 'Sometimes', 'No'];
  static const List<String> _neverSometimesOften = ['Never', 'Sometimes', 'Often'];
  static const List<String> _noSometimesYes = ['No', 'Sometimes', 'Yes'];

  // Scoring helpers
  // autism: positive behaviors => 2/1/0, red-flag behaviors reverse => 0/1/2
  int _scoreAutismAnswer(bool isRedFlag, int choiceIndex) {
    // choiceIndex: 0 -> first label (Yes / Never / No) etc.
    // Map to value 0..2 where higher = better for positive, reverse for red flag
    final mapPositive = {0: 2, 1: 1, 2: 0};
    final mapReverse = {0: 0, 1: 1, 2: 2};
    return isRedFlag ? mapReverse[choiceIndex]! : mapPositive[choiceIndex]!;
  }

  // ADHD: Never=0, Sometimes=1, Often=2 (higher => more symptoms)
  int _scoreADHDAnswer(int choiceIndex) => {0: 0, 1: 1, 2: 2}[choiceIndex]!;

  // Behaviour: No=0, Sometimes=1, Yes=2 (higher => more problems)
  int _scoreBehaviorAnswer(int choiceIndex) => {0: 0, 1: 1, 2: 2}[choiceIndex]!;

  double _normalize(int sum, int max) => max == 0 ? 0.0 : (sum / (max * 2));

  // Convert normalized (0..1 where higher is better for autism positive and worse for adhd/behavior depending)
  // to categorical risk 0=Low,1=Moderate,2=High. For domains where higher normalized means higher problems we use:
  // thresholds: <=0.33 -> Low(0), <=0.66 -> Moderate(1), >0.66 -> High(2) but adjusted per-domain.
  int _autismRiskCategory() {
    // compute effective score where higher==better
    var sum = 0;
    for (var i = 0; i < _autismPositive.length; i++) {
      sum += _scoreAutismAnswer(false, _autismAnswers[i] ?? 2); // default assume 'No' => worst for positive
    }
    for (var i = 0; i < _autismRedFlags.length; i++) {
      sum += _scoreAutismAnswer(true, _autismAnswers[_autismPositive.length + i] ?? 2); // default 'No' => best
    }
    final totalQ = _autismPositive.length + _autismRedFlags.length;
    final normalized = _normalize(sum, totalQ); // 0..1 where higher=better

    // Map normalized to risk where lower normalized -> higher risk
    if (normalized >= 0.75) return 0; // Low
    if (normalized >= 0.45) return 1; // Moderate
    return 2; // High
  }

  int _adhdRiskCategory() {
    var sum = 0;
    for (var i = 0; i < _adhdQuestions.length; i++) {
      sum += _scoreADHDAnswer(_adhdAnswers[i] ?? 0); // default 'Never'
    }
    final normalized = _normalize(sum, _adhdQuestions.length); // 0..1 where higher=worse
    if (normalized <= 0.33) return 0;
    if (normalized <= 0.66) return 1;
    return 2;
  }

  int _behaviorRiskCategory() {
    var sum = 0;
    for (var i = 0; i < _behaviorQuestions.length; i++) {
      sum += _scoreBehaviorAnswer(_behaviorAnswers[i] ?? 0);
    }
    final normalized = _normalize(sum, _behaviorQuestions.length); // 0..1 where higher=worse
    if (normalized <= 0.33) return 0;
    if (normalized <= 0.66) return 1;
    return 2;
  }

  String _riskLabelFromCode(int code) {
    switch (code) {
      case 2:
        return 'High';
      case 1:
        return 'Moderate';
      default:
        return 'Low';
    }
  }

  Color _riskColorFromCode(int code) {
    switch (code) {
      case 2:
        return const Color(0xFFE53935);
      case 1:
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFF43A047);
    }
  }

  List<String> _deriveReasons(int aCode, int adhdCode, int behCode) {
    final reasons = <String>[];
    // autism specific triggers
    if ((_autismAnswers[1] ?? 2) == 2) reasons.add('Limited eye contact');
    if ((_autismAnswers[0] ?? 2) == 2) reasons.add('No response to name');
    if ((_autismAnswers[4] ?? 0) == 0) reasons.add('Repetitive movements');

    // adhd triggers
    if ((_adhdAnswers[0] ?? 0) == 2) reasons.add('Frequent hyperactivity');
    if ((_adhdAnswers[3] ?? 0) == 2) reasons.add('Attention difficulties');

    // behaviour triggers
    if ((_behaviorAnswers[2] ?? 0) == 2) reasons.add('Social withdrawal');
    if ((_behaviorAnswers[0] ?? 0) == 2) reasons.add('Aggressive behaviour');

    return reasons;
  }

  Future<void> _submit() async {
    // Validate at least one section completed
    final l10n = AppLocalizations.of(context);

    // Enforce that all shown sections are fully answered
    if (widget.ageMonths >= 12 && widget.ageMonths <= 48) {
      final expected = _autismPositive.length + _autismRedFlags.length;
      if (_autismAnswers.length != expected) {
        _showError(l10n, 'Please answer all Autism questions.');
        return;
      }
    }
    if (widget.ageMonths >= 24) {
      if (_adhdAnswers.length != _adhdQuestions.length) {
        _showError(l10n, 'Please answer all ADHD questions.');
        return;
      }
    }
    if (_behaviorAnswers.length != _behaviorQuestions.length) {
      _showError(l10n, 'Please answer all Behaviour & Emotional questions.');
      return;
    }

    // Validate anthropometry & health
    final weightText = _weightController.text.trim();
    final heightText = _heightController.text.trim();
    if (weightText.isEmpty) {
      _showError(l10n, l10n.t('weight_required'));
      return;
    }
    if (heightText.isEmpty) {
      _showError(l10n, l10n.t('height_required'));
      return;
    }

    final double? weightKg = double.tryParse(weightText);
    final double? heightCm = double.tryParse(heightText);
    final double? muac = _muacController.text.trim().isEmpty ? null : double.tryParse(_muacController.text.trim());
    final double? hb = _hbController.text.trim().isEmpty ? null : double.tryParse(_hbController.text.trim());
    final double? birthWeightKg = _birthWeightController.text.trim().isEmpty ? null : double.tryParse(_birthWeightController.text.trim());
    final String illnessHistory = _illnessHistoryController.text.trim();

    if (weightKg == null || weightKg < 0.5 || weightKg > 60) {
      _showError(l10n, 'Enter a valid weight (0.5–60 kg).');
      return;
    }
    if (heightCm == null || heightCm < 30 || heightCm > 200) {
      _showError(l10n, 'Enter a valid height/length (30–200 cm).');
      return;
    }
    if (muac != null && (muac < 5 || muac > 30)) {
      _showError(l10n, 'Enter a valid MUAC (5–30 cm).');
      return;
    }
    if (hb != null && (hb < 3 || hb > 25)) {
      _showError(l10n, 'Enter a valid hemoglobin (3–25 g/dL).');
      return;
    }
    if (birthWeightKg != null && (birthWeightKg < 0.5 || birthWeightKg > 6)) {
      _showError(l10n, 'Enter a valid birth weight (0.5–6 kg).');
      return;
    }

    // Simple immunization status: full / partial / none (unknown defaults to medium risk)
    int immunizationStatusCode = 3; // 0=full,1=partial,2=none,3=unknown
    if (_immunizationStatus == 'full') immunizationStatusCode = 0;
    if (_immunizationStatus == 'partial') immunizationStatusCode = 1;
    if (_immunizationStatus == 'none') immunizationStatusCode = 2;
    final String immunizationRisk = immunizationStatusCode == 2 ? 'high' : (immunizationStatusCode == 0 ? 'low' : 'medium');

    setState(() => _submitting = true);

    // Compute domain risk categories and normalized scores
    final autismCode = (widget.ageMonths >= 12 && widget.ageMonths <= 48) ? _autismRiskCategory() : 0;
    final adhdCode = (widget.ageMonths >= 24) ? _adhdRiskCategory() : 0;
    final behaviorCode = _behaviorRiskCategory();

    // Normalized scores for display/storage (0..1) — lower is worse for autism normalized, so invert for display
    final autismSum = (() {
      var s = 0;
      for (var i = 0; i < _autismPositive.length; i++) s += _scoreAutismAnswer(false, _autismAnswers[i] ?? 2);
      for (var i = 0; i < _autismRedFlags.length; i++) s += _scoreAutismAnswer(true, _autismAnswers[_autismPositive.length + i] ?? 2);
      return s;
    })();
    final autismNorm = _autismPositive.length + _autismRedFlags.length == 0 ? 1.0 : autismSum / ((_autismPositive.length + _autismRedFlags.length) * 2);

    var adhdSum = 0;
    for (var i = 0; i < _adhdQuestions.length; i++) adhdSum += _scoreADHDAnswer(_adhdAnswers[i] ?? 0);
    final adhdNorm = _adhdQuestions.isEmpty ? 0.0 : adhdSum / (_adhdQuestions.length * 2);

    var behSum = 0;
    for (var i = 0; i < _behaviorQuestions.length; i++) behSum += _scoreBehaviorAnswer(_behaviorAnswers[i] ?? 0);
    final behNorm = _behaviorQuestions.isEmpty ? 0.0 : behSum / (_behaviorQuestions.length * 2);

    // Overall risk = worst of domain codes
    var worstCode = [autismCode, adhdCode, behaviorCode].reduce((a, b) => a > b ? a : b);

    // Map code to RiskLevel enum
    final overallRiskEnum = worstCode == 2
        ? RiskLevel.critical
        : (worstCode == 1 ? RiskLevel.medium : RiskLevel.low);

    // === Baseline score per rules (attachment):
    // - Each developmental delay domain adds +5 points
    // - Autism: High +15, Moderate +8
    // - ADHD: High +8, Moderate +4
    // - Behavioural: High +7
    // - Baseline category: <=10 Low, 11-25 Medium, >25 High

    // Count developmental delay domains from previous screening domainRiskLevels (GM/FM/LC/COG/SE)
    var devDelayCount = 0;
    if (widget.domainRiskLevels != null) {
      for (final d in AppConstants.domains) {
        final val = widget.domainRiskLevels![d];
        if (val == null) continue;
        final n = val.toString().trim().toLowerCase();
        if (n == 'medium' || n == 'high' || n == 'moderate') devDelayCount++;
      }
    }
    final devDelayPoints = devDelayCount * 5;

    final autismPoints = (autismCode == 2) ? 15 : (autismCode == 1 ? 8 : 0);
    final adhdPoints = (adhdCode == 2) ? 8 : (adhdCode == 1 ? 4 : 0);
    final behaviorPoints = (behaviorCode == 2) ? 7 : 0;

    final baselineScore = devDelayPoints + autismPoints + adhdPoints + behaviorPoints;
    final baselineCategory = baselineScore <= 10 ? 'Low' : (baselineScore <= 25 ? 'Medium' : 'High');

    // Prepare screening model & save locally (include baseline info inside explainability JSON)
    final screening = ScreeningModel(
      screeningId: 'bsp_${DateTime.now().millisecondsSinceEpoch}',
      childId: widget.childId,
      awwId: widget.awwId,
      assessmentType: AssessmentType.baseline,
      ageMonths: widget.ageMonths,
      domainResponses: {
        'BPS_AUT': [for (var i = 0; i < _autismPositive.length; i++) _autismAnswers[i] ?? 2]
            ..addAll([for (var i = 0; i < _autismRedFlags.length; i++) _autismAnswers[_autismPositive.length + i] ?? 2]),
        'BPS_ADHD': [for (var i = 0; i < _adhdQuestions.length; i++) _adhdAnswers[i] ?? 0],
        'BPS_BEH': [for (var i = 0; i < _behaviorQuestions.length; i++) _behaviorAnswers[i] ?? 0],
      },
      domainScores: {
        'BPS_AUT': autismNorm,
        'BPS_ADHD': adhdNorm,
        'BPS_BEH': behNorm,
      },
      overallRisk: overallRiskEnum,
      explainability: jsonEncode({
        'autism_risk_code': autismCode,
        'adhd_risk_code': adhdCode,
        'behavior_risk_code': behaviorCode,
        'dev_delay_domains': devDelayCount,
        'baseline_score': baselineScore,
        'baseline_category': baselineCategory,
        'points_breakdown': {
          'dev_delay_points': devDelayPoints,
          'autism_points': autismPoints,
          'adhd_points': adhdPoints,
          'behavior_points': behaviorPoints
        },
        'anthropometry': {
          'weight_kg': _weightController.text.isNotEmpty ? double.tryParse(_weightController.text) : null,
          'height_cm': _heightController.text.isNotEmpty ? double.tryParse(_heightController.text) : null,
          'muac_cm': _muacController.text.isNotEmpty ? double.tryParse(_muacController.text) : null,
          'birth_weight_kg': _birthWeightController.text.isNotEmpty ? double.tryParse(_birthWeightController.text) : null,
        },
        'health_indicators': {
          'hemoglobin_g_dl': _hbController.text.isNotEmpty ? double.tryParse(_hbController.text) : null,
          'illness_history': _illnessHistoryController.text.isNotEmpty ? _illnessHistoryController.text : null,
          'immunization_status': ['full', 'partial', 'none', 'unknown'][immunizationStatusCode],
          'immunization_status_code': immunizationStatusCode,
          'immunization_risk': immunizationRisk,
        }
      }),
      missedMilestones: 0,
      delayMonths: 0,
      consentGiven: true,
      consentTimestamp: DateTime.now(),
      referralTriggered: false,
      screeningDate: DateTime.now(),
      submittedAt: null,
    );

    if (!kIsWeb) {
      try {
        await _localDb.saveScreening(screening);
      } catch (e) {
        debugPrint('Local save error: $e');
      }
    }

    // Build payload for rule engine (API)
    final payload = {
      'child_id': widget.childId,
      'assessment_type': 'behavioural_psychosocial',
      'age_months': widget.ageMonths,
      'domain_responses': screening.domainResponses,
      'domain_scores': screening.domainScores,
      'autism_risk': autismCode,
      'adhd_risk': adhdCode,
      'behavior_risk': behaviorCode,
      'dev_delay_domains': devDelayCount,
      'baseline_score': baselineScore,
      'baseline_category': baselineCategory.toLowerCase(),
      'anthropometry': {
        'weight_kg': _weightController.text.isNotEmpty ? double.tryParse(_weightController.text) : null,
        'height_cm': _heightController.text.isNotEmpty ? double.tryParse(_heightController.text) : null,
        'muac_cm': _muacController.text.isNotEmpty ? double.tryParse(_muacController.text) : null,
        'birth_weight_kg': _birthWeightController.text.isNotEmpty ? double.tryParse(_birthWeightController.text) : null,
      },
      'health_indicators': {
        'hemoglobin_g_dl': _hbController.text.isNotEmpty ? double.tryParse(_hbController.text) : null,
        'illness_history': _illnessHistoryController.text.isNotEmpty ? _illnessHistoryController.text : null,
        'immunization_status': ['full', 'partial', 'none', 'unknown'][immunizationStatusCode],
        'immunization_status_code': immunizationStatusCode,
        'immunization_risk': immunizationRisk,
      }
    };

    // Try to submit to API but do not fail the UI flow on network error
    try {
      await _api.submitScreening(payload);
      final updated = screening.copyWith(submittedAt: DateTime.now());
      if (!kIsWeb) {
        try {
          await _localDb.saveScreening(updated);
        } catch (e) {
          debugPrint('Local update error: $e');
        }
      }
    } catch (_) {
      // ignore network errors — screening stays in local DB for sync
    }

    setState(() => _submitting = false);
    if (!mounted) return;

    final aCode = autismCode;
    final adCode = adhdCode;
    final bCode = behaviorCode;
    final summaryDomainScores = {
      ...widget.prevDomainScores,
      'BPS_AUT': autismNorm,
      'BPS_ADHD': adhdNorm,
      'BPS_BEH': behNorm,
    };
    final summaryDomainRiskLevels = {
      ...?widget.domainRiskLevels,
      'BPS_AUT': _riskLabelFromCode(aCode),
      'BPS_ADHD': _riskLabelFromCode(adCode),
      'BPS_BEH': _riskLabelFromCode(bCode),
    };

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BehavioralPsychosocialSummaryScreen(
          childId: widget.childId,
          awwId: widget.awwId,
          ageMonths: widget.ageMonths,
          genderLabel: AppLocalizations.of(context).t((_child?.gender ?? 'M') == 'F' ? 'gender_female' : 'gender_male'),
          awcCode: _child?.awcCode ?? '',
          overallRisk: worstCode == 2 ? 'high' : (worstCode == 1 ? 'medium' : 'low'),
          autismRisk: _riskLabelFromCode(aCode),
          adhdRisk: _riskLabelFromCode(adCode),
          behaviorRisk: _riskLabelFromCode(bCode),
          baselineScore: baselineScore,
          baselineCategory: baselineCategory,
          immunizationStatus: _immunizationStatus ?? 'unknown',
          weightKg: weightKg,
          heightCm: heightCm,
          muacCm: muac,
          birthWeightKg: birthWeightKg,
          hemoglobin: hb,
          illnessHistory: illnessHistory,
          domainScores: summaryDomainScores,
          domainRiskLevels: summaryDomainRiskLevels,
          missedMilestones: widget.missedMilestones,
          explainability: widget.explainability,
          delaySummary: widget.delaySummary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stepText = l10n.t('step_label', {'step': '2', 'of': '5'});

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('behavioural_psychosocial_screen_title')),
        backgroundColor: const Color(0xFF0D5BA7),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFF6FAFF),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('behavioural_psychosocial_subtext'), style: const TextStyle(color: Color(0xFF37474F))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_child?.childName ?? widget.childId, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('${l10n.t('age_with_months', {'age': '${widget.ageMonths}'})} • ${l10n.t((_child?.gender ?? 'M') == 'F' ? 'gender_female' : 'gender_male')}', style: const TextStyle(color: Color(0xFF6B7C8D))),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_child?.awcCode ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(stepText, style: const TextStyle(color: Color(0xFF6B7C8D))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: 0.35, minHeight: 6, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation(Color(0xFF0D5BA7))),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Section A - Autism (12-48 months)
                if (widget.ageMonths >= 12 && widget.ageMonths <= 48) ...[
                  _sectionHeader(l10n.t('autism_section_title'), Icons.visibility),
                  const SizedBox(height: 6),
                  ...List.generate(_autismPositive.length, (i) {
                    return TriStateQuestionCard(
                      question: _autismPositive[i],
                      icon: Icons.visibility,
                      labels: _yesSometimesNo,
                      value: _autismAnswers[i],
                      onChanged: (v) => setState(() => _autismAnswers[i] = v),
                    );
                  }),
                  const SizedBox(height: 6),
                  ...List.generate(_autismRedFlags.length, (i) {
                    final idx = _autismPositive.length + i;
                    return TriStateQuestionCard(
                      question: _autismRedFlags[i],
                      icon: Icons.report,
                      labels: _yesSometimesNo,
                      value: _autismAnswers[idx],
                      onChanged: (v) => setState(() => _autismAnswers[idx] = v),
                    );
                  }),
                ],

                const SizedBox(height: 12),

                // Section B - ADHD (>=24 months)
                if (widget.ageMonths >= 24) ...[
                  _sectionHeader(l10n.t('adhd_section_title'), Icons.bolt),
                  const SizedBox(height: 6),
                  ...List.generate(_adhdQuestions.length, (i) {
                    return TriStateQuestionCard(
                      question: _adhdQuestions[i],
                      icon: Icons.bolt,
                      labels: _neverSometimesOften,
                      value: _adhdAnswers[i],
                      onChanged: (v) => setState(() => _adhdAnswers[i] = v),
                    );
                  }),
                ],

                const SizedBox(height: 12),

                // Section C - Behavioural & Emotional (all ages)
                _sectionHeader(l10n.t('behaviour_section_title'), Icons.people),
                const SizedBox(height: 6),
                ...List.generate(_behaviorQuestions.length, (i) {
                  return TriStateQuestionCard(
                    question: _behaviorQuestions[i],
                    icon: Icons.people,
                    labels: _noSometimesYes,
                    value: _behaviorAnswers[i],
                    onChanged: (v) => setState(() => _behaviorAnswers[i] = v),
                  );
                }),

                const SizedBox(height: 12),

                // Anthropometry & Health Indicators Section
                _sectionHeader(l10n.t('anthropometry_section_title'), Icons.health_and_safety),
                const SizedBox(height: 10),
                
                // Weight (kg)
                TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${l10n.t('weight_label')} (kg)',
                    hintText: '0.5–60 kg',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                
                // Height/Length (cm)
                TextField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${l10n.t('height_label')} (cm)',
                    hintText: '30–200 cm',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                
                // MUAC (cm)
                TextField(
                  controller: _muacController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${l10n.t('muac_label')} (cm)',
                    hintText: '5–30 cm',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                
                // Birth Weight (kg)
                TextField(
                  controller: _birthWeightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${l10n.t('birth_weight_label')} (kg)',
                    hintText: '0.5–6 kg',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                
                // Hemoglobin Level (g/dL)
                TextField(
                  controller: _hbController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${l10n.t('hemoglobin_label')} (g/dL)',
                    hintText: '3–25 g/dL',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                
                // Illness History (optional textarea)
                TextField(
                  controller: _illnessHistoryController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.t('illness_history_label'),
                    hintText: 'e.g., recent fever, diarrhea, respiratory infection...',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                
                Text(l10n.t('immunization_label'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _immunizationStatus,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: 'full', child: Text(l10n.t('immunization_full'))),
                    DropdownMenuItem(value: 'partial', child: Text(l10n.t('immunization_partial'))),
                    DropdownMenuItem(value: 'none', child: Text(l10n.t('immunization_none'))),
                  ],
                  onChanged: (v) => setState(() => _immunizationStatus = v),
                ),

                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2F95EA), padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(_submitting ? l10n.t('submitting') : l10n.t('submit_assessment')),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2A6EBB)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ],
    );
  }
}

