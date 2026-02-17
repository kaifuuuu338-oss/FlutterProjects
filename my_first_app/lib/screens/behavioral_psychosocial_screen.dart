import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:my_first_app/core/constants/neuro_behavioral_question_bank.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/models/child_model.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'package:my_first_app/screens/behavioral_psychosocial_summary_screen.dart';
import 'package:my_first_app/services/api_service.dart';
import 'package:my_first_app/services/local_db_service.dart';
import 'package:my_first_app/widgets/question_card.dart';

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

class _RiskCalc {
  final int code; // 0=low,1=medium,2=high
  final double weightedScore;
  final double maxScore;
  final double t1;
  final double t2;
  final double p1;
  final double p2;
  final double normalizedRisk;

  const _RiskCalc({
    required this.code,
    required this.weightedScore,
    required this.maxScore,
    required this.t1,
    required this.t2,
    required this.p1,
    required this.p2,
    required this.normalizedRisk,
  });
}

class _HealthRange {
  final double minWeight;
  final double maxWeight;
  final double minHeight;
  final double maxHeight;
  final double minMuac;
  final double maxMuac;
  final double minHb;
  final double maxHb;
  final double minBirthWeight;

  const _HealthRange({
    required this.minWeight,
    required this.maxWeight,
    required this.minHeight,
    required this.maxHeight,
    required this.minMuac,
    required this.maxMuac,
    required this.minHb,
    required this.maxHb,
    required this.minBirthWeight,
  });
}

class _BehavioralPsychosocialScreenState extends State<BehavioralPsychosocialScreen> {
  final LocalDBService _localDb = LocalDBService();
  final APIService _api = APIService();

  final Map<int, int> _autismAnswers = {};
  final Map<int, int> _adhdAnswers = {};
  final Map<int, int> _behaviorAnswers = {};

  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _muacController = TextEditingController();
  final TextEditingController _birthWeightController = TextEditingController();
  final TextEditingController _hemoglobinController = TextEditingController();
  String _recentIllness = 'No';

  bool _submitting = false;
  ChildModel? _child;
  late final NeuroQuestionSet _set;

  @override
  void initState() {
    super.initState();
    _set = NeuroBehavioralQuestionBank.forAgeMonths(widget.ageMonths);
    _loadChild();
  }

