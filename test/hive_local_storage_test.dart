import 'package:flutter_test/flutter_test.dart';
import 'package:hive_local_storage/hive_local_storage.dart';

void main() {
  test('AuthToken instantiation', () {
    final token = AuthToken(
      accessToken: 'access_token_sample',
      refreshToken: 'refresh_token_sample',
    );
    expect(token.accessToken, 'access_token_sample');
    expect(token.refreshToken, 'refresh_token_sample');
  });
}
