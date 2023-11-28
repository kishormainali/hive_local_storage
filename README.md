## hive_local_storage

<hr>

A utility package to storage user session and cache values in hive box

- uses hive for caching
- uses flutter_secure_storage to storage encryption key of secured hive box for session storage

### Get Started

```yaml
dependencies:
  hive_local_storage: latest
```

if you want to use custom class for hive you need to add hive_generator in your dev_dependencies

```yaml
dev_dependencies:
  build_runner: latest
  hive_generator: latest
```

### Usage

``` dart
  import 'package:hive_local_storage/hive_local_storage.dart';
```

### Registering Custom Adapters

NOTE: avoid using typeId=0 for data classes because typeId=0 is already used by session class.

``` dart
  final localStorage = await LocalStorage.getInstance(registerAdapters:(){
    Hive..registerAdapter(adapter1)..registerAdapter(adapter2);
  });
```

### Session
hive_local_storage provides easy mechanism to store session using encrypted box

- #### Store Session
  ```dart
    final storage = await LocalStorage.getInstance();
    await storage.saveToken('accessToken','refreshToken'); // refreshToken is optional
  ```
- #### Get Session
  ```dart
     final storage = await LocalStorage.getInstance();
     /// get access token
     final accessToken  = storage.accessToken;

     /// get refresh token
     final refreshToken = storage.refreshToken;

     /// check wheather session is saved or not
     final bool hasSession = storage.hasSession;

     /// listen wheather session is present or not
     StreamSubscription<bool> _subscription = storage.onSessionChange.listen((bool hasSession){
      // do your stuff
     });
     /// cancel your subscription on close/dispose method;
     _subscription.cancel();

    //to check whether accessToken is expired or not
    final isTokenExpired = locaStorage.isTokenExpired;

  ```
- ### Remove Session
  ```dart
    final storage = await LocalStorage.getInstance();
    storage.clearSession();
  ```


### Opening Custom Boxes

This is useful when you want to store hive objects directly
to use this method you need to register adapter for hive objects in initialization

``` dart
    /// typeId must between 1-223
    @HiveType(typeId:1,adapterName:'TestAdapter')
    class TestModel extends HiveObject{
  
        @HiveField(0)
        late String firstName;
        
        /// rest of fields
    }

    final localStorage = await LocalStorage.getInstance([TestAdapter()]);
    await localStorage.openBox<TestModel>(boxName:'__TEST_BOX__',typeId:1)
```

### Read From Custom Box

``` dart 
   final localStorage = await LocalStorage.getInstance();
   List<TestModel> data = localStorage.values<TestModel>('__TEST_BOX__');
```

### Write data to Custom Box

``` dart 
   final localStorage = await LocalStorage.getInstance();
    void storeData() async {
      /// store single data
      final testModel = TestModel();
      await localStorage.add<TestModel>(boxName: '__TEST_BOX__',value:testModel);
      
      /// store multipleData
      final listData = <TestModel>[TestModel(),TestModel()];
      await localStorage.addAll<TestModel>(boxName: '__TEST_BOX__',values:listData);
    }
```

### delete data from Custom Box 

``` dart 
   final localStorage = await LocalStorage.getInstance();
    void deleteData(TestModel test) async {
      await localStorage.delete<TestModel>(boxName: '__TEST_BOX__',value:testModel);
    }
```

### update data to Custom Box 

``` dart 
   final localStorage = await LocalStorage.getInstance();
    void updateData(TestModel test) async {
      await localStorage.update<TestModel>(boxName: '__TEST_BOX__',value:testModel);
    }
```

#### To use with Riverpod

``` dart
/// create provider
final localStorageProvider = Provider<LocalStorage>((ref)=>throw UnImplementedError());

/// in main function

void main() {
  runZonedGuarded(
    () async {
      final localStorage = await LocalStorage.getInstance();
      runApp(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(localStorage),
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

``` dart
   /// initialize local_storage
final localStorage = await LocalStorage.getInstance();

// to store value in cache box
await localStorage.put<int>(key:'count',value:0);


// write multiple values in cache box
await localStorage.putAll(Map<String, dynamic> entries);

// put list of data in cache box
await localStorage.putList<Model>(key:'KeyName',value:<Model>[]);


```

Read data

``` dart
   /// initialize local_storage
final localStorage = await LocalStorage.getInstance();

// to get value from cache box
final count =  localStorage.get<int>(key:'count');


// watch value changed on key
localStorage.watchKey(key:'key').listen((value){
  //TODO: do your work
});

// read list data from cache box
final listData = localStorage.getList<Model>(key:'Your KeyName');


```

Delete data

``` dart
   /// initialize local_storage
final localStorage = await LocalStorage.getInstance();

// remove value from cache box
await localStorage.remove(key:'count');

// remove all from cache box
await localStorage.clear();

// clear both session and cache box
await localStorage.clearAll();

```

