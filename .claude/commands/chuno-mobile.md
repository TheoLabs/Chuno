---
description: APP 태스크(예 S1-8)를 chuno-mobile 에이전트로 구현하고, code-reviewer로 독립 검증한 뒤 docs에 상태를 반영한다 (구현→검증→docs 통합)
argument-hint: <task-id> (예 S1-8)
allowed-tools: Read, Grep, Glob, Bash, Task
---

# chuno-mobile 태스크 구현 → 검증 → docs 반영

대상 태스크: **$ARGUMENTS**

네 임무는 위 APP 태스크를 **① `chuno-mobile` 에이전트로 구현**하고, **② `code-reviewer`로 독립 검증**한 뒤, **③ 검증된 실제 상태를 docs에 반영**하는 것이다. **코드는 직접 편집하지 말고** `chuno-mobile` 에이전트가, **docs는** `docs-editor` 에이전트가 담당한다.

## 1) 태스크 컨텍스트 파악
- `docs/product/issue/step*.html`에서 `$ARGUMENTS` 이슈 블록을 찾아 **체크리스트·"완료 —" 기준**을 읽는다. 대응 `docs/product/mvp/step*.html` 항목도 확인.
- 설계 참조: `docs/chuno-mobile-design.md`(스펙), `docs/product/wireframes/index.html`(레이아웃/플로우).
- 현재 구현 상태 파악: `apps/chuno-mobile/lib/` 구조(관련 화면·위젯·모델·mock), 이미 있는 것/없는 것. 백엔드 계약이 걸리면 `apps/core-api`에서 실제 DTO·엔드포인트를 확인해 정확한 계약을 잡는다.
- APP 태스크가 아니면(백엔드/디자인) 그 사실을 알리고 중단한다.

## 2) 구현 (chuno-mobile 에이전트에 위임)
- `chuno-mobile` 서브에이전트(subagent_type: `chuno-mobile`)에 위임한다:
  - **태스크 ID·완료 기준**과 만들 것(화면/위젯/상태관리/네트워킹/네이티브 설정).
  - 1)의 **설계 참조**(와이어프레임·design.md)·**현재 코드 상태**(재사용 위젯·모델, 손댈 파일)·**백엔드 계약**(있으면 정확히).
  - 규약(다크+코랄 토큰·공용 위젯 재사용·좌표 미전송 프라이버시·오버플로우 금지).
  - **구현 후 `flutter analyze` 무이슈 + `flutter test` 통과**(회귀 `layout_test.dart` 유지)까지 완료하라는 지시.
- 작업이 크면 논리 단위로 나눠 위임한다.

## 3) 독립 검증 (code-reviewer 에이전트에 위임)
- 구현이 끝나면 `code-reviewer` 서브에이전트(subagent_type: `code-reviewer`)에 위임해 **독립 검증**한다. 1)의 **완료기준·대상 코드 범위·백엔드 계약**을 넘겨, 각 기준을 실제 코드와 대조하고 `flutter analyze`/`flutter test`를 돌려 근거를 확보한 **구조화된 리포트(판정 + ✅충족/⚠️갭/❗문제)** 를 받는다.
- 구현 에이전트의 자기보고와 **별개로**, 신선한 리뷰어의 독립 판정을 받는 게 목적이다(자기검증 방지).

## 4) 판정 정리
- code-reviewer 리포트를 사용자에게 간결히 전달한다(✅충족/⚠️갭/❗문제 + 파일:라인).
- 각 완료기준 항목을 **완료 / 남음 / 이월 / 스코프외**로 분류하고 **전체 판정**을 낸다(모든 기준 충족 + 미해결 문제 없음 → 통과, 하나라도 남으면 → 부분 완료). **절대 규칙: 검증으로 확인 못 한 항목을 완료로 표기하지 마라.**

## 5) docs 반영 (docs-editor 에이전트에 위임)
- `docs-editor` 서브에이전트(subagent_type: `docs-editor`)에 위임해 4)의 상태 분류를 반영한다:
  - `docs/product/issue/step*.html`의 해당 이슈 — 항목별 **완료/남음/이월/스코프외** 태그 + 완료기준(`.iaccept`) 문구를 현재 상태에 맞춤.
  - `docs/product/mvp/step*.html`의 해당 항목.
  - `docs/product/issue/index.html`(이슈 보드) — 해당 행의 완료 태그를 전체 판정에 맞춰 조정(통과→완료 태그, 부분/미완→완료 태그 금지).
  - 스키마/도메인이 바뀌었다면 `docs/domain/index.html`(카드·매핑·ERD)도.
- 각 항목의 상태·근거·이월/스코프 사유를 구체적으로 전달하고, 기존 **다크+코랄·자체완결·상호링크** 규칙 유지를 지시한다.

## 6) 요약
- **구현 요약 + 검증 판정(✅/⚠️/❗) + docs 반영 내역 + 남은 작업**(있으면)을 사용자에게 간결히 보고한다. 검증 불가(외부 자원/실서버) 부분은 명시한다.
