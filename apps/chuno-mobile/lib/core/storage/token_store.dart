import '../network/tokens.dart';
import 'key_value_store.dart';

/// access/refresh 토큰을 보안 저장(flutter_secure_storage)에 저장·조회·삭제한다.
class TokenStore {
  static const _accessKey = 'chuno.auth.accessToken';
  static const _refreshKey = 'chuno.auth.refreshToken';

  final KeyValueStore _store;
  TokenStore(this._store);

  /// 보안 저장 기반 기본 인스턴스.
  factory TokenStore.secure() => TokenStore(SecureKeyValueStore());

  Future<void> save(TokenPair tokens) async {
    await _store.write(_accessKey, tokens.accessToken);
    await _store.write(_refreshKey, tokens.refreshToken);
  }

  Future<String?> readAccessToken() => _store.read(_accessKey);

  Future<String?> readRefreshToken() => _store.read(_refreshKey);

  Future<TokenPair?> read() async {
    final access = await _store.read(_accessKey);
    final refresh = await _store.read(_refreshKey);
    if (access == null || refresh == null) return null;
    return TokenPair(accessToken: access, refreshToken: refresh);
  }

  Future<bool> hasTokens() async {
    final access = await _store.read(_accessKey);
    return access != null && access.isNotEmpty;
  }

  Future<void> clear() async {
    await _store.delete(_accessKey);
    await _store.delete(_refreshKey);
  }
}
