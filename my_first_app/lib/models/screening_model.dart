import 'package:hive/hive.dart';

part 'screening_model.g.dart';

@HiveType(typeId: 1)
enum RiskLevel {
  @HiveField(0)
  low,
  @HiveField(1)
  medium,
  @HiveField(2)
  high,
  @HiveField(3)
  critical,
}

@HiveType(typeId: 2)
enum AssessmentType {
  @HiveField(0)
  baseline,
  @HiveField(1)
  followUp,
  @HiveField(2)
  rescreen,
}

@HiveType(typeId: 3)
class ScreeningModel extends HiveObject {
  @HiveField(0)
  final String screeningId;
  @HiveField(1)
  final String childId;
  @HiveField(2)
  final String awwId;
  @HiveField(3)
  final AssessmentType assessmentType;
  @HiveField(4)
  final int ageMonths;
  @HiveField(5)
  final Map<String, List<int>> domainResponses;
  @HiveField(6)
  final Map<String, double> domainScores;
  @HiveField(7)
  final RiskLevel overallRisk;
  @HiveField(8)
  final String explainability;
  @HiveField(9)
  final int missedMilestones;
  @HiveField(10)
  final int delayMonths;
  @HiveField(11)
  final bool consentGiven;
  @HiveField(12)
  final DateTime consentTimestamp;
  @HiveField(13)
  final bool referralTriggered;
  @HiveField(14)
  final DateTime screeningDate;
  @HiveField(15)
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
