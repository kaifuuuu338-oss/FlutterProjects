import 'package:my_first_app/core/utils/problem_a_lms_service.dart';

class ProblemAEnvironmentInput {
  final bool talksDaily;
  final bool storyReading;
  final bool playTimeAdequate;
  final bool screenTimeHealthy;
  final bool toysAvailable;
  final bool safePlaySpace;

  const ProblemAEnvironmentInput({
    required this.talksDaily,
    required this.storyReading,
    required this.playTimeAdequate,
    required this.screenTimeHealthy,
    required this.toysAvailable,
    required this.safePlaySpace,
  });

  int positiveCount() {
    var score = 0;
    if (talksDaily) score += 1;
    if (storyReading) score += 1;
    if (playTimeAdequate) score += 1;
    if (screenTimeHealthy) score += 1;
    if (toysAvailable) score += 1;
    if (safePlaySpace) score += 1;
    return score;
  }
}

class ProblemAHealthInput {
  final int ageMonths;
  final String genderCode;
  final double weightKg;
  final double heightCm;
  final double muacCm;
  final double? birthWeightKg;
  final double hemoglobin;
  final bool recentIllness;

  const ProblemAHealthInput({
    required this.ageMonths,
    required this.genderCode,
    required this.weightKg,
    required this.heightCm,
    required this.muacCm,
    required this.birthWeightKg,
    required this.hemoglobin,
    required this.recentIllness,
  });
}

class ProblemAFlagsInput {
  final String autismRisk;
  final String adhdRisk;
  final String behaviorRisk;
  final int gmDelay;
  final int fmDelay;
  final int lcDelay;
  final int cogDelay;
  final int seDelay;

  const ProblemAFlagsInput({
    required this.autismRisk,
    required this.adhdRisk,
    required this.behaviorRisk,
    required this.gmDelay,
    required this.fmDelay,
    required this.lcDelay,
    required this.cogDelay,
    required this.seDelay,
  });
}

class ProblemARiskResult {
  final int score;
  final String category;
  final bool underweight;
  final bool stunted;
  final bool wasted;
  final bool anaemia;
  final bool lbw;
  final int nutritionScore;
  final String nutritionRisk;
  final double? waz;
  final double? haz;
  final double? whz;
  final bool lowStimulation;
  final bool earlyWarning;
  final double stimulationNormalized;
  final List<String> reasons;

  const ProblemARiskResult({
    required this.score,
    required this.category,
    required this.underweight,
    required this.stunted,
    required this.wasted,
    required this.anaemia,
    required this.lbw,
    required this.nutritionScore,
    required this.nutritionRisk,
    required this.waz,
    required this.haz,
    required this.whz,
    required this.lowStimulation,
    required this.earlyWarning,
    required this.stimulationNormalized,
    required this.reasons,
  });
}

class _HealthRange {
  final double minWeight;
  final double maxWeight;
  final double minHeight;
  final double maxHeight;

  const _HealthRange({
    required this.minWeight,
    required this.maxWeight,
    required this.minHeight,
    required this.maxHeight,
  });
}

class ProblemARiskEngine {
  static _HealthRange _rangeForAge(int ageMonths) {
    if (ageMonths <= 3) return const _HealthRange(minWeight: 5.0, maxWeight: 6.0, minHeight: 57, maxHeight: 61);
    if (ageMonths <= 6) return const _HealthRange(minWeight: 6.0, maxWeight: 7.5, minHeight: 61, maxHeight: 66);
    if (ageMonths <= 9) return const _HealthRange(minWeight: 7.0, maxWeight: 8.5, minHeight: 66, maxHeight: 71);
    if (ageMonths <= 12) return const _HealthRange(minWeight: 8.0, maxWeight: 9.5, minHeight: 70, maxHeight: 75);
    if (ageMonths <= 18) return const _HealthRange(minWeight: 9.0, maxWeight: 11.0, minHeight: 75, maxHeight: 82);
    if (ageMonths <= 24) return const _HealthRange(minWeight: 10.5, maxWeight: 12.5, minHeight: 82, maxHeight: 88);
    if (ageMonths <= 36) return const _HealthRange(minWeight: 12.0, maxWeight: 14.5, minHeight: 88, maxHeight: 96);
    if (ageMonths <= 48) return const _HealthRange(minWeight: 14.0, maxWeight: 17.0, minHeight: 96, maxHeight: 105);
    if (ageMonths <= 60) return const _HealthRange(minWeight: 16.0, maxWeight: 20.0, minHeight: 105, maxHeight: 112);
    return const _HealthRange(minWeight: 18.0, maxWeight: 23.0, minHeight: 112, maxHeight: 120);
  }

  static int _riskBonus(String risk, {required int high, required int moderate}) {
    final r = risk.trim().toLowerCase();
    if (r == 'critical' || r == 'high') return high;
    if (r == 'medium' || r == 'moderate') return moderate;
    return 0;
  }

