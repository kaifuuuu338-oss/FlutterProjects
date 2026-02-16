/// Model representing a Child
class ChildModel {
  final String childId;
  final String childName;
  final DateTime dateOfBirth;
  final int ageMonths;
  final String gender;
  final String awcCode;
  final String mandal;
  final String district;
  final String parentName;
  final String parentMobile;
  final String? aadhaar;
  final String? address;
  final String awwId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChildModel({
    required this.childId,
    required this.childName,
    required this.dateOfBirth,
    required this.ageMonths,
    required this.gender,
    required this.awcCode,
    required this.mandal,
    required this.district,
    required this.parentName,
    required this.parentMobile,
    this.aadhaar,
    this.address,
    required this.awwId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    return ChildModel(
      childId: json['child_id'] ?? '',
      childName: json['child_name'] ?? '',
      dateOfBirth: DateTime.parse(json['date_of_birth'] ?? DateTime.now().toIso8601String()),
      ageMonths: json['age_months'] ?? 0,
      gender: json['gender'] ?? 'M',
      awcCode: json['awc_code'] ?? '',
      mandal: json['mandal'] ?? '',
      district: json['district'] ?? '',
      parentName: json['parent_name'] ?? '',
      parentMobile: json['parent_mobile'] ?? '',
      aadhaar: json['aadhaar'],
      address: json['address'],
      awwId: json['aww_id'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'child_id': childId,
      'child_name': childName,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'age_months': ageMonths,
      'gender': gender,
      'awc_code': awcCode,
      'mandal': mandal,
      'district': district,
      'parent_name': parentName,
      'parent_mobile': parentMobile,
      'aadhaar': aadhaar,
      'address': address,
      'aww_id': awwId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ChildModel copyWith({
    String? childId,
    String? childName,
    DateTime? dateOfBirth,
    int? ageMonths,
    String? gender,
    String? awcCode,
    String? mandal,
    String? district,
    String? parentName,
    String? parentMobile,
    String? aadhaar,
    String? address,
    String? awwId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChildModel(
      childId: childId ?? this.childId,
      childName: childName ?? this.childName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      ageMonths: ageMonths ?? this.ageMonths,
      gender: gender ?? this.gender,
      awcCode: awcCode ?? this.awcCode,
      mandal: mandal ?? this.mandal,
      district: district ?? this.district,
      parentName: parentName ?? this.parentName,
      parentMobile: parentMobile ?? this.parentMobile,
      aadhaar: aadhaar ?? this.aadhaar,
      address: address ?? this.address,
      awwId: awwId ?? this.awwId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'ChildModel(childId: $childId, childName: $childName, ageMonths: $ageMonths)';
}
