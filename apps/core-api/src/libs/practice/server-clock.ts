import { Injectable } from '@nestjs/common';

/**
 * 서버 권위 시각 제공자.
 *
 * 공정한 동시 출발/카운트다운(S2-9)을 위해, 클라이언트는 자기 로컬 시계 대신
 * 이 서버 시각을 받아 **오프셋**을 계산한다:
 *   offset = serverTime − clientLocalNow
 *   remaining = scheduledStartAt − (clientLocalNow + offset)
 * 이렇게 하면 여러 기기의 카운트다운이 서버 기준으로 거의 동시에 0이 된다.
 *
 * NOTE: 시계 동기는 **단조로운 epoch millis(UTC)** 가 정확하다 —
 * 비즈니스 날짜(KST·`CalendarDate`, `xxxOn`)와는 성격이 다르며 여기선 순수 시각 오프셋용이다.
 */
@Injectable()
export class ServerClock {
  /** 서버 기준 현재 시각(UTC epoch millis). 핸드셰이크/주기 이벤트로 클라에 내려 오프셋 계산에 쓴다. */
  nowEpochMs(): number {
    return Date.now();
  }
}
