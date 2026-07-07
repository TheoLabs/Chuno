import { Room } from './room.entity';
import { Participant } from './participant.entity';
import { CalendarDate } from '@libs/types';
import { ParticipantJoined, ParticipantLeft, RoomCancelled, RoomLive, RoomStarting } from './events/room.events';

/**
 * S2-5 — Room 애그리거트가 상태 변화 시 도메인 이벤트를 수집(publishEvent)하는지 검증(순수 도메인).
 * 커밋 후 인프로세스 발행(BullMQ)은 @Transactional + BullDomainEventPublisher가 담당(별도).
 */
describe('Room 도메인 이벤트 (S2-5)', () => {
  const makeRoom = (id = 1, hostUserId = 10): Room => {
    const room = Room.of({
      name: '테스트방',
      hostUserId,
      targetDistance: 5,
      limitMinutes: 30,
      maxParticipants: 4,
      scheduledStartOn: '2999-01-01 00:00:00' as CalendarDate,
      participant: Participant.of({ userId: hostUserId, isHost: true }),
    });
    // DB가 부여하는 PK를 테스트에서 주입(이벤트 payload의 roomId 검증용).
    (room as unknown as { id: number }).id = id;
    return room;
  };

  it('생성 시엔 이벤트를 발행하지 않는다(RoomCreated는 정의만)', () => {
    expect(makeRoom().getPublishedEvents()).toHaveLength(0);
  });

  it('join → ParticipantJoined(roomId, userId) 수집', () => {
    const room = makeRoom(1, 10);
    room.join({ userId: 20 });

    const events = room.getPublishedEvents();
    expect(events).toHaveLength(1);
    expect(events[0]).toBeInstanceOf(ParticipantJoined);
    expect(events[0]).toMatchObject({ roomId: 1, userId: 20 });
  });

  it('비호스트 leave → ParticipantLeft(roomId, userId) 수집', () => {
    const room = makeRoom(1, 10);
    room.join({ userId: 20 });
    room.leave({ userId: 20 });

    const last = room.getPublishedEvents().at(-1);
    expect(last).toBeInstanceOf(ParticipantLeft);
    expect(last).toMatchObject({ roomId: 1, userId: 20 });
  });

  it('cancel → RoomCancelled(roomId, hostUserId) 수집', () => {
    const room = makeRoom(1, 10);
    room.cancel({ userId: 10 });

    const last = room.getPublishedEvents().at(-1);
    expect(last).toBeInstanceOf(RoomCancelled);
    expect(last).toMatchObject({ roomId: 1, hostUserId: 10 });
  });

  it('호스트 leave → 취소로 이어져 RoomCancelled 수집', () => {
    const room = makeRoom(1, 10);
    room.leave({ userId: 10 });

    expect(room.status).toBe('cancelled');
    expect(room.getPublishedEvents().some((e) => e instanceof RoomCancelled)).toBe(true);
  });
});

/** S2-3 — 예약 전환(markStarting/markLive)의 상태 머신·멱등·2명 미만 취소. */
describe('Room 예약 전환 (S2-3)', () => {
  const makeRoom = (hostUserId = 10): Room => {
    const room = Room.of({
      name: '테스트방',
      hostUserId,
      targetDistance: 5,
      limitMinutes: 30,
      maxParticipants: 4,
      scheduledStartOn: '2999-01-01 00:00:00' as CalendarDate,
      participant: Participant.of({ userId: hostUserId, isHost: true }),
    });
    (room as unknown as { id: number }).id = 1;
    return room;
  };

  it('markStarting: 2명 이상 → STARTING + RoomStarting', () => {
    const room = makeRoom();
    room.join({ userId: 20 });
    room.markStarting();

    expect(room.status).toBe('starting');
    expect(room.getPublishedEvents().at(-1)).toBeInstanceOf(RoomStarting);
  });

  it('markStarting: 2명 미만(호스트만) → CANCELLED + RoomCancelled (STARTING 아님)', () => {
    const room = makeRoom();
    room.markStarting();

    expect(room.status).toBe('cancelled');
    expect(room.getPublishedEvents().at(-1)).toBeInstanceOf(RoomCancelled);
  });

  it('markStarting 멱등: 이미 STARTING이면 재호출해도 이벤트 미추가', () => {
    const room = makeRoom();
    room.join({ userId: 20 });
    room.markStarting();
    const count = room.getPublishedEvents().length;
    room.markStarting(); // 재시작/중복 잡 시뮬레이션

    expect(room.status).toBe('starting');
    expect(room.getPublishedEvents().length).toBe(count);
  });

  it('markLive: STARTING → LIVE + RoomLive', () => {
    const room = makeRoom();
    room.join({ userId: 20 });
    room.markStarting();
    room.markLive();

    expect(room.status).toBe('live');
    expect(room.getPublishedEvents().at(-1)).toBeInstanceOf(RoomLive);
  });

  it('markLive 멱등: STARTING이 아니면(RECRUITING) no-op', () => {
    const room = makeRoom();
    room.markLive(); // 아직 RECRUITING

    expect(room.status).toBe('recruiting');
    expect(room.getPublishedEvents().some((e) => e instanceof RoomLive)).toBe(false);
  });
});
