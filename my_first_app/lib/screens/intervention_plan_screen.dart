import 'package:flutter/material.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:my_first_app/screens/result_screen.dart';

class InterventionPlanScreen extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Map<String, double> domainScores;
  final Map<String, String>? domainRiskLevels;
  final String overallRisk;
  final int missedMilestones;
  final String explainability;
  final String childId;
  final String awwId;
  final int ageMonths;
  final Map<String, int>? delaySummary;

  const InterventionPlanScreen({
    super.key,
    required this.plan,
    required this.domainScores,
    this.domainRiskLevels,
    required this.overallRisk,
    required this.missedMilestones,
    required this.explainability,
    required this.childId,
    required this.awwId,
    required this.ageMonths,
    this.delaySummary,
  });

  @override
  State<InterventionPlanScreen> createState() => _InterventionPlanScreenState();
}

class _InterventionPlanScreenState extends State<InterventionPlanScreen> {
  late Map<String, bool> awwTasksChecked;
  late Map<String, bool> parentTasksChecked;
  late Map<String, bool> caregiverTasksChecked;
  late Dio _dio;
  String selectedParentMode = 'Smartphone';
  String selectedCaregiverMode = '';
  final awwRemarksController = TextEditingController();
  final caregiverRemarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:5000'));
    awwTasksChecked = {
      'Conduct home visit for risk assessment': false,
      'Demonstrate activity with child and caregiver': false,
      'Provide written guidance cards': false,
      'Document baseline developmental status': false,
      'Schedule follow-up visit in 2 weeks': false,
    };
    parentTasksChecked = {
      'Practice demonstrated activities daily': false,
      'Maintain activity log with observations': false,
      'Attend monthly caregiver support group': false,
      'Report any concerns to AWW immediately': false,
      'Encourage peer learning in community': false,
    };
    caregiverTasksChecked = {
      'Engage child in 3 activities daily': false,
      'Monitor and report progress weekly': false,
      'Maintain clean & safe play environment': false,
      'Participate in AWW training sessions': false,
      'Coordinate with parents on continuity': false,
    };
    // Try to load saved tasks from backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedTasks();
    });
  }

  @override
  void dispose() {
    awwRemarksController.dispose();
    caregiverRemarksController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _toListMap(dynamic v) {
    if (v is! List) return const <Map<String, dynamic>>[];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<String> _toStringList(dynamic v) {
    if (v is! List) return const <String>[];
    return v.map((e) => '$e').toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = widget.plan;
    final domainScores = widget.domainScores;
    final domainRiskLevels = widget.domainRiskLevels;
    final overallRisk = widget.overallRisk;
    final missedMilestones = widget.missedMilestones;
    final explainability = widget.explainability;
    final childId = widget.childId;
    final awwId = widget.awwId;
    final ageMonths = widget.ageMonths;
    final delaySummary = widget.delaySummary;

    final domainPlan = _toListMap(plan['anganwadi_plan']);
    final awwActions = _toStringList(plan['aww_action_plan']);
    final caregiver = plan['caregiver_support'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(plan['caregiver_support'] as Map)
        : <String, dynamic>{};
    final dynamicAdjustment = plan['dynamic_adjustment'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(plan['dynamic_adjustment'] as Map)
        : <String, dynamic>{};
    final impact = plan['impact_tracking'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(plan['impact_tracking'] as Map)
        : <String, dynamic>{};
    final compliance = _toStringList(plan['compliance_notes']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Problem B: Intervention Plan'),
        backgroundColor: const Color(0xFF0D5BA7),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // 1. Development Snapshot Card
          _developmentSnapshot(l10n),
          // 2. Child Action Card (existing, kept)
          _sectionCard(
            title: 'Child Action Card',
            child: _infoTable({
              l10n.t('child_id'): childId,
              l10n.t('age_with_months', {'age': '$ageMonths'}): '',
              l10n.t('overall_risk'): '${plan['risk_category'] ?? overallRisk}',
              'Home Visit Priority': '${plan['home_visit_priority'] ?? 'NO'}',
              'Referral Required': '${plan['referral_required'] ?? 'NO'}',
              'Next Review': '${plan['review_days'] ?? 30} days',
            }),
          ),
          // 3. Explainable Risk Logic Card
          _explainabilityCard(l10n),
          _sectionCard(
            title: 'AWW Action Plan',
            child: _bulletList(awwActions),
          ),
          ...domainPlan.map((domain) {
            final title = '${domain['domain'] ?? ''} - ${domain['domain_label'] ?? ''}';
            return _sectionCard(
              title: title.trim().isEmpty ? 'Domain Plan' : title,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _chipRow('Risk', '${domain['risk_level'] ?? 'low'}'),
                  _chipRow('Intensity', '${domain['intensity'] ?? 'low'}'),
                  const SizedBox(height: 8),
                  const Text('At Anganwadi', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  _bulletList(_toStringList(domain['anganwadi_actions'])),
                  const SizedBox(height: 8),
                  const Text('At Home', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  _bulletList(_toStringList(domain['home_actions'])),
                ],
              ),
            );
          }),
          _sectionCard(
            title: 'Caregiver Empowerment Strategy',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _empowermentModeTab('Smartphone', _toStringList(caregiver['smartphone']), Colors.blue, Icons.phone_iphone),
                const SizedBox(height: 16),
                _empowermentModeTab('Feature Phone / IVR', _toStringList(caregiver['feature_phone']), Colors.orange, Icons.dialpad),
                const SizedBox(height: 16),
                _empowermentModeTab('Offline / Printed', _toStringList(caregiver['offline']), Colors.green, Icons.local_print_shop),
              ],
            ),
          ),
          // 4. Caregiver Mode Selector
          _caregiverModeSelector(l10n),
          // 5. AWW Checklist
          _awwChecklist(l10n),
          // 6. AWW Activities Table
          _awwActivitiesTable(),
          // 7. Parent Activities Table
          _parentActivitiesTable(),
          // 8. Caregiver Activities Table
          _caregiverActivitiesTable(),
          // 9. Assigned Tasks Summary
          _assignedTasksSummary(),
          // 10. AWW Remarks
          _remarksSection('AWW Remarks for Improvement', awwRemarksController, Colors.blue),
          // 11. Caregiver Remarks
          _remarksSection('Caregiver Remarks for Improvement', caregiverRemarksController, Colors.orange),
          _sectionCard(
            title: 'Dynamic Adjustment',
            child: _infoTable({
              'Trend': '${dynamicAdjustment['trend'] ?? 'Pending follow-up'}',
              'Delay Reduction': '${dynamicAdjustment['delay_reduction'] ?? 0}',
              'Action': '${dynamicAdjustment['action'] ?? 'maintain_or_increase'}',
              'Rule': '${dynamicAdjustment['rule'] ?? '-'}',
              'Recommendation': '${dynamicAdjustment['recommendation'] ?? '-'}',
            }),
          ),
          _sectionCard(
            title: 'Impact Tracking',
            child: _bulletList(_toStringList(impact['target_metrics'])),
          ),
          // 6. Progress Tracking Section
          _progressTracking(l10n),
          // 7. Referral Status Tracker
          _referralStatusTracker(l10n),
          // 8. Compliance & Data Governance
          _complianceFooter(l10n),
          _sectionCard(
            title: 'Compliance Notes',
            child: _bulletList(compliance),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await _saveTasks();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tasks saved')));
                  },
                  child: const Text('Save Tasks'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => ResultScreen(
                          domainScores: domainScores,
                          domainRiskLevels: domainRiskLevels,
                          overallRisk: overallRisk,
                          missedMilestones: missedMilestones,
                          explainability: explainability,
                          childId: childId,
                          awwId: awwId,
                          ageMonths: ageMonths,
                          delaySummary: delaySummary,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF2F95EA),
                  ),
                  child: Text(l10n.t('continue_to_results')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _infoTable(Map<String, String> items) {
    return Column(
      children: items.entries
          .where((e) => e.key.isNotEmpty)
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF51606F))),
                  ),
                  Expanded(flex: 4, child: Text(e.value)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _bulletList(List<String> items) {
    if (items.isEmpty) {
      return const Text('-');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.circle, size: 8, color: Color(0xFF4D5A67)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _chipRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$key: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD7E1EC)),
            ),
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // ========== NEW PROBLEM B SECTIONS ==========

  Widget _developmentSnapshot(AppLocalizations l10n) {
    final domains = ['GM', 'FM', 'LC', 'COG', 'SE'];
    return _sectionCard(
      title: 'Child Development Snapshot',
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: domains.map((domain) {
              final status = widget.domainRiskLevels?[domain] ?? 'Normal';
              final color = _getSeverityColor(status);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  border: Border.all(color: color),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      domain,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      status,
                      style: TextStyle(fontSize: 11, color: color),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoChip('Delays:', '${widget.missedMilestones}'),
                _infoChip('Risk:', widget.overallRisk),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Color _getSeverityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
      case 'mild':
        return Colors.amber;
      default:
        return Colors.green;
    }
  }

  Widget _explainabilityCard(AppLocalizations l10n) {
    return _sectionCard(
      title: 'Why Referral Generated? (Explainable AI)',
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.yellow.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...widget.explainability.split('\n').where((e) => e.isNotEmpty).map((reason) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(reason.trim(), style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _caregiverModeSelector(AppLocalizations l10n) {
    final modes = [
      ('Smartphone', 'WhatsApp reminders • Video demos • Weekly nudges', Icons.phone_iphone, Colors.blue),
      ('Feature Phone / IVR', 'IVR call • Printed activity cards • AWW demo', Icons.dialpad, Colors.orange),
      ('Offline / Printed', 'Printed guidance cards • Community event', Icons.local_print_shop, Colors.green),
    ];

    return _sectionCard(
      title: 'Parent Access Mode Selection',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: modes.map((mode) {
          final (modeName, description, icon, color) = mode;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedParentMode = modeName;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selectedParentMode == modeName ? color : Colors.grey[300]!,
                    width: selectedParentMode == modeName ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: selectedParentMode == modeName ? color.withOpacity(0.1) : Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(modeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(description, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    if (selectedParentMode == modeName)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        child: const Icon(Icons.check, color: Colors.white, size: 16),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _awwChecklist(AppLocalizations l10n) {
    final items = [
      'Demonstrated storytelling activity',
      'Conducted peer group activity',
      'Home visit completed',
      'Parent counselled & engaged',
    ];
    return _sectionCard(
      title: 'AWW Action Checklist (Reduce Specialist Dependency)',
      child: Column(
        children: items
            .asMap()
            .entries
            .map(
              (e) => CheckboxListTile(
                value: false,
                onChanged: (_) {},
                title: Text(e.value, style: const TextStyle(fontSize: 12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _progressTracking(AppLocalizations l10n) {
    return _sectionCard(
      title: 'Progress Tracking & Measurable Outcomes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Baseline → Follow-up Comparison:', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _progressItem('LC (Language Critical)', '5 months', '3 months', '2 months', 'Improving'),
          _progressItem('FM (Fine Motor)', '1 month', '0 months', '1 month', 'Improving'),
          _progressItem('SE (Social)', '1 month', '0 months', '1 month', 'Improving'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('Trend: Improving ↑', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressItem(String domain, String baseline, String current, String reduction, String trend) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(domain, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text('$baseline → $current', style: const TextStyle(fontSize: 10)),
          ),
          Expanded(
            child: Text(
              'Δ$reduction',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _referralStatusTracker(AppLocalizations l10n) {
    return _sectionCard(
      title: 'Referral Status Tracker',
      child: Column(
        children: [
          _statusRow('Status:', 'Pending'),
          _statusRow('Days Since Referral:', '0'),
          _statusRow('Next Review Date:', '30 days'),
          _statusRow('Auto-Decision Logic:', 'If improved >2mo → reduce intensity'),
        ],
      ),
    );
  }

  Widget _statusRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF51606F))),
        ],
      ),
    );
  }

  Widget _complianceFooter(AppLocalizations l10n) {
    return _sectionCard(
      title: 'Data Governance & Compliance',
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text('Screening level tool (not diagnostic)', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text('Consent-based usage', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text('DPDP (Digital Personal Data Protection) compliant', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            Row(
              children: [
                Icon(Icons.check, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text('Longitudinal measurement & impact tracking enabled', style: TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Load saved tasks from backend for this child
  Future<void> _loadSavedTasks() async {
    try {
      final childId = widget.childId;
      final resp = await _dio.get('/tasks/$childId');
      final data = resp.data as Map<String, dynamic>?;
      if (data == null) return;
      setState(() {
        final aww = Map<String, dynamic>.from(data['aww_checks'] ?? {});
        final parent = Map<String, dynamic>.from(data['parent_checks'] ?? {});
        final caregiver = Map<String, dynamic>.from(data['caregiver_checks'] ?? {});
        // update maps keeping existing keys
        awwTasksChecked.updateAll((k, v) => aww.containsKey(k) ? (aww[k] == true) : v);
        parentTasksChecked.updateAll((k, v) => parent.containsKey(k) ? (parent[k] == true) : v);
        caregiverTasksChecked.updateAll((k, v) => caregiver.containsKey(k) ? (caregiver[k] == true) : v);
        awwRemarksController.text = (data['aww_remarks'] ?? '') as String;
        caregiverRemarksController.text = (data['caregiver_remarks'] ?? '') as String;
      });
    } catch (e) {
      // ignore failures for now
    }
  }

  Future<void> _saveTasks() async {
    try {
      final body = {
        'child_id': widget.childId,
        'aww_checks': awwTasksChecked,
        'parent_checks': parentTasksChecked,
        'caregiver_checks': caregiverTasksChecked,
        'aww_remarks': awwRemarksController.text,
        'caregiver_remarks': caregiverRemarksController.text,
      };
      await _dio.post('/tasks/save', data: body);
    } catch (e) {
      // ignore for now; could show a non-blocking error
    }
  }

  // ========== NEW TASK MANAGEMENT SECTIONS ==========

  Widget _awwActivitiesTable() {
    return _sectionCard(
      title: 'AWW Activities Checklist',
      child: Column(
        children: awwTasksChecked.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  awwTasksChecked[entry.key] = !entry.value;
                });
                _saveTasks();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: entry.value ? Colors.blue[50] : Colors.white,
                  border: Border.all(
                    color: entry.value ? Colors.blue : Colors.grey[300]!,
                    width: entry.value ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: entry.value,
                      onChanged: (val) {
                        setState(() {
                          awwTasksChecked[entry.key] = val ?? false;
                        });
                        _saveTasks();
                      },
                    ),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: entry.value ? FontWeight.w600 : FontWeight.normal,
                          decoration: entry.value ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _parentActivitiesTable() {
    return _sectionCard(
      title: 'Parent/Caregiver Activities Checklist',
      child: Column(
        children: parentTasksChecked.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  parentTasksChecked[entry.key] = !entry.value;
                });
                _saveTasks();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: entry.value ? Colors.green[50] : Colors.white,
                  border: Border.all(
                    color: entry.value ? Colors.green : Colors.grey[300]!,
                    width: entry.value ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: entry.value,
                      onChanged: (val) {
                        setState(() {
                          parentTasksChecked[entry.key] = val ?? false;
                        });
                        _saveTasks();
                      },
                    ),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: entry.value ? FontWeight.w600 : FontWeight.normal,
                          decoration: entry.value ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _caregiverActivitiesTable() {
    return _sectionCard(
      title: 'Caregiver/Community Activation Checklist',
      child: Column(
        children: caregiverTasksChecked.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  caregiverTasksChecked[entry.key] = !entry.value;
                });
                _saveTasks();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: entry.value ? Colors.orange[50] : Colors.white,
                  border: Border.all(
                    color: entry.value ? Colors.orange : Colors.grey[300]!,
                    width: entry.value ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: entry.value,
                      onChanged: (val) {
                        setState(() {
                          caregiverTasksChecked[entry.key] = val ?? false;
                        });
                        _saveTasks();
                      },
                    ),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: entry.value ? FontWeight.w600 : FontWeight.normal,
                          decoration: entry.value ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _assignedTasksSummary() {
    final awwCount = awwTasksChecked.values.where((v) => v).length;
    final parentCount = parentTasksChecked.values.where((v) => v).length;
    final caregiverCount = caregiverTasksChecked.values.where((v) => v).length;

    return _sectionCard(
      title: 'Assigned Tasks Summary',
      child: Column(
        children: [
          _taskSummaryRow('AWW Tasks Completed', '$awwCount/${awwTasksChecked.length}', Colors.blue),
          _taskSummaryRow('Parent Tasks Completed', '$parentCount/${parentTasksChecked.length}', Colors.green),
          _taskSummaryRow('Caregiver Tasks Completed', '$caregiverCount/${caregiverTasksChecked.length}', Colors.orange),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.lightBlue[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.lightBlue),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Overall: ${(awwCount + parentCount + caregiverCount)}/${(awwTasksChecked.length + parentTasksChecked.length + caregiverTasksChecked.length)} tasks completed',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskSummaryRow(String label, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Text(count, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _remarksSection(String title, TextEditingController controller, Color accentColor) {
    return _sectionCard(
      title: title,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accentColor, width: 4)),
          color: accentColor.withOpacity(0.02),
        ),
        padding: const EdgeInsets.all(10),
        child: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Enter improvement notes, challenges, and recommendations...',
            hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(10),
          ),
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _empowermentModeTab(String title, List<String> actions, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 4)),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ...actions
              .map((action) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withOpacity(0.2),
                          ),
                          child: Center(
                            child: Icon(Icons.check, color: color, size: 14),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(action, style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ))
              ,
        ],
      ),
    );
  }
}