// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medication_schedule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedicationScheduleAdapter extends TypeAdapter<MedicationSchedule> {
  @override
  final int typeId = 1;

  @override
  MedicationSchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MedicationSchedule(
      scheduleId: fields[0] as int?,
      elderId: fields[1] as int,
      drugName: fields[2] as String,
      dosage: fields[3] as String,
      timeDue: fields[4] as String,
      daysOfWeek: fields[5] as String,
      active: fields[6] as int,
      prescribedBy: fields[7] as String,
      syncMethod: fields[8] as String,
      lastModified: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MedicationSchedule obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.scheduleId)
      ..writeByte(1)
      ..write(obj.elderId)
      ..writeByte(2)
      ..write(obj.drugName)
      ..writeByte(3)
      ..write(obj.dosage)
      ..writeByte(4)
      ..write(obj.timeDue)
      ..writeByte(5)
      ..write(obj.daysOfWeek)
      ..writeByte(6)
      ..write(obj.active)
      ..writeByte(7)
      ..write(obj.prescribedBy)
      ..writeByte(8)
      ..write(obj.syncMethod)
      ..writeByte(9)
      ..write(obj.lastModified);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicationScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
