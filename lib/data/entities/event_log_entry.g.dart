// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_log_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EventLogEntryAdapter extends TypeAdapter<EventLogEntry> {
  @override
  final int typeId = 2;

  @override
  EventLogEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EventLogEntry(
      eventId: fields[0] as int?,
      eventType: fields[1] as String,
      timestamp: fields[2] as String?,
      details: fields[3] as String?,
      syncedFlag: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, EventLogEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.eventId)
      ..writeByte(1)
      ..write(obj.eventType)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.details)
      ..writeByte(4)
      ..write(obj.syncedFlag);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventLogEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
