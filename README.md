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

```dart
  import 'package:hive_local_storage/hive_local_storage.dart';
```
### Registering Custom Adapters
NOTE: avoid using typeId=0 for data classes because typeId=0 is already used by session class.

```dart
  //  getInstance() method takes list of [TypeAdapter] 
  final localStorage = await LocalStorage.getInstance([YourAdapter()])
```

Write data
```dart
   /// initialize local_storage
  final localStorage = await LocalStorage.getInstance();
  
  // to store value in normal box
  await localStorage.put<int>(key:'count',value:0);
  
  // to store value in encrypted box
  await localStorage.put<String>(key:'key',value:'some important key',useEncryption:true);

  // write multiple values
  await localStorage.putAll(Map<String,dynamic> entries);
  
  // write multiple values in encrypted box
  await localStorage.putAll(entries:{},useEncryption:true);
  
  // to store use session
  final session = Session()
                ..accessToken = 'accessToken'
                ..refreshToken ='refreshToken'
                ..expiresIn = 1231232;
  await localStorage.saveSession(session);

```


Read data
```dart
   /// initialize local_storage
  final localStorage = await LocalStorage.getInstance();
  
  // to get value from normal box
  final count  = await localStorage.get<int>(key:'count');
  
  // to get value from encrypted box
  final key = await localStorage.get<String>(key:'key',useEncryption:true);
  
  // to get session
  final Session? session =  localStorage.getSession();
  
  //to check whether session has present or not
  final hasSession =  localStorage.hasSession;
  
  //to check whether accessToken is expired or not
  final isTokenExpired = locaStorage.isTokenExpired;

```

Delete data
```dart
   /// initialize local_storage
  final localStorage = await LocalStorage.getInstance();
  
  // remove value from normal box
   await localStorage.remove(key:'count');
   
   // remove all from normal box
   await localStorage.clear();
  
  // remove value from encrypted box
  await localStorage.remove(key:'key',useEncryption:true);
  
  
  //remove all values form encrypted box
  await localStorage.clear(useEncryption:true);
  
  // remove session
  await localStorage.clearSession();

```




# TODO:

- [X] support for TypeAdapters
- [ ] add Test Cases

 
