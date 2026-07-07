import { RankingScope } from '@modules/scoring/applications/ranking.service';
import { IsEnum, IsOptional } from 'class-validator';

export class RankingQueryDto {
  /** 랭킹 범위 — 기본 전체(all). */
  @IsEnum(RankingScope)
  @IsOptional()
  scope?: RankingScope;
}
