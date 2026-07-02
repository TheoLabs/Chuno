---
description: 기획 컨텍스트를 이슈 보드 태스크로 분해하고, 승인받아 보드·문서·(필요시)와이어프레임에 반영한다
argument-hint: <기획/제품 컨텍스트>
allowed-tools: Read, Grep, Glob, Task
---

# 기획 → 이슈 보드 태스크

기획 컨텍스트: **$ARGUMENTS**

네 임무는 위 기획을 **잘 정의된 태스크로 분해**하고, **사용자 승인 후에만** 이슈 보드·문서·(필요시)와이어프레임에 반영하는 것이다. 파일은 직접 쓰지 말고 서브에이전트에 위임한다.

## 1) 분해 (issue-planner에 위임)
`issue-planner` 서브에이전트(subagent_type: `issue-planner`)에 `$ARGUMENTS`를 넘겨, 기존 docs(issue/mvp/domain/README)·`apps/core-api/CLAUDE.md`를 읽고 **일관되게 분해**하게 한다. 반환받을 것: 태스크별 `유니크 id·스텝·카테고리·크기·제목·설명·체크리스트·완료기준·선행·관련 도메인/와이어프레임·needsWireframe` + 가정/열린질문/중복·보강 제안.

## 2) 초안 제시 + 승인 게이트
- planner의 초안을 **사용자에게 간결한 표로 제시**한다(제목·스텝·카테고리·크기·완료기준·선행·연관·디자인필요). 가정·열린 질문이 있으면 함께 확인해 확정한다.
- **승인 전에는 보드/문서/와이어프레임을 절대 건드리지 않는다.** 조정 요청은 반영해 다시 제시한다.

## 3) 반영 (승인 후에만)
- **docs-editor**(subagent_type: `docs-editor`)에 위임: 확정 태스크를 `docs/issue/step*.html`(이슈 카드) + `docs/mvp/step*.html`(로드맵 행) + `docs/issue/index.html`(보드 행)에 기존 스타일로 렌더. **관련 도메인/와이어프레임으로의 크로스링크**와 이슈 카운트를 갱신. 새 스키마/도메인 개념이 생기면 `docs/domain/index.html`(카드·매핑·ERD)도.
- **디자인 필요(needsWireframe) 태스크**: **wireframe-designer**(subagent_type: `wireframe-designer`)에 위임해 `docs/wireframes/index.html`에 화면·플로우를 추가하고, 이슈↔와이어프레임 화면 크로스링크를 맞춘다.
- docs-editor(보드/mvp/도메인)와 wireframe-designer(와이어프레임)는 **다른 파일**이라 병렬 가능하나, 겹칠 소지가 있으면 순차로 실행해 충돌을 피한다.

## 4) 요약
생성/보강된 태스크(유니크 id·연관·디자인 반영 여부)와 남은 열린 질문을 요약 보고한다.