  Future<void> _loadChild() async {
    try {
      await _localDb.initialize();
      final c = _localDb.getChild(widget.childId);
      if (!mounted) return;
      setState(() => _child = c);
    } catch (_) {
      if (!mounted) return;
      setState(() => _child = null);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _muacController.dispose();
    _birthWeightController.dispose();
    _hemoglobinController.dispose();
    super.dispose();
  }

  _HealthRange _healthRangeForAge(int ageMonths) {
    if (ageMonths <= 3) {
      return const _HealthRange(minWeight: 5.0, maxWeight: 6.0, minHeight: 57, maxHeight: 61, minMuac: 13.0, maxMuac: 13.8, minHb: 14, maxHb: 20, minBirthWeight: 2.5);
    }
    if (ageMonths <= 6) {
      return const _HealthRange(minWeight: 6.0, maxWeight: 7.5, minHeight: 61, maxHeight: 66, minMuac: 13.5, maxMuac: 14.5, minHb: 11, maxHb: 14, minBirthWeight: 2.5);
    }
    if (ageMonths <= 9) {
      return const _HealthRange(minWeight: 7.0, maxWeight: 8.5, minHeight: 66, maxHeight: 71, minMuac: 14.0, maxMuac: 15.0, minHb: 11, maxHb: 13, minBirthWeight: 2.5);
    }
    if (ageMonths <= 12) {
      return const _HealthRange(minWeight: 8.0, maxWeight: 9.5, minHeight: 70, maxHeight: 75, minMuac: 14.5, maxMuac: 15.5, minHb: 11, maxHb: 13, minBirthWeight: 2.5);
    }
    if (ageMonths <= 18) {
      return const _HealthRange(minWeight: 9.0, maxWeight: 11.0, minHeight: 75, maxHeight: 82, minMuac: 15.0, maxMuac: 16.0, minHb: 11, maxHb: 13, minBirthWeight: 2.5);
    }
    if (ageMonths <= 24) {
      return const _HealthRange(minWeight: 10.5, maxWeight: 12.5, minHeight: 82, maxHeight: 88, minMuac: 15.5, maxMuac: 16.5, minHb: 11, maxHb: 13, minBirthWeight: 2.5);
    }
    if (ageMonths <= 36) {
      return const _HealthRange(minWeight: 12.0, maxWeight: 14.5, minHeight: 88, maxHeight: 96, minMuac: 16.0, maxMuac: 17.0, minHb: 11, maxHb: 13, minBirthWeight: 2.5);
    }
    if (ageMonths <= 48) {
      return const _HealthRange(minWeight: 14.0, maxWeight: 17.0, minHeight: 96, maxHeight: 105, minMuac: 16.5, maxMuac: 17.5, minHb: 11, maxHb: 13.5, minBirthWeight: 2.5);
    }
    if (ageMonths <= 60) {
      return const _HealthRange(minWeight: 16.0, maxWeight: 20.0, minHeight: 105, maxHeight: 112, minMuac: 17.0, maxMuac: 18.0, minHb: 11.5, maxHb: 13.5, minBirthWeight: 2.5);
    }
    return const _HealthRange(minWeight: 18.0, maxWeight: 23.0, minHeight: 112, maxHeight: 120, minMuac: 17.5, maxMuac: 18.5, minHb: 11.5, maxHb: 14.0, minBirthWeight: 2.5);
  }

  String _riskLabelFromCode(int code) {
    switch (code) {
      case 2:
        return 'High';
      case 1:
        return 'Medium';
      default:
        return 'Low';
    }
  }

  _RiskCalc _computeRisk(List<NeuroQuestion> questions, Map<int, int> answers) {
    var weightedScore = 0.0;
    var maxScore = 0.0;

    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final answer = answers[i] ?? 0; // yes=1, no=0
      weightedScore += answer * q.weight;
      maxScore += q.weight;
    }

    final t1 = 0.33 * maxScore;
    final t2 = 0.66 * maxScore;
    final p1 = 1.0 / (1.0 + math.exp(-(weightedScore - t1)));
    final p2 = 1.0 / (1.0 + math.exp(-(weightedScore - t2)));

    // Soft-boundary classification
    final code = p1 < 0.5 ? 0 : (p2 < 0.5 ? 1 : 2);
    final normalizedRisk = maxScore == 0 ? 0.0 : weightedScore / maxScore;

    return _RiskCalc(
      code: code,
      weightedScore: weightedScore,
      maxScore: maxScore,
      t1: t1,
      t2: t2,
      p1: p1,
      p2: p2,
      normalizedRisk: normalizedRisk,
    );
  }

  List<String> _deriveReasons(List<NeuroQuestion> questions, Map<int, int> answers) {
    final reasons = <String>[];
    for (var i = 0; i < questions.length; i++) {
      if ((answers[i] ?? 0) == 1) reasons.add(questions[i].text);
    }
    return reasons;
  }

