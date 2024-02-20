import 'package:hive/hive.dart';

part 'session.g.dart';

@HiveType(typeId: 0, adapterName: 'SessionAdapter')
class Session extends HiveObject {
  @HiveField(0)
  late String accessToken;

  @HiveField(1)
  String? refreshToken;

  @HiveField(2)
  DateTime? createdAt;

  @HiveField(3)
  DateTime? updatedAt;

  @override
  String toString() {
    return 'Session{accessToken: $accessToken, refreshToken: $refreshToken , createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}
