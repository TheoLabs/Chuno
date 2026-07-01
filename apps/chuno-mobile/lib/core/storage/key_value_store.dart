import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 문자열 KV 저장 추상화. 기본 구현은 flutter_secure_storage 이지만,
/// 테스트에서는 인메모리 구현으로 대체할 수 있게 인터페이스로 분리한다.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// flutter_secure_storage 기반 보안 저장 구현.
class SecureKeyValueStore implements KeyValueStore {
  final FlutterSecureStorage _storage;

  SecureKeyValueStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// 인메모리 KV 저장(테스트/폴백용).
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _map;
  InMemoryKeyValueStore([Map<String, String>? initial])
      : _map = {...?initial};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;

  @override
  Future<void> delete(String key) async => _map.remove(key);
}
