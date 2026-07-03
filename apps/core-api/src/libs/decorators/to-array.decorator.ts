import { Transform } from 'class-transformer';

type ToArrayType = 'string' | 'number' | 'boolean';

function cast(value: unknown, type: ToArrayType): unknown {
  switch (type) {
    case 'number':
      // 변환 실패(NaN)는 그대로 두어 @IsInt/@IsNumber 가 거르게 한다.
      return Number(value);
    case 'boolean':
      return value === true || value === 'true';
    default:
      return value;
  }
}

/**
 * 쿼리스트링 값을 배열로 정규화하고, 각 요소를 지정 타입으로 캐스팅하는 데코레이터.
 *
 * **입력 규약: 콤마 조인(`?k=a,b,c`)이 프로젝트 표준.** 모든 프론트(chuno-mobile·back-office)는
 * 배열 쿼리 파라미터를 콤마로 이어 보낸다. 반복 파라미터(`?k=a&k=b`)도 함께 허용한다.
 *
 * @param type 요소 타입. 기본 `'string'`(캐스팅 없음).
 *
 * @example
 * // ?statuses=active          → ['active']
 * // ?statuses=active,expired  → ['active', 'expired']   (콤마 조인 — 표준)
 * @ToArray()                 // string[]
 * @IsEnum(LicenseStatus, { each: true })
 * @IsOptional()
 * statuses?: LicenseStatus[];
 *
 * @example
 * // ?tagIds=1     → [1]
 * // ?tagIds=1,2   → [1, 2]   (콤마 조인 — 표준)
 * @ToArray('number')         // number[]
 * @IsInt({ each: true })
 * @IsOptional()
 * tagIds?: number[];
 */
export function ToArray(type: ToArrayType = 'string'): PropertyDecorator {
  return Transform(({ value }) => {
    // undefined/null 은 그대로 두어 @IsOptional 이 동작하게 한다.
    if (value === undefined || value === null) {
      return value;
    }

    // 콤마 조인(?types=a,b,c)과 반복 파라미터(?types=a&types=b) 둘 다 배열로 정규화한다.
    const array = Array.isArray(value)
      ? value
      : typeof value === 'string'
        ? value
            .split(',')
            .map((item) => item.trim())
            .filter((item) => item.length > 0)
        : [value];

    return type === 'string' ? array : array.map((item) => cast(item, type));
  });
}
