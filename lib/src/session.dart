import 'package:hive/hive.dart';

part 'session.g.dart';

@HiveType(typeId: 0, adapterName: 'SessionAdapter')
class Session extends HiveObject {
  late String accessToken;
  late String refreshToken;
  late int expiresIn;
}
