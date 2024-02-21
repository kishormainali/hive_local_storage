// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: lines_longer_than_80_chars
// ******************************************************************
// Type Adapters
// ******************************************************************

import 'package:example/adapters/contact.dart';
import 'package:example/adapters/user.dart';
import 'package:hive_local_storage/hive_local_storage.dart';

void registerAdapters() {
  Hive
    ..registerAdapter<Contact>(ContactAdapter())
    ..registerAdapter<User>(UserAdapter());
}
