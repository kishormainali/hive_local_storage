import 'package:flutter_test/flutter_test.dart';
import 'package:hive_local_storage/hive_local_storage.dart';

void main() {
  test('LocalStorage.instance throws before initialize', () {
    expect(() => LocalStorage.instance, throwsException);
  });
}
