import 'package:hive_ce/hive.dart';

import 'token.dart';

/// Hive TypeAdapter for serializing and deserializing [Session] objects.
///
/// This adapter handles the binary serialization of Session instances for
/// storage in Hive boxes. It implements the required read and write methods
/// to convert Session objects to/from binary format.
///
/// The adapter uses typeId 0 and serializes the following fields in order:
/// - accessToken (field 0)
/// - refreshToken (field 1)
/// - createdAt (field 2)
/// - updatedAt (field 3)
class SessionAdapter extends TypeAdapter<Session> {
  /// The unique identifier for this type adapter.
  /// This must be unique across all registered adapters.
  @override
  final int typeId = 0;

  /// Deserializes a [Session] object from binary data.
  ///
  /// Reads the binary data and reconstructs a Session instance with
  /// the stored field values.
  @override
  Session read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Session(
      accessToken: fields[0] as String,
      refreshToken: fields[1] as String?,
      createdAt: fields[2] as DateTime?,
      updatedAt: fields[3] as DateTime?,
    );
  }

  /// Serializes a [Session] object to binary data.
  ///
  /// Writes the session fields to binary format in a specific order
  /// that matches the read method.
  @override
  void write(BinaryWriter writer, Session obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.accessToken)
      ..writeByte(1)
      ..write(obj.refreshToken)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.updatedAt);
  }

  /// Returns the hash code for this adapter based on its typeId.
  @override
  int get hashCode => typeId.hashCode;

  /// Compares this adapter with another object for equality.
  ///
  /// Two SessionAdapter instances are equal if they have the same
  /// runtime type and typeId.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
