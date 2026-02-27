import 'package:flutter/material.dart';
import 'package:my_first_app/core/constants/app_constants.dart';
import 'package:my_first_app/core/constants/question_bank.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/core/utils/delay_summary.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'package:my_first_app/screens/behavioral_psychosocial_screen.dart';
import 'package:my_first_app/services/local_db_service.dart';

class ScreeningScreen extends StatefulWidget {
  final String childId;
  final int ageMonths;
  final String awwId;
  final bool consentGiven;
  final DateTime consentTimestamp;
  final List<String> birthHistory;
  final List<String> healthHistory;

  const ScreeningScreen({
    super.key,
    required this.childId,
    required this.ageMonths,
    required this.awwId,
    required this.consentGiven,
    required this.consentTimestamp,
    this.birthHistory = const [],
    this.healthHistory = const [],
  });

  @override
  State<ScreeningScreen> createState() => _ScreeningScreenState();
}

class _ScreeningScreenState extends State<ScreeningScreen> {
  final LocalDBService _localDb = LocalDBService();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  int _ageMonths = 0;

  Map<String, List<String>> _questionsByDomain = <String, List<String>>{};
  final Map<String, List<int>> _responses = <String, List<int>>{};

  int _domainIndex = 0;
  int _questionIndex = 0;

  @override
  void initState() {
    super.initState();
    _ageMonths = widget.ageMonths < 0 ? 0 : widget.ageMonths;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _localDb.initialize();
    if (!mounted) return;

    final bank = QuestionBank.byAgeMonths(_ageMonths, languageCode: 'en');
    final seededResponses = <String, List<int>>{
      for (final domain in AppConstants.domains) domain: <int>[],
    };

    var firstDomain = 0;
    while (firstDomain < AppConstants.domains.length) {
      final domain = AppConstants.domains[firstDomain];
      final q = bank[domain] ?? const <String>[];
      if (q.isNotEmpty) break;
      firstDomain += 1;
    }

    setState(() {
      _questionsByDomain = bank;
      _responses
        ..clear()
        ..addAll(seededResponses);
      _domainIndex = firstDomain;
      _questionIndex = 0;
      _loading = false;
      _error = null;
    });
  }

  bool get _isComplete => _domainIndex >= AppConstants.domains.length;

  String get _currentDomain {
    if (_isComplete) return AppConstants.domains.last;
    return AppConstants.domains[_domainIndex];
  }

  List<String> get _currentQuestions {
    return _questionsByDomain[_currentDomain] ?? const <String>[];
  }

  int get _totalQuestions {
    var total = 0;
    for (final domain in AppConstants.domains) {
      total += (_questionsByDomain[domain] ?? const <String>[]).length;
    }
    return total;
  }

  int get _answeredQuestions {
    var answered = 0;
    for (final values in _responses.values) {
      answered += values.length;
    }
    if (answered > _totalQuestions) return _totalQuestions;
    return answered;
  }

  double get _progress {
    if (_totalQuestions <= 0) return 0.0;
    return (_answeredQuestions / _totalQuestions).clamp(0.0, 1.0);
  }

  void _answerCurrentQuestion(bool yes) {
    if (_isComplete || _submitting) return;

    final domain = _currentDomain;
    final answers = List<int>.from(_responses[domain] ?? const <int>[]);
    final binary = yes ? 1 : 0;

    if (_questionIndex < answers.length) {
      answers[_questionIndex] = binary;
    } else {
      answers.add(binary);
    }
    _responses[domain] = answers;

    _moveToNextQuestion();

    setState(() {
      _error = null;
    });
  }

  void _moveToNextQuestion() {
    final domainQuestions = _currentQuestions;
    if (_questionIndex + 1 < domainQuestions.length) {
      _questionIndex += 1;
      return;
    }

    var nextDomain = _domainIndex + 1;
    while (nextDomain < AppConstants.domains.length) {
      final domain = AppConstants.domains[nextDomain];
      final q = _questionsByDomain[domain] ?? const <String>[];
      if (q.isNotEmpty) break;
      nextDomain += 1;
    }

    _domainIndex = nextDomain;
    _questionIndex = 0;
  }

  Map<String, List<int>> _normalizedResponses() {
    final normalized = <String, List<int>>{};
    for (final domain in AppConstants.domains) {
      final questions = _questionsByDomain[domain] ?? const <String>[];
      final values = List<int>.from(_responses[domain] ?? const <int>[]);

      if (values.length > questions.length) {
        values.removeRange(questions.length, values.length);
      }
      while (values.length < questions.length) {
        values.add(0);
      }
      normalized[domain] = values;
    }
    return normalized;
  }

