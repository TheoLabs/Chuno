# 추노(Chuno) 설계 · 기획 문서

이 폴더는 추노의 **설계 및 디자인 문서**를 모아두는 곳입니다. 구현 코드는 각 앱(`apps/*`)에, 기획/설계/디자인 산출물은 모두 여기에 정리합니다.

## 문서 목록

| 문서 | 내용 |
| --- | --- |
| [chuno-mobile-design.md](./chuno-mobile-design.md) | 모바일 앱(Flutter) 설계·디자인 — 핵심 규칙, 화면(IA), 상태머신, 화면별 와이어프레임, 점수·포인트, 디자인 시스템 |
| [wireframes/index.html](./wireframes/index.html) | HTML 와이어프레임/인터랙티브 프로토타입 — 추격전(소프트) 정체성, 화면 클릭 플로우 + 경주 실시간 애니메이션. |
| [domain/index.html](./domain/index.html) | 도메인 설계(DDD) 시각화 — 바운디드 컨텍스트·애그리거트/엔티티/값객체·도메인 이벤트(EDA)·상태머신·관계도(ERD)·화면 매핑. |
| [mvp/index.html](./mvp/index.html) | MVP 로드맵 — 핵심 루프·포함/제외 범위 + Step 1~5(기반·인증 → 방 → 경주코어 → 점수·랭킹 → 출시) HTML. |
| [issue/index.html](./issue/index.html) | 이슈 보드 — MVP 스텝을 상세 티켓(S1-1 …)으로 분해, 스텝별 상세 페이지 + MVP·도메인·화면 상호 링크. |

## 작성 규칙

- 새 설계/기획 문서는 이 `docs/` 폴더에 추가하고 위 목록에 한 줄 등록.
- 파일명은 `<대상>-<주제>.md` (예: `core-api-architecture.md`, `chuno-mobile-design.md`).
