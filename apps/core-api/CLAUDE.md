# core-api 규칙

## 날짜 / 시각 컨벤션
날짜 필드는 **성격에 따라 두 갈래**로 나눈다.

1. **자동 감사 타임스탬프** — `createdAt` · `updatedAt` · `deletedAt`
   - TypeORM 자동 컬럼(`@CreateDateColumn` / `@UpdateDateColumn` / `@DeleteDateColumn`), 타입 `Date`.
   - **UTC 기준**(`new Date`). 시스템이 자동으로 찍는 감사용 값.
   - 네이밍: `xxxAt`.

2. **비즈니스에서 명시하는 날짜** — `joinOn` · `agreedOn` · `revokeOn` · `scheduledStartOn` 등
   - 타입 **`CalendarDate`**(`@libs/types`), 형식 `YYYY-MM-DD` 또는 `YYYY-MM-DD HH:mm:ss`.
   - **KST 기준**(`@libs/date`의 `today()` / `dayjs.tz`).
   - 도메인이 의미를 갖고 직접 지정하는 날짜.
   - 네이밍: **`xxxOn`**.

요약: **자동 = `xxxAt` / UTC / `Date`**, **비즈니스 = `xxxOn` / KST / `CalendarDate`**.

## 쿼리 배열 파라미터 규칙
- 배열 쿼리 파라미터는 **콤마 조인**으로 받는다: `?types=a,b,c`. (프로젝트 전-프론트 공통 규약 — 루트 `CLAUDE.md` 참조)
- DTO에서 **`@ToArray()`**(`@libs/decorators`)로 정규화한다. `@ToArray`가 콤마 문자열을 split·trim·빈값 제거해 배열로 만든다(반복 파라미터 `?k=a&k=b`도 허용). 요소 검증은 `@IsEnum(..., { each: true })` 등 + 선택이면 `@IsOptional()`.
- 응답 포맷: 목록(list)은 **`{ data: { items, total } }`**, 단건은 **`{ data: {...} }`**.

## HTTP 메서드 규칙
- CRUD은 **POST · GET · PUT · DELETE 만** 사용한다. **`PATCH` 금지** — 부분 업데이트도 `PUT`으로. (컨트롤러는 `@Patch` 쓰지 않는다.)
- 온보딩(1회성 상태전이) = **`PUT /users/onboard`** — `nickname`+`level` 필수, `onboardedOn`이 null일 때만 허용(이미 온보딩이면 409), **서버가 `onboardedOn`(KST)을 설정**(클라가 못 세팅).
- 프로필 수정 = **`PUT /users/me`**(추후, `onboardedOn` 제외).
