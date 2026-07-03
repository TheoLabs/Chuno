# 추노(Chuno) 설계 · 기획 문서

이 폴더는 추노의 **설계 및 디자인 문서**를 모아두는 곳입니다. 구현 코드는 각 앱(`apps/*`)에, 기획/설계/디자인 산출물은 모두 여기에 정리합니다.

두 트랙으로 나뉜다: **사용자 제품**(Flutter 앱)과 **백오피스**(관리자 SPA — React + TypeScript + React Query + React Router + Ant Design, `/api/admins`, SSO 로그인, role 기반 RBAC). 도메인 설계는 두 트랙이 함께 쓰는 공유 문서다.

## 문서 목록

### 공유

| 문서 | 내용 |
| --- | --- |
| [chuno-mobile-design.md](./chuno-mobile-design.md) | 모바일 앱(Flutter) 설계·디자인 — 핵심 규칙, 화면(IA), 상태머신, 화면별 와이어프레임, 점수·포인트, 디자인 시스템 |
| [domain/index.html](./domain/index.html) | 도메인 설계(DDD) 시각화 — 바운디드 컨텍스트·애그리거트/엔티티/값객체·도메인 이벤트(EDA)·상태머신·관계도(ERD)·화면 매핑. 사용자 제품 도메인 + Admin & IAM(백오피스) 컨텍스트를 함께 다룸. |

### 사용자 제품

| 문서 | 내용 |
| --- | --- |
| [product/mvp/index.html](./product/mvp/index.html) | MVP 로드맵 — 핵심 루프·포함/제외 범위 + Step 1~5(기반·인증 → 방 → 경주코어 → 점수·랭킹 → 출시) HTML. |
| [product/issue/index.html](./product/issue/index.html) | 이슈 보드 — MVP 스텝을 상세 티켓(S1-1 …)으로 분해, 스텝별 상세 페이지 + MVP·도메인·화면 상호 링크. |
| [product/wireframes/index.html](./product/wireframes/index.html) | HTML 와이어프레임/인터랙티브 프로토타입 — 추격전(소프트) 정체성, 화면 클릭 플로우 + 경주 실시간 애니메이션. |

### 백오피스

백오피스 = 관리자 전용 React + TypeScript SPA(React Query · React Router · Ant Design), API는 `/api/admins` 하위, 로그인은 SSO(외부 IdP), 인가는 역할 단위 RBAC(`@RequireRoles`).

| 문서 | 내용 |
| --- | --- |
| [backoffice/mvp/index.html](./backoffice/mvp/index.html) | MVP 로드맵 — 백오피스 Step 1~ (관리자 인증·RBAC → 운영 기능) HTML. |
| [backoffice/issue/index.html](./backoffice/issue/index.html) | 이슈 보드 — 백오피스 스텝별 상세 티켓(BO1-1 …), 도메인(Admin & IAM)·사용자 제품 이슈(예: 법적 문서 발행 재스코프 S1-16/S1-18)와 상호 링크. |
| [backoffice/wireframes/index.html](./backoffice/wireframes/index.html) | HTML 와이어프레임 — Ant Design 라이트 콘솔 목업(Sider·Header·Table·Form·Modal), 관리자 로그인·법적문서·사용자관리·모더레이션·경주운영·공지·포인트 9개 화면 + 백오피스 이슈 상호 링크. |

## 작성 규칙

- 새 설계/기획 문서는 이 `docs/` 폴더에 추가하고 위 목록에 한 줄 등록.
- 파일명은 `<대상>-<주제>.md` (예: `core-api-architecture.md`, `chuno-mobile-design.md`).
