import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:my_first_app/core/constants/neuro_behavioral_question_bank.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/core/navigation/navigation_state_service.dart';
import 'package:my_first_app/models/child_model.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'package:my_first_app/screens/nutrition_screen.dart';
import 'package:my_first_app/services/api_service.dart';
import 'package:my_first_app/services/local_db_service.dart';

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

class _BehavioralPsychosocialScreenState extends State<BehavioralPsychosocialScreen> {
  final LocalDBService _localDb = LocalDBService();
  final APIService _api = APIService();
  static const int _sectionCount = 3;

  final Map<int, int> _autismAnswers = {};
  final Map<int, int> _adhdAnswers = {};
  final Map<int, int> _behaviorAnswers = {};

  bool _submitting = false;
  ChildModel? _child;
  late final NeuroQuestionSet _set;
  int _sectionIndex = 0;
  int _questionIndex = 0;

  @override
  void initState() {
    super.initState();
    NavigationStateService.instance.saveState(
      screen: NavigationStateService.screenBehavioralPsychosocial,
      args: <String, dynamic>{
        'child_id': widget.childId,
        'aww_id': widget.awwId,
        'age_months': widget.ageMonths,
        'overall_risk': widget.overallRisk,
        'missed_milestones': widget.missedMilestones,
        'explainability': widget.explainability,
        'prev_domain_scores': widget.prevDomainScores,
        'domain_risk_levels': widget.domainRiskLevels ?? <String, String>{},
        'delay_summary': widget.delaySummary ?? <String, int>{},
      },
    );
    _set = NeuroBehavioralQuestionBank.forAgeMonths(widget.ageMonths);
    _sectionIndex = _firstNonEmptySectionIndex();
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
    super.dispose();
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

  String _normalizeRiskLabel(dynamic value, {String fallback = 'Low'}) {
    final raw = '$value'.trim().toLowerCase();
    if (raw == 'critical' || raw == 'very high') return 'Critical';
    if (raw == 'high') return 'High';
    if (raw == 'medium' || raw == 'moderate') return 'Medium';
    if (raw == 'low') return 'Low';
    return fallback;
  }

  RiskLevel _riskLevelFromLabel(String label) {
    switch (label.trim().toLowerCase()) {
      case 'critical':
        return RiskLevel.critical;
      case 'high':
        return RiskLevel.high;
      case 'medium':
      case 'moderate':
        return RiskLevel.medium;
      default:
        return RiskLevel.low;
    }
  }

  double _riskScoreFromLabel(String label) {
    switch (label.trim().toLowerCase()) {
      case 'critical':
        return 0.92;
      case 'high':
        return 0.75;
      case 'medium':
      case 'moderate':
        return 0.5;
      default:
        return 0.2;
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

    // Direct threshold classification:
    // S < T1 => Low, T1 <= S < T2 => Medium, S >= T2 => High
    int code;
    if (weightedScore < t1) {
      code = 0;
    } else if (weightedScore < t2) {
      code = 1;
    } else {
      code = 2;
    }
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

  int _firstNonEmptySectionIndex() {
    for (var i = 0; i < _sectionCount; i++) {
      if (_questionsForSection(i).isNotEmpty) {
        return i;
      }
    }
    return _sectionCount;
  }

  List<NeuroQuestion> _questionsForSection(int sectionIndex) {
    switch (sectionIndex) {
      case 0:
        return _set.autism;
      case 1:
        return _set.adhd;
      case 2:
      default:
        return _set.behavior;
    }
  }

  Map<int, int> _answersForSection(int sectionIndex) {
    switch (sectionIndex) {
      case 0:
        return _autismAnswers;
      case 1:
        return _adhdAnswers;
      case 2:
      default:
        return _behaviorAnswers;
    }
  }

  String _sectionTitle(int sectionIndex) {
    switch (sectionIndex) {
      case 0:
        return 'Autism Risk';
      case 1:
        return 'ADHD Risk';
      case 2:
      default:
        return 'Behavior Risk';
    }
  }

  String _sectionCode(int sectionIndex) {
    switch (sectionIndex) {
      case 0:
        return 'AUT';
      case 1:
        return 'ADHD';
      case 2:
      default:
        return 'BEH';
    }
  }

  int _answeredCountForSection(int sectionIndex) {
    final total = _questionsForSection(sectionIndex).length;
    final answers = _answersForSection(sectionIndex);
    var answered = 0;
    for (var i = 0; i < total; i++) {
      if (answers.containsKey(i)) {
        answered += 1;
      }
    }
    return answered;
  }

  int get _totalQuestions => _set.autism.length + _set.adhd.length + _set.behavior.length;

  int get _totalAnswered {
    var answered = 0;
    for (var i = 0; i < _sectionCount; i++) {
      answered += _answeredCountForSection(i);
    }
    return answered;
  }

  double get _progress {
    if (_totalQuestions == 0) return 0;
    return (_totalAnswered / _totalQuestions).clamp(0.0, 1.0);
  }

  bool get _isQuestionFlowComplete => _sectionIndex >= _sectionCount;

  void _moveToNextQuestion() {
    if (_isQuestionFlowComplete) return;
    final currentQuestions = _questionsForSection(_sectionIndex);
    if (_questionIndex + 1 < currentQuestions.length) {
      _questionIndex += 1;
      return;
    }
    var nextSection = _sectionIndex + 1;
    while (nextSection < _sectionCount) {
      if (_questionsForSection(nextSection).isNotEmpty) {
        break;
      }
      nextSection += 1;
    }
    _sectionIndex = nextSection;
    _questionIndex = 0;
  }

  void _moveToPreviousQuestion() {
    if (_sectionIndex == 0 && _questionIndex == 0) return;
    if (_isQuestionFlowComplete) {
      var lastSection = _sectionCount - 1;
      while (lastSection >= 0 && _questionsForSection(lastSection).isEmpty) {
        lastSection -= 1;
      }
      if (lastSection < 0) return;
      _sectionIndex = lastSection;
      _questionIndex = _questionsForSection(lastSection).length - 1;
      return;
    }
    if (_questionIndex > 0) {
      _questionIndex -= 1;
      return;
    }
    var prevSection = _sectionIndex - 1;
    while (prevSection >= 0) {
      if (_questionsForSection(prevSection).isNotEmpty) {
        break;
      }
      prevSection -= 1;
    }
    if (prevSection < 0) return;
    _sectionIndex = prevSection;
    _questionIndex = _questionsForSection(prevSection).length - 1;
  }

  void _answerCurrentQuestion(bool yes) {
    if (_isQuestionFlowComplete || _submitting) return;
    final answers = _answersForSection(_sectionIndex);
    answers[_questionIndex] = yes ? 1 : 0;
    setState(() {
      _moveToNextQuestion();
    });
  }

  void _retakeAssessment() {
    setState(() {
      _autismAnswers.clear();
      _adhdAnswers.clear();
      _behaviorAnswers.clear();
      _sectionIndex = _firstNonEmptySectionIndex();
      _questionIndex = 0;
      _submitting = false;
    });
  }

  Future<void> _showCompletedBackOptions() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Development Assessment Completed'),
          content: const Text(
            'Choose an action: retake this assessment or move to the next assessment.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _retakeAssessment();
              },
              child: const Text('Retake Assessment'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _submit();
              },
              child: const Text('Move to Next Assessment'),
            ),
          ],
        );
      },
    );
  }

  Color _riskColor(String risk) {
    switch (risk.trim().toLowerCase()) {
      case 'critical':
      case 'high':
        return const Color(0xFFC62828);
      case 'medium':
      case 'moderate':
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  Future<void> _showNeuroRiskTable({
    required String autismRisk,
    required String adhdRisk,
    required String behavioralRisk,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final rows = <Map<String, String>>[
          {'domain': 'AUTISM', 'risk': autismRisk},
          {'domain': 'ADHD', 'risk': adhdRisk},
          {'domain': 'BEHAVIORAL', 'risk': behavioralRisk},
        ];
        return AlertDialog(
          title: const Text('Neuro Behavioral Risk Table'),
          content: SizedBox(
            width: 420,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Domain')),
                DataColumn(label: Text('Risk')),
              ],
              rows: rows
                  .map(
                    (row) => DataRow(
                      cells: [
                        DataCell(Text(row['domain'] ?? '-')),
                        DataCell(
                          Text(
                            _normalizeRiskLabel(row['risk'], fallback: 'Low').toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _riskColor(row['risk'] ?? 'Low'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continue'),
            ),
          ],
        );
      },
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

    setState(() => _submitting = true);

    final autismCalc = _computeRisk(_set.autism, _autismAnswers);
    final adhdCalc = _computeRisk(_set.adhd, _adhdAnswers);
    final behaviorCalc = _computeRisk(_set.behavior, _behaviorAnswers);
    final worstCode = [autismCalc.code, adhdCalc.code, behaviorCalc.code]
        .reduce((a, b) => a > b ? a : b);

    final reasons = <String>[
      ..._deriveReasons(_set.autism, _autismAnswers),
      ..._deriveReasons(_set.adhd, _adhdAnswers),
      ..._deriveReasons(_set.behavior, _behaviorAnswers),
    ];

    final domainResponses = {
      'BPS_AUT': [for (var i = 0; i < _set.autism.length; i++) _autismAnswers[i] ?? 0],
      'BPS_ADHD': [for (var i = 0; i < _set.adhd.length; i++) _adhdAnswers[i] ?? 0],
      'BPS_BEH': [for (var i = 0; i < _set.behavior.length; i++) _behaviorAnswers[i] ?? 0],
    };

    var autismRiskLabel = _riskLabelFromCode(autismCalc.code);
    var adhdRiskLabel = _riskLabelFromCode(adhdCalc.code);
    var behaviorRiskLabel = _riskLabelFromCode(behaviorCalc.code);
    var overallRiskLabel = _riskLabelFromCode(worstCode);
    var explainabilityText = reasons.isEmpty ? 'No major risk triggers' : reasons.join(', ');

    DateTime? submittedAt;
    final payload = {
      'child_id': widget.childId,
      'awc_id': _child?.awcCode ?? '',
      'assessment_type': 'behavioural_psychosocial',
      'age_months': widget.ageMonths,
      'domain_responses': domainResponses,
      'domain_scores': {
        'BPS_AUT': autismCalc.normalizedRisk,
        'BPS_ADHD': adhdCalc.normalizedRisk,
        'BPS_BEH': behaviorCalc.normalizedRisk,
      },
      'autism_risk': autismRiskLabel,
      'adhd_risk': adhdRiskLabel,
      'behavior_risk': behaviorRiskLabel,
      'overall_risk': overallRiskLabel,
      'method': 'weighted_score_two_thresholds_sigmoid',
      'thresholds': {'t1_ratio': 0.33, 't2_ratio': 0.66},
    };

    try {
      final response = await _api.submitScreening(payload);
      submittedAt = DateTime.now();

      final responseDomainScores = response['domain_scores'];
      if (responseDomainScores is Map) {
        autismRiskLabel = _normalizeRiskLabel(
          responseDomainScores['BPS_AUT'],
          fallback: autismRiskLabel,
        );
        adhdRiskLabel = _normalizeRiskLabel(
          responseDomainScores['BPS_ADHD'],
          fallback: adhdRiskLabel,
        );
        behaviorRiskLabel = _normalizeRiskLabel(
          responseDomainScores['BPS_BEH'],
          fallback: behaviorRiskLabel,
        );
      }
      overallRiskLabel = _normalizeRiskLabel(
        response['risk_level'],
        fallback: overallRiskLabel,
      );

      final explanationList = response['explanation'];
      if (explanationList is List && explanationList.isNotEmpty) {
        final backendExplainability = explanationList
            .map((e) => '$e')
            .where((e) => e.trim().isNotEmpty)
            .join(', ');
        if (backendExplainability.trim().isNotEmpty) {
          explainabilityText = backendExplainability;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to submit neuro-behavioral assessment to server. '
              'Please check backend/database connection and try again.\n$e',
            ),
          ),
        );
        setState(() => _submitting = false);
      }
      return;
    }

    final screening = ScreeningModel(
      screeningId: 'bsp_${DateTime.now().millisecondsSinceEpoch}',
      childId: widget.childId,
      awwId: widget.awwId,
      assessmentType: AssessmentType.baseline,
      ageMonths: widget.ageMonths,
      domainResponses: domainResponses,
      domainScores: {
        'BPS_AUT': _riskScoreFromLabel(autismRiskLabel),
        'BPS_ADHD': _riskScoreFromLabel(adhdRiskLabel),
        'BPS_BEH': _riskScoreFromLabel(behaviorRiskLabel),
      },
      overallRisk: _riskLevelFromLabel(overallRiskLabel),
      explainability: jsonEncode({
        'method': 'weighted_score_two_thresholds_sigmoid',
        'autism': {
          'score': autismCalc.weightedScore,
          'max': autismCalc.maxScore,
          't1': autismCalc.t1,
          't2': autismCalc.t2,
          'p1': autismCalc.p1,
          'p2': autismCalc.p2,
          'risk_code': autismCalc.code,
        },
        'adhd': {
          'score': adhdCalc.weightedScore,
          'max': adhdCalc.maxScore,
          't1': adhdCalc.t1,
          't2': adhdCalc.t2,
          'p1': adhdCalc.p1,
          'p2': adhdCalc.p2,
          'risk_code': adhdCalc.code,
        },
        'behavior': {
          'score': behaviorCalc.weightedScore,
          'max': behaviorCalc.maxScore,
          't1': behaviorCalc.t1,
          't2': behaviorCalc.t2,
          'p1': behaviorCalc.p1,
          'p2': behaviorCalc.p2,
          'risk_code': behaviorCalc.code,
        },
        'backend_model': {
          'autism_risk': autismRiskLabel,
          'adhd_risk': adhdRiskLabel,
          'behavior_risk': behaviorRiskLabel,
          'overall_risk': overallRiskLabel,
          'explanation': explainabilityText,
        },
        'risk_triggers': reasons.take(12).toList(),
      }),
      missedMilestones: 0,
      delayMonths: 0,
      consentGiven: true,
      consentTimestamp: DateTime.now(),
      referralTriggered: false,
      screeningDate: DateTime.now(),
      submittedAt: submittedAt,
    );

    await _localDb.saveScreening(screening);

    if (!mounted) return;
    setState(() => _submitting = false);

    final summaryDomainScores = {
      ...widget.prevDomainScores,
      'BPS_AUT': _riskScoreFromLabel(autismRiskLabel),
      'BPS_ADHD': _riskScoreFromLabel(adhdRiskLabel),
      'BPS_BEH': _riskScoreFromLabel(behaviorRiskLabel),
    };
    final summaryDomainRiskLevels = {
      ...?widget.domainRiskLevels,
      'BPS_AUT': autismRiskLabel,
      'BPS_ADHD': adhdRiskLabel,
      'BPS_BEH': behaviorRiskLabel,
    };

    await _showNeuroRiskTable(
      autismRisk: autismRiskLabel,
      adhdRisk: adhdRiskLabel,
      behavioralRisk: behaviorRiskLabel,
    );
    if (!mounted) return;
    final awcCodeForFlow = widget.awwId.trim().isNotEmpty
        ? widget.awwId.trim()
        : (_child?.awcCode ?? '').trim();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NutritionScreen(
          childId: widget.childId,
          awwId: awcCodeForFlow,
          ageMonths: widget.ageMonths,
          genderLabel: AppLocalizations.of(context).t((_child?.gender ?? 'M') == 'F' ? 'gender_female' : 'gender_male'),
          genderCode: (_child?.gender ?? 'M'),
          awcCode: awcCodeForFlow,
          overallRisk: overallRiskLabel,
          autismRisk: autismRiskLabel,
          adhdRisk: adhdRiskLabel,
          behaviorRisk: behaviorRiskLabel,
          domainScores: summaryDomainScores,
          domainRiskLevels: summaryDomainRiskLevels,
          missedMilestones: widget.missedMilestones,
          explainability: explainabilityText,
          delaySummary: widget.delaySummary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: !_isQuestionFlowComplete && !_submitting,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _submitting) return;
        if (_isQuestionFlowComplete) {
          await _showCompletedBackOptions();
          return;
        }
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(result);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('behavioural_psychosocial_screen_title')),
          backgroundColor: const Color(0xFF0D5BA7),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF46C39D), Color(0xFF2CA38C)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assessment for Neuro-Behavioral',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _child?.childName ?? widget.childId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.t('age_with_months', {'age': '${widget.ageMonths}'})}  |  AWC: ${_child?.awcCode ?? '-'}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _progress,
                    minHeight: 6,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Answered: $_totalAnswered / $_totalQuestions | Age: ${widget.ageMonths} months',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(
                      _sectionCount,
                      _buildSectionPill,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _isQuestionFlowComplete
                    ? SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildCompleteCard(),
                          ],
                        ),
                      )
                    : _buildQuestionFlowCard(l10n),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (!_isQuestionFlowComplete || _submitting) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F95EA),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(_submitting ? l10n.t('submitting') : l10n.t('submit_assessment')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionPill(int sectionIndex) {
    final total = _questionsForSection(sectionIndex).length;
    final answered = _answeredCountForSection(sectionIndex);
    final done = total > 0 && answered >= total;
    final active = !_isQuestionFlowComplete && sectionIndex == _sectionIndex;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF1565C0)
            : (done ? const Color(0xFF2E7D32) : const Color(0xFFCFD8DC)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '${_sectionCode(sectionIndex)} $answered/$total',
        style: TextStyle(
          color: active || done ? Colors.white : const Color(0xFF37474F),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildQuestionFlowCard(AppLocalizations l10n) {
    final questions = _questionsForSection(_sectionIndex);
    final questionText = questions[_questionIndex].text;
    final sectionTitle = _sectionTitle(_sectionIndex);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E1EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sectionTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D5BA7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Question ${_questionIndex + 1} of ${questions.length}',
            style: const TextStyle(
              color: Color(0xFF546E7A),
              fontWeight: FontWeight.w600,
            ),
          ),
          const Divider(height: 24),
          Text(
            questionText,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1F2A37),
            ),
          ),
          const Spacer(),
          if (!(_sectionIndex == 0 && _questionIndex == 0)) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(_moveToPreviousQuestion),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous Question'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : () => _answerCurrentQuestion(true),
                  child: Text(l10n.t('yes')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : () => _answerCurrentQuestion(false),
                  child: Text(l10n.t('no')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteCard() {
    final concernDomains = <String>[];
    if (_autismAnswers.values.any((v) => v == 1)) concernDomains.add('Autism Risk');
    if (_adhdAnswers.values.any((v) => v == 1)) concernDomains.add('ADHD Risk');
    if (_behaviorAnswers.values.any((v) => v == 1)) concernDomains.add('Behavior Risk');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assessment complete',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Answered $_totalAnswered of $_totalQuestions questions.'),
          const SizedBox(height: 8),
          Text(
            concernDomains.isEmpty
                ? 'Potential concern domains: None flagged'
                : 'Potential concern domains: ${concernDomains.join(', ')}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('Tap Submit Assessment to continue to Nutrition Screening.'),
        ],
      ),
    );
  }

}
