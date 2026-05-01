// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_queue_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncQueueEntryAdapter extends TypeAdapter<SyncQueueEntry> {
  @override
  final int typeId = 3;

  @override
  SyncQueueEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncQueueEntry(
      changeId: fields[0] as String,
      entityType: fields[1] as String,
      entityId: fields[2] as int,
      changeType: fields[3] as String,
      timestamp: fields[4] as String?,
      syncState: fields[5] as String,
      direction: fields[6] as String,
      transport: fields[7] as String,
      payload: fields[8] as String,
      attempts: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SyncQueueEntry obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.changeId)
      ..writeByte(1)
      ..write(obj.entityType)
      ..writeByte(2)
      ..write(obj.entityId)
      ..writeByte(3)
      ..write(obj.changeType)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.syncState)
      ..writeByte(6)
      ..write(obj.direction)
      ..writeByte(7)
      ..write(obj.transport)
      ..writeByte(8)
      ..write(obj.payload)
      ..writeByte(9)
      ..write(obj.attempts);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncQueueEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
