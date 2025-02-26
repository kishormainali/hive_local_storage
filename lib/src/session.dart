// ignore_for_file: must_be_immutable

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';

part 'session.freezed.dart';

/// {@template session}
/// A class that represents a session.
/// {@endtemplate}
@freezed
class Session extends HiveObject with _$Session {
  /// {@macro session}
  Session({
    required this.accessToken,
    this.refreshToken = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// The access token.
  @override
  final String accessToken;

  /// The refresh token.
  @override
  final String refreshToken;

  /// The date and time the session was created.
  @override
  final DateTime? createdAt;

  /// The date and time the session was last updated.
  @override
  final DateTime? updatedAt;
}
