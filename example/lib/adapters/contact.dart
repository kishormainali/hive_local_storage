import 'package:hive_local_storage/hive_local_storage.dart';

part 'contact.g.dart';

@HiveType(typeId: 2, adapterName: 'ContactAdapter')
class Contact extends HiveObject {
  @HiveField(0)
  late String name;
}
