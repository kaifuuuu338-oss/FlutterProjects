import 'package:flutter/material.dart';
import 'package:my_first_app/core/utils/problem_a_risk_engine.dart';
import 'package:my_first_app/screens/behavioral_psychosocial_summary_screen.dart';

class ProblemARiskReviewScreen extends StatelessWidget {
  final String childId;
  final String awwId;
  final int ageMonths;
  final String genderLabel;
  final String genderCode;
  final String awcCode;
  final String overallRisk;
  final String autismRisk;
  final String adhdRisk;
  final String behaviorRisk;
  final double weightKg;
  final double heightCm;
  final double muacCm;
  final double? birthWeightKg;
  final double hemoglobin;
  final String recentIllness;
  final Map<String, double> domainScores;
  final Map<String, String>? domainRiskLevels;
  final int missedMilestones;
  final String explainability;
  final Map<String, int>? delaySummary;
  final ProblemAEnvironmentInput environmentInput;
  final String immunizationStatus;
  final bool congenitalDefect;
  final bool hearingConcern;
  final bool visionConcern;

  const ProblemARiskReviewScreen({
    super.key,
    required this.childId,
    required this.awwId,
    required this.ageMonths,
    required this.genderLabel,
    required this.genderCode,
    required this.awcCode,
    required this.overallRisk,
    required this.autismRisk,
    required this.adhdRisk,
    required this.behaviorRisk,
    required this.weightKg,
    required this.heightCm,
    required this.muacCm,
    required this.birthWeightKg,
    required this.hemoglobin,
    required this.recentIllness,
    required this.domainScores,
    required this.domainRiskLevels,
    required this.missedMilestones,
    required this.explainability,
    required this.delaySummary,
    required this.environmentInput,
    required this.immunizationStatus,
    required this.congenitalDefect,
    required this.hearingConcern,
    required this.visionConcern,
  });

  @override
  Widget build(BuildContext context) {
    final flags = ProblemAFlagsInput(
      autismRisk: autismRisk,
      adhdRisk: adhdRisk,
      behaviorRisk: behaviorRisk,
      gmDelay: delaySummary?['GM_delay'] ?? 0,
      fmDelay: delaySummary?['FM_delay'] ?? 0,
      lcDelay: delaySummary?['LC_delay'] ?? 0,
      cogDelay: delaySummary?['COG_delay'] ?? 0,
      seDelay: delaySummary?['SE_delay'] ?? 0,
    );
    final health = ProblemAHealthInput(
      ageMonths: ageMonths,
      genderCode: genderCode,
      weightKg: weightKg,
      heightCm: heightCm,
      muacCm: muacCm,
      birthWeightKg: birthWeightKg,
      hemoglobin: hemoglobin,
      recentIllness: recentIllness.toLowerCase() == 'yes',
    );
    final result = ProblemARiskEngine.evaluate(
      flags: flags,
      health: health,
      environment: environmentInput,
    );

    final mergedExplainability = [
      ...result.reasons,
      if (congenitalDefect) 'Congenital defect flag is present',
      if (hearingConcern) 'Hearing concern is present',
      if (visionConcern) 'Vision concern is present',
      if (immunizationStatus == 'none' || immunizationStatus == 'partial') 'Immunization is incomplete',
    ].join(', ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screening 4/4 - Composite Risk Review'),
        backgroundColor: const Color(0xFF0D5BA7),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Problem A Composite Risk', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Score: ${result.score}'),
                  Text('Category: ${result.category}'),
                  Text('Stimulation Score (0-10): ${result.stimulationNormalized.toStringAsFixed(2)}'),
                  Text('Low Stimulation: ${result.lowStimulation ? "Yes" : "No"}'),
                  Text('Underweight: ${result.underweight ? "Yes" : "No"}'),
                  Text('WAZ: ${result.waz?.toStringAsFixed(2) ?? "N/A"}'),
                  Text('Stunted: ${result.stunted ? "Yes" : "No"}'),
                  Text('HAZ: ${result.haz?.toStringAsFixed(2) ?? "N/A"}'),
                  Text('Wasted: ${result.wasted ? "Yes" : "No"}'),
                  Text('WHZ: ${result.whz?.toStringAsFixed(2) ?? "N/A"}'),
                  Text('Anaemia: ${result.anaemia ? "Yes" : "No"}'),
                  Text('Nutrition Score: ${result.nutritionScore}'),
                  Text('Nutrition Risk: ${result.nutritionRisk}'),
                  Text('LBW: ${result.lbw ? "Yes" : "No"}'),
                  Text('Early Warning: ${result.earlyWarning ? "Triggered" : "No"}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Explainability', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ...result.reasons.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('- $r'),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => BehavioralPsychosocialSummaryScreen(
                    childId: childId,
                    awwId: awwId,
                    ageMonths: ageMonths,
                    genderLabel: genderLabel,
                    awcCode: awcCode,
                    overallRisk: result.category,
                    autismRisk: autismRisk,
                    adhdRisk: adhdRisk,
                    behaviorRisk: behaviorRisk,
                    baselineScore: result.score,
                    baselineCategory: result.category,
                    immunizationStatus: immunizationStatus,
                    weightKg: weightKg,
                    heightCm: heightCm,
                    muacCm: muacCm,
                    birthWeightKg: birthWeightKg,
                    hemoglobin: hemoglobin,
                    illnessHistory: recentIllness == 'Yes' ? 'Recent illness: Yes' : 'No recent illness',
                    domainScores: domainScores,
                    domainRiskLevels: domainRiskLevels,
                    missedMilestones: missedMilestones,
                    explainability: mergedExplainability.isEmpty ? explainability : mergedExplainability,
                    delaySummary: delaySummary,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F95EA),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Continue to Summary'),
          ),
        ],
      ),
    );
  }
}
