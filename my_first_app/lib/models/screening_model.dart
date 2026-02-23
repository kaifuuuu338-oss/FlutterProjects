enum RiskLevel {
  low,
  medium,
  high,
  critical,
}

enum AssessmentType {
  baseline,
  followUp,
  rescreen,
}

class ScreeningModel {
  final String screeningId;
  final String childId;
  final String awwId;
  final AssessmentType assessmentType;
  final int ageMonths;
  final Map<String, List<int>> domainResponses;
  final Map<String, double> domainScores;
  final RiskLevel overallRisk;
  final String explainability;
  final int missedMilestones;
  final int delayMonths;
  final bool consentGiven;
  final DateTime consentTimestamp;
  final bool referralTriggered;
  final DateTime screeningDate;
  final DateTime? submittedAt;

  ScreeningModel({
    required this.screeningId,
    required this.childId,
    required this.awwId,
    required this.assessmentType,
    required this.ageMonths,
    required this.domainResponses,
    required this.domainScores,
    required this.overallRisk,
    required this.explainability,
    required this.missedMilestones,
    required this.delayMonths,
    required this.consentGiven,
    required this.consentTimestamp,
    required this.referralTriggered,
    required this.screeningDate,
    this.submittedAt,
  });

  factory ScreeningModel.fromJson(Map<String, dynamic> json) {
    return ScreeningModel(
      screeningId: json['screening_id'] ?? '',
      childId: json['child_id'] ?? '',
      awwId: json['aww_id'] ?? '',
      assessmentType: AssessmentType.values.firstWhere(
        (e) => e.toString().split('.').last == (json['assessment_type'] ?? 'baseline'),
        orElse: () => AssessmentType.baseline,
      ),
      ageMonths: json['age_months'] ?? 0,
      domainResponses: Map<String, List<int>>.from(
        (json['domain_responses'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, List<int>.from(v as List)),
            ) ??
            {},
      ),
      domainScores: Map<String, double>.from(
        (json['domain_scores'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num).toDouble()),
            ) ??
            {},
      ),
      overallRisk: RiskLevel.values.firstWhere(
        (e) => e.toString().split('.').last == (json['overall_risk'] ?? 'low'),
        orElse: () => RiskLevel.low,
      ),
      explainability: json['explainability'] ?? '',
      missedMilestones: json['missed_milestones'] ?? 0,
      delayMonths: json['delay_months'] ?? 0,
      consentGiven: json['consent_given'] ?? false,
      consentTimestamp: DateTime.parse(json['consent_timestamp'] ?? DateTime.now().toIso8601String()),
      referralTriggered: json['referral_triggered'] ?? false,
      screeningDate: DateTime.parse(json['screening_date'] ?? DateTime.now().toIso8601String()),
      submittedAt: json['submitted_at'] != null ? DateTime.parse(json['submitted_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'screening_id': screeningId,
      'child_id': childId,
      'aww_id': awwId,
      'assessment_type': assessmentType.toString().split('.').last,
      'age_months': ageMonths,
      'domain_responses': domainResponses,
      'domain_scores': domainScores,
      'overall_risk': overallRisk.toString().split('.').last,
      'explainability': explainability,
      'missed_milestones': missedMilestones,
      'delay_months': delayMonths,
      'consent_given': consentGiven,
      'consent_timestamp': consentTimestamp.toIso8601String(),
      'referral_triggered': referralTriggered,
      'screening_date': screeningDate.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
    };
  }

  ScreeningModel copyWith({
    String? screeningId,
    String? childId,
    String? awwId,
    AssessmentType? assessmentType,
    int? ageMonths,
    Map<String, List<int>>? domainResponses,
    Map<String, double>? domainScores,
    RiskLevel? overallRisk,
    String? explainability,
    int? missedMilestones,
    int? delayMonths,
    bool? consentGiven,
    DateTime? consentTimestamp,
    bool? referralTriggered,
    DateTime? screeningDate,
    DateTime? submittedAt,
  }) {
    return ScreeningModel(
      screeningId: screeningId ?? this.screeningId,
      childId: childId ?? this.childId,
      awwId: awwId ?? this.awwId,
      assessmentType: assessmentType ?? this.assessmentType,
      ageMonths: ageMonths ?? this.ageMonths,
      domainResponses: domainResponses ?? this.domainResponses,
      domainScores: domainScores ?? this.domainScores,
      overallRisk: overallRisk ?? this.overallRisk,
      explainability: explainability ?? this.explainability,
      missedMilestones: missedMilestones ?? this.missedMilestones,
      delayMonths: delayMonths ?? this.delayMonths,
      consentGiven: consentGiven ?? this.consentGiven,
      consentTimestamp: consentTimestamp ?? this.consentTimestamp,
      referralTriggered: referralTriggered ?? this.referralTriggered,
      screeningDate: screeningDate ?? this.screeningDate,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  @override
  String toString() => 'ScreeningModel(screeningId: $screeningId, childId: $childId, overallRisk: $overallRisk)';
}
