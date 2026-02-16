// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screening_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScreeningModelAdapter extends TypeAdapter<ScreeningModel> {
  @override
  final int typeId = 3;

  @override
  ScreeningModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScreeningModel(
      screeningId: fields[0] as String,
      childId: fields[1] as String,
      awwId: fields[2] as String,
      assessmentType: fields[3] as AssessmentType,
      ageMonths: fields[4] as int,
      domainResponses: (fields[5] as Map).map((dynamic k, dynamic v) =>
          MapEntry(k as String, (v as List).cast<int>())),
      domainScores: (fields[6] as Map).cast<String, double>(),
      overallRisk: fields[7] as RiskLevel,
      explainability: fields[8] as String,
      missedMilestones: fields[9] as int,
      delayMonths: fields[10] as int,
      consentGiven: fields[11] as bool,
      consentTimestamp: fields[12] as DateTime,
      referralTriggered: fields[13] as bool,
      screeningDate: fields[14] as DateTime,
      submittedAt: fields[15] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ScreeningModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.screeningId)
      ..writeByte(1)
      ..write(obj.childId)
      ..writeByte(2)
      ..write(obj.awwId)
      ..writeByte(3)
      ..write(obj.assessmentType)
      ..writeByte(4)
      ..write(obj.ageMonths)
      ..writeByte(5)
      ..write(obj.domainResponses)
      ..writeByte(6)
      ..write(obj.domainScores)
      ..writeByte(7)
      ..write(obj.overallRisk)
      ..writeByte(8)
      ..write(obj.explainability)
      ..writeByte(9)
      ..write(obj.missedMilestones)
      ..writeByte(10)
      ..write(obj.delayMonths)
      ..writeByte(11)
      ..write(obj.consentGiven)
      ..writeByte(12)
      ..write(obj.consentTimestamp)
      ..writeByte(13)
      ..write(obj.referralTriggered)
      ..writeByte(14)
      ..write(obj.screeningDate)
      ..writeByte(15)
      ..write(obj.submittedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreeningModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RiskLevelAdapter extends TypeAdapter<RiskLevel> {
  @override
  final int typeId = 1;

  @override
  RiskLevel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RiskLevel.low;
      case 1:
        return RiskLevel.medium;
      case 2:
        return RiskLevel.high;
      case 3:
        return RiskLevel.critical;
      default:
        return RiskLevel.low;
    }
  }

  @override
  void write(BinaryWriter writer, RiskLevel obj) {
    switch (obj) {
      case RiskLevel.low:
        writer.writeByte(0);
        break;
      case RiskLevel.medium:
        writer.writeByte(1);
        break;
      case RiskLevel.high:
        writer.writeByte(2);
        break;
      case RiskLevel.critical:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiskLevelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AssessmentTypeAdapter extends TypeAdapter<AssessmentType> {
  @override
  final int typeId = 2;

  @override
  AssessmentType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AssessmentType.baseline;
      case 1:
        return AssessmentType.followUp;
      case 2:
        return AssessmentType.rescreen;
      default:
        return AssessmentType.baseline;
    }
  }

  @override
  void write(BinaryWriter writer, AssessmentType obj) {
    switch (obj) {
      case AssessmentType.baseline:
        writer.writeByte(0);
        break;
      case AssessmentType.followUp:
        writer.writeByte(1);
        break;
      case AssessmentType.rescreen:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssessmentTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
