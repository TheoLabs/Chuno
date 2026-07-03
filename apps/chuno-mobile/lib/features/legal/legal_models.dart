/// 법적 문서(약관/개인정보/위치/마케팅) 도메인 모델.
///
/// list(`GET /legal-documents`) 응답엔 [content]·[expectedActivateOn] 이 없고,
/// retrieve(`GET /legal-documents/:id`) 응답에만 전문([content])·시행일([expectedActivateOn]) 이 있다.
class LegalDocument {
  /// 서버 PK. 온보딩 동의 제출 시 이 id 를 `legalDocumentIds` 로 전송한다.
  final int id;

  /// type slug. 예: terms-of-service · privacy-policy · location-service · marketing.
  final String type;

  /// 버전 문자열(예: v1.0). 서버가 동의 시점 스냅샷을 기록하므로 표시용으로만 쓴다.
  final String version;
  final String title;

  /// 필수 동의 여부(필수 3종=TERMS·PRIVACY·LOCATION).
  final bool isRequired;

  /// 상태(ACTIVE 등). list/retrieve 공통.
  final String status;

  /// 전문. retrieve 응답에만 존재. list 응답에선 null.
  final String? content;

  /// 예정 시행일(ISO 문자열). retrieve 응답에만 존재.
  final String? expectedActivateOn;

  const LegalDocument({
    required this.id,
    required this.type,
    required this.version,
    required this.title,
    required this.isRequired,
    required this.status,
    this.content,
    this.expectedActivateOn,
  });

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    return LegalDocument(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      isRequired: json['isRequired'] == true,
      status: json['status']?.toString() ?? '',
      content: json['content'] as String?,
      expectedActivateOn: json['expectedActivateOn'] as String?,
    );
  }
}
