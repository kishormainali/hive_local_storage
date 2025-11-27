import 'dart:convert';
import 'dart:developer' as dev;

class JwtDecoder {
  /// Decode a string JWT token into a `Map<String, dynamic>`
  /// containing the decoded JSON payload.
  ///
  /// Note: header and signature are not returned by this method.
  ///
  /// Throws [FormatException] if parameter is not a valid JWT token.
  static Map<String, dynamic> decode(String token) {
    // Remove 'Bearer ' prefix if present
    final tokenParts = token.split(' ');
    if (tokenParts.length == 2 && tokenParts[0] == 'Bearer') {
      token = tokenParts[1];
    }

    // Split the token by '.'
    final splitToken = token.split(".");
    if (splitToken.length != 3) {
      throw const FormatException('Invalid token');
    }
    try {
      final payloadBase64 = splitToken[1]; // Payload is always the index 1
      // Base64 should be multiple of 4. Normalize the payload before decode it
      final normalizedPayload = base64.normalize(payloadBase64);
      // Decode payload, the result is a String
      final payloadString = utf8.decode(base64.decode(normalizedPayload));
      // Parse the String to a Map<String, dynamic>
      final decodedPayload = jsonDecode(payloadString);

      // Return the decoded payload
      return decodedPayload;
    } catch (error) {
      dev.log('Error decoding token payload', error: error);
      throw const FormatException('Invalid payload');
    }
  }

  /// Decode a string JWT token into a `Map<String, dynamic>`
  /// containing the decoded JSON payload.
  ///
  /// Note: header and signature are not returned by this method.
  ///
  /// Returns null if the token is not valid
  static Map<String, dynamic>? tryDecode(String token) {
    try {
      return decode(token);
    } catch (error) {
      return null;
    }
  }

  /// Tells whether a token is expired.
  ///
  /// Returns false if the token is valid, true if it is expired.
  ///
  /// Throws [FormatException] if parameter is not a valid JWT token.
  static bool isExpired(String token) {
    final (expirationDate, isValid) = getExpirationDate(token);

    print(expirationDate);

    // Check if the expiration date is valid
    if (!isValid) {
      // If there is no expiration date, consider the token as expired
      dev.log('Token has no expiration date - considering it expired');
      return true;
    }

    // If the current date is after the expiration date, the token is already expired
    return DateTime.now().isAfter(expirationDate);
  }

  /// Returns token expiration date
  ///
  static (DateTime, bool) getExpirationDate(String token) {
    final decodedToken = tryDecode(token);

    if (decodedToken == null || !decodedToken.containsKey('exp')) {
      dev.log('Token has no expiration date - considering it expired');
      return (DateTime.now(), false);
    }

    // 'exp' claim is in seconds since epoch
    final exp = int.tryParse(decodedToken['exp'].toString());
    if (exp == null || exp <= 0) {
      dev.log(
        'Token expiration date is not an integer - considering it expired',
      );
      return (DateTime.now(), false);
    }
    return (getDateFromTimeStamp(exp), true);
  }

  /// Returns token issuing date (iat)
  ///
  /// Throws [FormatException] if parameter is not a valid JWT token.
  static Duration getTokenTime(String token) {
    final decodedToken = tryDecode(token);
    if (decodedToken == null || !decodedToken.containsKey('iat')) {
      dev.log('Token has no issuing date - considering it invalid');
      return Duration.zero;
    }

    final iat = int.tryParse(decodedToken['iat'].toString());
    if (iat == null || iat <= 0) {
      dev.log('Token issuing date is not an integer - considering it invalid');
      return Duration.zero;
    }

    final issuedAtDate = getDateFromTimeStamp(iat);
    return DateTime.now().difference(issuedAtDate);
  }

  /// Returns remaining time until expiry date.
  ///
  /// Throws [FormatException] if parameter is not a valid JWT token.
  static Duration getRemainingTime(String token) {
    final (expirationDate, isValid) = getExpirationDate(token);
    if (!isValid) {
      dev.log('Token has no expiration date - considering it expired');
      return Duration.zero;
    }
    return expirationDate.difference(DateTime.now());
  }

  /// Converts a timestamp to a DateTime object.
  /// The timestamp can be in seconds or milliseconds.
  static DateTime getDateFromTimeStamp(int timestamp) {
    if (timestamp > 1e12) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    }
  }
}

void main() {
  final token =
      'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMiwiZXhwIjoxNzY0MjM5OTk2fQ.iXeKl7i9PVK62uW3RlPbIrVpeISoB3cGXsLmEUR5qqQ';
  final decoded = JwtDecoder.decode(token);
  print('Decoded JWT Payload: $decoded');
  final isExpired = JwtDecoder.isExpired(token);
  print('Is token expired? $isExpired');
}
