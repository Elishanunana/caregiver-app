// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'elder_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ElderProfileAdapter extends TypeAdapter<ElderProfile> {
  @override
  final int typeId = 0;

  @override
  ElderProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ElderProfile(
      elderId: fields[0] as int?,
      name: fields[1] as String,
      language: fields[2] as String,
      caregiverPhones: fields[3] as String,
      createdAt: fields[4] as String?,
      lastModified: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ElderProfile obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.elderId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.language)
      ..writeByte(3)
      ..write(obj.caregiverPhones)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.lastModified);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElderProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
