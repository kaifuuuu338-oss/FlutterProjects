import 'package:flutter/material.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/models/child_model.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'package:my_first_app/screens/dashboard_screen.dart';
import 'package:my_first_app/screens/result_screen.dart';
import 'package:my_first_app/screens/screening_screen.dart';
import 'package:my_first_app/screens/settings_screen.dart';
import 'package:my_first_app/services/local_db_service.dart';
import 'package:my_first_app/widgets/language_menu_button.dart';
import 'package:my_first_app/core/utils/delay_summary.dart';

class ConsentScreen extends StatefulWidget {
  final String childId;
  final int ageMonths;
  final String awwId;
  final List<String> birthHistory;
  final List<String> healthHistory;

  const ConsentScreen({
    super.key,
    required this.childId,
    required this.ageMonths,
    required this.awwId,
    this.birthHistory = const [],
    this.healthHistory = const [],
  });

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool consentGiven = false;
  final LocalDBService _localDb = LocalDBService();

  void _continue() {
    if (!consentGiven) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScreeningScreen(
          childId: widget.childId,
          ageMonths: widget.ageMonths,
          awwId: widget.awwId,
          consentGiven: true,
          consentTimestamp: DateTime.now(),
          birthHistory: widget.birthHistory,
          healthHistory: widget.healthHistory,
        ),
      ),
    );
  }

  Future<void> _goDashboard() async {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  Future<void> _showChildrenCount() async {
    await _localDb.initialize();
    final count = _localDb.getAllChildren().length;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.t('children')),
        content: Text(l10n.t('total_registered_children', {'count': '$count'})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.t('ok')),
          ),
        ],
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
    final l10n = AppLocalizations.of(context);
    if (past.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('no_past_results'))));
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
            title: Text(
              '${s.childId} - ${l10n.t(risk.toLowerCase()).toUpperCase()}',
            ),
            subtitle: Text(
              l10n.t('date_label', {
                'date': s.screeningDate.toLocal().toString(),
              }),
            ),
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
    final critical = all
        .where((s) => s.overallRisk == RiskLevel.critical)
        .length;

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.t('risk_status')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('risk_count_low', {'count': '$low'})),
            Text(l10n.t('risk_count_medium', {'count': '$medium'})),
            Text(l10n.t('risk_count_high', {'count': '$high'})),
            Text(l10n.t('risk_count_critical', {'count': '$critical'})),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.t('ok')),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  Widget _buildNavDrawer() {
    final l10n = AppLocalizations.of(context);
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            ListTile(
              title: Text(
                l10n.t('navigation'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: Text(l10n.t('dashboard')),
              onTap: _goDashboard,
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: Text(l10n.t('children')),
              onTap: () {
                Navigator.of(context).pop();
                _showChildrenCount();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dataset_outlined),
              title: Text(l10n.t('risk_status')),
              onTap: () {
                Navigator.of(context).pop();
                _showRiskStatus();
              },
            ),
            ListTile(
              leading: const Icon(Icons.query_stats_outlined),
              title: Text(l10n.t('view_past_results')),
              onTap: () {
                Navigator.of(context).pop();
                _viewPastResults();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n.t('settings')),
              onTap: () {
                Navigator.of(context).pop();
                _openSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F5F7),
        body: Column(
          children: [
            Container(
              height: 58,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF41B88E), Color(0xFF4CC29B)],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/images/ap_logo.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'AP',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context).t('govt_andhra_pradesh'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  const Spacer(),
                  const LanguageMenuButton(iconColor: Colors.white),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 280,
                    color: const Color(0xFFFAFAFA),
                    child: ListView(
                      children: [
                        _SideItem(
                          icon: Icons.dashboard_outlined,
                          label: AppLocalizations.of(context).t('dashboard'),
                          onTap: _goDashboard,
                        ),
                        _SideItem(
                          icon: Icons.badge_outlined,
                          label: AppLocalizations.of(context).t('children'),
                          onTap: _showChildrenCount,
                        ),
                        _SideItem(
                          icon: Icons.dataset_outlined,
                          label: AppLocalizations.of(context).t('risk_status'),
                          onTap: _showRiskStatus,
                        ),
                        _SideItem(
                          icon: Icons.query_stats_outlined,
                          label: AppLocalizations.of(
                            context,
                          ).t('view_past_results'),
                          onTap: _viewPastResults,
                        ),
                        _SideItem(
                          icon: Icons.settings_outlined,
                          label: AppLocalizations.of(context).t('settings'),
                          onTap: _openSettings,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(40, 28, 20, 20),
                          child: SizedBox(
                            width: 760,
                            child: _consentContent(showContinue: true),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: _buildNavDrawer(),
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).t('consent_title'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF0D5BA7),
        foregroundColor: Colors.white,
        actions: [
          const LanguageMenuButton(iconColor: Colors.white),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ClipOval(
              child: Image.asset(
                'assets/images/ap_logo.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'AP',
                    style: TextStyle(
                      color: Color(0xFF0D5BA7),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
              child: _consentContent(showContinue: true),
            ),
          ),
        ),
      ),
    );
  }

  Widget _consentContent({required bool showContinue}) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.t('consent_header'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF1C5D97),
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.t('consent_description'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        _bulletLine(
          l10n.t('consent_bullet_intro_blue'),
          l10n.t('consent_bullet_intro_black'),
        ),
        const SizedBox(height: 8),
        _plainBullet(l10n.t('consent_bullet_one')),
        const SizedBox(height: 4),
        _plainBullet(l10n.t('consent_bullet_two')),
        const SizedBox(height: 20),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
            children: [
              TextSpan(text: l10n.t('consent_disclaimer_line1')),
              TextSpan(
                text: l10n.t('consent_disclaimer_highlight'),
                style: const TextStyle(color: Color(0xFF1C7DC1)),
              ),
              TextSpan(text: l10n.t('consent_disclaimer_line2')),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Material(
          color: consentGiven
              ? const Color(0xFF0E65B4)
              : const Color(0xFF85B8E0),
          borderRadius: BorderRadius.circular(12),
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => consentGiven = !consentGiven),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Icon(
                      consentGiven
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.t('parent_consent_confirm'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showContinue) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: consentGiven ? _continue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D5BA7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(l10n.t('continue_to_screening')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _bulletLine(String blueText, String blackText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            '• ',
            style: TextStyle(
              color: Color(0xFF1C7DC1),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              children: [
                TextSpan(
                  text: blueText,
                  style: const TextStyle(color: Color(0xFF1C7DC1)),
                ),
                TextSpan(text: blackText),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _plainBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            '• ',
            style: TextStyle(
              color: Color(0xFF1C7DC1),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _SideItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SideItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE6EAEE))),
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Icon(icon, size: 18, color: const Color(0xFF6F7B86)),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5E6A75),
          ),
        ),
      ),
    );
  }
}