  Future<void> _submitAssessment() async {
    if (!_isComplete || _submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final responses = _normalizedResponses();
      final delaySummary =
          buildDelaySummaryFromResponses(responses, ageMonths: _ageMonths) ??
          <String, int>{
            'GM_delay': 0,
            'FM_delay': 0,
            'LC_delay': 0,
            'COG_delay': 0,
            'SE_delay': 0,
            'num_delays': 0,
          };

      final results = <String, int>{
        for (final domain in AppConstants.domains)
          domain: delaySummary['${domain}_delay'] ?? 0,
      };
      final delayed = delaySummary['num_delays'] ?? 0;

      final risk = delayed <= 0
          ? RiskLevel.low
          : (delayed == 1
                ? RiskLevel.medium
                : (delayed <= 3 ? RiskLevel.high : RiskLevel.critical));

      final explainability =
          'Fixed milestone questionnaire completed using standard domain yes/no questions.';

      final scores = <String, double>{
        for (final d in AppConstants.domains) d: results[d] == 1 ? 0.35 : 0.9,
      };

      final screening = ScreeningModel(
        screeningId: 'scr_${DateTime.now().millisecondsSinceEpoch}',
        childId: widget.childId,
        awwId: widget.awwId,
        assessmentType: AssessmentType.baseline,
        ageMonths: _ageMonths,
        domainResponses: responses,
        domainScores: scores,
        overallRisk: risk,
        explainability: explainability,
        missedMilestones: delayed,
        delayMonths: 0,
        consentGiven: widget.consentGiven,
        consentTimestamp: widget.consentTimestamp,
        referralTriggered: false,
        screeningDate: DateTime.now(),
        submittedAt: DateTime.now(),
      );

      await _localDb.saveScreening(screening);
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BehavioralPsychosocialScreen(
            prevDomainScores: scores,
            domainRiskLevels: {
              for (final d in AppConstants.domains)
                d: results[d] == 1 ? 'High' : 'Low',
            },
            overallRisk: risk.toString().split('.').last,
            missedMilestones: delayed,
            explainability: explainability,
            childId: widget.childId,
            awwId: widget.awwId,
            ageMonths: _ageMonths,
            delaySummary: {
              'GM_delay': results['GM'] ?? 0,
              'FM_delay': results['FM'] ?? 0,
              'LC_delay': results['LC'] ?? 0,
              'COG_delay': results['COG'] ?? 0,
              'SE_delay': results['SE'] ?? 0,
              'num_delays': delayed,
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Submit failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Widget _buildDomainPill(String domain) {
    final total = (_questionsByDomain[domain] ?? const <String>[]).length;
    var answered = _responses[domain]?.length ?? 0;
    if (answered > total) answered = total;
    final done = total > 0 && answered >= total;
    final active = !_isComplete && domain == _currentDomain;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF1565C0)
            : (done ? const Color(0xFF2E7D32) : const Color(0xFFCFD8DC)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$domain $answered/$total',
        style: TextStyle(
          color: active || done ? Colors.white : const Color(0xFF37474F),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildQuestionCard(AppLocalizations l10n) {
    final domain = _currentDomain;
    final questions = _currentQuestions;
    final questionText = questions[_questionIndex];
    final domainLabel = AppConstants.domainNames[domain] ?? domain;

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
            domainLabel,
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
    final delayedDomains = <String>[
      for (final domain in AppConstants.domains)
        if ((_responses[domain] ?? const <int>[]).isNotEmpty)
          if ((_responses[domain] ?? const <int>[]).contains(0))
            AppConstants.domainNames[domain] ?? domain,
    ];

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
          Text('Answered $_answeredQuestions of $_totalQuestions questions.'),
          if (delayedDomains.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Potential concern domains: ${delayedDomains.join(', ')}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 8),
          const Text('Tap Submit Assessment to continue.'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('screening_assessment'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                      Text(
                        'Assessment for ${widget.childId}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _progress, minHeight: 6),
                      const SizedBox(height: 6),
                      Text(
                        'Answered: $_answeredQuestions / $_totalQuestions  | Age: $_ageMonths months',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppConstants.domains
                            .map(_buildDomainPill)
                            .toList(),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _isComplete
                        ? _buildCompleteCard()
                        : _buildQuestionCard(l10n),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (!_isComplete || _submitting)
                          ? null
                          : _submitAssessment,
                      child: Text(
                        _submitting
                            ? l10n.t('submitting')
                            : l10n.t('submit_assessment'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
