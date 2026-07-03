import { Transform } from 'class-transformer';

/**
 * 쿼리스트링 'true'/'false' 값을 실제 boolean 으로 변환하는 데코레이터.
 *
 * - `undefined`/`null` 은 그대로 둔다 → `@IsOptional` 이 정상 동작(필터 미지정).
 * - 이미 boolean 이면 그대로 통과.
 * - 매칭되지 않는 값('yes' 등)은 원본을 반환해 `@IsBoolean` 이 거르게 한다.
 *
 * @example
 * // ?isFree=true → true,  ?isFree=false → false,  (미지정) → undefined
 * @ToBoolean()
 * @IsBoolean()
 * @IsOptional()
 * isFree?: boolean;
 */
export function ToBoolean(): PropertyDecorator {
  return Transform(({ value }) => {
    if (value === undefined || value === null) {
      return value;
    }
    if (typeof value === 'boolean') {
      return value;
    }
    if (value === 'true') {
      return true;
    }
    if (value === 'false') {
      return false;
    }
    return value;
  });
}
