import 'package:hive_local_storage/hive_local_storage.dart';

part 'user.g.dart';

@HiveType(typeId: 3, adapterName: 'UserAdapter')
class User extends HiveObject {
  @HiveField(0)
  late String name;

  @HiveField(1)
  late String address;

  @HiveField(2)
  late List<User> users;

  @override
  String toString() {
    return '$name, $address ${users.map((e) => e.toString())}';
  }
}
