import { Injectable } from '@nestjs/common';
import { DomainEventHandler } from '@libs/queue';
import { RunnerStatsService } from '@modules/scoring/applications/runner-stats.service';

/**
 * RunnerStats 누적 핸들러 (S4-3) — `RaceFinished`를 소비해 유저별 누적 통계·티어를 갱신한다.
 *
 * ScoringResultHandler(S4-2)와 같은 RaceFinished에 반응하는 **두 번째** 핸들러.
 * 디스패처가 핸들러별 격리 ALS에서 실행하므로 두 트랜잭션이 교차오염 없이 안전. 멱등(RaceStatApplied 마커).
 */
@Injectable()
export class RunnerStatsHandler extends DomainEventHandler {
  constructor(private readonly runnerStats: RunnerStatsService) {
    super();
  }

  supports(eventName: string): boolean {
    return eventName === 'RaceFinished';
  }

  async handle(_eventName: string, data: Record<string, unknown>): Promise<void> {
    const roomId = Number(data?.roomId);
    if (!roomId) return;
    await this.runnerStats.accumulate(roomId);
  }
}
