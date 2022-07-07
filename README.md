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

Write data
```dart
   /// initialize local_storage
  final localStorage = await LocalStorage.getInstance();
  
  // to store value in normal box
  await localStorage.saveCache<int>('count',0);
  
  // to store value in encrypted box
  await localStorage.saveEncrypted<String>('key','some important key');
  
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
  final count  = await localStorage.getCache<int>('count');
  
  // to get value from encrypted box
  final key = await localStorage.getEncrypted<String>('key');
  
  // to get session
  final Session? session = await localStorage.getSession();
  
  //to check whether session has present or not
  final hasSession = await localStorage.hasSession();

```

Delete data
```dart
   /// initialize local_storage
  final localStorage = await LocalStorage.getInstance();
  
  // remove value from normal box
   await localStorage.remove('count');
   
   // remove all from normal box
   await localStorage.clear();
  
  // remove value from encrypted box
  await localStorage.removeEncrypted('key');
  
  //remove all values form encrypted box
  await localStorage.clearEncrypted();
  
  // remove session
  await localStorage.clearSession();

```


# TODO:

- [ ] support for TypeAdapters
- [ ] add Test 

 
