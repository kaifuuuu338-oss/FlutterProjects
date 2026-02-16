/// Model representing an Anganwadi Worker
class AWWModel {
  final String awwId;
  final String name;
  final String mobileNumber;
  final String awcCode;
  final String mandal;
  final String district;
  final String password;
  final DateTime createdAt;
  final DateTime updatedAt;

  AWWModel({
    required this.awwId,
    required this.name,
    required this.mobileNumber,
    required this.awcCode,
    required this.mandal,
    required this.district,
    required this.password,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AWWModel.fromJson(Map<String, dynamic> json) {
    return AWWModel(
      awwId: json['aww_id'] ?? '',
      name: json['name'] ?? '',
      mobileNumber: json['mobile_number'] ?? '',
      awcCode: json['awc_code'] ?? '',
      mandal: json['mandal'] ?? '',
      district: json['district'] ?? '',
      password: json['password'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'aww_id': awwId,
      'name': name,
      'mobile_number': mobileNumber,
      'awc_code': awcCode,
      'mandal': mandal,
      'district': district,
      'password': password,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AWWModel copyWith({
    String? awwId,
    String? name,
    String? mobileNumber,
    String? awcCode,
    String? mandal,
    String? district,
    String? password,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AWWModel(
      awwId: awwId ?? this.awwId,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      awcCode: awcCode ?? this.awcCode,
      mandal: mandal ?? this.mandal,
      district: district ?? this.district,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'AWWModel(awwId: $awwId, name: $name, awcCode: $awcCode)';
}