  static ProblemARiskResult evaluate({
    required ProblemAFlagsInput flags,
    required ProblemAHealthInput health,
    required ProblemAEnvironmentInput environment,
  }) {
    final range = _rangeForAge(health.ageMonths);
    final stimulationRaw = environment.positiveCount();
    final stimulationNormalized = (stimulationRaw / 6.0) * 10.0;
    final lowStimulation = stimulationNormalized < 5.0;

    final lms = ProblemALmsService.instance;
    final wfaLms = lms.wfaByAgeMonths(
      ageMonths: health.ageMonths,
      genderCode: health.genderCode,
    );
    final hfaLms = lms.hfaByAgeMonths(
      ageMonths: health.ageMonths,
      genderCode: health.genderCode,
    );
    final wfhLms = lms.wfhByHeightCm(
      heightCm: health.heightCm,
      genderCode: health.genderCode,
    );

    final waz = wfaLms == null
        ? null
        : lms.zScore(x: health.weightKg, point: wfaLms);
    final haz = hfaLms == null
        ? null
        : lms.zScore(x: health.heightCm, point: hfaLms);
    final whz = wfhLms == null
        ? null
        : lms.zScore(x: health.weightKg, point: wfhLms);

    final underweight = waz == null ? (health.weightKg < range.minWeight) : (waz < -2);
    final stunted = haz == null ? (health.heightCm < range.minHeight) : (haz < -2);
    // Book-aligned wasting rule:
    // WHZ < -2 => wasted, WHZ < -3 => severe wasted.
    final wasted = whz != null && whz < -2;
    final severeWasted = whz != null && whz < -3;

    // Book-aligned anemia rule:
    // for 6-59 months only, Hb < 11 => anemia.
    final anaemia = health.ageMonths >= 6 && health.ageMonths <= 59 && health.hemoglobin < 11.0;
    final lbw = (health.birthWeightKg ?? 9.9) < 2.5;

    // Nutrition dataset formula (fixed weights):
    // nutrition_score = 2*underweight + 3*stunting + 2*wasting + 1*anemia
    final nutritionScore = (underweight ? 2 : 0) +
        (stunted ? 3 : 0) +
        (wasted ? 2 : 0) +
        (anaemia ? 1 : 0);
    final nutritionRisk = nutritionScore == 0
        ? 'Low'
        : (nutritionScore <= 3 ? 'Medium' : 'High');

    final numDelays = [flags.gmDelay, flags.fmDelay, flags.lcDelay, flags.cogDelay, flags.seDelay].where((d) => d > 0).length;
    final delayPoints = numDelays * 5;

    final autismBonus = _riskBonus(flags.autismRisk, high: 15, moderate: 8);
    final adhdBonus = _riskBonus(flags.adhdRisk, high: 8, moderate: 4);
    final behaviorBonus = _riskBonus(flags.behaviorRisk, high: 7, moderate: 0);

    var score = delayPoints + autismBonus + adhdBonus + behaviorBonus;
    if (stunted) score += 3;
    if (wasted) score += 4;
    if (anaemia) score += 2;
    if (lbw) score += 2;
    if (lowStimulation) score += 3;
    if (health.recentIllness) score += 1;

    final earlyWarning = (numDelays == 0 && lbw && anaemia && lowStimulation) ||
        (flags.lcDelay > 0 && (lbw || anaemia));

    String category;
    if (score <= 10) {
      category = 'Low';
    } else if (score <= 25) {
      category = 'Medium';
    } else if (score <= 40) {
      category = 'High';
    } else {
      category = 'Critical';
    }

    final reasons = <String>[];
    if (numDelays >= 2) reasons.add('Multiple developmental delays detected');
    if (_riskBonus(flags.autismRisk, high: 1, moderate: 1) > 0) reasons.add('Autism indicators are elevated');
    if (_riskBonus(flags.adhdRisk, high: 1, moderate: 1) > 0) reasons.add('ADHD indicators are elevated');
    if (_riskBonus(flags.behaviorRisk, high: 1, moderate: 0) > 0) reasons.add('Behavior risk is elevated');
    if (underweight) reasons.add('Underweight flag is present');
    if (stunted) reasons.add('Height is below age-expected range');
    if (wasted) reasons.add(severeWasted ? 'WHZ below -3 (severe wasting)' : 'WHZ below -2 (wasting)');
    if (anaemia) reasons.add('Hemoglobin below 11 g/dL (anaemia flag)');
    reasons.add('Nutrition score = $nutritionScore ($nutritionRisk risk)');
    if (lbw) reasons.add('Low birth weight history');
    if (lowStimulation) reasons.add('Low stimulation home environment');
    if (health.recentIllness) reasons.add('Recent illness adds vulnerability');
    if (earlyWarning) reasons.add('Future risk early warning triggered');
    if (waz != null) reasons.add('WAZ: ${waz.toStringAsFixed(2)}');
    if (haz != null) reasons.add('HAZ: ${haz.toStringAsFixed(2)}');
    if (whz != null) reasons.add('WHZ: ${whz.toStringAsFixed(2)}');
    if (whz == null) reasons.add('WHZ not computed (WFH LMS file not found)');

    return ProblemARiskResult(
      score: score,
      category: category,
      underweight: underweight,
      stunted: stunted,
      wasted: wasted,
      anaemia: anaemia,
      lbw: lbw,
      nutritionScore: nutritionScore,
      nutritionRisk: nutritionRisk,
      waz: waz,
      haz: haz,
      whz: whz,
      lowStimulation: lowStimulation,
      earlyWarning: earlyWarning,
      stimulationNormalized: stimulationNormalized,
      reasons: reasons,
    );
  }
}
