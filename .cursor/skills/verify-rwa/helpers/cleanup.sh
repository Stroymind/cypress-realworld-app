#!/usr/bin/env bash
# Stop only the tmux session and PIDs recorded by launch.sh for this run.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
RUN_ID="${VERIFY_RWA_RUN_ID:?Set VERIFY_RWA_RUN_ID}"
STATE="/tmp/verify-rwa-${RUN_ID}"
HELPER_DIR="$(cd "$(dirname "$0")" && pwd)"
TMUX_CONF="/exec-daemon/tmux.portal.conf"
if [[ -f "$TMUX_CONF" ]]; then
  TMUX=(tmux -f "$TMUX_CONF")
else
  TMUX=(tmux)
fi
echo "command=cleanup.sh"
echo "run_id=$RUN_ID"
if [[ ! -f "$STATE/identity.env" ]]; then
  echo "cleanup_exit=2"
  echo "reason=no launch state for $RUN_ID; nothing of ours to stop"
  exit 2
fi
# shellcheck disable=SC1090
. "$STATE/identity.env"
if "${TMUX[@]}" has-session -t "=$session" 2>/dev/null; then
  "${TMUX[@]}" kill-session -t "$session"
  echo "kill_session_exit=$?"
else
  echo "kill_session_exit=absent"
fi
if [[ -f "$STATE/pgid" ]]; then
  pgid="$(tr -cd '0-9' < "$STATE/pgid")"
  if [[ "$pgid" =~ ^[0-9]+$ && "$pgid" -gt 1 ]]; then
    if ps -o pgid= -p "$pgid" >/dev/null 2>&1 || pgrep -g "$pgid" >/dev/null 2>&1; then
      echo "term_own_pgid=$pgid"
      kill -TERM -- "-$pgid" 2>/dev/null || true
      sleep 1
      if pgrep -g "$pgid" >/dev/null 2>&1; then
        echo "kill_own_pgid=$pgid"
        kill -KILL -- "-$pgid" 2>/dev/null || true
      fi
    else
      echo "pgid_absent=$pgid"
    fi
  fi
fi
sleep 1
if [[ -f "$STATE/pids.txt" ]]; then
  while read -r pid; do
    [[ -n "$pid" && -d "/proc/$pid" ]] || continue
    echo "term_own_pid=$pid"
    kill -TERM "$pid" 2>/dev/null || true
  done < "$STATE/pids.txt"
  sleep 1
  while read -r pid; do
    [[ -n "$pid" && -d "/proc/$pid" ]] || continue
    echo "kill_own_pid=$pid"
    kill -KILL "$pid" 2>/dev/null || true
  done < "$STATE/pids.txt"
  sleep 1
fi
alive=0
if [[ -f "$STATE/pids.txt" ]]; then
  while read -r pid; do
    if [[ -n "$pid" && -d "/proc/$pid" ]]; then
      echo "still_alive=$pid"
      alive=1
    fi
  done < "$STATE/pids.txt"
fi
python3 "$HELPER_DIR/port_owners.py" | tee "$STATE/owners-cleanup.txt"
python3 - <<PY
import pathlib, sys
state = pathlib.Path("$STATE")
owned = set()
pid_file = state / "pids.txt"
if pid_file.exists():
    owned = {int(line) for line in pid_file.read_text().split() if line.isdigit()}
text = (state / "owners-cleanup.txt").read_text().strip().splitlines()
foreign = False
ours = False
for line in text:
    if not line.strip():
        continue
    port_s, pid_s, addr = line.split(maxsplit=2)
    pid = None if pid_s == "-" else int(pid_s)
    if pid in owned:
        print(f"own_listener_remains port={port_s} pid={pid_s}")
        ours = True
    else:
        print(f"unrelated_listener port={port_s} pid={pid_s} addr={addr}")
        foreign = True
if not text:
    print("listeners=none")
sys.exit(3 if ours else 4 if foreign else 0)
PY
ports_exit=$?
if [[ -f "$STATE/database.json.before" ]]; then
  if cmp -s "$STATE/database.json.before" "$ROOT/data/database.json"; then
    echo "database_restore=unchanged"
  else
    cp -a "$STATE/database.json.before" "$ROOT/data/database.json"
    echo "database_restore=restored_pre_launch_bytes"
  fi
fi
echo "evidence_dir=$ROOT/.cursor/skills/verify-rwa/evidence/$RUN_ID"
if [[ "$alive" -ne 0 || "$ports_exit" -ne 0 ]]; then
  echo "cleanup_exit=1"
  exit 1
fi
echo "cleanup_exit=0"
exit 0
