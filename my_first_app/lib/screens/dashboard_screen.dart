import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/core/navigation/app_route_observer.dart';
import 'package:my_first_app/core/navigation/navigation_state_service.dart';
import 'package:my_first_app/models/child_model.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'package:my_first_app/screens/child_registration_screen.dart';
import 'package:my_first_app/screens/consent_screen.dart';
import 'package:my_first_app/screens/district_monitor_screen.dart';
import 'package:my_first_app/screens/login_screen.dart';
import 'package:my_first_app/screens/registered_children_screen.dart';
import 'package:my_first_app/screens/result_screen.dart';
import 'package:my_first_app/screens/awc_intervention_monitor_screen.dart';
import 'package:my_first_app/screens/settings_screen.dart';
import 'package:my_first_app/screens/behavioral_psychosocial_summary_screen.dart';
import 'package:my_first_app/services/api_service.dart';
import 'package:my_first_app/services/auth_service.dart';
import 'package:my_first_app/services/local_db_service.dart';
import 'package:my_first_app/widgets/language_menu_button.dart';
import 'package:my_first_app/core/utils/delay_summary.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with RouteAware {
  static final RegExp _awcCodePattern = RegExp(r'^(AWW|AWS)_DEMO_(\d{3,4})$');
  final LocalDBService _localDb = LocalDBService();
  final APIService _api = APIService();
  final AuthService _authService = AuthService();

  int totalChildren = 0;
  int pendingSync = 0;
  String _loggedInAwcCode = '';
  Timer? _statsRefreshTimer;
  bool _statsLoadInProgress = false;

  double _uiScale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width / 390.0;
    return scale.clamp(0.88, 1.08);
  }

  void _openBehavioralSummaryShortcut() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BehavioralPsychosocialSummaryScreen(
          childId: 'demo_child',
          awwId: 'demo_aww',
          ageMonths: 36,
          genderLabel: 'Unknown',
          awcCode: 'DEMO_AWC',
          overallRisk: 'low',
          autismRisk: 'low',
          adhdRisk: 'low',
          behaviorRisk: 'low',
          immunizationStatus: 'full',
          weightKg: 0,
          heightCm: 0,
          muacCm: null,
          birthWeightKg: null,
          hemoglobin: null,
          illnessHistory: '',
          domainScores: const {
            'GM': 0,
            'FM': 0,
            'LC': 0,
            'COG': 0,
            'SE': 0,
          },
          domainRiskLevels: const {
            'GM': 'Low',
            'FM': 'Low',
            'LC': 'Low',
            'COG': 'Low',
            'SE': 'Low',
          },
          missedMilestones: 0,
          explainability: '',
          delaySummary: const {
            'GM_delay': 0,
            'FM_delay': 0,
            'LC_delay': 0,
            'COG_delay': 0,
            'SE_delay': 0,
            'num_delays': 0,
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    NavigationStateService.instance.saveState(
      screen: NavigationStateService.screenDashboard,
    );
    _loadStats();
    _startStatsAutoRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _statsRefreshTimer?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadStats();
  }

  void _startStatsAutoRefresh() {
    _statsRefreshTimer?.cancel();
    _statsRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadStats();
    });
  }

  bool _awcCodesMatch(String left, String right) {
    final a = left.trim().toUpperCase();
    final b = right.trim().toUpperCase();
    if (a.isEmpty || b.isEmpty) {
      return a == b;
    }
    if (a == b) {
      return true;
    }
    final ma = _awcCodePattern.firstMatch(a);
    final mb = _awcCodePattern.firstMatch(b);
    if (ma == null || mb == null) {
      return false;
    }
    return ma.group(2) == mb.group(2);
  }

  Future<void> _loadStats() async {
    if (_statsLoadInProgress) return;
    _statsLoadInProgress = true;
    try {
      await _localDb.initialize();
      final savedAwcCode =
          (await _authService.getLoggedInAwcCode() ?? '').trim().toUpperCase();
      final screenings = _localDb.getUnsyncedScreenings();
      final referrals = _localDb.getUnsyncedReferrals();
      int registeredCount;
      try {
        registeredCount = await _api.getRegisteredChildrenCount(
          limit: 1000,
          awcCode: savedAwcCode.isEmpty ? null : savedAwcCode,
        );
      } catch (_) {
        final children = _localDb
            .getAllChildren()
            .where(
              (c) =>
                  savedAwcCode.isEmpty ||
                  _awcCodesMatch(c.awcCode, savedAwcCode),
            )
            .toList();
        registeredCount = children.length;
      }

      if (!mounted) return;
      final nextPending = screenings.length + referrals.length;
      if (registeredCount != totalChildren ||
          nextPending != pendingSync ||
          savedAwcCode != _loggedInAwcCode) {
        setState(() {
          totalChildren = registeredCount;
          pendingSync = nextPending;
          _loggedInAwcCode = savedAwcCode;
        });
      }
    } finally {
      _statsLoadInProgress = false;
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
    required double s,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: 84 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      padding: EdgeInsets.symmetric(vertical: 14 * s, horizontal: 14 * s),
      child: Row(
        children: [
          Container(
            width: 46 * s,
            height: 46 * s,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 22 * s),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 24 * s, fontWeight: FontWeight.bold, color: const Color(0xFF1F2D3D)),
                ),
                SizedBox(height: 4 * s),
                Text(
                  label,
                  style: TextStyle(color: const Color(0xFF5B6B7C), fontWeight: FontWeight.w600, fontSize: 12.5 * s),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _childrenCountCard(double s) {
    return _statCard(
      label: AppLocalizations.of(context).t('registered_children'),
      value: '$totalChildren',
      icon: Icons.groups,
      accent: const Color(0xFF2E7D32),
      s: s,
    );
  }

  Widget _actionTile({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double s,
    Color textColor = Colors.white,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      elevation: 1.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: 150 * s,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 42 * s, color: textColor),
                SizedBox(height: 10 * s),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16 * s,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, double s, {String? subtitle}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 18 * s, fontWeight: FontWeight.bold, color: const Color(0xFF243445))),
          if (subtitle != null) ...[
            SizedBox(height: 4 * s),
            Text(subtitle, style: TextStyle(color: const Color(0xFF6B7C8D), fontSize: 12 * s)),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Future<void> _openRegisterChild() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChildRegistrationScreen()),
    );
    await _loadStats();
  }

  Future<void> _viewRegisteredChildren() async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RegisteredChildrenScreen(),
      ),
    );
  }

  Future<void> _startScreening() async {
    await _localDb.initialize();
    final savedAwcCode = _loggedInAwcCode.isNotEmpty
        ? _loggedInAwcCode
        : (await _authService.getLoggedInAwcCode() ?? '').trim().toUpperCase();
    final localChildren = _localDb
        .getAllChildren()
        .where(
          (c) =>
              savedAwcCode.isEmpty || _awcCodesMatch(c.awcCode, savedAwcCode),
        )
        .toList();
    final localChildById = <String, ChildModel>{
      for (final c in localChildren) c.childId: c,
    };
    List<Map<String, dynamic>> backendChildren = const <Map<String, dynamic>>[];
    try {
      backendChildren = await _api.getRegisteredChildren(
        limit: 1000,
        awcCode: savedAwcCode.isEmpty ? null : savedAwcCode,
      );
    } catch (_) {
      backendChildren = const <Map<String, dynamic>>[];
    }
    final childRowsById = <String, Map<String, dynamic>>{};
    for (final child in localChildren) {
      childRowsById[child.childId] = <String, dynamic>{
        'child_id': child.childId,
        'age_months': child.ageMonths,
        'aww_id': child.awwId.isNotEmpty ? child.awwId : child.awcCode,
        'has_screening': false,
      };
    }
    bool boolValue(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final raw = (value ?? '').toString().trim().toLowerCase();
      return raw == 'true' || raw == '1' || raw == 'yes';
    }
    for (final row in backendChildren) {
      final childId = (row['child_id'] ?? '').toString().trim();
      if (childId.isEmpty) continue;
      final ageRaw = row['age_months'];
      final ageMonths = ageRaw is num
          ? ageRaw.toInt()
          : int.tryParse('${ageRaw ?? ''}') ?? 0;
      final awcCode = (row['awc_code'] ?? '').toString().trim();
      final hasScreening = boolValue(row['has_screening']);
      final existing = childRowsById[childId];
      if (existing == null) {
        childRowsById[childId] = <String, dynamic>{
          'child_id': childId,
          'age_months': ageMonths,
          'aww_id': awcCode.isNotEmpty ? awcCode : savedAwcCode,
          'has_screening': hasScreening,
        };
      } else {
        final currentAge = existing['age_months'] is num
            ? (existing['age_months'] as num).toInt()
            : int.tryParse('${existing['age_months'] ?? ''}') ?? 0;
        if (currentAge <= 0 && ageMonths > 0) {
          existing['age_months'] = ageMonths;
        }
        final currentAww = (existing['aww_id'] ?? '').toString().trim();
        if (currentAww.isEmpty && awcCode.isNotEmpty) {
          existing['aww_id'] = awcCode;
        }
        if (hasScreening) {
          existing['has_screening'] = true;
        }
      }
    }
    final children = childRowsById.values.toList();
    if (!mounted) return;
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('please_register_child_first'))),
      );
      return;
    }

    bool hasDevelopmentAssessment(
      String childId, {
      String? awwId,
      DateTime? notBefore,
    }) {
      final screenings = _localDb.getChildScreenings(childId);
      final normalizedAwwId = (awwId ?? '').trim();
      return screenings.any(
        (s) {
          final hasAllDomains =
              s.domainResponses.containsKey('GM') &&
            s.domainResponses.containsKey('FM') &&
            s.domainResponses.containsKey('LC') &&
            s.domainResponses.containsKey('COG') &&
            s.domainResponses.containsKey('SE');
          if (!hasAllDomains) {
            return false;
          }
          final hasMatchingAww = normalizedAwwId.isEmpty
              ? true
              : _awcCodesMatch(s.awwId, normalizedAwwId);
          if (!hasMatchingAww) {
            return false;
          }
          if (notBefore != null && s.screeningDate.isBefore(notBefore)) {
            return false;
          }
          return true;
        },
      );
    }

    final statusByChildId = <String, bool>{
      for (final c in children)
        (c['child_id'] ?? '').toString().trim(): (() {
          final cid = (c['child_id'] ?? '').toString().trim();
          final rowAwwId = (c['aww_id'] ?? '').toString().trim();
          final localChild = localChildById[cid];
          final localDone = hasDevelopmentAssessment(
            cid,
            awwId: localChild?.awcCode ?? rowAwwId,
            notBefore: localChild?.createdAt,
          );
          final backendDone = boolValue(c['has_screening']);
          return localDone || backendDone;
        })(),
    };
    final orderedChildren = [...children]
      ..sort((a, b) {
        final aId = (a['child_id'] ?? '').toString().trim();
        final bId = (b['child_id'] ?? '').toString().trim();
        final aSubmitted = statusByChildId[aId] ?? false;
        final bSubmitted = statusByChildId[bId] ?? false;
        if (aSubmitted == bSubmitted) {
          return aId.compareTo(bId);
        }
        // Show pending children first.
        return aSubmitted ? 1 : -1;
      });

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView.builder(
          itemCount: orderedChildren.length,
          itemBuilder: (itemContext, index) {
            final child = orderedChildren[index];
            final childId = (child['child_id'] ?? '').toString().trim();
            final ageRaw = child['age_months'];
            final ageMonths = ageRaw is num
                ? ageRaw.toInt()
                : int.tryParse('${ageRaw ?? ''}') ?? 0;
            final awwId = (child['aww_id'] ?? '').toString().trim();
            final isSubmitted = statusByChildId[childId] ?? false;
            final statusText = isSubmitted
                ? 'Assessment submitted'
                : 'Assessment not done';
            final statusColor = isSubmitted
                ? const Color(0xFF2E7D32)
                : const Color(0xFFE65100);

            return ListTile(
              title: Text(childId),
              subtitle: Text(
                '${AppLocalizations.of(context).t('age_with_months', {'age': '$ageMonths'})} | $statusText',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isSubmitted ? 'Submitted' : 'Pending',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (!isSubmitted) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ],
              ),
              onTap: () {
                if (isSubmitted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Assessment submitted')),
                  );
                  return;
                }
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ConsentScreen(
                      childId: childId,
                      ageMonths: ageMonths,
                      awwId: savedAwcCode.isNotEmpty
                          ? savedAwcCode
                          : (awwId.isNotEmpty ? awwId : savedAwcCode),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _startBehaviouralPsychosocial() async {
    // Enforce canonical flow: Developmental screening must happen before
    // neuro-behavioral assessment so developmental_risk_score is always saved.
    await _startScreening();
  }

  Future<void> _viewPastResults() async {
    await _localDb.initialize();
    final children = _localDb.getAllChildren();
    final past = <ScreeningModel>[];
    for (final ChildModel c in children) {
      past.addAll(_localDb.getChildScreenings(c.childId));
    }
    past.sort((a, b) => b.screeningDate.compareTo(a.screeningDate));

    if (!mounted) return;
    if (past.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('no_past_results'))),
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
            title: Text('${s.childId} - ${AppLocalizations.of(context).t(risk.toLowerCase()).toUpperCase()}'),
            subtitle: Text(AppLocalizations.of(context).t('date_label', {'date': '${s.screeningDate.toLocal()}'})),
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

  Future<void> _showRiskStatus() async {
    await _localDb.initialize();
    final children = _localDb.getAllChildren();
    final all = <ScreeningModel>[];
    for (final ChildModel c in children) {
      all.addAll(_localDb.getChildScreenings(c.childId));
    }
    final low = all.where((s) => s.overallRisk == RiskLevel.low).length;
    final medium = all.where((s) => s.overallRisk == RiskLevel.medium).length;
    final high = all.where((s) => s.overallRisk == RiskLevel.high).length;
    final critical = all.where((s) => s.overallRisk == RiskLevel.critical).length;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('risk_status')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppLocalizations.of(context).t('low')}: $low'),
            Text('${AppLocalizations.of(context).t('medium')}: $medium'),
            Text('${AppLocalizations.of(context).t('high')}: $high'),
            Text('${AppLocalizations.of(context).t('critical')}: $critical'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(AppLocalizations.of(context).t('ok'))),
        ],
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openAwcMonitor() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AwcInterventionMonitorScreen()),
    );
  }

  void _openDistrictMonitor() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DistrictMonitorScreen()),
    );
  }

  Widget _buildNavDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            ListTile(title: Text(AppLocalizations.of(context).t('navigation'), style: const TextStyle(fontWeight: FontWeight.bold))),
            ListTile(leading: const Icon(Icons.home_outlined), title: Text(AppLocalizations.of(context).t('dashboard')), onTap: () => Navigator.of(context).pop()),
            ListTile(leading: const Icon(Icons.people_outline), title: Text(AppLocalizations.of(context).t('children')), onTap: () { Navigator.of(context).pop(); _viewRegisteredChildren(); }),
            ListTile(leading: const Icon(Icons.dataset_outlined), title: Text(AppLocalizations.of(context).t('risk_status')), onTap: () { Navigator.of(context).pop(); _showRiskStatus(); }),
            ListTile(leading: const Icon(Icons.query_stats_outlined), title: Text(AppLocalizations.of(context).t('view_past_results')), onTap: () { Navigator.of(context).pop(); _viewPastResults(); }),
            ListTile(leading: const Icon(Icons.settings_outlined), title: Text(AppLocalizations.of(context).t('settings')), onTap: () { Navigator.of(context).pop(); _openSettings(); }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = _uiScale(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 900;
    final pendingLabel = pendingSync == 0
        ? l10n.t('all_synced')
        : l10n.t('pending_count', {'count': '$pendingSync'});
    final pendingColor = pendingSync == 0 ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
    final awcHeaderLabel = _loggedInAwcCode.isEmpty
        ? AppLocalizations.of(context).t('aww_short')
        : _loggedInAwcCode;

    return Scaffold(
      drawer: _buildNavDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE9F2F8), Color(0xFFF8FCFF)],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadStats,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16 * s, 8 * s, 16 * s, 14 * s),
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF0B4C91), Color(0xFF145FA8)]),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16), bottom: Radius.circular(16)),
                    boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  padding: EdgeInsets.fromLTRB(14 * s, 14 * s, 14 * s, 14 * s),
                  child: Row(
                    children: [
                      ClipOval(
                        child: Image.asset(
                          'assets/images/ap_logo.png',
                          width: 48 * s,
                          height: 48 * s,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 48 * s,
                            height: 48 * s,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                            alignment: Alignment.center,
                            child: Text(AppLocalizations.of(context).t('ap_short'), style: TextStyle(color: const Color(0xFF1565C0), fontWeight: FontWeight.bold, fontSize: 13 * s)),
                          ),
                        ),
                      ),
                      SizedBox(width: 12 * s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context).t('govt_andhra_pradesh'), style: TextStyle(color: Colors.white70, fontSize: 12 * s)),
                            SizedBox(height: 3 * s),
                            Text(AppLocalizations.of(context).t('anganwadi_dashboard'), style: TextStyle(color: Colors.white, fontSize: 22 * s, fontWeight: FontWeight.bold)),
                            SizedBox(height: 6 * s),
                            _statusPill(pendingLabel, pendingColor),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Builder(
                            builder: (context) => IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onPressed: () => Scaffold.of(context).openDrawer(),
                            ),
                          ),
                          const LanguageMenuButton(iconColor: Colors.white),
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person, color: Color(0xFF1565C0)),
                          ),
                          SizedBox(height: 4 * s),
                          SizedBox(
                            width: 130 * s,
                            child: Text(
                              awcHeaderLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12 * s,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12 * s),
                _childrenCountCard(s),
                SizedBox(height: 14 * s),
                _sectionTitle(AppLocalizations.of(context).t('quick_actions'), s, subtitle: AppLocalizations.of(context).t('quick_actions_subtitle')),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isWide ? 4 : 2,
                  crossAxisSpacing: 10 * s,
                  mainAxisSpacing: 10 * s,
                  childAspectRatio: isWide ? 1.05 : 1.03,
                  children: [
                    _actionTile(color: const Color(0xFF50B655), icon: Icons.add_circle, label: AppLocalizations.of(context).t('register_new_child'), onTap: _openRegisterChild, s: s),
                    _actionTile(color: const Color(0xFF2EA0F3), icon: Icons.groups, label: AppLocalizations.of(context).t('view_registered_children'), onTap: _viewRegisteredChildren, s: s),
                    _actionTile(color: const Color(0xFFF6C414), icon: Icons.assignment_rounded, textColor: Colors.black87, label: AppLocalizations.of(context).t('start_screening'), onTap: _startScreening, s: s),
                    _actionTile(color: const Color(0xFF8E6CF6), icon: Icons.psychology, label: AppLocalizations.of(context).t('behavioural_psychosocial_shortcut'), onTap: _startBehaviouralPsychosocial, s: s),
                    _actionTile(color: const Color(0xFF1E88E5), icon: Icons.assessment, label: 'Behavior Summary', onTap: _openBehavioralSummaryShortcut, s: s),
                    _actionTile(color: const Color(0xFFF35A52), icon: Icons.show_chart, label: AppLocalizations.of(context).t('view_past_results'), onTap: _viewPastResults, s: s),
                    _actionTile(color: const Color(0xFF5E35B1), icon: Icons.monitor_heart, label: 'AWC Monitor', onTap: _openAwcMonitor, s: s),
                    _actionTile(color: const Color(0xFF3949AB), icon: Icons.map, label: 'Mandal/District View', onTap: _openDistrictMonitor, s: s),
                    if (!isWide)
                      _actionTile(color: const Color(0xFF6C63FF), icon: Icons.settings, label: AppLocalizations.of(context).t('settings'), onTap: _openSettings, s: s),
                  ],
                ),
                SizedBox(height: 8 * s),
                TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.t('logout')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
