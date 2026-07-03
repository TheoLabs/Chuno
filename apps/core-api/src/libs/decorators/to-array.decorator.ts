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
 * @param type 요소 타입. 기본 `'string'`(캐스팅 없음).
 *
 * @example
 * // ?statuses=active                  → ['active']
 * // ?statuses=active&statuses=expired → ['active', 'expired']
 * @ToArray()                 // string[]
 * @IsEnum(LicenseStatus, { each: true })
 * @IsOptional()
 * statuses?: LicenseStatus[];
 *
 * @example
 * // ?tagIds=1            → [1]
 * // ?tagIds=1&tagIds=2   → [1, 2]
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

    const array = Array.isArray(value) ? value : [value];

    return type === 'string' ? array : array.map((item) => cast(item, type));
  });
}
