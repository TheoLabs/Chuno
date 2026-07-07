import { Injectable } from '@nestjs/common';
import { AsyncLocalStorage } from 'async_hooks';

export enum ContextKey {
  ENTITY_MANAGER = 'entityManager',
  DDD_EVENTS = 'dddEvents',
  TXID = 'txId',
  ACCOUNT = 'admin',
  USER = 'user',
  CREATOR = 'creator',
  ROLE = 'role',
  // NOTE: 추후 필요한 경우 추가.
}

export const asyncLocalStorage = new AsyncLocalStorage<Map<string, any>>();

/**
 * ALS 컨텍스트 스토어 안에서 콜백을 실행한다 — HTTP `ContextMiddleware`/WS `WsContextInterceptor`가 심는
 * 스토어의 워커(BullMQ) 대응. 스토어가 이미 있으면 그대로 재사용, 없으면 새로 만든다.
 *
 * 왜 필요한가: BullMQ 워커의 `process()`는 요청 파이프라인 밖이라 ALS 스토어가 없다. 그 안에서
 * `@Transactional`(→ `context.set(ENTITY_MANAGER…)`)을 호출하면 "no context store"로 던진다.
 * 워커 경계에서 이 헬퍼로 감싸면 워커 트리거 트랜잭션(예약 전환·Race 생성/종료)이 정상 동작한다.
 */
export function runWithContext<T>(fn: () => T): T {
  if (asyncLocalStorage.getStore()) {
    return fn();
  }
  return asyncLocalStorage.run(new Map<string, any>(), fn);
}

@Injectable()
export class Context {
  getStore() {
    return asyncLocalStorage.getStore();
  }

  set<T extends ContextKey>(key: T, value: any) {
    const store = this.getStore();

    if (store) {
      store.set(key, value);
    } else {
      throw new Error('There is no context store.');
    }
  }

  get<K>(key: ContextKey): K {
    return this.getStore()?.get(key);
  }
}
