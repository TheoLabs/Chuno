# 추노 (Chuno)

러너들끼리 경쟁하는 러닝 경주 매칭 서비스.

## 모노레포 구조

```
Chuno/
├─ apps/
│  ├─ core-api/      # NestJS 백엔드
│  └─ chuno-mobile/  # Flutter 앱 (iOS / Android)
├─ pnpm-workspace.yaml
└─ package.json
```

Flutter(Dart)는 JS 워크스페이스에 포함되지 않으며 디렉토리 기반으로 함께 관리됩니다.

## 시작하기

```bash
# JS 의존성 설치 (core-api)
pnpm install

# core-api 개발 서버
pnpm api:dev

# Flutter 앱 실행
pnpm app:run
```
