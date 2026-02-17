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

class _BehavioralPsychosocialScreenState extends State<BehavioralPsychosocialScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _muacController = TextEditingController();
  final TextEditingController _birthWeightController = TextEditingController();
  final TextEditingController _hemoglobinController = TextEditingController();
  final TextEditingController _illnessHistoryController = TextEditingController();

  String _recentIllness = 'No';
  String? _immunizationStatus;
  bool _submitting = false;
  ChildModel? _child;

  late final NeuroQuestionSet _set;

  @override
  void initState() {
    super.initState();
    _set = NeuroBehavioralQuestionBank.forAgeMonths(widget.ageMonths);
    _loadChild();
  }

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

  Future<void> _loadChild() async {
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
    _birthWeightController.dispose();
    _hemoglobinController.dispose();
    super.dispose();
  }

  _HealthRange _healthRangeForAge(int ageMonths) {
    if (ageMonths <= 3) return const _HealthRange(minWeight: 0, maxWeight: 0, minHeight: 0, maxHeight: 0, minMuac: 0, maxMuac: 0, minHb: 0, maxHb: 0, minBirthWeight: 0);
    // ... your existing ranges, unchanged
    return const _HealthRange(minWeight: 18.0, maxWeight: 23.0, minHeight: 112, maxHeight: 120, minMuac: 17.5, maxMuac: 18.5, minHb: 11.5, maxHb: 14.0, minBirthWeight: 2.5);
  }

  String _riskLabelFromCode(int code) {
    switch (code) {
      case 2: return 'High';
      case 1: return 'Medium';
      default: return 'Low';
    }
  }

  _RiskCalc _computeRisk(List<NeuroQuestion> questions, Map<int, int> answers) {
    var weightedScore = 0.0;
    var maxScore = 0.0;

    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final answer = answers[i] ?? 0;
      weightedScore += answer * q.weight;
      maxScore += q.weight;
    }

    final t1 = 0.33 * maxScore;
    final t2 = 0.66 * maxScore;
    final p1 = 1.0 / (1.0 + math.exp(-(weightedScore - t1)));
    final p2 = 1.0 / (1.0 + math.exp(-(weightedScore - t2)));

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
      final q = questions[i];
      final answer = answers[i] ?? 0;
      if (answer == 1) reasons.add(q.text);
    }
    return reasons;
  }

  Future<void> _saveSectionDraft(String sectionTitle, Map<int, int> answers, int expected) async {
    final l10n = AppLocalizations.of(context);
    if (answers.length != expected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.t('please_answer_all_questions')} ($sectionTitle)')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$sectionTitle ${l10n.t('saved_locally')}')),
    );
  }

  // ... rest of your submit logic and build() function unchanged

}
