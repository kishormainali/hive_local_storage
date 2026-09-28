## hive_local_storage

<hr>

A utility package that wraps hive_ce to make it easy to store and encrypt local data

- uses hive_ce for caching
- uses flutter_secure_storage internally to store the encryption key of the encrypted hive box

### Get Started

```yaml
dependencies:
  hive_local_storage: latest
  hive_ce: latest
  hive_ce_flutter: latest # optional
```

if you want to use custom class for hive you need to add hive_generator in your dev_dependencies

```yaml
dev_dependencies:
  build_runner: latest
  hive_ce_generator: latest
```

### Usage

```dart
  import 'package:hive_local_storage/hive_local_storage.dart';
```

### Registering Custom Adapters

```dart
part 'hive_adapters.g.dart';
  @GenerateAdapters(
    [AdapterSpec<Contact>(), AdapterSpec<User>()],
    firstTypeId: 1,
  )
  // ignore: unused_element
  void _() {}

```

and import extension function Hive.registerAdapters generated using hive_ce_generator from `hive_registrar.g.dart`

```dart
  await LocalStorage.initialize(registerAdapters:Hive.registerAdapters);
```

### Opening Custom Boxes

This is useful when you want to store hive objects directly
to use this method you need to register adapter for hive objects in initialization

```dart
    /// typeId must between 1-223
    class TestModel{

        TestModel(this.firstName);

        final String firstName;

        /// rest of fields
    }
    await LocalStorage.i.openBox<TestModel>(boxName:'__TEST_BOX__',typeId:1)
```

### Read From Custom Box

```dart
   List<TestModel> data = LocalStorage.i.values<TestModel>('__TEST_BOX__');
```

### Write data to Custom Box

```dart
    void storeData() async {
      /// store single data
      final testModel = TestModel();
      await LocalStorage.i.add<TestModel>(boxName: '__TEST_BOX__',value:testModel);

      /// store multipleData
      final listData = <TestModel>[TestModel(),TestModel()];
      await LocalStorage.i.addAll<TestModel>(boxName: '__TEST_BOX__',values:listData);
    }
```

### delete data from Custom Box

```dart
    void deleteData(TestModel test) async {
      await LocalStorage.i.delete<TestModel>(boxName: '__TEST_BOX__',value:testModel);
    }
```

### update data to Custom Box

```dart
    void updateData(TestModel test) async {
      await LocalStorage.i.update<TestModel>(boxName: '__TEST_BOX__',value:testModel);
    }
```

#### To use with Riverpod

```dart
/// create provider
final localStorageProvider = Provider<LocalStorage>((ref)=>throw UnImplementedError());

/// in main function

void main() {
  runZonedGuarded(
    () async {
      await LocalStorage.initialize();
      runApp(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(LocalStorage.i),
          ],
          child: App(),
        ),
      );
    },
    (e, _) => throw e,
  );
}


```

Write data

```dart
   /// initialize local_storage
await LocalStorage.initialize();

// to store value in cache box
await LocalStorage.i.put<int>(key:'count',value:0);


// write multiple values in cache box
await LocalStorage.i.putAll(Map<String, dynamic> entries);

// put list of data in cache box
await LocalStorage.i.putList<Model>(key:'KeyName',value:<Model>[]);

```

Read data

```dart
   /// initialize local_storage
await LocalStorage.initialize();

// to get value from cache box
final count =  LocalStorage.i.get<int>(key:'count');

// watch value changed on key
LocalStorage.i.watchKey(key:'key').listen((value){
  //TODO: do your work
});

// read list data from cache box
final listData = LocalStorage.i.getList<Model>(key:'Your KeyName');


```

Delete data

```dart
   /// initialize local_storage
await LocalStorage.initialize();

// remove value from cache box
await LocalStorage.i.remove(key:'count');

// remove all from cache box
await LocalStorage.i.clear();

// clear cache box and all custom boxes opened via openBox()
await LocalStorage.i.clearAll();

```
