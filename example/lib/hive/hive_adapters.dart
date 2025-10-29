import 'package:hive_ce/hive.dart';
import 'package:example/models/contact.dart';
import 'package:example/models/user.dart';
part 'hive_adapters.g.dart';

@GenerateAdapters(
  [AdapterSpec<Contact>(), AdapterSpec<User>()],
  firstTypeId: 1,
  reservedTypeIds: {0},
)
// ignore: unused_element
void _() {}
