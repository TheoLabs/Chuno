import { Injectable } from '@nestjs/common';
import { DomainEventHandler } from '@libs/queue';
import { ScoringService } from '@modules/scoring/applications/scoring.service';

/**
 * RaceResult 저장 핸들러 (S4-2) — `RaceFinished`를 소비해 러너별 순위·점수를 산출·저장한다.
 *
 * 디스패처가 팬아웃하며, RunnerStatsHandler와 **둘 다** 같은 RaceFinished에 반응한다(핸들러별 ALS 격리).
 * RaceFinished payload는 roomId만 담으므로 서비스가 roomId로 Race(runners)를 로드해 계산한다. 멱등.
 */
@Injectable()
export class ScoringResultHandler extends DomainEventHandler {
  constructor(private readonly scoring: ScoringService) {
    super();
  }

  supports(eventName: string): boolean {
    return eventName === 'RaceFinished';
  }

  async handle(_eventName: string, data: Record<string, unknown>): Promise<void> {
    const roomId = Number(data?.roomId);
    if (!roomId) return;
    await this.scoring.recordResults(roomId);
  }
}
