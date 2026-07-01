/// access / refresh 토큰 한 쌍. 회전형 리프레시(rotating refresh)이므로
/// refresh 성공 시 access·refresh 를 함께 새로 발급받아 저장한다.
class TokenPair {
  final String accessToken;
  final String refreshToken;

  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
  });

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    final access = json['accessToken'] ?? json['access_token'];
    final refresh = json['refreshToken'] ?? json['refresh_token'];
    if (access is! String || refresh is! String) {
      throw const FormatException('토큰 응답 형식이 올바르지 않습니다.');
    }
    return TokenPair(accessToken: access, refreshToken: refresh);
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };

  @override
  bool operator ==(Object other) =>
      other is TokenPair &&
      other.accessToken == accessToken &&
      other.refreshToken == refreshToken;

  @override
  int get hashCode => Object.hash(accessToken, refreshToken);
}
