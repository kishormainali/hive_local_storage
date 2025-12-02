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
      throw const FormatException('Invalid jwt token');
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

    // Check if the expiration date is valid
    if (!isValid) {
      // If there is no expiration date, consider the token as expired
      dev.log('Token has no expiration date - considering it expired');
      return true;
    }

    // Get the current date in UTC
    final now = DateTime.now().toUtc();

    // If the current date is after the expiration date, the token is already expired
    return now.isAfter(expirationDate);
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
    final exp = double.tryParse(decodedToken['exp'].toString());
    if (exp == null || exp <= 0) {
      dev.log(
        'Token expiration date is not a valid double - considering it expired',
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

    // 'iat' claim is in double value representing seconds since epoch
    final iat = double.tryParse(decodedToken['iat'].toString());
    if (iat == null || iat <= 0) {
      dev.log(
        'Token issuing date is not a valid double - considering it invalid',
      );
      return Duration.zero;
    }

    final issuedAtDate = getDateFromTimeStamp(iat);
    final now = DateTime.now().toUtc();
    final time = now.difference(issuedAtDate);
    return time.isNegative ? Duration.zero : time;
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
    final now = DateTime.now().toUtc();
    final time = expirationDate.difference(now);
    return time.isNegative ? Duration.zero : time;
  }

  /// Converts a timestamp to a DateTime object.
  /// The timestamp can be in seconds or milliseconds.
  static DateTime getDateFromTimeStamp(double timestamp) {
    if (timestamp > 1e12) {
      return DateTime.fromMillisecondsSinceEpoch(
        timestamp.toInt(),
        isUtc: true,
      );
    } else {
      return DateTime.fromMillisecondsSinceEpoch(
        (timestamp * 1000).toInt(),
        isUtc: true,
      );
    }
  }
}

void main() {
  // final token =
  //     'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiI2NGVjM2U0MjkwOGVmNzY1NzQwYjMzNDIiLCJqdGkiOiJjNTdmNzcxZDFiMDNkZmUzNWQzN2RmYzQyZjVkZjEzYjlhNDRjMzdhMGQzYjdjNjEzM2JiN2QzY2JjNTk2YzFmZDQzZmJlMTNmZmY2MGI4OSIsImlhdCI6MTc2NDI0MzQxMi4wOTM3NTYsIm5iZiI6MTc2NDI0MzQxMi4wOTM3NiwiZXhwIjoyMzk1Mzk1NDEyLjA4ODEyLCJzdWIiOiI2ODg3MmVjMjdiZDU1YmI4NTkwZWZlZDgiLCJzY29wZXMiOltdfQ.ZlltGRWcWP41UlZ95wuKT1cxqFWkBhszV4MyWXfBR4rxTsoF55or2HevTcsFj33hJScX7vPkPR_o2S1ai_S_OoNsfU4jY60HXi0tBUW87E62n_u67QqzFsa55K9ongCn0x5nTeCFnPNMVeDRgrMFQ4YX5ce347Pnp1KXN-QrlKyF5zP2Xsc27Nhuj5ybMvUdr_dUPlTYAhBg4L0jgLA69Dgt_A1mF71CDVhLQ2XmBqo-FNi06l0c99Z36bB_CqYjuQjv6Hd_jxlM5tC_l6swFDH9XndIReM1u2V3jhZIOqPEqt14on3GaffIEg_98UbJuAqu6PX6CsPuG7kwHPCEtytTEdn97kw9M7-QhF9sqxu5-lIq00c1QhhPnygxchit6sLVtmYZcdFaPd23kHChT6nyWX37rbHZINkYa6zQRdBdL9Eypr9z43uEvFBxK2VvrAyL2W5pWZVMmVuR2aea3UCdBRKKhwq42qsq-hFvm1BwN-0a6VgalWdEfpxbQoTqyLI3T-_JrQ_oxpPysPrTn_YxSiicaauxUVzkO0mJ_K4opKdQCRN89zY5RENNqd2A32erahQS8CSUQZmRDPb4gE23uOiwAn2z5psxste-5JKjlVjZ_j7hnwmLDZEbjCcPCtA94CU-3IMVX3jlTv-bCTEhF_KVnx8Pa9yf4Bt8eoA';
  final token =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6IndoaXNrcnNAZ21haWwuY29tIiwic3ViIjoiNjkxNmExZDcxMDQ0YmY0OWI4MDYzOWM1IiwianRpIjoiNTdlNDQyNGMtNjY5My00Mzc0LTgxZDktYzkwZDRhMTY2MmUwIiwiaWF0IjoxNzY0MjMzODUxLCJleHAiOjE3NjQyMzM5MTF9.-ejdjqRB2m1pT2d-lXnQ8wlSsxjtif02PM0aeG5wOKg';
  final decoded = JwtDecoder.decode(token);
  print('Decoded token: $decoded');
  final isExpired = JwtDecoder.isExpired(token);
  print('Is token expired? $isExpired');
  final remainingTime = JwtDecoder.getRemainingTime(token);
  print('Remaining time until expiry: $remainingTime');
}
