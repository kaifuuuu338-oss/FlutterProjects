import 'package:flutter/material.dart';
import 'package:my_first_app/core/constants/app_constants.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'package:my_first_app/screens/behavioral_psychosocial_screen.dart';
import 'package:my_first_app/services/ecd_chatbot_api_service.dart';
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

enum _IntakeStep { age, weight, height, details, done }

class _ScreeningScreenState extends State<ScreeningScreen> {
  final LocalDBService _localDb = LocalDBService();
  final EcdChatbotApiService _api = EcdChatbotApiService();
  final ScrollController _scroll = ScrollController();
  final TextEditingController _input = TextEditingController();

  bool _loading = true;
  bool _answering = false;
  bool _submitting = false;
  String? _error;
  bool _llmEnabled = false;

  _IntakeStep _step = _IntakeStep.age;
  int _ageMonths = 0;
  double? _weightKg;
  double? _heightCm;
  String _details = '';

  String? _sessionId;
  Map<String, dynamic>? _currentQuestion;
  Map<String, dynamic>? _summary;
  int _answered = 0;
  int _domainsDone = 0;
  int _domainsTotal = 5;
  double _progress = 0.0;

  final List<_ChatMessage> _messages = <_ChatMessage>[];

  bool get _needsTextInput => _sessionId == null && _summary == null;

