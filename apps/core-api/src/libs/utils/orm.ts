import { Brackets, FindOptionsRelations, ObjectLiteral, SelectQueryBuilder, ValueTransformer } from 'typeorm';
import { LessThan, MoreThanOrEqual, And, Like, In } from 'typeorm';
import { PaginationOptions } from './pagination';

/**
 * DECIMAL 컬럼 transformer.
 * mysql 드라이버는 DECIMAL 을 정밀도 보존을 위해 "문자열"로 돌려주므로, 엔티티에서 number 로 정규화한다.
 * 사용: `@Column({ type: 'decimal', precision: 20, scale: 10, transformer: decimalTransformer })`
 */
export const decimalTransformer: ValueTransformer = {
  to: (value?: number | null) => value,
  from: (value?: string | null) => (value == null ? value : Number(value)),
};

export interface TypeormRelationOptions<T> {
  relations?: FindOptionsRelations<T>;

  options?: PaginationOptions;

  lock?:
    | {
        mode: 'optimistic';
        version: number | Date;
      }
    | {
        mode: 'pessimistic_read' | 'pessimistic_write';
        tables?: string[];
        onLocked?: 'nowait' | 'skip_locked';
      };
}

export const convertOptions = <T>(args?: TypeormRelationOptions<T>) => {
  let skip;
  let take;
  let order;

  if (args && args.options && args.options.page) {
    skip = ((args.options.page || 1) - 1) * (args.options.limit || 1);
  }

  if (args && args.options && args.options.limit) {
    take = args.options.limit;
  }

  if (args && args.options && args.options.sort && args.options.order) {
    order = { [args.options.sort]: args.options.order };
  }

  return { skip, take, order, relations: args?.relations, lock: args?.lock };
};

export interface TypeormRelationOptions<T> extends PaginationOptions {
  relations?: FindOptionsRelations<T>;
}

/**
 * QueryBuilder 에 페이지네이션/정렬을 적용한다(convertOptions 의 QB 버전).
 * - convertOptions 와 동일 규약: page → skip, limit → take, sort+order → orderBy.
 * - sort 는 qb 메인 alias 로 prefix 한다(이미 'alias.col' 형태면 그대로 사용 → 조인 컬럼 정렬 가능).
 *
 * 주의: sort 는 orderBy 에 문자열로 보간된다. 신뢰 못 할 입력이면 호출부에서 정렬 컬럼 allowlist 로 거른다.
 */
export function applyPagination<T extends ObjectLiteral>(
  qb: SelectQueryBuilder<T>,
  options?: PaginationOptions
): SelectQueryBuilder<T> {
  if (!options) {
    return qb;
  }

  if (options.page) {
    qb.skip(((options.page || 1) - 1) * (options.limit || 1));
  }

  if (options.limit) {
    qb.take(options.limit);
  }

  if (options.sort && options.order) {
    qb.orderBy(options.sort.includes('.') ? options.sort : `${qb.alias}.${options.sort}`, options.order);
  }

  return qb;
}

/**
 * QueryBuilder 에 멀티 컬럼 LIKE 검색(OR)을 적용한다.
 * - searchKeys 각 키를 columnMap 으로 실제 SQL 표현식(alias 포함)으로 변환한다.
 * - columnMap 에 없는 키는 무시(주입 방어선) — 입력 검증은 DTO 의 @IsIn(Object.keys(columnMap)) 로.
 * - OR 그룹을 Brackets 로 묶어, 다른 andWhere(예: status 필터)와 올바르게 AND 된다.
 *
 * 예) columnMap = { contentTitle: 'content.title', title: 'episode.title', chapter: 'CAST(episode.chapter AS CHAR)' }
 */
export function applyLikeSearch<T extends ObjectLiteral>(
  qb: SelectQueryBuilder<T>,
  columnMap: Record<string, string>,
  searchKeys?: string[],
  searchValue?: string
): SelectQueryBuilder<T> {
  const cols = (searchKeys ?? []).map((key) => columnMap[key]).filter(Boolean);

  if (!cols.length || !searchValue) {
    return qb;
  }

  const q = `%${searchValue}%`;

  return qb.andWhere(
    new Brackets((b) =>
      cols.forEach((col, i) => (i === 0 ? b.where(`${col} LIKE :q`, { q }) : b.orWhere(`${col} LIKE :q`, { q })))
    )
  );
}

/**
 * 범위 값 체크
 * @param minValue 최소값
 * @param maxValue 최대값
 * @returns 범위 값
 */
export function checkRangeValue(minValue?: any, maxValue?: any) {
  const hasMin = minValue != null;
  const hasMax = maxValue != null;

  if (!hasMin && hasMax) {
    return LessThan(maxValue);
  }

  if (hasMin && !hasMax) {
    return MoreThanOrEqual(minValue);
  }

  if (hasMin && hasMax) {
    return And(MoreThanOrEqual(minValue), LessThan(maxValue));
  }

  return undefined;
}

/**
 * 문자열 포함 여부 체크
 * @param searchKey 검색 키워드
 * @param searchValue 검색 값
 * @returns 검색 키워드와 검색 값
 */
export function checkLikeValue({ searchKey, searchValue }: { searchKey?: string; searchValue?: string }) {
  if (searchKey && searchValue) {
    return { [searchKey]: Like(`%${searchValue}%`) };
  }

  return undefined;
}

export function checkInValue(values?: any[]) {
  return values && In(values);
}
