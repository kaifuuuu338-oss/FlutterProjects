import 'package:flutter/material.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/screens/result_screen.dart';
import 'package:my_first_app/core/utils/delay_summary.dart';

class BehavioralPsychosocialSummaryScreen extends StatelessWidget {
  final String childId;
  final String awwId;
  final int ageMonths;
  final String genderLabel;
  final String awcCode;
  final String overallRisk;
  final String autismRisk;
  final String adhdRisk;
  final String behaviorRisk;
  final int baselineScore;
  final String baselineCategory;
  final String immunizationStatus;
  final double weightKg;
  final double heightCm;
  final double? muacCm;
  final double? birthWeightKg;
  final double? hemoglobin;
  final String illnessHistory;
  final Map<String, double> domainScores;
  final Map<String, String>? domainRiskLevels;
  final int missedMilestones;
  final String explainability;
  final Map<String, int>? delaySummary;

  const BehavioralPsychosocialSummaryScreen({
    super.key,
    required this.childId,
    required this.awwId,
    required this.ageMonths,
    required this.genderLabel,
    required this.awcCode,
    required this.overallRisk,
    required this.autismRisk,
    required this.adhdRisk,
    required this.behaviorRisk,
    required this.baselineScore,
    required this.baselineCategory,
    required this.immunizationStatus,
    required this.weightKg,
    required this.heightCm,
    this.muacCm,
    this.birthWeightKg,
    this.hemoglobin,
    required this.illnessHistory,
    required this.domainScores,
    this.domainRiskLevels,
    required this.missedMilestones,
    required this.explainability,
    this.delaySummary,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final immunizationLabel = _immunizationLabel(immunizationStatus, l10n);
    final overallRiskLabel = _prettyRisk(overallRisk);
    final baselineLabel = _prettyRisk(baselineCategory);
    final autismLabel = _prettyRisk(autismRisk);
    final adhdLabel = _prettyRisk(adhdRisk);
    final behaviorLabel = _prettyRisk(behaviorRisk);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('behavioural_psychosocial_summary_title')),
        backgroundColor: const Color(0xFF0D5BA7),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _summaryHeader(
            context,
            l10n,
            overallRiskLabel,
            baselineLabel,
            immunizationLabel,
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: l10n.t('child_details'),
            icon: Icons.person_outline,
            child: _infoTable({
              l10n.t('child_id'): childId,
              l10n.t('age_with_months', {'age': '$ageMonths'}): '',
              l10n.t('gender'): genderLabel,
              l10n.t('awc_code'): awcCode,
            }),
          ),
          _sectionCard(
            title: l10n.t('behaviour_section_title'),
            icon: Icons.psychology_alt_outlined,
            child: Column(
              children: [
                _infoRow(l10n.t('autism_risk'), _riskBadge(autismLabel)),
                _infoRow(l10n.t('adhd_risk'), _riskBadge(adhdLabel)),
                _infoRow(l10n.t('behavior_risk'), _riskBadge(behaviorLabel)),
              ],
            ),
          ),
          _sectionCard(
            title: l10n.t('baseline_risk_scoring'),
            icon: Icons.analytics_outlined,
            child: Row(
              children: [
                Expanded(
                  child: _metricTile(
                    l10n.t('baseline_score_label'),
                    '$baselineScore',
                    const Color(0xFF0D5BA7),
                    const Color(0xFFE8F1FB),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metricTile(
                    l10n.t('baseline_category_label'),
                    baselineLabel,
                    _riskColor(baselineLabel),
                    _riskTint(baselineLabel),
                  ),
                ),
              ],
            ),
          ),
          _sectionCard(
            title: l10n.t('anthropometry_section_title'),
            icon: Icons.monitor_weight_outlined,
            child: _infoTable({
              l10n.t('weight_label'): '${weightKg.toStringAsFixed(1)} kg',
              l10n.t('height_label'): '${heightCm.toStringAsFixed(1)} cm',
              l10n.t('muac_label'): muacCm == null ? '-' : '${muacCm!.toStringAsFixed(1)} cm',
              l10n.t('birth_weight_label'): birthWeightKg == null ? '-' : '${birthWeightKg!.toStringAsFixed(1)} kg',
              l10n.t('hemoglobin_label'): hemoglobin == null ? '-' : '${hemoglobin!.toStringAsFixed(1)} g/dL',
              l10n.t('illness_history_label'): illnessHistory.isEmpty ? '-' : illnessHistory,
            }),
          ),
          _sectionCard(
            title: l10n.t('immunization_label'),
            icon: Icons.vaccines_outlined,
            child: _infoRow(l10n.t('immunization_label'), _statusBadge(immunizationLabel)),
          ),
          _sectionCard(
            title: l10n.t('developmental_domain_delays'),
            icon: Icons.rule_outlined,
            child: _buildDomainDelayTable(
              context,
              {
                'GM': l10n.t('gm_delay'),
                'FM': l10n.t('fm_delay'),
                'LC': l10n.t('lc_delay'),
                'COG': l10n.t('cog_delay'),
                'SE': l10n.t('se_delay'),
              },
            ),
          ),
          _sectionCard(
            title: l10n.t('domain_breakdown'),
            icon: Icons.table_chart_outlined,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: domainScores.entries.map((entry) {
                final label = domainRiskLevels?[entry.key];
                final title = label == null ? entry.key : '${entry.key} · ${_prettyRisk(label)}';
                return _pill(title, risk: label);
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
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
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    IconData? icon,
    Widget? trailing,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F1FB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: const Color(0xFF0D5BA7)),
                  ),
                if (icon != null) const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
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
                    child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F5D6B))),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(e.value, style: const TextStyle(color: Color(0xFF1F2D3D))),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _infoRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F5D6B))),
          ),
          Expanded(
            flex: 4,
            child: Align(alignment: Alignment.centerLeft, child: value),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, {String? risk}) {
    final bg = risk == null ? const Color(0xFFEFF4FA) : _riskTint(risk);
    final border = risk == null ? const Color(0xFFD7E1EC) : _riskColor(risk).withValues(alpha: 0.35);
    final textColor = risk == null ? const Color(0xFF1F2D3D) : _riskColor(risk);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  Widget _buildDomainDelayTable(BuildContext context, Map<String, String> domainNames) {
    final l10n = AppLocalizations.of(context);

    if (delaySummary == null || delaySummary!.isEmpty) {
      return Text(
        l10n.t('no_specific_domain_triggers'),
        style: const TextStyle(color: Colors.grey),
      );
    }

    final delayRows = <Widget>[];
    const domains = ['GM', 'FM', 'LC', 'COG', 'SE'];

    for (final domain in domains) {
      final delayCount = delayValueForDomain(delaySummary, domain);
      final domainName = domainNames[domain] ?? domain;

      final isDelay = delayCount == 1;
      final delayColor = isDelay ? const Color(0xFFE53935) : const Color(0xFF2E7D32);
      delayRows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  domainName,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F5D6B)),
                ),
              ),
              Expanded(
                flex: 4,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: delayColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: delayColor.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      '$delayCount',
                      style: TextStyle(color: delayColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: delayRows);
  }

  String _immunizationLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'full':
        return l10n.t('immunization_full');
      case 'partial':
        return l10n.t('immunization_partial');
      case 'none':
        return l10n.t('immunization_none');
      default:
        return l10n.t('immunization_unknown');
    }
  }

  String _prettyRisk(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return value;
    final lower = trimmed.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  Color _riskColor(String risk) {
    switch (risk.trim().toLowerCase()) {
      case 'critical':
      case 'high':
        return const Color(0xFFE53935);
      case 'moderate':
      case 'medium':
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  Color _riskTint(String risk) {
    switch (risk.trim().toLowerCase()) {
      case 'critical':
      case 'high':
        return const Color(0xFFFFEBEE);
      case 'moderate':
      case 'medium':
        return const Color(0xFFFFF8E1);
      default:
        return const Color(0xFFE8F5E9);
    }
  }

  Widget _riskBadge(String label) {
    final color = _riskColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _riskTint(label),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _statusBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFD4EE)),
      ),
      child: Text(label, style: const TextStyle(color: Color(0xFF0D5BA7), fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _metricTile(String label, String value, Color accent, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF5B6B7C), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: accent)),
        ],
      ),
    );
  }

  Widget _summaryHeader(BuildContext context, AppLocalizations l10n, String overall, String baseline, String immunization) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D5BA7), Color(0xFF2F95EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('behavioural_psychosocial_summary_title'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  childId,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              _riskBadge(overall),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _metricTile(l10n.t('baseline_category_label'), baseline, const Color(0xFF0D5BA7), Colors.white)),
              const SizedBox(width: 10),
              Expanded(child: _metricTile(l10n.t('immunization_label'), immunization, const Color(0xFF0D5BA7), Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}
