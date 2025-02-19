// ignore_for_file: must_be_immutable

import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

/// {@template session}
/// A class that represents a session.
/// {@endtemplate}
class Session extends HiveObject with EquatableMixin {
  /// {@macro session}
  Session({
    required this.accessToken,
    this.refreshToken = '',
    this.createdAt,
    this.updatedAt,
  });

  /// The access token.
  final String accessToken;

  /// The refresh token.
  final String refreshToken;

  /// The date and time the session was created.
  final DateTime? createdAt;

  /// The date and time the session was last updated.
  final DateTime? updatedAt;

  /// copyWith
  Session copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Session(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        accessToken,
        refreshToken,
        createdAt,
        updatedAt,
      ];
}
