import '../models.dart';
import '../theme/app_theme.dart';

/// MVP 스캐폴딩용 mock 데이터. 추후 core-api 실연동으로 교체.
class Mock {
  static const rooms = <Room>[
    Room(name: '🏃 5km 새벽 추격', targetKm: 5.0, limitMin: 40, cur: 3, max: 6, startInfo: '06:00 시작', countdown: '12분 후', status: RoomStatus.soon),
    Room(name: '🏃 10km 챌린지', targetKm: 10.0, limitMin: 70, cur: 2, max: 8, startInfo: '07:30 시작', status: RoomStatus.open),
    Room(name: '🏃 3km 스프린트', targetKm: 3.0, limitMin: 20, cur: 4, max: 4, startInfo: '진행 중 · 관전 가능', status: RoomStatus.live),
  ];

  static final lobby = <Participant>[
    Participant('나', AppColors.coral, isMe: true, host: true),
    Participant('준호', AppColors.a3),
    Participant('민지', AppColors.a5),
  ];

  static List<RaceRunner> raceRunners() => [
        RaceRunner(id: 'me', name: '나', color: AppColors.coral, base: .058, isMe: true, km: 3.20),
        RaceRunner(id: 'j', name: '준호', color: AppColors.a3, base: .055, km: 3.05),
        RaceRunner(id: 'm', name: '민지', color: AppColors.a5, base: .050, km: 2.70),
        RaceRunner(id: 's', name: '서연', color: AppColors.a4, base: .044, km: 2.10),
      ];
}
