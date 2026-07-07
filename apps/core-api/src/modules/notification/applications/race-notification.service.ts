import { Injectable } from '@nestjs/common';
import { RoomRepository } from '@modules/room/infrastructure/room.repository';
import { RaceRepository } from '@modules/race/infrastructure/race.repository';
import { NotiType } from '@modules/notification/domain/notification.entity';
import { NotificationService } from '@modules/notification/applications/notification.service';

/**
 * 경주 알림 오케스트레이션 (S5-1) — 이벤트 payload(roomId)로 대상 유저를 로드해 NotificationService에 위임.
 *
 * 구독 핸들러(ParticipantJoined·RoomStarting·RaceFinished)와 리마인더 지연잡이 공유하는 방 로딩 로직을 한곳에 모은다.
 * 모든 발송은 멱등(dedupeKey) — 중복 이벤트/리마인더에도 1건만 저장·발송된다.
 */
@Injectable()
export class RaceNotificationService {
  constructor(
    private readonly roomRepository: RoomRepository,
    private readonly raceRepository: RaceRepository,
    private readonly notificationService: NotificationService
  ) {}

  /** 새 참가자 입장 → 방장에게. */
  async notifyParticipantJoined(roomId: number, joinerUserId: number): Promise<void> {
    const [room] = await this.roomRepository.find({ id: roomId });
    if (!room) return;
    if (room.hostUserId === joinerUserId) return; // 방장 자신은 알리지 않음

    await this.notificationService.notify({
      userIds: [room.hostUserId],
      type: NotiType.PARTICIPANT_JOINED,
      roomId,
      title: '새 참가자 입장',
      body: '내 방에 새 러너가 참가했어요.',
      payload: { roomId, joinerUserId },
    });
  }

  /** 경주 임박(RoomStarting, T-10s) → 참가자 전원에게 "곧 시작". */
  async notifyRaceStarting(roomId: number): Promise<void> {
    const [room] = await this.roomRepository.find({ id: roomId }, { relations: { participants: true } });
    if (!room) return;

    const userIds = room.participants.map((p) => p.userId);
    if (userIds.length === 0) return;

    await this.notificationService.notify({
      userIds,
      type: NotiType.RACE_STARTING,
      roomId,
      title: '곧 시작해요',
      body: '경주가 곧 시작됩니다. 준비하세요!',
      payload: { roomId },
    });
  }

  /** 결과 도착(RaceFinished) → 참가 러너 전원에게. */
  async notifyResultReady(roomId: number): Promise<void> {
    const [race] = await this.raceRepository.find({ roomId }, { relations: { runners: true } });
    if (!race) return;

    const userIds = race.runners.map((r) => r.userId);
    if (userIds.length === 0) return;

    await this.notificationService.notify({
      userIds,
      type: NotiType.RESULT_READY,
      roomId,
      title: '경주 결과 도착',
      body: '경주가 끝났어요. 결과를 확인하세요!',
      payload: { roomId, raceId: race.id },
    });
  }
}
