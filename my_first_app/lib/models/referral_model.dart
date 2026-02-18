/// Referral types
enum ReferralType { rbsk, phc, specialist, educational }

/// Referral urgency levels
enum ReferralUrgency { normal, urgent, immediate }

/// Referral status
enum ReferralStatus { pending, scheduled, completed, underTreatment, cancelled }

/// Model representing a Referral
class ReferralModel {
  final String referralId;
  final String screeningId;
  final String childId;
  final String awwId;
  final ReferralType referralType;
  final ReferralUrgency urgency;
  final ReferralStatus status;
  final String? notes;
  final DateTime expectedFollowUpDate;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? referredTo;
  final Map<String, dynamic>? metadata;

  ReferralModel({
    required this.referralId,
    required this.screeningId,
    required this.childId,
    required this.awwId,
    required this.referralType,
    required this.urgency,
    required this.status,
    this.notes,
    required this.expectedFollowUpDate,
    required this.createdAt,
    this.completedAt,
    this.referredTo,
    this.metadata,
  });

  factory ReferralModel.fromJson(Map<String, dynamic> json) {
    return ReferralModel(
      referralId: json['referral_id'] ?? '',
      screeningId: json['screening_id'] ?? '',
      childId: json['child_id'] ?? '',
      awwId: json['aww_id'] ?? '',
      referralType: ReferralType.values.firstWhere(
        (e) => e.toString().split('.').last == (json['referral_type'] ?? 'rbsk'),
        orElse: () => ReferralType.rbsk,
      ),
      urgency: ReferralUrgency.values.firstWhere(
        (e) => e.toString().split('.').last == (json['urgency'] ?? 'normal'),
        orElse: () => ReferralUrgency.normal,
      ),
      status: ReferralStatus.values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == (json['status'] ?? 'pending').toString().replaceAll('_', '').toLowerCase(),
        orElse: () => ReferralStatus.pending,
      ),
      notes: json['notes'],
      expectedFollowUpDate: DateTime.parse(json['expected_follow_up_date'] ?? DateTime.now().toIso8601String()),
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      referredTo: json['referred_to'],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'referral_id': referralId,
      'screening_id': screeningId,
      'child_id': childId,
      'aww_id': awwId,
      'referral_type': referralType.toString().split('.').last,
      'urgency': urgency.toString().split('.').last,
      'status': status.toString().split('.').last,
      'notes': notes,
      'expected_follow_up_date': expectedFollowUpDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'referred_to': referredTo,
      'metadata': metadata,
    };
  }

  ReferralModel copyWith({
    String? referralId,
    String? screeningId,
    String? childId,
    String? awwId,
    ReferralType? referralType,
    ReferralUrgency? urgency,
    ReferralStatus? status,
    String? notes,
    DateTime? expectedFollowUpDate,
    DateTime? createdAt,
    DateTime? completedAt,
    String? referredTo,
    Map<String, dynamic>? metadata,
  }) {
    return ReferralModel(
      referralId: referralId ?? this.referralId,
      screeningId: screeningId ?? this.screeningId,
      childId: childId ?? this.childId,
      awwId: awwId ?? this.awwId,
      referralType: referralType ?? this.referralType,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      expectedFollowUpDate: expectedFollowUpDate ?? this.expectedFollowUpDate,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      referredTo: referredTo ?? this.referredTo,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() => 'ReferralModel(referralId: $referralId, childId: $childId, status: $status)';
}
