# 추노 (Chuno)

러너들끼리 경쟁하는 러닝 경주 매칭 서비스.

## 모노레포 구조

```
Chuno/
├─ apps/
│  ├─ core-api/      # NestJS 백엔드 (규칙 정본: apps/core-api/CLAUDE.md)
│  └─ chuno-mobile/  # Flutter 앱 (iOS / Android)
├─ docs/             # 설계 문서 (도메인/와이어프레임/MVP 로드맵/이슈 보드)
├─ .claude/          # Claude Code 커맨드·에이전트 (개발 워크플로우)
├─ pnpm-workspace.yaml
└─ package.json
```

Flutter(Dart)는 JS 워크스페이스에 포함되지 않으며 디렉토리 기반으로 함께 관리됩니다.

## 시작하기

```bash
# JS 의존성 설치 (core-api)
pnpm install

# core-api 개발 서버
pnpm api:dev

# Flutter 앱 실행
pnpm app:run
```

## 설계 문서 (`docs/`)

자체완결 HTML/Markdown, 공용 다크+코랄 "추격전" 스타일, 서로 크로스링크됨. 인덱스는 `docs/README.md`.

- `docs/domain/` — DDD 도메인 설계(바운디드 컨텍스트·애그리거트·이벤트·ERD)
- `docs/wireframes/` — 인터랙티브 프로토타입(폰 클릭 플로우·색상 스위처)
- `docs/mvp/` — MVP 로드맵(Step 1~5)
- `docs/issue/` — 이슈 보드(`index.html` + `step1..5.html`). 이슈 ID = `S<스텝>-<번호>`(예 `S1-4`), 이슈↔도메인↔와이어프레임 크로스링크로 추적성 유지
- `docs/chuno-mobile-design.md` — 모바일 설계 스펙

## 개발 워크플로우 (`.claude/`)

Claude Code 기반. **슬래시 커맨드**가 **서브에이전트**를 오케스트레이션한다(서브에이전트끼리는 서로 호출하지 못하므로 커맨드가 조율).

### 슬래시 커맨드 (`.claude/commands/`)

| 커맨드 | 하는 일 |
|---|---|
| `/plan-issues <기획>` | 새 기획 컨텍스트 → 태스크로 분해 → **초안 승인** 후 이슈 보드·(필요시)와이어프레임에 반영 |
| `/replan <변경>` | 기획 변경 → 의존성·연관 그래프 전체의 **임팩트 분석**(하위 전파·크로스링크·완료분 회귀) → 승인 후 반영 |
| `/chuno-mobile <task-id>` | APP 태스크 컨텍스트를 모아 `chuno-mobile` 에이전트에 Flutter 구현 위임 + `flutter analyze`/`test` 검증 |
| `/verify-task <task-id>` | 태스크를 `code-reviewer`로 검증 → 검증된 실제 상태(완료/남음/이월/스코프외)를 docs·이슈 보드에 반영 |

### 에이전트 (`.claude/agents/`)

| 에이전트 | 역할 | 쓰기 |
|---|---|---|
| `issue-planner` | 기획→태스크 분해 / 변경 임팩트 분석. 유니크 id·완료기준·선행·도메인/와이어프레임 연관을 담은 구조화 초안 반환 | 읽기전용 |
| `wireframe-designer` | `docs/wireframes/` 인터랙티브 프로토타입 화면·플로우 디자인 | docs/wireframes |
| `docs-editor` | `docs/`(이슈 보드·MVP·도메인·README·스타일시트) 렌더·최신화. 다크+코랄·자체완결·크로스링크 유지 | docs/ (와이어프레임 제외) |
| `code-reviewer` | `apps/**` 검증 — 완료기준·정확성·설계이탈·보안. 통과/문제 리포트 | 읽기전용 |
| `chuno-mobile` | Flutter 앱(`apps/chuno-mobile/**`) 구현 전담 | apps/chuno-mobile |

### 대표 흐름

```
기획   /plan-issues → issue-planner(분해) → [승인] → docs-editor + wireframe-designer(반영)
변경   /replan      → issue-planner(임팩트) → [승인] → docs-editor + wireframe-designer(회귀 반영)
구현   /chuno-mobile(앱) 또는 직접(백엔드)
검증   /verify-task → code-reviewer(검증) → docs-editor(보드 상태·완료 태그)
```

## 프로젝트 규칙 (컨벤션)

**백엔드 규칙 정본 = `apps/core-api/CLAUDE.md`** (세션마다 자동 로드):

- **날짜/시각**: 자동 감사 타임스탬프 `createdAt`/`updatedAt`/`deletedAt` = `xxxAt` · UTC · `Date`(TypeORM 자동 컬럼). 비즈니스 명시 날짜 = **`xxxOn`** · KST · **`CalendarDate`**(`@libs/types`, `@libs/date`).
- **HTTP 메서드**: CRUD은 **POST·GET·PUT·DELETE만**, **`PATCH` 금지**(부분 업데이트도 PUT). 온보딩 = `PUT /users/onboard`(1회성, 서버가 `onboardedOn` 설정), 프로필 수정 = `PUT /users/me`.
- **아키텍처**: DDD — 모듈 = 바운디드 컨텍스트, `domain/application/infrastructure/interface` 레이어, 리포지토리는 포트로 두고 infrastructure에서 구현.
- **프라이버시**: 경주 중 좌표는 서버에 전송하지 않고 거리(km)/진행률만. 점수는 서버 권위.

**작업 컨벤션:**

- `docs/` 편집은 `docs-editor`(와이어프레임은 `wireframe-designer`)에 위임 — 직접 편집하지 않음.
- 태스크 검증은 `code-reviewer`(읽기전용)로. **검증으로 확인된 것만 완료**로 표기하고, 부분 완료도 정확히 반영.
- **`.env.local` 등 사용자 소유 `.env*`는 수정 전 항상 확인** — 에이전트도 자동 생성/수정 금지. E2E 부팅 검증은 인라인 env 또는 일회용 `.env.<NODE_ENV>`로.
- 문서 수정/검증 시 **브라우저 자동 실행(`open`) 금지** — 태그 균형·링크·grep으로 점검.
- 요청 범위를 **미니멀**하게 — 오버엔지니어링 지양.
