import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'legal_repository.dart';

/// 법적 문서 원격 저장소. 인증 API 클라이언트(apiClientProvider)를 사용한다.
/// 테스트에서는 fake 로 override 한다.
final legalDocumentRepositoryProvider = Provider<LegalDocumentRepository>(
  (ref) => HttpLegalDocumentRepository(ref.watch(apiClientProvider)),
);

/// 온보딩 동의 단계에서 조회할 문서 type slug(필수 3종 + 선택 marketing).
const List<String> onboardingLegalTypes = [
  'terms-of-service',
  'privacy-policy',
  'location-service',
  'marketing',
];
