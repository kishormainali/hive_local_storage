import 'package:hive/hive.dart';

part 'session.g.dart';

@HiveType(typeId: 0, adapterName: 'SessionAdapter')
class Session extends HiveObject {
  @HiveField(0)
  late String accessToken;
  @HiveField(1)
  late String refreshToken;

  @override
  String toString() {
    return 'Session{accessToken: $accessToken, refreshToken: $refreshToken}';
  }
}
