---
description: 워킹트리 변경을 논리적 커밋으로 정리한다 — commit-organizer가 그룹핑을 제안하고, 승인 후 규약대로 main에 커밋
argument-hint: (선택) 범위/힌트 (예 "core-api만", "docs 제외")
allowed-tools: Read, Grep, Glob, Bash, Task
---

# 커밋 정리

$ARGUMENTS

네 임무는 현재 워킹트리의 변경분을 **잘 나뉜 논리적 커밋들로 정리**하는 것이다. **main에 커밋**하며(이 repo의 워크플로우), **승인 전에는 아무것도 커밋하지 않는다.** `$ARGUMENTS`에 범위/힌트가 있으면 반영한다(없으면 전체 워킹트리).

## 커밋 룰 (항상 적용)
- **그룹핑**: 영역(core-api·chuno-mobile·docs·config) × 관심사(feat/fix/docs/refactor)로 분리. 서로 무관한 변경을 한 커밋에 섞지 않는다.
- **메시지**: Conventional Commits `type(scope): 한국어 제목` (repo 기존 스타일 유지).
- **트레일러**: 모든 커밋 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **인덱스 클린**(중요): 각 커밋 전 `git reset`으로 스테이징을 비우고, 그 커밋의 파일만 명시적으로 `git add` 한다 — 미리 스테이징된 다른 변경이 섞여 커밋이 오염되는 것을 막는다.
- **제외**: `.env*`·사용자 소유 파일은 건드리지 않는다. 이미 커밋된 것도 제외.
- **검증 안 함**: build/test·lint는 돌리지 않는다(속도 우선 — 코드 검증은 `/verify-task`로 별도).
- **푸시 안 함**: 커밋까지만. 푸시는 사용자가 명시 요청할 때만.

## 1) 현황 파악
- `git status`·현재 브랜치 확인. **main이 아니면** 그 사실을 알리고 어떻게 할지 확인한다(기본은 main 커밋 전제).
- 변경이 없으면 그 사실을 알리고 종료한다.

## 2) 그룹핑 분석 (commit-organizer 에이전트에 위임)
- `commit-organizer` 서브에이전트(subagent_type: `commit-organizer`)에 위임해 **커밋 그룹핑 계획**(파일→커밋+Conventional 메시지)을 받는다. 위 그룹핑 룰·repo 스타일을 지키게 하고, `$ARGUMENTS` 범위 힌트를 전달한다. (에이전트는 읽기 전용 — 커밋하지 않는다)

## 3) 계획 제시 + 승인 게이트
- 받은 계획을 **표로 제시**(순서·`type(scope): 제목`·파일 목록·근거). 미배정/모호 파일이 있으면 함께 확인한다.
- **승인 전에는 커밋하지 않는다.** 조정 요청은 반영해 다시 제시.

## 4) 실행 (승인 후에만)
- 계획 순서대로 커밋한다. 각 커밋마다:
  1. `git reset --quiet`(--mixed)로 인덱스 초기화 →
  2. 그 커밋의 파일만 `git add`(리네임/삭제가 있으면 해당 경로에 `git add -A`) →
  3. `git commit -q -m "<type(scope): 제목>" -m "<Co-Authored-By 트레일러>"`.
- **인터랙티브 플래그 금지**(`-i` 류 사용 안 함). `set -e`로 실패 시 중단.
- 전부 끝나면 `git status`가 **클린**인지, `git log --oneline`으로 커밋들이 의도대로 쌓였는지, 오염(다른 영역 파일 섞임) 없는지 확인한다.

## 5) 요약
- 만든 커밋 목록(해시·메시지)과 워킹트리 클린 여부, origin 대비 앞선 커밋 수를 보고한다. **푸시가 필요하면 사용자에게 물어본다**(임의 푸시 금지).