  Future<void> _saveSectionDraft(String title, Map<int, int> answers, int expected) async {
    if (answers.length != expected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please answer all questions ($title).')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title saved locally')),
    );
  }

  Future<void> _submit() async {
    if (_autismAnswers.length != _set.autism.length ||
        _adhdAnswers.length != _set.adhd.length ||
        _behaviorAnswers.length != _set.behavior.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions in all sections.')),
      );
      return;
    }

    final weight = double.tryParse(_weightController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final muac = double.tryParse(_muacController.text.trim());
    final birthWeight = _birthWeightController.text.trim().isEmpty
        ? null
        : double.tryParse(_birthWeightController.text.trim());
    final hb = double.tryParse(_hemoglobinController.text.trim());

    if (weight == null || height == null || muac == null || hb == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill health parameters (weight, height, MUAC, hemoglobin).')),
      );
      return;
    }

    setState(() => _submitting = true);

    final autismCalc = _computeRisk(_set.autism, _autismAnswers);
    final adhdCalc = _computeRisk(_set.adhd, _adhdAnswers);
    final behaviorCalc = _computeRisk(_set.behavior, _behaviorAnswers);
    final worstCode = [autismCalc.code, adhdCalc.code, behaviorCalc.code].reduce((a, b) => a > b ? a : b);

    final overallRiskEnum = worstCode == 2
        ? RiskLevel.high
        : (worstCode == 1 ? RiskLevel.medium : RiskLevel.low);

    final reasons = <String>[
      ..._deriveReasons(_set.autism, _autismAnswers),
      ..._deriveReasons(_set.adhd, _adhdAnswers),
      ..._deriveReasons(_set.behavior, _behaviorAnswers),
    ];

    final screening = ScreeningModel(
      screeningId: 'bsp_${DateTime.now().millisecondsSinceEpoch}',
      childId: widget.childId,
      awwId: widget.awwId,
      assessmentType: AssessmentType.baseline,
      ageMonths: widget.ageMonths,
      domainResponses: {
        'BPS_AUT': [for (var i = 0; i < _set.autism.length; i++) _autismAnswers[i] ?? 0],
        'BPS_ADHD': [for (var i = 0; i < _set.adhd.length; i++) _adhdAnswers[i] ?? 0],
        'BPS_BEH': [for (var i = 0; i < _set.behavior.length; i++) _behaviorAnswers[i] ?? 0],
      },
      domainScores: {
        'BPS_AUT': autismCalc.normalizedRisk,
        'BPS_ADHD': adhdCalc.normalizedRisk,
        'BPS_BEH': behaviorCalc.normalizedRisk,
      },
      overallRisk: overallRiskEnum,
      explainability: jsonEncode({
        'method': 'weighted_score_two_thresholds_sigmoid',
        'autism': {'score': autismCalc.weightedScore, 'max': autismCalc.maxScore, 't1': autismCalc.t1, 't2': autismCalc.t2, 'p1': autismCalc.p1, 'p2': autismCalc.p2, 'risk_code': autismCalc.code},
        'adhd': {'score': adhdCalc.weightedScore, 'max': adhdCalc.maxScore, 't1': adhdCalc.t1, 't2': adhdCalc.t2, 'p1': adhdCalc.p1, 'p2': adhdCalc.p2, 'risk_code': adhdCalc.code},
        'behavior': {'score': behaviorCalc.weightedScore, 'max': behaviorCalc.maxScore, 't1': behaviorCalc.t1, 't2': behaviorCalc.t2, 'p1': behaviorCalc.p1, 'p2': behaviorCalc.p2, 'risk_code': behaviorCalc.code},
        'health_parameters': {
          'weight_kg': weight,
          'height_cm': height,
          'muac_cm': muac,
          'birth_weight_kg': birthWeight,
          'hemoglobin_g_dl': hb,
          'recent_illness': _recentIllness,
        },
        'risk_triggers': reasons.take(12).toList(),
      }),
      missedMilestones: 0,
      delayMonths: 0,
      consentGiven: true,
      consentTimestamp: DateTime.now(),
      referralTriggered: false,
      screeningDate: DateTime.now(),
      submittedAt: null,
    );

    await _localDb.saveScreening(screening);

    final payload = {
      'child_id': widget.childId,
      'assessment_type': 'behavioural_psychosocial',
      'age_months': widget.ageMonths,
      'domain_responses': screening.domainResponses,
      'domain_scores': screening.domainScores,
      'autism_risk': autismCalc.code,
      'adhd_risk': adhdCalc.code,
      'behavior_risk': behaviorCalc.code,
      'overall_risk': worstCode,
      'method': 'weighted_score_two_thresholds_sigmoid',
      'thresholds': {'t1_ratio': 0.33, 't2_ratio': 0.66},
      'health_parameters': {
        'weight_kg': weight,
        'height_cm': height,
        'muac_cm': muac,
        'birth_weight_kg': birthWeight,
        'hemoglobin_g_dl': hb,
        'recent_illness': _recentIllness,
      },
    };

    try {
      await _api.submitScreening(payload);
      await _localDb.saveScreening(screening.copyWith(submittedAt: DateTime.now()));
    } catch (_) {
      // Offline path: keep unsynced locally.
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    final summaryDomainScores = {
      ...widget.prevDomainScores,
      'BPS_AUT': autismCalc.normalizedRisk,
      'BPS_ADHD': adhdCalc.normalizedRisk,
      'BPS_BEH': behaviorCalc.normalizedRisk,
    };
    final summaryDomainRiskLevels = {
      ...?widget.domainRiskLevels,
      'BPS_AUT': _riskLabelFromCode(autismCalc.code),
      'BPS_ADHD': _riskLabelFromCode(adhdCalc.code),
      'BPS_BEH': _riskLabelFromCode(behaviorCalc.code),
    };

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BehavioralPsychosocialSummaryScreen(
          childId: widget.childId,
          awwId: widget.awwId,
          ageMonths: widget.ageMonths,
          genderLabel: AppLocalizations.of(context).t((_child?.gender ?? 'M') == 'F' ? 'gender_female' : 'gender_male'),
          awcCode: _child?.awcCode ?? '',
          overallRisk: _riskLabelFromCode(worstCode),
          autismRisk: _riskLabelFromCode(autismCalc.code),
          adhdRisk: _riskLabelFromCode(adhdCalc.code),
          behaviorRisk: _riskLabelFromCode(behaviorCalc.code),
          baselineScore: autismCalc.code + adhdCalc.code + behaviorCalc.code,
          baselineCategory: _riskLabelFromCode(worstCode),
          immunizationStatus: 'unknown',
          weightKg: weight,
          heightCm: height,
          muacCm: muac,
          birthWeightKg: birthWeight,
          hemoglobin: hb,
          illnessHistory: _recentIllness == 'Yes' ? 'Recent illness: Yes' : 'No recent illness',
          domainScores: summaryDomainScores,
          domainRiskLevels: summaryDomainRiskLevels,
          missedMilestones: widget.missedMilestones,
          explainability: reasons.isEmpty ? 'No major risk triggers' : reasons.join(', '),
          delaySummary: widget.delaySummary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final range = _healthRangeForAge(widget.ageMonths);
    final totalAnswered = _autismAnswers.length + _adhdAnswers.length + _behaviorAnswers.length;
    final totalQuestions = _set.autism.length + _set.adhd.length + _set.behavior.length;

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
                const Text('Screening 2/3 - Neuro-Behavioral', style: TextStyle(color: Color(0xFF37474F), fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(_child?.childName ?? widget.childId, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  '${l10n.t('age_with_months', {'age': '${widget.ageMonths}'})}  |  AWC: ${_child?.awcCode ?? '-'}',
                  style: const TextStyle(color: Color(0xFF6B7C8D)),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: totalQuestions == 0 ? 0 : (totalAnswered / totalQuestions).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF0D5BA7)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _sectionHeader('Autism Risk', Icons.psychology_alt),
                const SizedBox(height: 6),
                ...List.generate(_set.autism.length, (i) {
                  return QuestionCard(
                    question: _set.autism[i].text,
                    value: _autismAnswers[i],
                    onChanged: (v) => setState(() => _autismAnswers[i] = v),
                  );
                }),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _saveSectionDraft('Autism', _autismAnswers, _set.autism.length),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Autism Section'),
                  ),
                ),
                const SizedBox(height: 12),
                _sectionHeader('ADHD Risk', Icons.bolt),
                const SizedBox(height: 6),
                ...List.generate(_set.adhd.length, (i) {
                  return QuestionCard(
                    question: _set.adhd[i].text,
                    value: _adhdAnswers[i],
                    onChanged: (v) => setState(() => _adhdAnswers[i] = v),
                  );
                }),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _saveSectionDraft('ADHD', _adhdAnswers, _set.adhd.length),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save ADHD Section'),
                  ),
                ),
                const SizedBox(height: 12),
                _sectionHeader('Behavior Risk', Icons.people_alt_outlined),
                const SizedBox(height: 6),
                ...List.generate(_set.behavior.length, (i) {
                  return QuestionCard(
                    question: _set.behavior[i].text,
                    value: _behaviorAnswers[i],
                    onChanged: (v) => setState(() => _behaviorAnswers[i] = v),
                  );
                }),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _saveSectionDraft('Behavior', _behaviorAnswers, _set.behavior.length),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Behavior Section'),
                  ),
                ),
                const SizedBox(height: 12),
                _sectionHeader('Health Parameters (Age-based)', Icons.health_and_safety_outlined),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FCFF),
                    border: Border.all(color: const Color(0xFFCAE6F7)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Expected for age:\n'
                    'Weight: ${range.minWeight}-${range.maxWeight} kg\n'
                    'Height: ${range.minHeight}-${range.maxHeight} cm\n'
                    'MUAC: ${range.minMuac}-${range.maxMuac} cm\n'
                    'Hemoglobin: ${range.minHb}-${range.maxHb} g/dL\n'
                    'Birth weight: >= ${range.minBirthWeight} kg\n'
                    'Recent illness: No',
                    style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _muacController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'MUAC (cm)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _birthWeightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Birth Weight (kg) - optional', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _hemoglobinController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Hemoglobin (g/dL)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _recentIllness,
                  decoration: const InputDecoration(labelText: 'Recent Illness', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'No', child: Text('No')),
                    DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _recentIllness = v);
                  },
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F95EA),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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
