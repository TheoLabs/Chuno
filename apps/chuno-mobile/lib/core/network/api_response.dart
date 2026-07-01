/// API 공통 응답 봉투(envelope). 백엔드(S1-5) 확정 전 계약(placeholder)이며
/// `{ success, data, message }` 형태를 가정한다. 실제 스키마 확정 시 조정한다.
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;

  const ApiResponse({
    required this.success,
    this.data,
    this.message,
  });

  /// [json] 이 공통 봉투를 감싼 형태면 그 안의 `data` 를, 아니면 전체를 [parse] 로 변환한다.
  factory ApiResponse.fromJson(
    Object? json,
    T Function(Object? data) parse,
  ) {
    if (json is Map<String, dynamic> &&
        (json.containsKey('data') ||
            json.containsKey('success') ||
            json.containsKey('message'))) {
      final rawData = json['data'];
      final success = json['success'] as bool? ?? (rawData != null);
      return ApiResponse(
        success: success,
        data: rawData == null ? null : parse(rawData),
        message: json['message'] as String?,
      );
    }
    // 봉투가 아니면 페이로드 자체로 취급.
    return ApiResponse(success: true, data: parse(json));
  }
}
