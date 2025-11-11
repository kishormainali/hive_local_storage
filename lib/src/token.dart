import 'jwt_decoder.dart';

/// Represents a user session containing authentication tokens and timestamps.
///
/// This class holds the access token and optional refresh token for user
/// authentication, along with creation and update timestamps for session
/// management.
///
/// Example usage:
/// ```dart
/// final session = Session(
///   accessToken: 'your-access-token',
///   refreshToken: 'your-refresh-token',
/// );
/// ```
class Session extends AuthToken {
  /// Creates a new [Session] instance.
  ///
  /// The [accessToken] is required and represents the primary authentication token.
  /// The [refreshToken] is optional and used for token renewal.
  /// If [createdAt] or [updatedAt] are not provided, they default to the current time.
  Session({
    required super.accessToken,
    super.refreshToken,
    super.createdAt,
    super.updatedAt,
  });

  /// Returns a string representation of the session for debugging purposes.
  @override
  String toString() {
    return 'Session{accessToken: $accessToken, refreshToken: $refreshToken , createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}

class AuthToken {
  /// Creates a new [AuthToken] instance.
  ///
  /// The [accessToken] is required and represents the primary authentication token.
  /// The [refreshToken] is optional and used for token renewal.
  /// If [createdAt] or [updatedAt] are not provided, they default to the current time.
  AuthToken({
    required this.accessToken,
    this.refreshToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// The primary authentication token used for API requests.
  final String accessToken;

  /// Optional token used to refresh the [accessToken] when it expires.
  final String? refreshToken;

  /// The timestamp when this session was created.
  final DateTime? createdAt;

  /// The timestamp when this session was last updated.
  final DateTime? updatedAt;

  /// Creates a copy of this session with optionally updated values.
  ///
  /// This method allows updating specific fields while preserving others.
  /// Any parameter that is not provided will use the value from the current session.
  ///
  /// Example:
  /// ```dart
  /// final updatedSession = session.copyWith(
  ///   accessToken: 'new-access-token',
  ///   updatedAt: DateTime.now(),
  /// );
  /// ```
  AuthToken copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AuthToken(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Tells whether the access token is expired.
  bool get isAccessTokenExpired {
    return JwtDecoder.isExpired(accessToken);
  }

  /// Tells whether the refresh token is expired.
  bool get isRefreshTokenExpired {
    if (refreshToken == null) {
      return true;
    }
    return JwtDecoder.isExpired(refreshToken!);
  }

  /// Tells whether the access token can be refreshed.
  bool get canRefresh => refreshToken != null && !isRefreshTokenExpired;

  @override
  int get hashCode =>
      Object.hashAll([accessToken, refreshToken, createdAt, updatedAt]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AuthToken &&
        other.accessToken == accessToken &&
        other.refreshToken == refreshToken &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  /// Returns a string representation of the session for debugging purposes.
  @override
  String toString() {
    return 'AuthToken{accessToken: $accessToken, refreshToken: $refreshToken , createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}
