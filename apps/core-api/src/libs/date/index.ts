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

export default dayjs;
