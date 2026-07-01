---
description: APP 태스크(예 S1-7)의 컨텍스트를 모아 chuno-mobile 에이전트에 Flutter 구현을 위임하고 검증한다
argument-hint: <task-id> (예 S1-8)
allowed-tools: Read, Grep, Glob, Bash, Task
---

# chuno-mobile 태스크 구현·검증

대상 태스크: **$ARGUMENTS**

네 임무는 위 APP 태스크의 **컨텍스트를 정리해 `chuno-mobile` 서브에이전트에 Flutter 구현을 위임**하고, 구현이 `flutter analyze`/`flutter test`로 **검증되도록** 하는 것이다. **코드는 직접 편집하지 말고** 반드시 chuno-mobile 에이전트가 구현하게 한다.

## 1) 태스크 컨텍스트 파악
- `docs/issue/step*.html`에서 `$ARGUMENTS` 이슈 블록을 찾아 **체크리스트·"완료 —" 기준**을 읽는다. 대응 `docs/mvp/step*.html` 항목도 확인.
- 관련 설계를 확인한다: `docs/chuno-mobile-design.md`(스펙), `docs/wireframes/index.html`(레이아웃/플로우).
- 현재 구현 상태를 파악한다: `apps/chuno-mobile/lib/` 구조(관련 화면·위젯·모델·mock), 이미 있는 것과 없는 것.
- APP 태스크가 아니면(백엔드/디자인) 그 사실을 알리고 중단한다.

## 2) chuno-mobile 에이전트에 구현 위임
- `chuno-mobile` 서브에이전트(subagent_type: `chuno-mobile`)에 다음을 담아 위임한다:
  - **태스크 ID·완료 기준**과 무엇을 만들어야 하는지(화면/위젯/상태관리/네트워킹/네이티브 설정).
  - 1)에서 확인한 **설계 참조**(해당 화면의 와이어프레임·design.md 규칙)와 **현재 코드 상태**(재사용할 위젯·모델, 손댈 파일).
  - 지켜야 할 규약(다크+코랄 토큰, 공용 위젯 재사용, 좌표 미전송 프라이버시, 오버플로우 금지).
  - **구현 후 `flutter analyze` 무이슈 + `flutter test` 통과까지 완료**하라는 지시(회귀 테스트 `layout_test.dart` 유지).
- 여러 화면 등 작업이 크면 논리 단위로 나눠 위임해도 된다.

## 3) 결과 보고
- 에이전트가 반환한 **구현 요약 + 검증 결과(analyze/test)** 와 완료 기준 대비 남은 것·검증 불가 부분을 사용자에게 간결히 전달한다.

## 참고
- 이 커맨드는 **구현 + 검증**까지다. 태스크 상태를 docs에 반영(완료/남음)하려면 이후 **`/verify-task $ARGUMENTS`** 를 돌린다.
