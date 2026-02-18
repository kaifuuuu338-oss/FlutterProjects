class ReferralSummaryItem {
  final String referralId;
  final String childId;
  final String awwId;
  final int ageMonths;
  final String overallRisk;
  final String referralType;
  final String urgency;
  final String status;
  final DateTime createdAt;
  final DateTime expectedFollowUpDate;
  final String? notes;
  final List<String> reasons;

  const ReferralSummaryItem({
    required this.referralId,
    required this.childId,
    required this.awwId,
    required this.ageMonths,
    required this.overallRisk,
    required this.referralType,
    required this.urgency,
    this.status = 'pending',
    required this.createdAt,
    required this.expectedFollowUpDate,
    required this.reasons,
    this.notes,
  });
}
