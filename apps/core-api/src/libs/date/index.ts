import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import { CalendarDate } from '@libs/types';

dayjs.extend(utc);
dayjs.extend(timezone);

// 기본 타임존 = KST(Asia/Seoul). dayjs.tz(...) 호출 시 이 존을 기준으로 동작.
dayjs.tz.setDefault('Asia/Seoul');

export function today(format: 'YYYY-MM-DD' | 'YYYY-MM-DD HH:mm:ss' = 'YYYY-MM-DD'): CalendarDate {
  return dayjs.tz().format(format) as CalendarDate;
}

/**
 * 비즈니스 날짜(KST `CalendarDate`)를 절대시각 epoch millis로 변환한다.
 * 기본 존이 Asia/Seoul이라 `dayjs.tz(date)`가 문자열을 KST로 해석한다. 예약 지연잡 delay 계산 등에 사용.
 */
export function toEpochMs(date: CalendarDate): number {
  return dayjs.tz(date).valueOf();
}

export default dayjs;
