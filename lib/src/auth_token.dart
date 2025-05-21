import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_local_storage/src/_jwt_decoder.dart';

part 'auth_token.freezed.dart';
part 'auth_token.g.dart';

/// {@template auth_token}
/// AuthToken class
/// This class is used to store the access token and refresh token.
/// It also provides methods to check if the tokens are expired.
/// {@endtemplate}
@freezed
abstract class AuthToken with _$AuthToken {
  /// {@macro auth_token}
  AuthToken._({DateTime? createdAt, DateTime? updatedAt})
    : createdAt = createdAt ?? DateTime.now(),
      updatedAt = updatedAt ?? DateTime.now();

  /// {@macro auth_token}
  factory AuthToken({
    required String accessToken,
    @Default('') String refreshToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _AuthToken;

  /// created at
  @override
  final DateTime createdAt;

  /// updated at
  @override
  final DateTime updatedAt;

  /// check if access token is expired or not
  bool get isAccessTokenExpired => JwtDecoder.isExpired(accessToken);

  /// check if refresh token is expired or not
  bool get isRefreshTokenExpired =>
      refreshToken.isNotEmpty ? JwtDecoder.isExpired(refreshToken) : false;

  factory AuthToken.fromJson(Map<String, dynamic> json) =>
      _$AuthTokenFromJson(json);
}
