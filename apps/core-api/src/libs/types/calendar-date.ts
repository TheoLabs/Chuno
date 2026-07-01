/**
 * CalendarDate
 *
 * 런타임에는 그냥 `string`(`YYYY-MM-DD` 또는 `YYYY-MM-DD HH:mm:ss`)이라
 * JSON 직렬화·TypeORM 컬럼(date/datetime)과 그대로 호환되고,
 * 컴파일 타임에는 일반 string과 구분되는 브랜드 타입이다.
 * 실제 파싱·검증·포맷은 추후 dayjs 기반 `libs/date`에서 담당한다.
 */

declare const brand: unique symbol;

/** `YYYY-MM-DD` 또는 `YYYY-MM-DD HH:mm:ss` 형식의 문자열 */
export type CalendarDate = string & { readonly [brand]: 'CalendarDate' };
