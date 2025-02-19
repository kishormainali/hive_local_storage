import 'package:hive_local_storage/hive_local_storage.dart';

part 'adapters.g.dart';

@GenerateAdapters([AdapterSpec<Session>()])
class HiveAdapters {}
