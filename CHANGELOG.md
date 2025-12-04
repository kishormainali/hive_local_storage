# Changelog

## 2.0.10 (2025-12-04)

- Export SecureStorage class from LocalStorage package

## 2.0.9 (2025-12-02)

## 2.0.8 (2025-12-02)

- Persist encryption key while clearing cache box
- Token times are now subject to UTC time
- Handle token times includes milliseconds fragments

## 2.0.7 (2025-11-27)

- Improve date expiration logic in access token

## 2.0.6 (2025-11-24)

- Fixes issue with data migration on some devices
- Remove old cache box after migration

## 2.0.5 (2025-11-17)

- Improve error handling while migrating old data
- Fixes session migration issue

## 2.0.4 (2025-11-14)

- Migrate old data with new cipher

## 2.0.3 (2025-11-14)

- LocalStorage.clearAll() now clears session also
- LocalStorage.clear() now clears all opened boxes including cache box

## 2.0.2 (2025-11-11)

- Updated docs

## 2.0.1 (2025-11-11)

> This is a patch release for version 2.0.0 and contains breaking changes

- Migrated session storage from hive_ce to flutter_secure_storage, after this related methods and getters are now asynchronous
- Deprecated Session related methods and getters. Use Token related methods and getters instead (will be removed in future releases)
- Added AES GCM encryption for LocalStorage
- By default, LocalStorage now uses AES GCM encryption. You can add your own encryption cipher by passing customCipher while initializing LocalStorage
- Added SecureStorage class for secure key-value storage using flutter_secure_storage

## 2.0.0

> This release contains breaking changes

- Make LocalStorage singleton and renamed getInstance with initialize, use LocalStorage.instance or LocalStorage.i or LocalStorage() for accessing member functions and getters
- Migrated to hive_ce
- Changed dart min sdk to 3.8

## 1.1.3

- clear all storage keys on platform exception.

## 1.1.2

- add storage directory path in `LocalStorage.getInstance` method

## 1.1.1

- make createdAt nullable in Session

## 1.1.0

> This release contains breaking changes

- removed `getCusom` and `putCustom` methods use `get` and `put` with `boxName` instead
- removed `removeCustom` method use `remove` with `boxName` instead
- renamed `getBoxValues` to `values`
- add `getBox` method to get box instance
- `openBox` method now returns `Box<T>` instead of `void`
- `watchKey` now supports custom box

## 1.0.10

- added `getCustom` and `putCustom` methods to get and put custom data in box
- added `removeCustom` method to remove custom data from box

## 1.0.9

- renamed `openCustomBox` to `openBox`
- renamed `getCustomList` to `getBoxValues`
- updated typeId check in `openBox` method

## 1.0.8

- updated repository url
- added createAt and updatedAt fields in Session
- added `deleteAll` method to delete all boxes from disk
- added `filter` parameter in `update` and `delete` method

## 1.0.7

- updated `flutter_secure_storage`
- removed deprecated methods

## 1.0.6

- add `clearAll()` method to clear both session and cache box
- add custom encryption support for boxes. pass HiveCipher while registering local storage

```dart
final storage = LocalStorage.getInstance(customCipher: HiveCipher // custom encryption algorithm,)
/// if you want ot open custom box
storage.openCustomBox( boxName:'box',
    typeId:100,
    customCipher:HiveCipher // custom encryption algorithm,
    );
```

> Breaking Changes

- deprecate `getSession()` use `accessToken` or `refreshToken` getter instead
- renamed `saveSession(Session)` to `saveToken(String accessToken,[String? refreshToken])`
- onSessionChange now returns `Stream<bool>` instead of `Stream<Session?>`

## 1.0.5

- removed redundant jsonDecode for getList

## 1.0.4

- added watchKey to listen on value changed for key

## 1.0.3+1

## 1.0.3

- added onSessionChange event for session box
- added synchronization
- updated min dart sdk version to 2.18

## 1.0.2

- updated _flutter_secure_storage_ version

## 1.0.1

[BREAKING CHANGES]

- refactored adapter registration logic

## 1.0.0+1

- updated documentation

## 1.0.0

[BREAKING CHANGES]

- added support for opening custom boxes
- use encrypted box by default
- added support for adding list (encode/decode data)
- removed expiresIn from Session [Node: uses JWTDecoder to decode and get expiry time]

## 0.0.9

- added factory constructor to make compatible with riverpod

## 0.0.8

- added HiveField annotation in session object's fields

## 0.0.7

- Bug fixes when getting session
- added JwtDecoder

## 0.0.6

- Removed unnecessary type cast
- added isTokenExpired getter to check whether accessToken is expired or not
- hasSession() method renamed to hasSession getter
- added support for registering custom type adapters

## 0.0.5

- Breaking Changes
  - Methods are renamed for easy understanding
- map getter added to make compatible to CacheStore

## 0.0.4

- Bug fixes

## 0.0.3

- updated README.md

## 0.0.2

- typo fixes

## 0.0.1

- initial release
