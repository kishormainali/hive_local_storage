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

