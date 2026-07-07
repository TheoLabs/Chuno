import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { ConfigsService } from '@configs';
import { QUEUE } from './queue.constants';

/**
 * Redis/BullMQ 라이브니스 — 부팅 시 연결을 검증하고(S2-12 완료기준: "부팅 시 Redis 연결 성공"),
 * 런타임 `/health` 엔드포인트에서도 재사용된다.
 *
 * BullMQ 큐의 ioredis 커넥션으로 PING을 날린다. 부팅 시 실패면 **부팅을 차단**해 빠르게 드러낸다.
 * graceful shutdown: 큐 커넥션 정리는 BullMQ가 Nest 셧다운 훅(`enableShutdownHooks`)에 맞춰 자동 처리.
 */
@Injectable()
export class QueueHealthIndicator implements OnApplicationBootstrap {
  private readonly logger = new Logger(QueueHealthIndicator.name);

  constructor(
    @InjectQueue(QUEUE.ROOM_SCHEDULER) private readonly queue: Queue,
    private readonly configs: ConfigsService
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    await this.ping(); // 실패 시 예외 → 부팅 차단
    const { host, port } = this.configs.redis;
    this.logger.log(`Redis 연결 정상 · BullMQ 지연잡 수용 준비 완료 (${host}:${port})`);
  }

  /** Redis 연결 검증. 연결/응답 실패면 예외(부팅 차단/헬스 실패). 로깅 없음(호출측이 결정). */
  async ping(): Promise<void> {
    // waitUntilReady: BullMQ ioredis 커넥션이 준비될 때 resolve(못 붙으면 reject).
    const client = await this.queue.waitUntilReady();
    // IRedisClient 타입엔 ping이 노출 안 돼 캐스팅 — 확정 liveness 신호로 PONG 확인.
    const pong = await (client as unknown as { ping(): Promise<string> }).ping();
    if (pong !== 'PONG') {
      throw new Error(`Redis 헬스체크 실패(PING 응답: ${pong})`);
    }
  }

  /** `/health` 등 런타임 체크용 — 예외를 삼켜 boolean으로 반환. */
  async isHealthy(): Promise<boolean> {
    try {
      await this.ping();
      return true;
    } catch {
      return false;
    }
  }
}
