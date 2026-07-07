import { Injectable } from '@nestjs/common';
import { OrderType, PaginationOptions } from '@libs/utils';
import { RaceResultRepository } from '@modules/scoring/infrastructure/race-result.repository';
import { RaceResultResponseDto } from '@modules/scoring/presentation/dto';

/**
 * 기록/결과 조회 서비스 (S4-5) — 읽기 전용.
 * - getMyResults: 내 RaceResult 목록(페이지네이션).
 * - getRaceResult: 한 경주의 전체 결과(러너 전원, rank 오름차순).
 */
@Injectable()
export class RaceResultQueryService {
  constructor(private readonly raceResultRepository: RaceResultRepository) {}

  /** 내 기록 목록 — 최신순 기본, 페이지네이션. */
  async getMyResults(userId: number, options?: PaginationOptions) {
    const listOptions: PaginationOptions = { sort: 'createdAt', order: OrderType.DESC, ...options };
    const [results, total] = await Promise.all([
      this.raceResultRepository.find({ userId }, { options: listOptions }),
      this.raceResultRepository.count({ userId }),
    ]);

    return {
      items: results.map((result) => result.toInstance(RaceResultResponseDto)),
      total,
    };
  }

  /** 한 경주 전체 결과 — rank 오름차순. */
  async getRaceResult(raceId: number) {
    const results = await this.raceResultRepository.find(
      { raceId },
      { options: { sort: 'rank', order: OrderType.ASC } }
    );

    return {
      raceId,
      results: results.map((result) => result.toInstance(RaceResultResponseDto)),
    };
  }
}
