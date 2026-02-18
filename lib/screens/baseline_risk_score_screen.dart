import 'package:flutter/material.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';

class BaselineRiskScoreScreen extends StatelessWidget {
  final int baselineScore;
  final String baselineCategory;
  final Map<String, int>? delaySummary; // keys: GM_delay, FM_delay, LC_delay, COG_delay, SE_delay, num_delays
  final Map<String, double> domainScores;
  final Map<String, String>? domainRiskLevels;

  const BaselineRiskScoreScreen({
    super.key,
    required this.baselineScore,
    required this.baselineCategory,
    required this.delaySummary,
    required this.domainScores,
    this.domainRiskLevels,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gm = delaySummary?['GM_delay'] ?? 0;
    final fm = delaySummary?['FM_delay'] ?? 0;
    final lc = delaySummary?['LC_delay'] ?? 0;
    final cog = delaySummary?['COG_delay'] ?? 0;
    final se = delaySummary?['SE_delay'] ?? 0;
    final total = delaySummary?['num_delays'] ?? (gm + fm + lc + cog + se);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        title: Text(l10n.t('baseline_risk_scoring')),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF7F9FB),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _card(
            child: Row(
              children: [
                Expanded(child: _metric(l10n.t('baseline_score_label'), '$baselineScore')),
                const SizedBox(width: 12),
                Expanded(child: _metric(l10n.t('baseline_category_label'), baselineCategory)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _card(
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _chip('Delays: 2 x 5 = $total'),
                _chip('Autism: +0'),
                _chip('ADHD: +0'),
                _chip('Behavior: +0'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l10n.t('developmental_domain_delays'),
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF404B5A)),
            ),
          ),
          const SizedBox(height: 6),
          _card(
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 32,
              columnSpacing: 28,
              columns: [
                DataColumn(label: Text(l10n.t('gm_delay'))),
                DataColumn(label: Text(l10n.t('fm_delay'))),
                DataColumn(label: Text(l10n.t('lc_delay'))),
                DataColumn(label: Text(l10n.t('cog_delay'))),
                DataColumn(label: Text(l10n.t('se_delay'))),
                DataColumn(label: Text(l10n.t('num_delays'))),
              ],
              rows: [
                DataRow(cells: [
                  DataCell(Text('$gm')),
                  DataCell(Text('$fm')),
                  DataCell(Text('$lc')),
                  DataCell(Text('$cog')),
                  DataCell(Text('$se')),
                  DataCell(Text('$total')),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: const Color(0xFF1976D2),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.t('continue_to_results'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Card(
      color: const Color(0xFFF9F2E8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6A7380))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1976D2))),
      ],
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0D6C7)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF5A4C3A))),
    );
  }
}
