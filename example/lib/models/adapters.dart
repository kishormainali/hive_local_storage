import 'package:example/models/user.dart';
import 'package:hive_local_storage/hive_local_storage.dart';

part 'adapters.g.dart';

@GenerateAdapters([AdapterSpec<User>()])
// ignore: unused_element
void _() {}
