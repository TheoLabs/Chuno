import { FindOptionsWhere } from 'typeorm';

type NonFunction<T> = {
  [K in keyof T as T[K] extends (...args: any[]) => any ? never : K]: T[K];
};

type StrippableWhere<T> = {
  [K in keyof FindOptionsWhere<NonFunction<T>>]?: FindOptionsWhere<NonFunction<T>>[K] | undefined;
};

type StrictFindOptionsWhere<T> = FindOptionsWhere<T>;

/**
 * 순수 객체(plain object)인지 판별합니다.
 * Date, 배열, TypeORM FindOperator(MoreThan/In/Like 등) 같은 인스턴스는
 * 재귀 대상에서 제외하기 위해 false 를 반환합니다.
 */
function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (value === null || typeof value !== 'object') {
    return false;
  }
  const proto = Object.getPrototypeOf(value);
  return proto === Object.prototype || proto === null;
}

/**
 * 객체에서 undefined 값을 가진 속성을 재귀적으로 제거합니다.
 * 중첩된 순수 객체도 동일하게 처리하며, 비워진 중첩 객체는 키째 제거합니다.
 * Date / 배열 / FindOperator 는 값 그대로 유지합니다.
 */
function stripUndefinedDeep(obj: Record<string, unknown>): Record<string, unknown> {
  return Object.keys(obj).reduce((acc: Record<string, unknown>, key) => {
    const value = obj[key];

    if (value === undefined) {
      return acc;
    }

    if (isPlainObject(value)) {
      const nested = stripUndefinedDeep(value);
      // 중첩 객체가 모두 제거되어 비었다면 해당 키 자체를 생략합니다.
      if (Object.keys(nested).length > 0) {
        acc[key] = nested;
      }
      return acc;
    }

    acc[key] = value;
    return acc;
  }, {});
}

/**
 * 객체에서 undefined 값을 가진 속성을 (중첩 객체 포함) 재귀적으로 제거하고,
 * 그 결과 객체의 정확한 타입 (TypeORM FindOptionsWhere)을 추론합니다.
 * 빈 객체가 될 경우, 스프레드 연산을 위해 {}를 반환합니다.
 */
export function stripUndefined<T>(obj: StrippableWhere<T>): StrictFindOptionsWhere<T> {
  const stripped = stripUndefinedDeep(obj);

  // [수정] 빈 객체일 경우 스프레드 연산의 안전성을 위해 {}를 반환합니다.
  if (Object.keys(stripped).length === 0) {
    return {};
  }

  // 최종 결과는 TypeORM 검색 조건 객체 타입으로 단언하여 반환합니다.
  return stripped as StrictFindOptionsWhere<T>;
}
