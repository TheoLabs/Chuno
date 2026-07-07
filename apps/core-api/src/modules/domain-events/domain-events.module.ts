import { Module } from '@nestjs/common';
import { DiscoveryModule } from '@nestjs/core';
import { BullModule } from '@nestjs/bullmq';
import { QUEUE } from '@libs/queue';
import { DomainEventDispatcher } from './domain-event-dispatcher';

/**
 * 도메인 이벤트 디스패치 모듈 (S3-3 리팩터).
 *
 * `domain-events` 큐의 단일 워커(`DomainEventDispatcher`)를 제공한다. 워커는 `DiscoveryService`로
 * 전역의 모든 `DomainEventHandler` 프로바이더를 수집해 팬아웃한다 — 각 도메인 모듈(room·race…)은
 * 자기 핸들러를 **일반 프로바이더로 등록**하기만 하면 이 디스패처가 자동으로 소비에 포함한다.
 */
@Module({
  imports: [DiscoveryModule, BullModule.registerQueue({ name: QUEUE.DOMAIN_EVENTS })],
  providers: [DomainEventDispatcher],
})
export class DomainEventsModule {}
