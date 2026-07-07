import { Injectable } from '@nestjs/common';
import { QueueHealthIndicator } from '@libs/queue';

@Injectable()
export class AppService {
  constructor(private readonly queueHealth: QueueHealthIndicator) {}

  /** 라이브니스 — Redis/BullMQ 연결 상태 포함. */
  async health(): Promise<{ status: string; redis: 'ok' | 'down' }> {
    const redisOk = await this.queueHealth.isHealthy();
    return { status: redisOk ? 'ok' : 'degraded', redis: redisOk ? 'ok' : 'down' };
  }
}
