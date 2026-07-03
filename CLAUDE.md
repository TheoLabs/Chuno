# 추노 — 프로젝트 공통 규약

앱별 세부 규칙은 각 `apps/*/CLAUDE.md` 참조. 이 문서는 **여러 앱(core-api·chuno-mobile·back-office)에 공통으로 걸리는 규약**만 담는다.

## API 쿼리 배열 파라미터 = 콤마 조인 (전-프론트 공통)
- 배열형 쿼리 파라미터는 **항상 콤마 조인**으로 주고받는다: `?types=terms-of-service,privacy-policy,location-service`.
- **모든 프론트 영역**(chuno-mobile, back-office 등)은 배열 쿼리를 **콤마로 이어 전송**한다. 반복 파라미터(`?k=a&k=b`) 방식은 쓰지 않는다.
  - Flutter(dio): `queryParameters: {'types': list.join(',')}`
  - React(back-office): 쿼리 빌드 시 배열을 `arr.join(',')`로 직렬화
- **백엔드(core-api)**: DTO에서 `@ToArray()`(`@libs/decorators`)가 콤마 문자열을 배열로 정규화한다(split·trim·빈값 제거). 요소 검증은 `@IsEnum(..., { each: true })` + 선택이면 `@IsOptional()`.

## 응답 포맷
- 목록(list): **`{ data: { items: [...], total } }`**
- 단건(retrieve): **`{ data: {...} }`**
- (인증 토큰 발급 등 일부 엔드포인트는 예외 — 각 앱 규칙 참조)

## 관리자(백오피스) API
- 관리자용 엔드포인트는 **`/api/admins/...`** 프리픽스로 사용자 API와 분리하고 별도 `AdminGuard`(role 기반 RBAC)로 보호한다. 사용자 조회 API는 공개/인증 사용자 대상. (상세: `docs/backoffice/`)
