import 'package:flutter/material.dart';
import 'package:my_first_app/core/utils/problem_a_risk_engine.dart';
import 'package:my_first_app/screens/problem_a_risk_review_screen.dart';

class ProblemAEnvironmentScreen extends StatefulWidget {
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

  const ProblemAEnvironmentScreen({
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
  });

  @override
  State<ProblemAEnvironmentScreen> createState() => _ProblemAEnvironmentScreenState();
}

class _ProblemAEnvironmentScreenState extends State<ProblemAEnvironmentScreen> {
  bool talksDaily = true;
  bool storyReading = false;
  bool playAdequate = true;
  bool screenHealthy = true;
  bool toysAvailable = true;
  bool safeSpace = true;

  String immunizationStatus = 'unknown';
  bool congenitalDefect = false;
  bool hearingConcern = false;
  bool visionConcern = false;

  Widget _ynTile(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE7F2)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _continue() {
    final env = ProblemAEnvironmentInput(
      talksDaily: talksDaily,
      storyReading: storyReading,
      playTimeAdequate: playAdequate,
      screenTimeHealthy: screenHealthy,
      toysAvailable: toysAvailable,
      safePlaySpace: safeSpace,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProblemARiskReviewScreen(
          childId: widget.childId,
          awwId: widget.awwId,
          ageMonths: widget.ageMonths,
          genderLabel: widget.genderLabel,
          genderCode: widget.genderCode,
          awcCode: widget.awcCode,
          overallRisk: widget.overallRisk,
          autismRisk: widget.autismRisk,
          adhdRisk: widget.adhdRisk,
          behaviorRisk: widget.behaviorRisk,
          weightKg: widget.weightKg,
          heightCm: widget.heightCm,
          muacCm: widget.muacCm,
          birthWeightKg: widget.birthWeightKg,
          hemoglobin: widget.hemoglobin,
          recentIllness: widget.recentIllness,
          domainScores: widget.domainScores,
          domainRiskLevels: widget.domainRiskLevels,
          missedMilestones: widget.missedMilestones,
          explainability: widget.explainability,
          delaySummary: widget.delaySummary,
          environmentInput: env,
          immunizationStatus: immunizationStatus,
          congenitalDefect: congenitalDefect,
          hearingConcern: hearingConcern,
          visionConcern: visionConcern,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screening 3/4 - Environment & Health Flags'),
        backgroundColor: const Color(0xFF0D5BA7),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Environment / Stimulation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _ynTile('Caregiver talks to child daily', talksDaily, (v) => setState(() => talksDaily = v)),
          _ynTile('Story reading happens regularly', storyReading, (v) => setState(() => storyReading = v)),
          _ynTile('Play time is at least 1 hour', playAdequate, (v) => setState(() => playAdequate = v)),
          _ynTile('Screen time is <= 1 hour/day', screenHealthy, (v) => setState(() => screenHealthy = v)),
          _ynTile('Toys/play materials are available', toysAvailable, (v) => setState(() => toysAvailable = v)),
          _ynTile('Safe play area is available', safeSpace, (v) => setState(() => safeSpace = v)),
          const SizedBox(height: 14),
          const Text('Immunization & Congenital Flags', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: immunizationStatus,
            decoration: const InputDecoration(labelText: 'Immunization status', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'full', child: Text('Full')),
              DropdownMenuItem(value: 'partial', child: Text('Partial')),
              DropdownMenuItem(value: 'none', child: Text('None')),
              DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
            ],
            onChanged: (v) => setState(() => immunizationStatus = v ?? 'unknown'),
          ),
          const SizedBox(height: 8),
          _ynTile('Any congenital defect reported', congenitalDefect, (v) => setState(() => congenitalDefect = v)),
          _ynTile('Hearing concern observed', hearingConcern, (v) => setState(() => hearingConcern = v)),
          _ynTile('Vision concern observed', visionConcern, (v) => setState(() => visionConcern = v)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _continue,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F95EA),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Continue to Risk Engine'),
          ),
        ],
      ),
    );
  }
}
