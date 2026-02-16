import 'package:flutter/material.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/screens/result_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('behavioural_psychosocial_summary_title')),
        backgroundColor: const Color(0xFF0D5BA7),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _sectionCard(
            title: l10n.t('child_details'),
            child: _infoTable({
              l10n.t('child_id'): childId,
              l10n.t('age_with_months', {'age': '$ageMonths'}): '',
              l10n.t('gender'): genderLabel,
              l10n.t('awc_code'): awcCode,
            }),
          ),
          _sectionCard(
            title: l10n.t('behaviour_section_title'),
            child: _infoTable({
              l10n.t('autism_risk'): autismRisk,
              l10n.t('adhd_risk'): adhdRisk,
              l10n.t('behavior_risk'): behaviorRisk,
              l10n.t('overall_risk'): overallRisk,
            }),
          ),
          _sectionCard(
            title: l10n.t('baseline_risk_scoring'),
            child: _infoTable({
              l10n.t('baseline_score_label'): '$baselineScore',
              l10n.t('baseline_category_label'): baselineCategory,
            }),
          ),
          _sectionCard(
            title: l10n.t('anthropometry_section_title'),
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
            child: _infoTable({
              l10n.t('immunization_label'): immunizationLabel,
            }),
          ),
          _sectionCard(
            title: l10n.t('domain_breakdown'),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: domainScores.entries.map((entry) {
                final label = domainRiskLevels?[entry.key];
                final title = label == null ? entry.key : '${entry.key} - $label';
                return _pill(title);
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

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 3,
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
                  Expanded(
                    flex: 4,
                    child: Text(e.value),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7E1EC)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
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
}
