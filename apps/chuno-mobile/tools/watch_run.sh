#!/usr/bin/env bash
# 저장 시 완전 자동 반영. lib/의 .dart 가 바뀌면:
#   1) SIGUSR1(핫 리로드) 시도
#   2) flutter 가 리로드를 거부하면(=const/구조 변경) 자동으로 SIGUSR2(핫 리스타트)
# → 손으로 R 누를 필요 없음. 종료는 Ctrl-C.
#
# 참고: 출력을 캡처하려고 파이프로 실행하므로 인터랙티브 키(r/R/q)는 비활성.
#       대신 저장이 전부 자동 반영되고, 멈출 땐 Ctrl-C.
set -uo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

PIDFILE="$(mktemp -t chuno_flutter.XXXXXX)"
LOG="$(mktemp -t chuno_log.XXXXXX)"
WATCH_PID=""
cleanup() {
  [ -n "$WATCH_PID" ] && kill "$WATCH_PID" 2>/dev/null
  rm -f "$PIDFILE" "$LOG"
}
trap cleanup EXIT INT TERM

# lib/ 안 .dart 최신 수정시각(epoch). BSD(macOS) 우선, GNU fallback.
mtime_sig() {
  find lib -name '*.dart' -type f -exec stat -f '%m' {} + 2>/dev/null \
    || find lib -name '*.dart' -type f -exec stat -c '%Y' {} + 2>/dev/null
}

(
  while [ ! -s "$PIDFILE" ]; do sleep 0.5; done
  echo "👀 저장 감시 시작 — 리로드 실패 시 자동 리스타트까지 처리"
  last="$(mtime_sig | sort -n | tail -1)"
  while kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; do
    sleep 1
    cur="$(mtime_sig | sort -n | tail -1)"
    [ -n "$cur" ] && [ "$cur" != "$last" ] || continue
    last="$cur"
    pid="$(cat "$PIDFILE" 2>/dev/null)"; [ -n "$pid" ] || continue
    before="$(wc -l < "$LOG" 2>/dev/null || echo 0)"
    kill -USR1 "$pid" 2>/dev/null && echo "🔁 hot reload $(date +%H:%M:%S)"
    # 리로드 결과 확인 → 거부되면 자동 리스타트
    for _ in 1 2 3 4 5 6 7 8; do
      sleep 0.4
      new="$(tail -n "+$((before + 1))" "$LOG" 2>/dev/null)"
      if printf '%s' "$new" | grep -qiE 'reload was rejected|hot restart instead|not reloaded'; then
        kill -USR2 "$pid" 2>/dev/null && echo "↻ 구조 변경 감지 → hot restart"
        break
      fi
      printf '%s' "$new" | grep -qiE 'Reloaded|Restarted application' && break
    done
  done
) &
WATCH_PID=$!

echo "▶ flutter run 시작… (저장=자동 반영 / 종료=Ctrl-C)"
flutter run --pid-file "$PIDFILE" "$@" 2>&1 | tee "$LOG"
