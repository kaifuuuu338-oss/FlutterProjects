import 'package:flutter/material.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'package:my_first_app/services/api_service.dart';
import 'package:my_first_app/services/local_db_service.dart';
import 'package:my_first_app/widgets/language_menu_button.dart';

class ReferralDetailsScreen extends StatefulWidget {
  final String referralId;
  final String childId;
  final String awwId;
  final int ageMonths;
  final String overallRisk;
  final String referralType;
  final String urgency;
  final String status;
  final DateTime createdAt;
  final DateTime expectedFollowUpDate;
  final String? notes;
  final List<String> reasons;

  const ReferralDetailsScreen({
    super.key,
    required this.referralId,
    required this.childId,
    required this.awwId,
    required this.ageMonths,
    required this.overallRisk,
    required this.referralType,
    required this.urgency,
    this.status = 'pending',
    required this.createdAt,
    required this.expectedFollowUpDate,
    required this.reasons,
    this.notes,
  });

  @override
  State<ReferralDetailsScreen> createState() => _ReferralDetailsScreenState();
}

class _ReferralDetailsScreenState extends State<ReferralDetailsScreen> {
  static const List<String> _domains = <String>['GM', 'FM', 'LC', 'COG', 'SE'];
  final LocalDBService _localDb = LocalDBService();
  bool _loading = true;
  ScreeningModel? _latest;
  ScreeningModel? _previous;
  int _cohortLcCritical = 0;
  int _cohortLcImproved = 0;
  String _parentMode = 'Smartphone';
  String _currentStatus = 'pending';
  bool _engineLoading = false;
  int _engineCompliancePercent = 0;
  String _engineComplianceAction = 'Reinforce';
  List<_EngineActivity> _engineActivities = <_EngineActivity>[];
  List<_EngineWeekProgress> _engineWeeklyProgress = <_EngineWeekProgress>[];
  String _engineAgeBand = '';
  String _engineSeverity = '';
  int _engineReviewCycleDays = 30;
  int _enginePhaseWeeks = 0;
  DateTime? _enginePhaseStartDate;
  DateTime? _enginePhaseEndDate;
  String _engineExpectedWindow = '';
  String _engineTargetMilestone = '';
  String _engineProjection = 'Moderate';
  String _engineEscalationDecision = 'Continue';
  String _engineNextAction = 'Continue_Current_Plan';
  Map<String, dynamic> _enginePlanRegen = <String, dynamic>{};
  List<_Appointment> _appointments = <_Appointment>[];
  String _computedReferralStatus = 'Pending';
  String _suggestedReferralStatus = 'Pending';
  _Appointment? _nextAppointment;
  DateTime? _caregiverFromDate;
  DateTime? _caregiverToDate;
  DateTime? _awwFromDate;
  DateTime? _awwToDate;
  String _caregiverDomainFilter = 'All';
  String _awwDomainFilter = 'All';
  int _caregiverWeekIndex = 0;
  int _awwWeekIndex = 0;
  final Map<String, bool> _awwTaskChecks = <String, bool>{};
  final Map<String, bool> _caregiverTaskChecks = <String, bool>{};
  final Map<String, bool> _awwChecklist = <String, bool>{
    'Demonstrated storytelling': false,
    'Conducted peer activity': false,
    'Home visit completed': false,
    'Parent counselled': false,
  };

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status.toLowerCase();
    _loadScreeningData();
  }

  Future<void> _loadScreeningData() async {
    try {
      await _localDb.initialize();
      final child = _localDb.getChildScreenings(widget.childId)
        ..sort((a, b) => b.screeningDate.compareTo(a.screeningDate));
      if (child.isNotEmpty) _latest = child.first;
      if (child.length > 1) _previous = child[1];
      _computeCohort();
      await _loadEngineActivities();
      await _loadAppointments();
    } catch (_) {
      // Keep view usable even without local records.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAppointments() async {
    try {
      final api = APIService();
      final response = await api.getReferralAppointments(widget.referralId);
      final raw = (response['appointments'] as List?) ?? const [];
      _appointments = raw
          .whereType<Map>()
          .map((e) => _Appointment.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
      _suggestedReferralStatus = response['suggested_status']?.toString() ?? _computeReferralStatusLocal();
      _computedReferralStatus = response['current_status']?.toString() ?? _computeReferralStatusLocal();
      final nextRaw = response['next_appointment'];
      if (nextRaw is Map) {
        _nextAppointment = _Appointment.fromJson(Map<String, dynamic>.from(nextRaw));
      } else {
        _nextAppointment = _appointments.firstWhere(
          (a) => a.status == 'SCHEDULED',
          orElse: () => _appointments.isEmpty ? _Appointment.empty() : _appointments.first,
        );
      }
    } catch (_) {
      _computedReferralStatus = _computeReferralStatusLocal();
    }
  }

  String _computeReferralStatusLocal() {
    if (_appointments.isEmpty) return 'Pending';
    final completed = _appointments.where((a) => a.status == 'COMPLETED').length;
    return completed < _appointments.length ? 'Under Treatment' : 'Completed';
  }

  Future<void> _setReferralStatus(String status) async {
    try {
      final api = APIService();
      final response = await api.updateReferralStatus(referralId: widget.referralId, status: status);
      _computedReferralStatus = response['current_status']?.toString() ?? status;
      _suggestedReferralStatus = response['suggested_status']?.toString() ?? _suggestedReferralStatus;
      if (mounted) setState(() {});
    } catch (_) {
      // keep UI usable even if backend is unavailable
    }
  }

  Future<void> _createAppointment() async {
    final types = <String>[
      'Initial Consultation',
      'Therapy Session',
      'Follow-up Review',
      'Specialist Review',
    ];
    var selectedType = types.first;
    var selectedDate = DateTime.now().add(const Duration(days: 2));
    final notesController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule New Appointment'),
        content: StatefulBuilder(
          builder: (context, setInner) => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(_formatPrettyDate(selectedDate)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setInner(() => selectedDate = picked);
                  }
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Appointment Type'),
                items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) {
                  if (v != null) setInner(() => selectedType = v);
                },
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (created != true) return;
    try {
      final api = APIService();
      await api.createAppointment(
        referralId: widget.referralId,
        childId: widget.childId,
        scheduledDate: _formatDate(selectedDate),
        appointmentType: selectedType,
        notes: notesController.text.trim(),
      );
      await _loadAppointments();
      if (mounted) setState(() {});
    } catch (_) {
      // keep UI usable even if backend is unavailable
    }
  }

  Future<void> _updateAppointmentStatus(_Appointment appt, String status) async {
    try {
      final api = APIService();
      await api.updateAppointmentStatus(appointmentId: appt.appointmentId, status: status);
      await _loadAppointments();
      if (mounted) setState(() {});
    } catch (_) {
      // keep UI usable even if backend is unavailable
    }
  }

  String _severityFromSnapshot(List<String> delayedDomains, String autismRisk) {
    final risk = autismRisk.trim().toLowerCase();
    if (risk == 'high' || risk == 'elevated') return 'Critical';
    if (delayedDomains.length > 3) return 'Severe';
    if (delayedDomains.length >= 2) return 'Moderate';
    return 'Mild';
    }

  Future<void> _loadEngineActivities() async {
    final snapshot = _snapshot();
    var delayed = _activeDomains(snapshot);
    if (delayed.isEmpty) {
      delayed = _domainsFromReasons(widget.reasons);
    }
    final autismRisk = ((snapshot['LC'] == 'Critical' || snapshot['LC'] == 'High') &&
            (snapshot['SE'] == 'Critical' || snapshot['SE'] == 'High'))
        ? 'High'
        : 'Low';
    final severity = _severityFromSnapshot(delayed, autismRisk);

    setState(() => _engineLoading = true);
    try {
      final api = APIService();
      final response = await api.generateProblemBActivities({
        'child_id': widget.childId,
        'age_months': widget.ageMonths,
        'delayed_domains': delayed,
        'autism_risk': autismRisk,
        'baseline_risk_category': widget.overallRisk,
        'severity_level': severity,
      });
      _applyEnginePayload(response, fallbackSeverity: severity);
    } catch (_) {
      // Keep fallback UI functional even if backend endpoint is unavailable.
    } finally {
      if (mounted) setState(() => _engineLoading = false);
    }
  }

  void _applyEnginePayload(
    Map<String, dynamic> response, {
    required String fallbackSeverity,
  }) {
    final summary = Map<String, dynamic>.from(response['summary'] ?? {});
    final compliance = Map<String, dynamic>.from(response['compliance'] ?? {});
    final activitiesRaw = (response['activities'] as List?) ?? const [];
    final weeklyRaw = (response['weekly_progress'] as List?) ?? const [];

    _engineActivities = activitiesRaw
        .whereType<Map>()
        .map((e) => _EngineActivity.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    _engineWeeklyProgress = weeklyRaw
        .whereType<Map>()
        .map((e) => _EngineWeekProgress.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    _engineAgeBand = summary['age_band']?.toString() ?? '';
    _engineSeverity = summary['severity_level']?.toString() ?? fallbackSeverity;
    _engineReviewCycleDays = int.tryParse(summary['review_cycle_days']?.toString() ?? '') ?? 30;
    _enginePhaseWeeks = int.tryParse(summary['phase_duration_weeks']?.toString() ?? '') ?? 0;
    _engineExpectedWindow = summary['expected_improvement_window']?.toString() ?? '';
    _engineTargetMilestone = summary['target_milestone']?.toString() ?? '';
    _enginePhaseStartDate = DateTime.tryParse(summary['phase_start_date']?.toString() ?? '');
    _enginePhaseEndDate = DateTime.tryParse(summary['phase_end_date']?.toString() ?? '');
    _engineCompliancePercent = int.tryParse(compliance['completion_percent']?.toString() ?? '') ?? 0;
    _engineComplianceAction = compliance['action']?.toString() ?? 'Reinforce';
    _engineProjection = response['projection']?.toString() ?? 'Moderate';
    _engineEscalationDecision = response['escalation_decision']?.toString() ?? 'Continue';
    _engineNextAction = response['next_action']?.toString() ?? _engineNextAction;
    _enginePlanRegen = Map<String, dynamic>.from(response['plan_regeneration'] ?? {});
    final defaultFrom = _enginePhaseStartDate ?? widget.createdAt;
    final defaultTo = _enginePhaseEndDate ?? widget.expectedFollowUpDate;
    _caregiverFromDate ??= defaultFrom;
    _caregiverToDate ??= defaultTo;
    _awwFromDate ??= defaultFrom;
    _awwToDate ??= defaultTo;
  }

  Future<void> _markEngineActivity(_EngineActivity activity, bool done) async {
    final index = _engineActivities.indexWhere((a) => a.activityId == activity.activityId);
    if (index == -1) return;
    setState(() {
      _engineActivities[index] = activity.copyWith(
        status: done ? 'completed' : 'pending',
        completedCount: done ? activity.requiredCount : 0,
      );
    });
    try {
      final api = APIService();
      final response = await api.markProblemBActivityStatus(
        childId: widget.childId,
        activityId: activity.activityId,
        status: done ? 'completed' : 'pending',
      );
      if (!mounted) return;
      setState(() {
        _applyEnginePayload(response, fallbackSeverity: _engineSeverity);
      });
    } catch (_) {
      // keep local optimistic status when backend is unreachable
    }
  }

  void _computeCohort() {
    final children = _localDb.getAllChildren();
    var critical = 0;
    var improved = 0;
    for (final child in children) {
      final list = _localDb.getChildScreenings(child.childId)
        ..sort((a, b) => b.screeningDate.compareTo(a.screeningDate));
      if (list.isEmpty || list.first.awwId != widget.awwId) continue;
      final latestRisk = _riskFromScore(list.first.domainScores['LC']);
      if (latestRisk == 'critical') critical += 1;
      if (list.length > 1) {
        final delta = _delayMonths(list[1].domainScores['LC']) - _delayMonths(list.first.domainScores['LC']);
        if (delta > 0) improved += 1;
      }
    }
    _cohortLcCritical = critical;
    _cohortLcImproved = improved;
  }

  String _riskFromScore(double? score) {
    final s = score ?? 1.0;
    if (s <= 0.4) return 'critical';
    if (s <= 0.6) return 'high';
    if (s <= 0.8) return 'mild';
    return 'normal';
  }

  int _delayMonths(double? score) {
    final s = score ?? 1.0;
    if (s <= 0.4) return 5;
    if (s <= 0.6) return 3;
    if (s <= 0.8) return 1;
    return 0;
  }

  String _statusFromRisk(String risk) {
    switch (risk) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'mild':
        return 'Mild Delay';
      default:
        return 'Normal';
    }
  }

  Color _riskColor(String risk) {
    final r = risk.toLowerCase();
    if (r == 'critical' || r == 'high') return const Color(0xFFE53935);
    if (r == 'mild' || r == 'medium') return const Color(0xFFF9A825);
    return const Color(0xFF43A047);
  }

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  String _formatPrettyDate(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  int _priorityScore() {
    if (_latest == null) return 0;
    var score = 0;
    _latest!.domainScores.forEach((_, value) {
      score += ((1.0 - value) * 8).round();
    });
    if (widget.overallRisk.toLowerCase() == 'critical') score += 8;
    return score.clamp(0, 40);
  }

  Map<String, String> _snapshot() {
    final out = <String, String>{};
    for (final d in _domains) {
      out[d] = 'Normal';
    }
    if (_latest != null) {
      for (final d in _domains) {
        out[d] = _statusFromRisk(_riskFromScore(_latest?.domainScores[d]));
      }
      return out;
    }
    final reasonDomains = _domainsFromReasons(widget.reasons);
    if (reasonDomains.isEmpty) return out;
    final reasonText = widget.reasons.join(' ');
    for (final domain in reasonDomains) {
      out[domain] = _statusFromReason(reasonText);
    }
    return out;
  }

  List<String> _activeDomains(Map<String, String> snapshot) {
    return snapshot.entries.where((e) => e.value != 'Normal').map((e) => e.key).toList();
  }

  List<String> _domainsFromReasons(List<String> reasons) {
    final result = <String>{};
    for (final reason in reasons) {
      final r = reason.toLowerCase();
      if (r.contains('gm') || r.contains('gross motor')) result.add('GM');
      if (r.contains('fm') || r.contains('fine motor')) result.add('FM');
      if (r.contains('lc') || r.contains('language')) result.add('LC');
      if (r.contains('cog') || r.contains('cognitive')) result.add('COG');
      if (r.contains('se') || r.contains('social') || r.contains('emotional')) result.add('SE');
    }
    return result.toList();
  }

  String _statusFromReason(String reasonText) {
    final r = reasonText.toLowerCase();
    if (r.contains('critical')) return 'Critical';
    if (r.contains('high')) return 'High';
    if (r.contains('mild')) return 'Mild Delay';
    return 'Mild Delay';
  }

  List<String> _centerPlan(String domain) {
    switch (domain) {
      case 'GM':
        return <String>['Movement and balance circuit', 'Assisted stair-jump play'];
      case 'FM':
        return <String>['Fine motor station (beads, pegs)', 'Tracing and grip practice'];
      case 'LC':
        return <String>['Structured storytelling (15 mins)', 'Peer communication circle', 'Action-song repetition'];
      case 'COG':
        return <String>['Puzzle and sorting corner', 'Guided memory games'];
      case 'SE':
        return <String>['Turn-taking social circle', 'Emotion naming activities'];
      default:
        return <String>['General developmental activity'];
    }
  }

  List<_TaskRow> _awwTasksForDomain(String domain) {
    switch (domain) {
      case 'GM':
        return const <_TaskRow>[
          _TaskRow(domain: 'GM', activity: 'Balance beam walk', frequency: '5/week'),
          _TaskRow(domain: 'GM', activity: 'Ball catch and throw', frequency: '5/week'),
          _TaskRow(domain: 'GM', activity: 'Step climbing supervision', frequency: '4/week'),
          _TaskRow(domain: 'GM', activity: 'Jumping pattern game', frequency: '5/week'),
          _TaskRow(domain: 'GM', activity: 'Movement circuit 15 mins', frequency: 'Daily'),
        ];
      case 'FM':
        return const <_TaskRow>[
          _TaskRow(domain: 'FM', activity: 'Bead and peg activity', frequency: '5/week'),
          _TaskRow(domain: 'FM', activity: 'Grip-tracing practice', frequency: '5/week'),
          _TaskRow(domain: 'FM', activity: 'Block stacking challenge', frequency: 'Daily'),
          _TaskRow(domain: 'FM', activity: 'Object sort transfer', frequency: '4/week'),
          _TaskRow(domain: 'FM', activity: 'Hand coordination game', frequency: '5/week'),
        ];
      case 'LC':
        return const <_TaskRow>[
          _TaskRow(domain: 'LC', activity: 'Storytelling circle', frequency: 'Daily'),
          _TaskRow(domain: 'LC', activity: 'Object naming drill', frequency: 'Daily'),
          _TaskRow(domain: 'LC', activity: '2-word sentence prompting', frequency: '5/week'),
          _TaskRow(domain: 'LC', activity: 'Action song repetition', frequency: '5/week'),
          _TaskRow(domain: 'LC', activity: 'Peer communication game', frequency: '4/week'),
        ];
      case 'COG':
        return const <_TaskRow>[
          _TaskRow(domain: 'COG', activity: 'Shape sorting tasks', frequency: '5/week'),
          _TaskRow(domain: 'COG', activity: 'Pattern completion game', frequency: '4/week'),
          _TaskRow(domain: 'COG', activity: 'Memory card recall', frequency: '5/week'),
          _TaskRow(domain: 'COG', activity: 'Puzzle solving corner', frequency: '4/week'),
          _TaskRow(domain: 'COG', activity: 'Concept matching drill', frequency: '5/week'),
        ];
      case 'SE':
        return const <_TaskRow>[
          _TaskRow(domain: 'SE', activity: 'Peer turn-taking session', frequency: '5/week'),
          _TaskRow(domain: 'SE', activity: 'Emotion naming circle', frequency: 'Daily'),
          _TaskRow(domain: 'SE', activity: 'Cooperative play group', frequency: '4/week'),
          _TaskRow(domain: 'SE', activity: 'Social greeting routine', frequency: 'Daily'),
          _TaskRow(domain: 'SE', activity: 'Behavior cue practice', frequency: '5/week'),
        ];
      default:
        return const <_TaskRow>[];
    }
  }

  List<_TaskRow> _caregiverTasksForDomain(String domain) {
    switch (domain) {
      case 'GM':
        return const <_TaskRow>[
          _TaskRow(domain: 'GM', activity: 'Climb steps with support', frequency: 'Daily'),
          _TaskRow(domain: 'GM', activity: '10-min outdoor movement', frequency: 'Daily'),
          _TaskRow(domain: 'GM', activity: 'Ball kick practice', frequency: '5/week'),
          _TaskRow(domain: 'GM', activity: 'Jump-and-land game', frequency: '5/week'),
          _TaskRow(domain: 'GM', activity: 'Follow movement imitation', frequency: '4/week'),
        ];
      case 'FM':
        return const <_TaskRow>[
          _TaskRow(domain: 'FM', activity: 'Drawing line practice', frequency: 'Daily'),
          _TaskRow(domain: 'FM', activity: 'Sort 5 objects task', frequency: 'Daily'),
          _TaskRow(domain: 'FM', activity: 'Block stacking at home', frequency: '5/week'),
          _TaskRow(domain: 'FM', activity: 'Spoon transfer game', frequency: '5/week'),
          _TaskRow(domain: 'FM', activity: 'Grip squeeze toy drill', frequency: '4/week'),
        ];
      case 'LC':
        return const <_TaskRow>[
          _TaskRow(domain: 'LC', activity: 'Name 5 objects daily', frequency: 'Daily'),
          _TaskRow(domain: 'LC', activity: 'Expand 2-word phrase', frequency: 'Daily'),
          _TaskRow(domain: 'LC', activity: 'Read 10-min picture book', frequency: 'Daily'),
          _TaskRow(domain: 'LC', activity: 'Body-part naming game', frequency: '5/week'),
          _TaskRow(domain: 'LC', activity: 'Simple Q&A conversation', frequency: '5/week'),
        ];
      case 'COG':
        return const <_TaskRow>[
          _TaskRow(domain: 'COG', activity: 'Color-shape sorting', frequency: 'Daily'),
          _TaskRow(domain: 'COG', activity: 'Memory card game', frequency: '5/week'),
          _TaskRow(domain: 'COG', activity: 'Find hidden object', frequency: '4/week'),
          _TaskRow(domain: 'COG', activity: 'Matching pair practice', frequency: '5/week'),
          _TaskRow(domain: 'COG', activity: 'Simple problem game', frequency: '4/week'),
        ];
      case 'SE':
        return const <_TaskRow>[
          _TaskRow(domain: 'SE', activity: 'Turn-taking home game', frequency: 'Daily'),
          _TaskRow(domain: 'SE', activity: 'Emotion word training', frequency: 'Daily'),
          _TaskRow(domain: 'SE', activity: 'Social greeting practice', frequency: '5/week'),
          _TaskRow(domain: 'SE', activity: 'Shared toy activity', frequency: '5/week'),
          _TaskRow(domain: 'SE', activity: 'Calm response routine', frequency: '4/week'),
        ];
      default:
        return const <_TaskRow>[];
    }
  }

  String _taskKey(_TaskRow row) => '${row.domain}|${row.activity}';

  void _ensureTaskState(List<_TaskRow> awwRows, List<_TaskRow> caregiverRows) {
    for (final row in awwRows) {
      _awwTaskChecks.putIfAbsent(_taskKey(row), () => false);
    }
    for (final row in caregiverRows) {
      _caregiverTaskChecks.putIfAbsent(_taskKey(row), () => false);
    }
  }

  int _checkedCount(Map<String, bool> state, List<_TaskRow> rows) {
    var count = 0;
    for (final row in rows) {
      if (state[_taskKey(row)] == true) count += 1;
    }
    return count;
  }

  List<String> _homePlan(String domain) {
    switch (domain) {
      case 'GM':
        return <String>['Daily 10-min movement play', 'Outdoor active play with caregiver'];
      case 'FM':
        return <String>['Name and sort 5 objects daily', 'Stacking and drawing play'];
      case 'LC':
        return <String>['Name 5 objects daily', 'Expand 2-word phrases', 'Daily 10-min reading and body-part naming'];
      case 'COG':
        return <String>['Color-shape matching game', 'Find-and-name objects'];
      case 'SE':
        return <String>['Turn-taking game daily', 'Emotion words in conversation'];
      default:
        return <String>['Play-based caregiver interaction'];
    }
  }

  String _trend() {
    if (_latest == null || _previous == null) return 'Awaiting follow-up';
    var sum = 0;
    for (final d in _domains) {
      sum += _delayMonths(_previous!.domainScores[d]) - _delayMonths(_latest!.domainScores[d]);
    }
    if (sum > 1) return 'Improving';
    if (sum < 0) return 'Worsening';
    return 'No change';
  }

  String _intensity() {
    final severity = _engineSeverity.isNotEmpty ? _engineSeverity : widget.overallRisk;
    final normalized = _normalizedSeverity(severity);
    if (normalized == 'Critical' || normalized == 'Severe') {
      return 'High - Daily structured stimulation';
    }
    if (normalized == 'Moderate') return 'Moderate - 3x weekly';
    return 'Routine - Reinforcement only';
  }

  int _totalImprovement() {
    if (_latest == null || _previous == null) return 0;
    var total = 0;
    for (final d in _domains) {
      total += _delayMonths(_previous!.domainScores[d]) - _delayMonths(_latest!.domainScores[d]);
    }
    return total;
  }

  String _nextDecision({
    required int totalImprovement,
    required int adherencePercent,
  }) {
    if (_latest == null || _previous == null) {
      return adherencePercent >= 70
          ? 'Good adherence. Continue current plan until first follow-up.'
          : 'Increase adherence first, then review at follow-up.';
    }
    if (totalImprovement > 2 && adherencePercent >= 70) {
      return 'Reduce intensity at next cycle.';
    }
    if (totalImprovement < 0) {
      return 'Worsening: re-evaluate referral and escalate.';
    }
    if (adherencePercent < 50) {
      return 'Low adherence: intensify AWW + caregiver coaching before escalation.';
    }
    return 'Continue current intensity and reassess in next review cycle.';
  }

  String _projectedOutcome({
    required int totalImprovement,
    required int adherencePercent,
  }) {
    if (adherencePercent >= 80 && totalImprovement >= 0) return 'High';
    if (adherencePercent >= 50) return 'Moderate';
    return 'Low';
  }

  String _normalizedSeverity(String severity) {
    final s = severity.trim().toLowerCase();
    if (s == 'critical') return 'Critical';
    if (s == 'severe') return 'Severe';
    if (s == 'moderate') return 'Moderate';
    return 'Mild';
  }

  String _expectedImprovementWindow(String severity) {
    switch (_normalizedSeverity(severity)) {
      case 'Critical':
        return 'Referral + 15-day monitoring';
      case 'Severe':
        return '3-4 months';
      case 'Moderate':
        return '2-3 months';
      default:
        return '1-2 months';
    }
  }

  int _totalWeeksForSeverity(String severity) {
    switch (_normalizedSeverity(severity)) {
      case 'Critical':
        return 16;
      case 'Severe':
        return 12;
      case 'Moderate':
        return 8;
      default:
        return 6;
    }
  }

  int _reviewDaysForSeverity(String severity) {
    switch (_normalizedSeverity(severity)) {
      case 'Critical':
      case 'Severe':
        return 15;
      case 'Moderate':
        return 30;
      default:
        return 60;
    }
  }

  String _targetMilestone(List<String> activeDomains) {
    if (activeDomains.contains('LC')) return 'Use 2-word meaningful phrases consistently';
    if (activeDomains.contains('GM')) return 'Climb steps with minimal support';
    if (activeDomains.contains('FM')) return 'Perform controlled grasp and stacking tasks';
    if (activeDomains.contains('SE')) return 'Participate in turn-taking play without prompts';
    if (activeDomains.contains('COG')) return 'Complete simple sorting and memory tasks';
    return 'Maintain age-appropriate milestone trajectory';
  }

  String _weeklyNote(int percent) {
    if (percent >= 80) return 'Good progress';
    if (percent >= 50) return 'Improving';
    return 'Needs reinforcement';
  }

  String _referralStatus() {
    switch (_currentStatus) {
      case 'scheduled':
        return 'Appointment Scheduled';
      case 'completed':
        return 'Completed';
      case 'undertreatment':
      case 'under_treatment':
        return 'Under Treatment';
      default:
        return 'Pending';
    }
  }

  int _daysSinceReferral() => DateTime.now().difference(widget.createdAt).inDays.clamp(0, 9999);

  bool _isReferralDelayed() {
    final now = DateTime.now();
    return now.isAfter(widget.expectedFollowUpDate);
  }

  int _stimulationScore(Map<String, String> snapshot) {
    final delays = snapshot.values.where((v) => v != 'Normal').length;
    return (100 - (delays * 15) - (_priorityScore() ~/ 4)).clamp(20, 100);
  }

  String _adhdRisk(Map<String, String> snapshot) {
    final cog = snapshot['COG'] ?? 'Normal';
    final se = snapshot['SE'] ?? 'Normal';
    if (cog == 'Critical' || se == 'Critical') return 'Elevated';
    if (cog == 'High' || se == 'High') return 'Moderate';
    return 'Low';
  }

  String _classifyAgeBand(int ageMonths) {
    if (ageMonths < 6) return 'Infant 1';
    if (ageMonths < 12) return 'Infant 2';
    if (ageMonths < 24) return 'Toddler 1';
    if (ageMonths < 36) return 'Toddler 2';
    if (ageMonths < 48) return 'Preschool 1';
    if (ageMonths < 60) return 'Preschool 2';
    return 'Preschool 3';
  }

  List<_WeekRange> _buildWeekRanges() {
    final start = _enginePhaseStartDate ?? widget.createdAt;
    final weeks = _enginePhaseWeeks > 0 ? _enginePhaseWeeks : 8;
    return List<_WeekRange>.generate(weeks, (index) {
      final s = start.add(Duration(days: index * 7));
      final e = s.add(const Duration(days: 6));
      return _WeekRange(index + 1, s, e);
    });
  }

  String _weekLabel(_WeekRange range) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${range.start.day} ${months[range.start.month - 1]} - ${range.end.day} ${months[range.end.month - 1]}';
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() => onPicked(picked));
    }
  }

  Widget _sectionCard(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(flex: 3, child: Text(key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          Expanded(flex: 4, child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _bullet(String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.circle, size: 7, color: Color(0xFF4D5A67)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF5D6B78), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _taskTable({
    required String title,
    required List<_TaskRow> rows,
    required Map<String, bool> state,
  }) {
    return _sectionCard(
      title,
      rows.isEmpty
          ? const Text('No issue-specific tasks detected.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                columns: const <DataColumn>[
                  DataColumn(label: Text('Domain')),
                  DataColumn(label: Text('Activity')),
                  DataColumn(label: Text('Frequency')),
                  DataColumn(label: Text('Done')),
                ],
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: <DataCell>[
                          DataCell(Text(row.domain)),
                          DataCell(SizedBox(width: 290, child: Text(row.activity))),
                          DataCell(Text(row.frequency)),
                          DataCell(
                            Checkbox(
                              value: state[_taskKey(row)] ?? false,
                              onChanged: (v) => setState(() => state[_taskKey(row)] = v ?? false),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }

  List<_EngineActivity> _engineBy({
    required String stakeholder,
    String? frequencyType,
    String? activityType,
    int? weekNumber,
  }) {
    return _engineActivities
        .where((a) =>
            a.stakeholder == stakeholder &&
            (frequencyType == null || a.frequencyType == frequencyType) &&
            (activityType == null || a.activityType == activityType) &&
            (weekNumber == null || a.weekNumber == weekNumber))
        .toList();
  }

  int _phaseCurrentWeek(int totalWeeks) {
    if (totalWeeks <= 0) return 1;
    final start = _enginePhaseStartDate ?? widget.createdAt;
    return ((DateTime.now().difference(start).inDays ~/ 7) + 1).clamp(1, totalWeeks);
  }

  int _weeklyCompletionForWeek(int weekNumber) {
    final fromEngine = _engineWeeklyProgress.where((w) => w.weekNumber == weekNumber);
    if (fromEngine.isNotEmpty) return fromEngine.first.completionPercentage;
    return 0;
  }

  String _weeklyNoteForWeek(int weekNumber, int completion) {
    final fromEngine = _engineWeeklyProgress.where((w) => w.weekNumber == weekNumber);
    if (fromEngine.isNotEmpty) return fromEngine.first.reviewNotes;
    return _weeklyNote(completion);
  }

  int _completionPercentForStakeholder(String stakeholder, int weekNumber) {
    final bucket = _engineActivities.where((a) => a.stakeholder == stakeholder && a.weekNumber == weekNumber).toList();
    if (bucket.isEmpty) return 0;
    var required = 0;
    var done = 0;
    for (final row in bucket) {
      final req = row.requiredCount <= 0 ? 1 : row.requiredCount;
      required += req;
      final completed = row.completedCount > req ? req : row.completedCount;
      done += completed;
    }
    return ((done / (required == 0 ? 1 : required)) * 100).round();
  }

  Widget _engineTable({
    required String title,
    required List<_EngineActivity> rows,
  }) {
    return _sectionCard(
      title,
      _engineLoading
          ? const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            )
          : rows.isEmpty
              ? const Text('No generated activities for this bucket.')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 18,
                    columns: const <DataColumn>[
                      DataColumn(label: Text('Domain')),
                      DataColumn(label: Text('Activity')),
                      DataColumn(label: Text('Duration')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: rows
                        .map(
                          (row) => DataRow(
                            cells: <DataCell>[
                              DataCell(Text(row.domain)),
                              DataCell(SizedBox(width: 320, child: Text(row.title))),
                              DataCell(Text('${row.durationMinutes} min')),
                              DataCell(
                                Checkbox(
                                  value: row.status == 'completed',
                                  onChanged: (v) => _markEngineActivity(row, v ?? false),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
    );
  }

  Widget _appointmentsCard() {
    final hasNext = _nextAppointment != null && _nextAppointment!.appointmentId.isNotEmpty;
    return _sectionCard(
      'Appointments',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: _createAppointment,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Schedule New Appointment'),
              ),
              const SizedBox(width: 12),
              if (hasNext)
                Text(
                  'Next: ${_formatPrettyDate(_nextAppointment!.scheduledDate)} (${_nextAppointment!.appointmentType})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _appointments.isEmpty
              ? const Text('No appointments scheduled yet.')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 18,
                    columns: const <DataColumn>[
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: _appointments
                        .map(
                          (appt) => DataRow(
                            cells: <DataCell>[
                              DataCell(Text(_formatPrettyDate(appt.scheduledDate))),
                              DataCell(Text(appt.appointmentType)),
                              DataCell(Text(appt.status)),
                              DataCell(
                                DropdownButton<String>(
                                  value: appt.status,
                                  items: const <String>[
                                    'SCHEDULED',
                                    'COMPLETED',
                                    'CANCELLED',
                                    'RESCHEDULED',
                                    'MISSED',
                                  ]
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) _updateAppointmentStatus(appt, v);
                                  },
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _datePickerBox({
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        width: 170,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD9DCE5)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withValues(alpha: 0.7),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _formatPrettyDate(date),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const Icon(Icons.calendar_month_outlined, size: 18, color: Color(0xFF2F67C7)),
          ],
        ),
      ),
    );
  }

  Widget _assignmentManagementCard({
    required String title,
    required String stakeholder,
    required DateTime fromDate,
    required DateTime toDate,
    required String domainFilter,
    required ValueChanged<DateTime> onFromPicked,
    required ValueChanged<DateTime> onToPicked,
    required ValueChanged<String> onDomainChanged,
    required int selectedWeekIndex,
    required ValueChanged<int> onWeekChanged,
    required List<_EngineActivity> rows,
  }) {
    final domains = <String>{'All', ..._domains};
    final weekRanges = _buildWeekRanges();
    final selectedWeek = selectedWeekIndex.clamp(0, weekRanges.isEmpty ? 0 : weekRanges.length - 1);
    final weekNumber = weekRanges.isEmpty ? 1 : weekRanges[selectedWeek].weekNumber;
    final filtered = rows.where((r) {
      if (r.weekNumber != weekNumber) return false;
      if (domainFilter != 'All' && r.domain != domainFilter) return false;
      return true;
    }).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF2E2A3B)),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: <Widget>[
                    const Text('From', style: TextStyle(fontSize: 14)),
                    _datePickerBox(
                      date: fromDate,
                      onTap: () => _pickDate(initial: fromDate, onPicked: onFromPicked),
                    ),
                    const Text('To', style: TextStyle(fontSize: 14)),
                    _datePickerBox(
                      date: toDate,
                      onTap: () => _pickDate(initial: toDate, onPicked: onToPicked),
                    ),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD9DCE5)),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: domainFilter,
                          items: domains
                              .map(
                                (d) => DropdownMenuItem<String>(
                                  value: d,
                                  child: Text(d),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) onDomainChanged(v);
                          },
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$stakeholder tasks saved')),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: Text('Save'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B7CD5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                        child: const Text(
                          'Weekly',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 2),
                      ...List<Widget>.generate(weekRanges.length, (index) {
                        final selected = index == selectedWeek;
                        return InkWell(
                          onTap: () => onWeekChanged(index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFFEAF0FF) : const Color(0xFFF5F2FB),
                              border: Border(
                                bottom: BorderSide(
                                  color: selected ? const Color(0xFF4B7CD5) : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              _weekLabel(weekRanges[index]),
                              style: TextStyle(
                                color: const Color(0xFF2E4EA0),
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 24,
                    columns: const <DataColumn>[
                      DataColumn(label: Text('Assigned Date')),
                      DataColumn(label: Text('Domain')),
                      DataColumn(label: Text('Activity')),
                      DataColumn(label: Text('Frequency')),
                      DataColumn(label: Text('Guide')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: filtered
                        .map(
                          (row) => DataRow(
                            cells: <DataCell>[
                              DataCell(Text(_formatPrettyDate(row.assignedDate))),
                              DataCell(Text(row.domain)),
                              DataCell(SizedBox(width: 260, child: Text(row.title))),
                              DataCell(Text(row.frequencyType == 'daily' ? 'Daily' : '${row.requiredCount}/week')),
                              DataCell(
                                IconButton(
                                  onPressed: () => _showActivityGuide(row),
                                  icon: const Icon(Icons.play_circle_outline, color: Color(0xFF3A63C6)),
                                  tooltip: 'How to do',
                                ),
                              ),
                              DataCell(
                                Checkbox(
                                  value: row.status == 'completed',
                                  onChanged: (v) => _markEngineActivity(row, v ?? false),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _phaseTimelineCard({
    required int phaseWeeks,
    required int currentWeek,
  }) {
    return _sectionCard(
      'Phase Timeline View',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List<Widget>.generate(phaseWeeks, (index) {
          final week = index + 1;
          final completion = week > currentWeek ? 0 : _weeklyCompletionForWeek(week);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 74,
                  child: Text(
                    'Week $week',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: completion / 100,
                      backgroundColor: const Color(0xFFE6EAF2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completion >= 80
                            ? const Color(0xFF43A047)
                            : completion >= 50
                                ? const Color(0xFF1E88E5)
                                : const Color(0xFFF9A825),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  child: Text(
                    '$completion%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _phaseLifecycleStagesCard({
    required int phaseWeeks,
    required DateTime phaseStart,
  }) {
    final midpointWeeks = (phaseWeeks / 2).ceil();
    final phase1End = phaseStart.add(Duration(days: (midpointWeeks * 7) - 1));
    final phase2Start = phase1End.add(const Duration(days: 1));
    final phase2End = phaseStart.add(Duration(days: (phaseWeeks * 7) - 1));
    return _sectionCard(
      'Phase Lifecycle Stages',
      Column(
        children: <Widget>[
          _kv('Phase 1 (Weeks 1-$midpointWeeks)', '${_formatPrettyDate(phaseStart)} to ${_formatPrettyDate(phase1End)}'),
          _kv('Checkpoint 1', 'Review compliance + early milestone progress'),
          _kv('Phase 2 (Weeks ${midpointWeeks + 1}-$phaseWeeks)', '${_formatPrettyDate(phase2Start)} to ${_formatPrettyDate(phase2End)}'),
          _kv('Checkpoint 2', 'Reassess delays, adjust intensity, decide escalation'),
        ],
      ),
    );
  }

  Widget _complianceThresholdCard({
    required int adherencePercent,
    required int totalImprovement,
  }) {
    final currentRule = adherencePercent < 40
        ? 'Trigger Intensify'
        : (totalImprovement < 0 ? 'Trigger Referral Review' : 'Continue current phase');
    return _sectionCard(
      'Compliance Threshold Rules',
      Column(
        children: <Widget>[
          _kv('Rule 1', 'If adherence < 40% for 2 weeks -> Intensify'),
          _kv('Rule 2', 'If no improvement after phase -> Escalate'),
          _kv('Rule 3', 'If worsening trend -> Specialist review'),
          _kv('Current trigger', currentRule),
        ],
      ),
    );
  }

  Widget _planRegenerationCard({
    required String decision,
    required int currentActivityCount,
    required int phaseWeeks,
  }) {
    final regenCount = int.tryParse(_enginePlanRegen['updated_activity_count']?.toString() ?? '') ?? currentActivityCount;
    final extra = int.tryParse(_enginePlanRegen['extra_activities_added']?.toString() ?? '') ?? 0;
    final deltaDays = int.tryParse(_enginePlanRegen['review_interval_delta_days']?.toString() ?? '') ?? 0;
    final action = _enginePlanRegen['action']?.toString() ?? decision;
    final actionLower = action.toLowerCase();
    final regeneratedText = actionLower.contains('refer')
        ? 'Escalation path activated: specialist referral + high intensity monitoring.'
        : (actionLower.contains('intensify')
            ? 'Regenerated plan with higher weekly targets and increased supervision.'
            : 'Continue current plan; no regeneration required this cycle.');
    return _sectionCard(
      'Post-Review Auto-Adjustment',
      Column(
        children: <Widget>[
          _kv('Review decision', decision),
          _kv('Auto-action', action),
          _kv('Current plan activities', '$currentActivityCount'),
          _kv('Updated plan activities', '$regenCount'),
          _kv('Extra activities added', '$extra'),
          _kv('Review interval change', deltaDays == 0 ? 'No change' : '$deltaDays days'),
          _kv('Regeneration status', regeneratedText),
        ],
      ),
    );
  }

  void _showActivityGuide(_EngineActivity row) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('How to Do This Activity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Activity: ${row.title}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Guidance: ${row.description.isEmpty ? 'Follow AWW demonstrated steps for this activity.' : row.description}'),
            const SizedBox(height: 8),
            Text('Duration: ${row.durationMinutes} minutes'),
            Text('Frequency: ${row.frequencyType == 'daily' ? 'Daily' : '${row.requiredCount} times/week'}'),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900;
    final snapshot = _snapshot();
    var activeDomains = _activeDomains(snapshot);
    if (activeDomains.isEmpty) {
      activeDomains = _domainsFromReasons(widget.reasons);
    }
    final awwRows = activeDomains.expand(_awwTasksForDomain).toList();
    final caregiverRows = activeDomains.expand(_caregiverTasksForDomain).toList();
    final awwDailyRows = _engineBy(stakeholder: 'aww', frequencyType: 'daily');
    final awwWeeklyRows = _engineBy(stakeholder: 'aww', frequencyType: 'weekly');
    final caregiverDailyRows = _engineBy(stakeholder: 'caregiver', frequencyType: 'daily');
    final caregiverWeeklyRows = _engineBy(stakeholder: 'caregiver', frequencyType: 'weekly');
    final caregiverMgmtRows = <_EngineActivity>[...caregiverDailyRows, ...caregiverWeeklyRows];
    final awwMgmtRows = <_EngineActivity>[...awwDailyRows, ...awwWeeklyRows];
    final fallbackSeverity = _severityFromSnapshot(
      activeDomains,
      ((snapshot['LC'] == 'Critical' || snapshot['LC'] == 'High') &&
              (snapshot['SE'] == 'Critical' || snapshot['SE'] == 'High'))
          ? 'High'
          : 'Low',
    );
    final phaseSeverity = _engineSeverity.isEmpty ? fallbackSeverity : _engineSeverity;
    final phaseWeeks = _enginePhaseWeeks > 0 ? _enginePhaseWeeks : _totalWeeksForSeverity(phaseSeverity);
    final expectedWindow = _engineExpectedWindow.isNotEmpty ? _engineExpectedWindow : _expectedImprovementWindow(phaseSeverity);
    final targetMilestone = _engineTargetMilestone.isNotEmpty ? _engineTargetMilestone : _targetMilestone(activeDomains);
    final phaseReviewDays = _engineReviewCycleDays > 0 ? _engineReviewCycleDays : _reviewDaysForSeverity(phaseSeverity);
    final referralStatus = _appointments.isEmpty ? _referralStatus() : _computedReferralStatus;
    final currentWeek = _phaseCurrentWeek(phaseWeeks);
    _ensureTaskState(awwRows, caregiverRows);
    final awwChecked = _checkedCount(_awwTaskChecks, awwRows);
    final caregiverChecked = _checkedCount(_caregiverTaskChecks, caregiverRows);
    final checklistChecked = _awwChecklist.values.where((v) => v).length;
    final checklistTotal = _awwChecklist.length;
    final checklistCompletion = checklistTotal == 0 ? 0 : ((checklistChecked / checklistTotal) * 100).round();
    int awwCompletion;
    int caregiverCompletion;
    int combinedAdherence;
    var awwEngineTotal = 0;
    var awwEngineDone = 0;
    var caregiverEngineTotal = 0;
    var caregiverEngineDone = 0;
    if (_engineActivities.isNotEmpty) {
      final awwBucket = _engineActivities.where((a) => a.stakeholder == 'aww' && a.weekNumber == currentWeek).toList();
      for (final row in awwBucket) {
        final req = row.requiredCount <= 0 ? 1 : row.requiredCount;
        awwEngineTotal += req;
        awwEngineDone += row.completedCount > req ? req : row.completedCount;
      }
      final caregiverBucket = _engineActivities.where((a) => a.stakeholder == 'caregiver' && a.weekNumber == currentWeek).toList();
      for (final row in caregiverBucket) {
        final req = row.requiredCount <= 0 ? 1 : row.requiredCount;
        caregiverEngineTotal += req;
        caregiverEngineDone += row.completedCount > req ? req : row.completedCount;
      }
      awwCompletion = _completionPercentForStakeholder('aww', currentWeek);
      caregiverCompletion = _completionPercentForStakeholder('caregiver', currentWeek);
      combinedAdherence = _engineCompliancePercent > 0
          ? _engineCompliancePercent
          : ((awwCompletion + caregiverCompletion) / 2).round();
    } else {
      awwCompletion = awwRows.isEmpty ? 0 : ((awwChecked / awwRows.length) * 100).round();
      caregiverCompletion = caregiverRows.isEmpty ? 0 : ((caregiverChecked / caregiverRows.length) * 100).round();
      combinedAdherence = ((awwCompletion + caregiverCompletion + checklistCompletion) / 3).round();
    }
    final dailyCoreEngineRows = _engineActivities
        .where((a) => a.activityType == 'daily_core' && a.weekNumber == currentWeek)
        .toList();
    final weeklyTargetEngineRows = _engineActivities
        .where((a) => a.activityType == 'weekly_target' && a.weekNumber == currentWeek)
        .toList();
    final delayCount = snapshot.values.where((v) => v != 'Normal').length;
    final autismRisk = ((snapshot['LC'] == 'Critical' || snapshot['LC'] == 'High') &&
            (snapshot['SE'] == 'Critical' || snapshot['SE'] == 'High'))
        ? 'Elevated'
        : 'Low';
    final adhdRisk = _adhdRisk(snapshot);
    final stimulationScore = _stimulationScore(snapshot);
    final baselineLc = _previous == null ? _delayMonths(_latest?.domainScores['LC']) : _delayMonths(_previous!.domainScores['LC']);
    final followupLc = _delayMonths(_latest?.domainScores['LC']);
    final lcGain = (baselineLc - followupLc).clamp(0, 99);
    final totalImprovement = _totalImprovement();
    final decision = _engineEscalationDecision == 'Continue'
        ? _nextDecision(totalImprovement: totalImprovement, adherencePercent: combinedAdherence)
        : _engineEscalationDecision;
    final projectedOutcome = _engineProjection.isNotEmpty
        ? _engineProjection
        : _projectedOutcome(totalImprovement: totalImprovement, adherencePercent: combinedAdherence);
    final improvementRate = _cohortLcCritical == 0 ? 0 : ((_cohortLcImproved / _cohortLcCritical) * 100).round();
    final needsEscalation = combinedAdherence < 40 || totalImprovement < 0 || decision.toLowerCase().contains('escalate');
    final reviewDecision = totalImprovement > 2
        ? 'Continue Phase'
        : (combinedAdherence < 50 ? 'Intensify' : (needsEscalation ? 'Refer' : 'Continue Phase'));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFF3F7FB), Color(0xFFE9F1F8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Container(
                height: isWide ? 180 : 150,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: <Color>[Color(0xFF0D47A1), Color(0xFF1976D2)]),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Align(alignment: Alignment.topRight, child: const LanguageMenuButton(iconColor: Colors.white)),
                    Text(l10n.t('govt_andhra_pradesh'), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Problem B - Intervention Lifecycle', style: TextStyle(color: Colors.white, fontSize: isWide ? 22 : 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 920),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _sectionCard(
                                  'Referral Decision Block',
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: <Widget>[
                                          _infoTile('Referral ID', widget.referralId),
                                          _infoTile(l10n.t('child_id'), widget.childId),
                                          _infoTile(l10n.t('referral_type'), widget.referralType),
                                          _infoTile(l10n.t('urgency'), widget.urgency),
                                          _infoTile('Referral Status', referralStatus),
                                          _infoTile(l10n.t('created_on'), _formatDate(widget.createdAt)),
                                          _infoTile(l10n.t('follow_up_by'), _formatDate(widget.expectedFollowUpDate)),
                                          _infoTile('Days Since Referral', '${_daysSinceReferral()}'),
                                        ],
                                      ),
                                      if (_isReferralDelayed())
                                        Container(
                                          margin: const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF3E0),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFFFB74D)),
                                          ),
                                          child: Row(
                                            children: <Widget>[
                                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFF57C00)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Referral delayed: follow-up date ${_formatDate(widget.expectedFollowUpDate)} has passed.',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: <Widget>[
                                          const Text('Update status'),
                                          DropdownButton<String>(
                                            value: referralStatus,
                                            items: const <String>[
                                              'Pending',
                                              'Appointment Scheduled',
                                              'Completed',
                                              'Under Treatment',
                                            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                            onChanged: (v) {
                                              if (v != null) _setReferralStatus(v);
                                            },
                                          ),
                                          Text(
                                            'Suggested: $_suggestedReferralStatus',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: 240,
                                        child: ElevatedButton.icon(
                                          onPressed: _createAppointment,
                                          icon: const Icon(Icons.calendar_month_outlined, size: 18),
                                          label: const Text('Schedule Appointment'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _appointmentsCard(),
                                _sectionCard(
                                  'Child Development Snapshot',
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _domains.map((d) {
                                          final s = snapshot[d] ?? 'Normal';
                                          final color = _riskColor(s);
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                            child: Text('$d: $s', style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 10),
                                      _kv('Number of delays', '$delayCount'),
                                      _kv('Risk category', widget.overallRisk.toUpperCase()),
                                      _kv('Priority score', '${_priorityScore()}/40'),
                                      _kv('Autism risk', autismRisk),
                                      _kv('ADHD risk', adhdRisk),
                                      _kv('Stimulation score', '$stimulationScore/100'),
                                    ],
                                  ),
                                ),
                                _sectionCard(
                                  'Explainable Risk Logic',
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      if (snapshot['LC'] == 'Critical') _bullet('LC delay is critical.'),
                                      if (baselineLc >= 4) _bullet('Delay severity exceeds 4 months.'),
                                      if (_priorityScore() > 25) _bullet('Priority risk score is above 25.'),
                                      ...widget.reasons.map((r) => _bullet('Trigger: $r')),
                                    ],
                                  ),
                                ),
                                _sectionCard(
                                  'Personalized Intervention Plan (Detected Issues Only)',
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        activeDomains.isEmpty
                                            ? 'No active delayed domains in latest screening.'
                                            : 'Multi-domain merge: ${activeDomains.join(' + ')}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 8),
                                      if (activeDomains.isNotEmpty) ...activeDomains.map(
                                        (domain) => _kv(
                                          domain,
                                          'AWW: ${_centerPlan(domain).join(' | ')} | Home: ${_homePlan(domain).join(' | ')}',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _sectionCard(
                                  'Intervention Phase Plan',
                                  Column(
                                    children: <Widget>[
                                      _kv('Severity', _normalizedSeverity(phaseSeverity)),
                                      _kv('Phase duration', '$phaseWeeks weeks'),
                                      _kv('Expected improvement window', expectedWindow),
                                      _kv('Daily time commitment', '20 minutes'),
                                      _kv('Review interval', '$phaseReviewDays days'),
                                      _kv('Phase start', _formatDate(_enginePhaseStartDate ?? widget.createdAt)),
                                      _kv('Phase end', _formatDate(_enginePhaseEndDate ?? widget.createdAt.add(Duration(days: phaseWeeks * 7)))),
                                      _kv('Target milestone', targetMilestone),
                                    ],
                                  ),
                                ),
                                _sectionCard(
                                  'Compliance Indicator',
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      _kv('Weekly compliance', '$combinedAdherence%'),
                                      _kv('Projected improvement', projectedOutcome),
                                      _kv('Dynamic action', _engineComplianceAction),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          minHeight: 10,
                                          value: combinedAdherence / 100,
                                          backgroundColor: const Color(0xFFE3E8F2),
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            combinedAdherence >= 80
                                                ? const Color(0xFF43A047)
                                                : combinedAdherence >= 50
                                                    ? const Color(0xFF1E88E5)
                                                    : const Color(0xFFE53935),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _phaseTimelineCard(
                                  phaseWeeks: phaseWeeks,
                                  currentWeek: currentWeek,
                                ),
                                _phaseLifecycleStagesCard(
                                  phaseWeeks: phaseWeeks,
                                  phaseStart: _enginePhaseStartDate ?? widget.createdAt,
                                ),
                                _complianceThresholdCard(
                                  adherencePercent: combinedAdherence,
                                  totalImprovement: totalImprovement,
                                ),
                                _sectionCard(
                                  'Daily Core Routine (Mandatory)',
                                  dailyCoreEngineRows.isEmpty
                                      ? const Text('No mandatory daily routine detected for current delayed domains.')
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            columns: const <DataColumn>[
                                              DataColumn(label: Text('Domain')),
                                              DataColumn(label: Text('Activity')),
                                              DataColumn(label: Text('Duration')),
                                              DataColumn(label: Text('Status')),
                                            ],
                                            rows: dailyCoreEngineRows.map((row) {
                                              final done = row.status == 'completed';
                                              return DataRow(cells: <DataCell>[
                                                DataCell(Text(row.domain)),
                                                DataCell(SizedBox(width: 320, child: Text(row.title))),
                                                DataCell(Text('${row.durationMinutes} min')),
                                                DataCell(
                                                  Checkbox(
                                                    value: done,
                                                    onChanged: (v) => _markEngineActivity(row, v ?? false),
                                                  ),
                                                ),
                                              ]);
                                            }).toList(),
                                          ),
                                        ),
                                ),
                                _sectionCard(
                                  'Weekly Target Skills (Reinforcement) - Week $currentWeek/$phaseWeeks',
                                  weeklyTargetEngineRows.isEmpty
                                      ? const Text('No weekly reinforcement activities for this phase.')
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            columns: const <DataColumn>[
                                              DataColumn(label: Text('Domain')),
                                              DataColumn(label: Text('Activity')),
                                              DataColumn(label: Text('Target/Week')),
                                              DataColumn(label: Text('Progress')),
                                            ],
                                            rows: weeklyTargetEngineRows.map((row) {
                                              final target = row.requiredCount;
                                              final progress = row.completedCount;
                                              return DataRow(cells: <DataCell>[
                                                DataCell(Text(row.domain)),
                                                DataCell(SizedBox(width: 320, child: Text(row.title))),
                                                DataCell(Text('$target times')),
                                                DataCell(Text('$progress/$target')),
                                              ]);
                                            }).toList(),
                                          ),
                                        ),
                                ),
                                _sectionCard(
                                  'Phase Progression Tracker (Week 1 - Week $phaseWeeks)',
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const <DataColumn>[
                                        DataColumn(label: Text('Week')),
                                        DataColumn(label: Text('Completion %')),
                                        DataColumn(label: Text('Notes')),
                                      ],
                                      rows: List<DataRow>.generate(phaseWeeks, (index) {
                                        final week = index + 1;
                                        final isFuture = week > currentWeek;
                                        final completion = isFuture ? 0 : _weeklyCompletionForWeek(week);
                                        final note = isFuture ? 'Planned' : _weeklyNoteForWeek(week, completion);
                                        return DataRow(cells: <DataCell>[
                                          DataCell(Text('Week $week')),
                                          DataCell(Text(isFuture ? '-' : '$completion%')),
                                          DataCell(Text(note)),
                                        ]);
                                      }),
                                    ),
                                  ),
                                ),
                                _sectionCard(
                                  'AI Activity Engine (Age + Severity Adaptive)',
                                  Column(
                                    children: <Widget>[
                                      _kv('Age band', _engineAgeBand.isEmpty ? _classifyAgeBand(widget.ageMonths) : _engineAgeBand),
                                      _kv('Severity level', _engineSeverity.isEmpty ? _severityFromSnapshot(activeDomains, autismRisk) : _engineSeverity),
                                      _kv('Review cycle', '$_engineReviewCycleDays days'),
                                      _kv('Compliance action', _engineComplianceAction),
                                      _kv('Projected improvement', _engineProjection),
                                      _kv('Escalation decision', _engineEscalationDecision),
                                      _kv('Total generated activities', '${_engineActivities.length}'),
                                    ],
                                  ),
                                ),
                                _engineTable(
                                  title: 'AWW Daily Plan (Today)',
                                  rows: awwDailyRows,
                                ),
                                _engineTable(
                                  title: 'AWW Weekly Plan',
                                  rows: awwWeeklyRows,
                                ),
                                _engineTable(
                                  title: 'Caregiver Daily Plan (Today)',
                                  rows: caregiverDailyRows,
                                ),
                                _engineTable(
                                  title: 'Caregiver Weekly Goals',
                                  rows: caregiverWeeklyRows,
                                ),
                                _assignmentManagementCard(
                                  title: 'Caregiver Assigned Intervention Tasks - Daily Management',
                                  stakeholder: 'Caregiver',
                                  fromDate: _caregiverFromDate ?? (_enginePhaseStartDate ?? widget.createdAt),
                                  toDate: _caregiverToDate ?? (_enginePhaseEndDate ?? widget.expectedFollowUpDate),
                                  domainFilter: _caregiverDomainFilter,
                                  onFromPicked: (d) => _caregiverFromDate = d,
                                  onToPicked: (d) => _caregiverToDate = d,
                                  onDomainChanged: (v) => setState(() => _caregiverDomainFilter = v),
                                  selectedWeekIndex: _caregiverWeekIndex,
                                  onWeekChanged: (v) => setState(() => _caregiverWeekIndex = v),
                                  rows: caregiverMgmtRows,
                                ),
                                _assignmentManagementCard(
                                  title: 'AWW Assigned Intervention Tasks - Daily Management',
                                  stakeholder: 'AWW',
                                  fromDate: _awwFromDate ?? (_enginePhaseStartDate ?? widget.createdAt),
                                  toDate: _awwToDate ?? (_enginePhaseEndDate ?? widget.expectedFollowUpDate),
                                  domainFilter: _awwDomainFilter,
                                  onFromPicked: (d) => _awwFromDate = d,
                                  onToPicked: (d) => _awwToDate = d,
                                  onDomainChanged: (v) => setState(() => _awwDomainFilter = v),
                                  selectedWeekIndex: _awwWeekIndex,
                                  onWeekChanged: (v) => setState(() => _awwWeekIndex = v),
                                  rows: awwMgmtRows,
                                ),
                                _taskTable(
                                  title: 'AWW Tasks Table (Issue-Specific)',
                                  rows: awwRows,
                                  state: _awwTaskChecks,
                                ),
                                _taskTable(
                                  title: 'Caregiver Activities Table (Issue-Specific)',
                                  rows: caregiverRows,
                                  state: _caregiverTaskChecks,
                                ),
                                _sectionCard('Intervention Intensity Level', Column(children: <Widget>[_kv('Intensity', _intensity()), _kv('Trend', _trend())])),
                                _sectionCard(
                                  'Caregiver Engagement Module',
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          ChoiceChip(label: const Text('Smartphone'), selected: _parentMode == 'Smartphone', onSelected: (_) => setState(() => _parentMode = 'Smartphone')),
                                          const SizedBox(width: 8),
                                          ChoiceChip(label: const Text('Keypad'), selected: _parentMode == 'Keypad', onSelected: (_) => setState(() => _parentMode = 'Keypad')),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...(_parentMode == 'Smartphone'
                                              ? <String>['Send WhatsApp reminder', 'Send video demo', 'Send weekly progress nudge']
                                              : <String>['IVR call', 'Printed activity card', 'AWW demonstration'])
                                          .map(_bullet),
                                    ],
                                  ),
                                ),
                                _sectionCard(
                                  'AWW Action Checklist',
                                  Column(
                                    children: _awwChecklist.entries
                                        .map((e) => CheckboxListTile(
                                              contentPadding: EdgeInsets.zero,
                                              value: e.value,
                                              onChanged: (v) => setState(() => _awwChecklist[e.key] = v ?? false),
                                              title: Text(e.key, style: const TextStyle(fontSize: 12)),
                                            ))
                                        .toList(),
                                  ),
                                ),
                                _sectionCard(
                                  'Dynamic Progress Tracking',
                                  Column(
                                    children: <Widget>[
                                      _kv('Baseline LC delay', '$baselineLc months'),
                                      _kv('Follow-up LC delay', '$followupLc months'),
                                      _kv('Improvement', '$lcGain months'),
                                      _kv('Trend', _trend()),
                                      _kv(
                                        'AWW task completion',
                                        _engineActivities.isNotEmpty
                                            ? '$awwEngineDone/$awwEngineTotal ($awwCompletion%)'
                                            : '$awwChecked/${awwRows.length} ($awwCompletion%)',
                                      ),
                                      _kv(
                                        'Caregiver task completion',
                                        _engineActivities.isNotEmpty
                                            ? '$caregiverEngineDone/$caregiverEngineTotal ($caregiverCompletion%)'
                                            : '$caregiverChecked/${caregiverRows.length} ($caregiverCompletion%)',
                                      ),
                                      _kv('Checklist completion', '$checklistChecked/$checklistTotal ($checklistCompletion%)'),
                                      _kv('Combined adherence', '$combinedAdherence%'),
                                      _kv('Projected effect', projectedOutcome),
                                      const SizedBox(height: 8),
                                      if (activeDomains.isNotEmpty)
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            columns: const <DataColumn>[
                                              DataColumn(label: Text('Domain')),
                                              DataColumn(label: Text('Previous delay')),
                                              DataColumn(label: Text('Current delay')),
                                              DataColumn(label: Text('Improvement')),
                                              DataColumn(label: Text('Trend')),
                                            ],
                                            rows: activeDomains.map((domain) {
                                              final prev = _delayMonths(_previous?.domainScores[domain]);
                                              final curr = _delayMonths(_latest?.domainScores[domain]);
                                              final improve = (prev - curr).clamp(0, 99);
                                              final trend = curr < prev
                                                  ? 'Improving'
                                                  : (curr == prev ? 'Stable' : 'Worsening');
                                              return DataRow(
                                                cells: <DataCell>[
                                                  DataCell(Text(domain)),
                                                  DataCell(Text('$prev m')),
                                                  DataCell(Text('$curr m')),
                                                  DataCell(Text('$improve m')),
                                                  DataCell(Text(trend)),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                _sectionCard(
                                  'Referral Status Tracker',
                                  Column(
                                    children: <Widget>[
                                      _kv('Current status', _referralStatus()),
                                      _kv('Days since referral', '${_daysSinceReferral()}'),
                                      _kv('Progress steps', 'Pending -> Appointment Scheduled -> Completed -> Under Treatment'),
                                    ],
                                  ),
                                ),
                                _sectionCard(
                                  'Next Review Decision Logic',
                                  Column(
                                    children: <Widget>[
                                      _kv('Decision', decision),
                                      _kv('Rule basis', 'Improvement: $totalImprovement | Adherence: $combinedAdherence%'),
                                    ],
                                  ),
                                ),
                                _sectionCard(
                                  'Monthly / Review Assessment',
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      _kv('Baseline delay (LC)', '$baselineLc months'),
                                      _kv('Current delay (LC)', '$followupLc months'),
                                      _kv('Improvement', '$lcGain months'),
                                      _kv('Status', _trend()),
                                      _kv('Recommended action', reviewDecision),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: <Widget>[
                                          OutlinedButton(
                                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Decision saved: Continue Phase')),
                                            ),
                                            child: const Text('Continue Phase'),
                                          ),
                                          OutlinedButton(
                                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Decision saved: Intensify')),
                                            ),
                                            child: const Text('Intensify'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Decision saved: Refer')),
                                            ),
                                            child: const Text('Refer'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                _planRegenerationCard(
                                  decision: reviewDecision,
                                  currentActivityCount: _engineActivities.length,
                                  phaseWeeks: phaseWeeks,
                                ),
                                if (needsEscalation)
                                  _sectionCard(
                                    'Escalation & Referral Logic',
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        _kv('Escalation status', 'Triggered'),
                                        _kv('Reason', combinedAdherence < 40
                                            ? 'Compliance below 40%'
                                            : (totalImprovement < 0
                                                ? 'Worsening trend in follow-up'
                                                : 'Rule engine escalation')),
                                        _kv('Action', 'Specialist referral review recommended'),
                                        _kv('Urgency', widget.urgency),
                                      ],
                                    ),
                                  ),
                                _sectionCard(
                                  'Expected Outcome & Escalation Logic',
                                  Column(
                                    children: <Widget>[
                                      _kv('Projected improvement score', projectedOutcome),
                                      _kv('Next review date', _formatDate(widget.expectedFollowUpDate)),
                                      _kv('Escalation rule 1', 'If no improvement for 2 reviews -> Escalate'),
                                      _kv('Escalation rule 2', 'If adherence < 30% -> Consider referral'),
                                      _kv('Escalation rule 3', 'If worsening trend -> Specialist review'),
                                    ],
                                  ),
                                ),
                                _sectionCard(
                                  'Impact Indicator',
                                  Column(
                                    children: <Widget>[
                                      _kv('Children with LC Critical in this AWC', '$_cohortLcCritical'),
                                      _kv('Children improved after intervention', '$_cohortLcImproved'),
                                      _kv('Improvement rate', '$improvementRate%'),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.of(context).pop(),
                                    icon: const Icon(Icons.check_circle_outline),
                                    label: Text(l10n.t('close')),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskRow {
  final String domain;
  final String activity;
  final String frequency;

  const _TaskRow({
    required this.domain,
    required this.activity,
    required this.frequency,
  });
}

class _EngineActivity {
  final String activityId;
  final String domain;
  final String stakeholder;
  final String frequencyType;
  final String activityType;
  final String title;
  final String description;
  final String status;
  final int durationMinutes;
  final int weekNumber;
  final int requiredCount;
  final int completedCount;
  final DateTime assignedDate;

  const _EngineActivity({
    required this.activityId,
    required this.domain,
    required this.stakeholder,
    required this.frequencyType,
    required this.activityType,
    required this.title,
    required this.description,
    required this.status,
    required this.durationMinutes,
    required this.weekNumber,
    required this.requiredCount,
    required this.completedCount,
    required this.assignedDate,
  });

  factory _EngineActivity.fromJson(Map<String, dynamic> json) {
    return _EngineActivity(
      activityId: json['activity_id']?.toString() ?? '',
      domain: json['domain']?.toString() ?? '',
      stakeholder: json['stakeholder']?.toString() ?? '',
      frequencyType: json['frequency_type']?.toString() ?? '',
      activityType: json['activity_type']?.toString() ?? 'weekly_target',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      durationMinutes: int.tryParse(json['duration_minutes']?.toString() ?? '') ?? 10,
      weekNumber: int.tryParse(json['week_number']?.toString() ?? '') ?? 1,
      requiredCount: int.tryParse(json['required_count']?.toString() ?? '') ?? 1,
      completedCount: int.tryParse(json['completed_count']?.toString() ?? '') ?? 0,
      assignedDate: DateTime.tryParse(json['assigned_date']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  _EngineActivity copyWith({
    String? status,
    int? completedCount,
  }) {
    return _EngineActivity(
      activityId: activityId,
      domain: domain,
      stakeholder: stakeholder,
      frequencyType: frequencyType,
      activityType: activityType,
      title: title,
      description: description,
      status: status ?? this.status,
      durationMinutes: durationMinutes,
      weekNumber: weekNumber,
      requiredCount: requiredCount,
      completedCount: completedCount ?? this.completedCount,
      assignedDate: assignedDate,
    );
  }
}

class _EngineWeekProgress {
  final int weekNumber;
  final int completionPercentage;
  final String reviewNotes;

  const _EngineWeekProgress({
    required this.weekNumber,
    required this.completionPercentage,
    required this.reviewNotes,
  });

  factory _EngineWeekProgress.fromJson(Map<String, dynamic> json) {
    return _EngineWeekProgress(
      weekNumber: int.tryParse(json['week_number']?.toString() ?? '') ?? 1,
      completionPercentage: int.tryParse(json['completion_percentage']?.toString() ?? '') ?? 0,
      reviewNotes: json['review_notes']?.toString() ?? 'Planned',
    );
  }
}

class _WeekRange {
  final int weekNumber;
  final DateTime start;
  final DateTime end;

  const _WeekRange(this.weekNumber, this.start, this.end);
}
class _Appointment {
  final String appointmentId;
  final String referralId;
  final String childId;
  final DateTime scheduledDate;
  final String appointmentType;
  final String status;
  final String notes;

  const _Appointment({
    required this.appointmentId,
    required this.referralId,
    required this.childId,
    required this.scheduledDate,
    required this.appointmentType,
    required this.status,
    required this.notes,
  });

  factory _Appointment.fromJson(Map<String, dynamic> json) {
    return _Appointment(
      appointmentId: json['appointment_id']?.toString() ?? '',
      referralId: json['referral_id']?.toString() ?? '',
      childId: json['child_id']?.toString() ?? '',
      scheduledDate: DateTime.tryParse(json['scheduled_date']?.toString() ?? '') ?? DateTime.now(),
      appointmentType: json['appointment_type']?.toString() ?? 'Follow-up',
      status: json['status']?.toString() ?? 'SCHEDULED',
      notes: json['notes']?.toString() ?? '',
    );
  }

  static _Appointment empty() {
    return _Appointment(
      appointmentId: '',
      referralId: '',
      childId: '',
      scheduledDate: DateTime.now(),
      appointmentType: 'Follow-up',
      status: 'SCHEDULED',
      notes: '',
    );
  }
}
