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
class Session {
  /// Creates a new [Session] instance.
  ///
  /// The [accessToken] is required and represents the primary authentication token.
  /// The [refreshToken] is optional and used for token renewal.
  /// If [createdAt] or [updatedAt] are not provided, they default to the current time.
  Session({
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

  /// Returns a string representation of the session for debugging purposes.
  @override
  String toString() {
    return 'Session{accessToken: $accessToken, refreshToken: $refreshToken , createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}
