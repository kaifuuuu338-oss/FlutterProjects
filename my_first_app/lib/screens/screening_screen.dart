import 'package:flutter/material.dart';
import 'package:my_first_app/core/constants/app_constants.dart';
import 'package:my_first_app/core/constants/question_bank.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/core/navigation/navigation_state_service.dart';
import 'package:my_first_app/core/utils/delay_summary.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'package:my_first_app/screens/behavioral_psychosocial_screen.dart';
import 'package:my_first_app/services/api_service.dart';
import 'package:my_first_app/services/auth_service.dart';
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
  static final RegExp _awcDemoPattern = RegExp(r'^(AWW|AWS)_DEMO_(\d{3,4})$');
  static final RegExp _awcDemoReversedPattern = RegExp(
    r'^DEMO_(AWW|AWS)_(\d{3,4})$',
  );
  final LocalDBService _localDb = LocalDBService();
  final APIService _api = APIService();
  final AuthService _auth = AuthService();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  int _ageMonths = 0;

  Map<String, List<String>> _questionsByDomain = <String, List<String>>{};
  final Map<String, List<int>> _responses = <String, List<int>>{};

  int _domainIndex = 0;
  int _questionIndex = 0;

  int _firstNonEmptyDomainIndex() {
    var firstDomain = 0;
    while (firstDomain < AppConstants.domains.length) {
      final domain = AppConstants.domains[firstDomain];
      final q = _questionsByDomain[domain] ?? const <String>[];
      if (q.isNotEmpty) break;
      firstDomain += 1;
    }
    return firstDomain;
  }

  void _retakeAssessment() {
    setState(() {
      for (final domain in AppConstants.domains) {
        _responses[domain] = <int>[];
      }
      _domainIndex = _firstNonEmptyDomainIndex();
      _questionIndex = 0;
      _error = null;
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
                await _submitAssessment();
              },
              child: const Text('Move to Next Assessment'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    NavigationStateService.instance.saveState(
      screen: NavigationStateService.screenScreening,
      args: <String, dynamic>{
        'child_id': widget.childId,
        'age_months': widget.ageMonths,
        'aww_id': widget.awwId,
        'consent_given': widget.consentGiven,
        'consent_timestamp': widget.consentTimestamp.toIso8601String(),
        'birth_history': widget.birthHistory,
        'health_history': widget.healthHistory,
      },
    );
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

  void _moveToPreviousQuestion() {
    final firstDomain = _firstNonEmptyDomainIndex();
    if (_domainIndex <= firstDomain && _questionIndex == 0) {
      return;
    }
    if (_questionIndex > 0) {
      _questionIndex -= 1;
      return;
    }

    var prevDomain = _domainIndex - 1;
    while (prevDomain >= firstDomain) {
      final q = _questionsByDomain[AppConstants.domains[prevDomain]] ?? const <String>[];
      if (q.isNotEmpty) break;
      prevDomain -= 1;
    }
    if (prevDomain < firstDomain) return;

    _domainIndex = prevDomain;
    final prevQuestions = _questionsByDomain[AppConstants.domains[prevDomain]] ?? const <String>[];
    _questionIndex = prevQuestions.isEmpty ? 0 : prevQuestions.length - 1;
  }

  bool get _canGoPrevious {
    final firstDomain = _firstNonEmptyDomainIndex();
    return !(_domainIndex <= firstDomain && _questionIndex == 0);
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

  String _normalizeAwcCode(String value) {
    final raw = value.trim().toUpperCase();
    final direct = _awcDemoPattern.firstMatch(raw);
    if (direct != null) {
      return 'AWW_DEMO_${direct.group(2)}';
    }
    final reversed = _awcDemoReversedPattern.firstMatch(raw);
    if (reversed != null) {
      return 'AWW_DEMO_${reversed.group(2)}';
    }
    return raw;
  }

  bool _isCanonicalAwc(String value) => _awcDemoPattern.hasMatch(value);

  String _normalizeRiskLabel(dynamic value) {
    final raw = (value ?? '').toString().trim().toLowerCase();
    switch (raw) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'medium':
      case 'moderate':
        return 'Medium';
      default:
        return 'Low';
    }
  }

  RiskLevel _riskFromDelayCount(int delayed) {
    if (delayed <= 0) return RiskLevel.low;
    if (delayed == 1) return RiskLevel.medium;
    if (delayed <= 3) return RiskLevel.high;
    return RiskLevel.critical;
  }

  RiskLevel _riskLevelFromString(dynamic value) {
    switch (_normalizeRiskLabel(value).toLowerCase()) {
      case 'critical':
        return RiskLevel.critical;
      case 'high':
        return RiskLevel.high;
      case 'medium':
        return RiskLevel.medium;
      default:
        return RiskLevel.low;
    }
  }

  double _riskLabelToScore(String label) {
    switch (_normalizeRiskLabel(label).toLowerCase()) {
      case 'critical':
        return 0.20;
      case 'high':
        return 0.40;
      case 'medium':
        return 0.65;
      default:
        return 0.90;
    }
  }

  Map<String, int> _sanitizeDelaySummary(dynamic rawSummary) {
    final summary = <String, int>{};
    if (rawSummary is Map) {
      for (final domain in AppConstants.domains) {
        final key = '${domain}_delay';
        final value = rawSummary[key];
        summary[key] = value is num
            ? (value > 0 ? 1 : 0)
            : ((value?.toString() == '1') ? 1 : 0);
      }
      final numDelaysValue = rawSummary['num_delays'];
      summary['num_delays'] = numDelaysValue is num
          ? numDelaysValue.toInt()
          : int.tryParse('${numDelaysValue ?? ''}') ?? 0;
    } else {
      for (final domain in AppConstants.domains) {
        summary['${domain}_delay'] = 0;
      }
      summary['num_delays'] = 0;
    }

    final computedTotal = AppConstants.domains
        .map((d) => summary['${d}_delay'] ?? 0)
        .fold<int>(0, (a, b) => a + b);
    summary['num_delays'] = summary['num_delays']!.clamp(0, 5);
    if (summary['num_delays'] == 0 && computedTotal > 0) {
      summary['num_delays'] = computedTotal;
    }
    return summary;
  }

  Future<void> _showDomainDelayTable(Map<String, int> delaySummary) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final gm = delaySummary['GM_delay'] ?? 0;
        final fm = delaySummary['FM_delay'] ?? 0;
        final lc = delaySummary['LC_delay'] ?? 0;
        final cog = delaySummary['COG_delay'] ?? 0;
        final se = delaySummary['SE_delay'] ?? 0;
        final num = delaySummary['num_delays'] ?? (gm + fm + lc + cog + se);

        DataColumn col(String key) => DataColumn(
              label: Text(
                AppLocalizations.of(context).t(key),
                style: const TextStyle(fontSize: 10),
              ),
            );

        DataCell cell(int value) =>
            DataCell(Text('$value', style: const TextStyle(fontSize: 12)));

        return AlertDialog(
          title: const Text('Domain Delay Table'),
          content: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 32,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 34,
              columnSpacing: 24,
              columns: [
                col('gm_delay'),
                col('fm_delay'),
                col('lc_delay'),
                col('cog_delay'),
                col('se_delay'),
                col('num_delays'),
              ],
              rows: [
                DataRow(
                  cells: [
                    cell(gm),
                    cell(fm),
                    cell(lc),
                    cell(cog),
                    cell(se),
                    cell(num),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitAssessment() async {
    if (!_isComplete || _submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final responses = _normalizedResponses();
      final child = _localDb.getChild(widget.childId);
      final loggedInAwcCode = _normalizeAwcCode(
        ((await _auth.getLoggedInAwcCode()) ?? '').trim(),
      );
      final widgetAwcCode = _normalizeAwcCode(widget.awwId.trim());
      final childAwcCode = _normalizeAwcCode((child?.awcCode ?? '').trim());
      final awcCodeForSubmit = _isCanonicalAwc(loggedInAwcCode)
          ? loggedInAwcCode
          : (_isCanonicalAwc(widgetAwcCode)
              ? widgetAwcCode
              : (_isCanonicalAwc(childAwcCode) ? childAwcCode : widgetAwcCode));
      var delaySummary =
          buildDelaySummaryFromResponses(responses, ageMonths: _ageMonths) ??
          <String, int>{
            'GM_delay': 0,
            'FM_delay': 0,
            'LC_delay': 0,
            'COG_delay': 0,
            'SE_delay': 0,
            'num_delays': 0,
          };
      var delayed = delaySummary['num_delays'] ?? 0;
      var risk = _riskFromDelayCount(delayed);
      var explainability =
          'Domain delay predicted from milestone responses using AI model.';
      var domainRiskLevels = <String, String>{
        for (final domain in AppConstants.domains)
          domain: (delaySummary['${domain}_delay'] ?? 0) > 0 ? 'High' : 'Low',
      };

      try {
        final prediction = await _api.predictDomainDelays({
          'child_id': widget.childId,
          'age_months': _ageMonths,
          'aww_id': widget.awwId,
          'awc_id': awcCodeForSubmit,
          'awc_code': awcCodeForSubmit,
          'domain_responses': responses,
        });

        delaySummary = _sanitizeDelaySummary(prediction['delay_summary']);
        delayed = delaySummary['num_delays'] ?? 0;
        risk = _riskLevelFromString(prediction['risk_level']);
        if ('${prediction['risk_level'] ?? ''}'.trim().isEmpty) {
          risk = _riskFromDelayCount(delayed);
        }

        final predictedRiskMap = prediction['domain_scores'];
        if (predictedRiskMap is Map) {
          domainRiskLevels = {
            for (final domain in AppConstants.domains)
              domain: _normalizeRiskLabel(predictedRiskMap[domain]),
          };
        } else {
          domainRiskLevels = <String, String>{
            for (final domain in AppConstants.domains)
              domain:
                  (delaySummary['${domain}_delay'] ?? 0) > 0 ? 'High' : 'Low',
          };
        }

        final explanationList = prediction['explanation'];
        if (explanationList is List && explanationList.isNotEmpty) {
          explainability = explanationList.map((e) => '$e').join(', ');
        }
      } catch (_) {
        // Keep local fallback result when backend prediction is unavailable.
      }

      DateTime? submittedAt = DateTime.now();
      try {
        // Persist developmental screening to backend so child status can be
        // marked as completed across sessions/devices.
        await _api.submitScreening({
          'child_id': widget.childId,
          'age_months': _ageMonths,
          'aww_id': widget.awwId.trim().isNotEmpty
              ? widget.awwId.trim()
              : awcCodeForSubmit,
          'awc_id': awcCodeForSubmit,
          'awc_code': awcCodeForSubmit,
          'district': child?.district ?? '',
          'mandal': child?.mandal ?? '',
          'gender': child?.gender ?? '',
          'assessment_cycle': 'Baseline',
          'domain_responses': responses,
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to save developmental assessment to database: $e',
              ),
            ),
          );
          setState(() {
            _submitting = false;
          });
        }
        return;
      }

      final results = <String, int>{
        for (final domain in AppConstants.domains)
          domain: delaySummary['${domain}_delay'] ?? 0,
      };

      final scores = <String, double>{
        for (final d in AppConstants.domains)
          d: _riskLabelToScore(domainRiskLevels[d] ?? 'Low'),
      };

      final screening = ScreeningModel(
        screeningId: 'scr_${DateTime.now().millisecondsSinceEpoch}',
        childId: widget.childId,
        awwId: awcCodeForSubmit,
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
        submittedAt: submittedAt,
      );

      await _localDb.saveScreening(screening);
      if (!mounted) return;

      await _showDomainDelayTable({
        'GM_delay': results['GM'] ?? 0,
        'FM_delay': results['FM'] ?? 0,
        'LC_delay': results['LC'] ?? 0,
        'COG_delay': results['COG'] ?? 0,
        'SE_delay': results['SE'] ?? 0,
        'num_delays': delayed,
      });
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BehavioralPsychosocialScreen(
            prevDomainScores: scores,
            domainRiskLevels: domainRiskLevels,
            overallRisk: risk.toString().split('.').last,
            missedMilestones: delayed,
            explainability: explainability,
            childId: widget.childId,
            awwId: awcCodeForSubmit,
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
          if (_canGoPrevious) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _submitting
                    ? null
                    : () {
                        setState(() {
                          _moveToPreviousQuestion();
                        });
                      },
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

    return PopScope(
      canPop: !_isComplete && !_submitting,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _submitting) return;
        if (_isComplete) {
          await _showCompletedBackOptions();
          return;
        }
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(result);
        }
      },
      child: Scaffold(
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
      ),
    );
  }
}