  @override
  void initState() {
    super.initState();
    _ageMonths = widget.ageMonths;
    _bootstrap();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _localDb.initialize();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _messages
        ..clear()
        ..add(
          const _ChatMessage.system(
            'Welcome. I will ask adaptive child-development questions.',
          ),
        )
        ..add(const _ChatMessage.bot('What is the child age in months?'));
    });
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _submitText() async {
    final raw = _input.text.trim();
    if (raw.isEmpty) return;
    if (_answering || _submitting) return;

    if (_step == _IntakeStep.age) {
      final age = int.tryParse(raw);
      if (age == null || age < 0 || age > 96) {
        _snack('Enter valid age in months (0-96).');
        return;
      }
      setState(() {
        _ageMonths = age;
        _messages.add(_ChatMessage.user(raw));
        _messages.add(
          const _ChatMessage.bot('What is the child weight in kg?'),
        );
        _step = _IntakeStep.weight;
        _input.clear();
      });
      _scrollDown();
      return;
    }

    if (_step == _IntakeStep.weight) {
      final value = double.tryParse(raw);
      if (value == null || value <= 0 || value > 50) {
        _snack('Enter valid weight in kg.');
        return;
      }
      setState(() {
        _weightKg = value;
        _messages.add(_ChatMessage.user(raw));
        _messages.add(
          const _ChatMessage.bot('What is the child height in cm?'),
        );
        _step = _IntakeStep.height;
        _input.clear();
      });
      _scrollDown();
      return;
    }

    if (_step == _IntakeStep.height) {
      final value = double.tryParse(raw);
      if (value == null || value <= 0 || value > 160) {
        _snack('Enter valid height in cm.');
        return;
      }
      setState(() {
        _heightCm = value;
        _messages.add(_ChatMessage.user(raw));
        _messages.add(
          const _ChatMessage.bot(
            'Any basic concerns? (feeding/sleep/behavior). Type "none" if no concerns.',
          ),
        );
        _step = _IntakeStep.details;
        _input.clear();
      });
      _scrollDown();
      return;
    }

    if (_step == _IntakeStep.details) {
      _details = raw.toLowerCase() == 'none' ? '' : raw;
      setState(() {
        _messages.add(_ChatMessage.user(raw));
        _messages.add(
          const _ChatMessage.system('Starting adaptive interview...'),
        );
        _step = _IntakeStep.done;
        _input.clear();
      });
      _scrollDown();
      await _startAdaptiveSession();
    }
  }

  Future<void> _startAdaptiveSession() async {
    try {
      setState(() {
        _answering = true;
        _error = null;
      });
      final child = _localDb.getChild(widget.childId);
      final dob = child?.dateOfBirth.toIso8601String().split('T')[0];
      final res = await _api.startAdaptiveSession(
        childId: widget.childId,
        dateOfBirth: dob,
        ageMonths: _ageMonths,
        weightKg: _weightKg,
        heightCm: _heightCm,
        basicDetails: {
          if (_details.isNotEmpty) 'caregiver_observation': _details,
        },
        birthHistory: widget.birthHistory,
        healthHistory: widget.healthHistory,
      );
      if (!mounted) return;
      _applySessionPayload(res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _answering = false);
    }
  }

  Future<void> _answer(bool yes) async {
    if (_answering || _sessionId == null || _currentQuestion == null) return;
    final qid = _currentQuestion!['id']?.toString() ?? '';
    if (qid.isEmpty) return;
    setState(() {
      _answering = true;
      _messages.add(_ChatMessage.user(yes ? 'Yes' : 'No'));
    });
    _scrollDown();
    try {
      final res = await _api.answerAdaptiveSession(
        sessionId: _sessionId!,
        questionId: qid,
        answer: yes ? 1 : 0,
        useLlm: true,
      );
      if (!mounted) return;
      _applySessionPayload(res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _answering = false);
    }
  }

  void _applySessionPayload(Map<String, dynamic> payload) {
    final progress = payload['progress'] as Map<String, dynamic>? ?? {};
    final assistant = payload['assistantMessage']?.toString() ?? '';
    final question = payload['currentQuestion'];
    final completed = payload['completed'] == true;
    setState(() {
      _sessionId = payload['sessionId']?.toString();
      _llmEnabled = payload['llmEnabled'] == true;
      _answered = _int(progress['answered']);
      _domainsDone = _int(progress['domainsCompleted']);
      _domainsTotal = _int(progress['totalDomains']) == 0
          ? 5
          : _int(progress['totalDomains']);
      _progress = (_int(progress['progressPercent']) / 100).clamp(0.0, 1.0);
      if (assistant.trim().isNotEmpty) {
        _messages.add(_ChatMessage.system(assistant.trim()));
      }
      if (completed) {
        _summary = payload['summary'] as Map<String, dynamic>? ?? {};
        _currentQuestion = null;
        _messages.add(
          const _ChatMessage.bot('Interview complete. Tap Submit Assessment.'),
        );
      } else if (question is Map<String, dynamic>) {
        _currentQuestion = question;
        _messages.add(
          _ChatMessage.bot(
            question['text']?.toString() ?? '',
            domain: question['domain']?.toString(),
          ),
        );
      }
    });
    _scrollDown();
  }

  int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Future<void> _submitAssessment() async {
    if (_summary == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final raw = _summary!['domainResults'] as Map<String, dynamic>? ?? {};
      final results = <String, int>{
        for (final d in AppConstants.domains) d: _int(raw[d]) == 1 ? 1 : 0,
      };
      final delayed = _int(_summary!['delayedCount']);
      final risk = delayed <= 0
          ? RiskLevel.low
          : (delayed == 1
                ? RiskLevel.medium
                : (delayed <= 3 ? RiskLevel.high : RiskLevel.critical));
      final explainability = [
        (_summary!['message'] ?? '').toString().trim(),
        (_summary!['llmGuidance'] ?? '').toString().trim(),
        (_summary!['disclaimer'] ?? '').toString().trim(),
      ].where((e) => e.isNotEmpty).join('\n\n');
      final scores = {
        for (final d in AppConstants.domains) d: results[d] == 1 ? 0.35 : 0.9,
      };
      final vectors =
          _summary!['responseVectors'] as Map<String, dynamic>? ?? {};
      final responses = <String, List<int>>{
        for (final d in AppConstants.domains)
          d: ((vectors[d] as List?) ?? const [])
              .map((e) => _int(e) == 1 ? 1 : 0)
              .toList(),
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
      _snack('Submit failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
                        'Answered: $_answered  | Domains: $_domainsDone/$_domainsTotal  | Age: $_ageMonths',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        _llmEnabled
                            ? 'AI guidance enabled'
                            : 'Adaptive rule engine enabled',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
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
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _bubble(_messages[i]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _summary != null
                      ? const Text('Adaptive assessment complete.')
                      : (_currentQuestion != null
                            ? Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _answering
                                          ? null
                                          : () => _answer(true),
                                      child: Text(l10n.t('yes')),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _answering
                                          ? null
                                          : () => _answer(false),
                                      child: Text(l10n.t('no')),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _input,
                                      enabled: _needsTextInput && !_answering,
                                      onSubmitted: (_) => _submitText(),
                                      keyboardType: _step == _IntakeStep.details
                                          ? TextInputType.text
                                          : const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                      decoration: InputDecoration(
                                        hintText: _step == _IntakeStep.age
                                            ? 'Age in months'
                                            : _step == _IntakeStep.weight
                                            ? 'Weight in kg'
                                            : _step == _IntakeStep.height
                                            ? 'Height in cm'
                                            : 'Basic concerns or "none"',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _needsTextInput && !_answering
                                        ? _submitText
                                        : null,
                                    child: const Text('Send'),
                                  ),
                                ],
                              )),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_summary == null || _submitting)
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

  Widget _bubble(_ChatMessage m) {
    final bot = m.isBot || m.isSystem;
    return Align(
      alignment: bot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: m.isSystem
              ? const Color(0xFFE8F5F2)
              : (m.isBot ? Colors.white : const Color(0xFF1E88E5)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD6E1EA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.domain != null && m.isBot)
              Text(
                AppConstants.domainNames[m.domain] ?? m.domain!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D5BA7),
                ),
              ),
            Text(
              m.text,
              style: TextStyle(
                color: bot ? const Color(0xFF1F2A37) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isBot;
  final bool isSystem;
  final String? domain;

  const _ChatMessage._({
    required this.text,
    required this.isBot,
    required this.isSystem,
    this.domain,
  });

  const _ChatMessage.bot(String text, {String? domain})
    : this._(text: text, isBot: true, isSystem: false, domain: domain);

  const _ChatMessage.user(String text)
    : this._(text: text, isBot: false, isSystem: false);

  const _ChatMessage.system(String text)
    : this._(text: text, isBot: true, isSystem: true);
}
