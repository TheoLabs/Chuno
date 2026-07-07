import { ResponseDto } from '@libs/utils';
import { Exclude, Expose } from 'class-transformer';

/** RaceResult 응답(러너 1명분). 4축 점수를 중첩 없이 평탄하게 노출. */
@Exclude()
export class RaceResultResponseDto extends ResponseDto {
  @Expose()
  id: number;

  @Expose()
  raceId: number;

  @Expose()
  userId: number;

  @Expose()
  finished: boolean;

  @Expose()
  distanceKm: number;

  @Expose()
  finishTime: number | null;

  @Expose()
  rank: number;

  @Expose()
  total: number;

  @Expose()
  rankScore: number;

  @Expose()
  distanceScore: number;

  @Expose()
  finishBonus: number;

  @Expose()
  marginScore: number;

  @Expose()
  pointsAwarded: number;
}
