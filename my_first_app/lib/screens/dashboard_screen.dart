import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/core/constants/app_constants.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/core/navigation/app_route_observer.dart';
import 'package:my_first_app/models/child_model.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'package:my_first_app/models/referral_model.dart';
import 'package:my_first_app/screens/child_registration_screen.dart';
import 'package:my_first_app/screens/consent_screen.dart';
import 'package:my_first_app/screens/login_screen.dart';
import 'package:my_first_app/screens/referral_batch_summary_screen.dart';
import 'package:my_first_app/screens/referral_details_screen.dart';
import 'package:my_first_app/screens/result_screen.dart';
import 'package:my_first_app/screens/behavioral_psychosocial_screen.dart';
import 'package:my_first_app/screens/settings_screen.dart';
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
  final LocalDBService _localDb = LocalDBService();
  final AuthService _authService = AuthService();

  int totalChildren = 0;
  int pendingSync = 0;

  double _uiScale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width / 390.0;
    return scale.clamp(0.88, 1.08);
  }

  @override
  void initState() {
    super.initState();
    _loadStats();
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
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadStats();
  }

  Future<void> _loadStats() async {
    await _localDb.initialize();
    final children = _localDb.getAllChildren();
    final screenings = _localDb.getUnsyncedScreenings();
    final referrals = _localDb.getUnsyncedReferrals();

    if (!mounted) return;
    setState(() {
      totalChildren = children.length;
      pendingSync = screenings.length + referrals.length;
    });
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
    if (!Hive.isBoxOpen(AppConstants.childBoxName)) {
      return _statCard(
        label: AppLocalizations.of(context).t('registered_children'),
        value: '$totalChildren',
        icon: Icons.groups,
        accent: const Color(0xFF2E7D32),
        s: s,
      );
    }
    final box = Hive.box<Map>(AppConstants.childBoxName);
    return ValueListenableBuilder<Box<Map>>(
      valueListenable: box.listenable(),
      builder: (context, value, _) {
        final count = value.values.length;
        return _statCard(
          label: AppLocalizations.of(context).t('registered_children'),
          value: '$count',
          icon: Icons.groups,
          accent: const Color(0xFF2E7D32),
          s: s,
        );
      },
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
    await _localDb.initialize();
    final children = _localDb.getAllChildren();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('registered_children')),
        content: SizedBox(
          width: double.maxFinite,
          child: children.isEmpty
              ? Text(AppLocalizations.of(context).t('no_children_registered'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: children.length,
                  itemBuilder: (context, index) {
                    final c = children[index];
                    final genderLabel = c.gender == 'M' ? AppLocalizations.of(context).t('gender_male') : AppLocalizations.of(context).t('gender_female');
                    return ListTile(
                      title: Text(c.childId),
                      subtitle: Text('${AppLocalizations.of(context).t('age_with_months', {'age': '${c.ageMonths}'})} | $genderLabel'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).t('close')),
          ),
        ],
      ),
    );
  }

  Future<void> _startScreening() async {
    await _localDb.initialize();
    final children = _localDb.getAllChildren();
    if (!mounted) return;
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('please_register_child_first'))),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: children.length,
        itemBuilder: (context, index) {
          final child = children[index];
          return ListTile(
            title: Text(child.childId),
            subtitle: Text(AppLocalizations.of(context).t('age_with_months', {'age': '${child.ageMonths}'})),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ConsentScreen(
                    childId: child.childId,
                    ageMonths: child.ageMonths,
                    awwId: child.awwId,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _startBehaviouralPsychosocial() async {
    await _localDb.initialize();
    final children = _localDb.getAllChildren();
    if (!mounted) return;
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('please_register_child_first'))),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: children.length,
        itemBuilder: (context, index) {
          final child = children[index];
          return ListTile(
            title: Text(child.childId),
            subtitle: Text(AppLocalizations.of(context).t('age_with_months', {'age': '${child.ageMonths}'})),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BehavioralPsychosocialScreen(
                    prevDomainScores: {},
                    domainRiskLevels: null,
                    delaySummary: null,
                    overallRisk: 'low',
                    missedMilestones: 0,
                    explainability: '',
                    childId: child.childId,
                    awwId: child.awwId,
                    ageMonths: child.ageMonths,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
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

  Future<void> _openReferralBatchSummary() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ReferralBatchSummaryScreen(),
      ),
    );
  }

  Future<void> _openReferralSummary() async {
    await _localDb.initialize();
    final referrals = _localDb.getAllReferrals();
    if (!mounted) return;
    if (referrals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('no_past_results'))),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: referrals.length,
        itemBuilder: (context, index) {
          final r = referrals[index];
          final meta = r.metadata ?? {};
          final domainKey = meta['domain'] as String?;
          final domainRisk = meta['domain_risk'] as String?;
          final referralTypeLabel = (meta['referral_type_label'] as String?) ?? r.referralType.toString().split('.').last;
          final overallRisk = (meta['overall_risk'] as String?) ?? 'low';
          final ageMonthsValue = meta['age_months'];
          final ageMonths = ageMonthsValue is int ? ageMonthsValue : int.tryParse(ageMonthsValue?.toString() ?? '') ?? 0;
          final reasons = <String>[];
          if (domainKey != null && domainKey.isNotEmpty) {
            final domainLabel = _domainLabel(domainKey);
            if (domainRisk != null && domainRisk.isNotEmpty) {
              reasons.add('$domainLabel (${_riskLabel(domainRisk)})');
            } else {
              reasons.add(domainLabel);
            }
          }

          return ListTile(
            title: Text('${r.childId} • ${referralTypeLabel}'),
            subtitle: Text(AppLocalizations.of(context).t('date_label', {'date': '${r.createdAt.toLocal()}'})),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReferralDetailsScreen(
                    referralId: r.referralId,
                    childId: r.childId,
                    awwId: r.awwId,
                    ageMonths: ageMonths,
                    overallRisk: overallRisk,
                    referralType: referralTypeLabel,
                    urgency: _urgencyLabel(r.urgency),
                    createdAt: r.createdAt,
                    expectedFollowUpDate: r.expectedFollowUpDate,
                    notes: r.notes,
                    reasons: reasons,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _domainLabel(String key) {
    final l10n = AppLocalizations.of(context);
    switch (key) {
      case 'GM':
        return l10n.t('domain_gm');
      case 'FM':
        return l10n.t('domain_fm');
      case 'LC':
        return l10n.t('domain_lc');
      case 'COG':
        return l10n.t('domain_cog');
      case 'SE':
        return l10n.t('domain_se');
      default:
        return key;
    }
  }

  String _riskLabel(String riskKey) {
    final l10n = AppLocalizations.of(context);
    switch (riskKey.trim().toLowerCase()) {
      case 'critical':
        return l10n.t('critical');
      case 'high':
        return l10n.t('high');
      case 'medium':
        return l10n.t('medium');
      case 'low':
        return l10n.t('low');
      default:
        return riskKey;
    }
  }

  String _urgencyLabel(ReferralUrgency urgency) {
    final l10n = AppLocalizations.of(context);
    switch (urgency) {
      case ReferralUrgency.immediate:
        return l10n.t('urgency_immediate');
      case ReferralUrgency.urgent:
        return l10n.t('urgency_urgent');
      default:
        return l10n.t('urgency_normal');
    }
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
                          Text(AppLocalizations.of(context).t('aww_short'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12 * s)),
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
                    _actionTile(color: const Color(0xFFF35A52), icon: Icons.show_chart, label: AppLocalizations.of(context).t('view_past_results'), onTap: _viewPastResults, s: s),
                    _actionTile(color: const Color(0xFF26A69A), icon: Icons.assignment_turned_in, label: AppLocalizations.of(context).t('referral_batch_summary_shortcut'), onTap: _openReferralBatchSummary, s: s),
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
