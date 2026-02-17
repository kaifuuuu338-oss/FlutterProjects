import 'dart:math';

/// Weighted Scoring Engine with Sigmoidal Threshold
/// 
/// Formula (where aᵢ ∈ {0,1}, wᵢ are weights):
/// 
/// S = Σ(aᵢ × wᵢ)                    [Weighted Sum]
/// T = 0.5 × Σ(wᵢ)                  [Threshold @ 50% of max]
/// P = 1 / (1 + e^(-(S-T)))          [Sigmoid centered at T]
/// Output = 1 if P ≥ 0.5, else 0     [Binary decision]

class WeightedScoringEngine {
  /// Question bank with weights for each age band
  static const Map<String, Map<String, List<Map<String, dynamic>>>> questionWeights = {
    '0-12': _q0To12Weights,
    '13-24': _q13To24Weights,
    '25-36': _q25To36Weights,
    '37-48': _q37To48Weights,
    '49-60': _q49To60Weights,
    '61-72': _q61To72Weights,
  };

  /// Get age band key for given age in months
  static String _getAgeBandKey(int ageMonths) {
    if (ageMonths <= 12) return '0-12';
    if (ageMonths <= 24) return '13-24';
    if (ageMonths <= 36) return '25-36';
    if (ageMonths <= 48) return '37-48';
    if (ageMonths <= 60) return '49-60';
    return '61-72';
  }

  /// Calculate weighted risk score for a domain
  /// 
  /// Parameters:
  /// - domain: GM, FM, LC, COG, SE
  /// - responses: List of 0 (No) or 1 (Yes) binary answers
  /// - ageMonths: Child's age in months
  /// 
  /// Returns: Risk score (0.0 to 1.0) where 1.0 = highest risk
  /// 
  /// Formula:
  /// S = Σ(aᵢ × wᵢ)                    [Weighted sum of answers]
  /// T = 0.5 × Σ(wᵢ)                  [Threshold at 50% of max]
  /// P = 1 / (1 + e^(-(S-T)))          [Sigmoid function]
  /// risk_score = P                    [Return probability]
  static double computeDomainScore(
    String domain,
    List<int> responses,
    int ageMonths,
  ) {
    final ageBand = _getAgeBandKey(ageMonths);
    final weights = questionWeights[ageBand]?[domain];

    if (weights == null || weights.isEmpty) {
      return 0.5; // default neutral if no data
    }

    if (responses.isEmpty || responses.length != weights.length) {
      return 0.5; // mismatch between responses and weights
    }

    // STEP 1: Calculate weighted sum S = Σ(aᵢ × wᵢ)
    double totalScore = 0;
    double totalWeight = 0;

    for (int i = 0; i < responses.length; i++) {
      final answer = responses[i]; // 0 or 1 (binary: No or Yes)
      final weight = weights[i]['weight'] as int;

      totalScore += (answer * weight);
      totalWeight += weight;
    }

    // STEP 2: Calculate threshold T = 0.5 × Σ(wᵢ)
    final threshold = 0.5 * totalWeight;

    // STEP 3: Apply sigmoid function P = 1 / (1 + e^(-(S-T)))
    final riskScore = _sigmoidFunction(totalScore, threshold);

    return riskScore;
  }

  /// Sigmoid function: P = 1 / (1 + e^(-(x - center)))
  /// 
  /// This creates an S-curve centered at 'center':
  /// - When x << center: P ≈ 0 (low risk)
  /// - When x = center: P = 0.5 (50% probability)
  /// - When x >> center: P ≈ 1 (high risk)
  static double _sigmoidFunction(double score, double threshold) {
    if (score <= threshold - 10) return 0.0; // avoid underflow
    if (score >= threshold + 10) return 1.0; // avoid overflow

    final exponent = -(score - threshold);
    return 1 / (1 + exp(exponent));
  }

  /// Convert domain risk score to risk label
  /// 
  /// Thresholds (based on sigmoid output):
  /// - 0.0 - 0.3: Low
  /// - 0.3 - 0.6: Medium
  /// - 0.6 - 0.85: High
  /// - 0.85 - 1.0: Critical
  static String domainScoreToRiskLabel(double score) {
    if (score < 0.3) return 'low';
    if (score < 0.6) return 'medium';
    if (score < 0.85) return 'high';
    return 'critical';
  }

  /// Calculate overall risk from domain scores (maximum risk level)
  static String overallRiskFromDomains(Map<String, double> domainScores) {
    if (domainScores.isEmpty) return 'low';

    final maxRisk = domainScores.values.fold<double>(0, (max, score) => score > max ? score : max);
    return domainScoreToRiskLabel(maxRisk);
  }

  // ===== AGE BAND WEIGHTS =====

  static const Map<String, List<Map<String, dynamic>>> _q0To12Weights = {
    'GM': [
      {'weight': 2, 'type': 'Expected'},
      {'weight': 4, 'type': 'Neurological'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'FM': [
      {'weight': 2, 'type': 'Expected'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'LC': [
      {'weight': 2, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'COG': [
      {'weight': 2, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'SE': [
      {'weight': 2, 'type': 'Expected'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
  };

  static const Map<String, List<Map<String, dynamic>>> _q13To24Weights = {
    'GM': [
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 4, 'type': 'Neurological'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'FM': [
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'LC': [
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'COG': [
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'SE': [
      {'weight': 2, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
  };

  static const Map<String, List<Map<String, dynamic>>> _q25To36Weights = {
    'GM': [
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'FM': [
      {'weight': 3, 'type': 'Expected'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'LC': [
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'COG': [
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'SE': [
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
  };

  static const Map<String, List<Map<String, dynamic>>> _q37To48Weights = {
    'GM': [
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 4, 'type': 'Neurological'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'FM': [
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'LC': [
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'COG': [
      {'weight': 2, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'SE': [
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
  };

  static const Map<String, List<Map<String, dynamic>>> _q49To60Weights = {
    'GM': [
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 4, 'type': 'Neurological'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'FM': [
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Expected'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'LC': [
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'COG': [
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Expected'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'SE': [
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
  };

  static const Map<String, List<Map<String, dynamic>>> _q61To72Weights = {
    'GM': [
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Expected'},
      {'weight': 4, 'type': 'Neurological'},
      {'weight': 3, 'type': 'Expected'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'FM': [
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'LC': [
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'COG': [
      {'weight': 3, 'type': 'Expected'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
    'SE': [
      {'weight': 3, 'type': 'Expected'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 3, 'type': 'Progressive'},
      {'weight': 2, 'type': 'Expected'},
      {'weight': 8, 'type': 'Red Flag'},
    ],
  };
}
