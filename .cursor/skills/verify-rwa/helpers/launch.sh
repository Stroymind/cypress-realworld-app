#!/usr/bin/env bash
# Start the Cypress Real World App for one verification run.
# Refuses to start when port 3000 or 3001 is already listening.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
RUN_ID="${VERIFY_RWA_RUN_ID:?Set VERIFY_RWA_RUN_ID}"
STATE="/tmp/verify-rwa-${RUN_ID}"
TMUX_CONF="/exec-daemon/tmux.portal.conf"
SESSION="verify-rwa-${RUN_ID}"
HELPER_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$STATE"
LOG="$STATE/launch.log"
exec > >(tee -a "$LOG") 2>&1
echo "started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "command=launch.sh"
echo "root=$ROOT"
echo "run_id=$RUN_ID"

if [[ ! "$RUN_ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "launch_exit=2"
  echo "reason=RUN_ID must be alphanumeric, dot, underscore, or dash"
  exit 2
fi

cp -a "$ROOT/data/database.json" "$STATE/database.json.before"
echo "database_snapshot=$STATE/database.json.before"

# shellcheck disable=SC1091
set +u
. "$HOME/.nvm/nvm.sh"
nvm install 22.20.0
nvm_install_exit=$?
nvm use 22.20.0
nvm_use_exit=$?
set -u
export PATH="$HOME/.nvm/versions/node/v22.20.0/bin:$PATH"
hash -r
echo "nvm_install_exit=$nvm_install_exit"
echo "nvm_use_exit=$nvm_use_exit"
echo "node_path=$(command -v node)"
echo "node_version=$(node -v)"
echo "yarn_path=$(command -v yarn)"
echo "yarn_version=$(yarn -v)"
if [[ "$(node -v)" != "v22.20.0" || "$(yarn -v)" != "1.22.22" ]]; then
  echo "launch_exit=3"
  echo "reason=required Node v22.20.0 and Yarn 1.22.22"
  exit 3
fi

echo "command=yarn install --frozen-lockfile"
yarn install --frozen-lockfile
yarn_install_exit=$?
echo "yarn_install_exit=$yarn_install_exit"
if [[ "$yarn_install_exit" -ne 0 ]]; then
  echo "launch_exit=$yarn_install_exit"
  exit "$yarn_install_exit"
fi

if [[ -s "$STATE/owners-before.txt" ]]; then
  rm -f "$STATE/owners-before.txt"
fi
python3 "$HELPER_DIR/port_owners.py" | tee "$STATE/owners-before.txt"
if [[ -s "$STATE/owners-before.txt" ]]; then
  echo "launch_exit=4"
  echo "reason=port 3000 or 3001 is already listening; refusing to start another instance"
  exit 4
fi

ORIGIN_URL="$(git config --get remote.origin.url || true)"
case "$ORIGIN_URL" in
  *x-access-token*|*ghp_*|*github_pat*)
    ORIGIN_URL="https://github.com/Stroymind/cypress-realworld-app"
    ;;
esac
COMMIT="$(git rev-parse HEAD)"
{
  echo "run_id=$RUN_ID"
  echo "cwd=$ROOT"
  echo "commit=$COMMIT"
  echo "origin=$ORIGIN_URL"
  echo "session=$SESSION"
  echo "node_version=$(node -v)"
  echo "yarn_version=$(yarn -v)"
} > "$STATE/identity.env"

cat > "$STATE/start-dev.sh" <<EOF
#!/usr/bin/env bash
export PATH="$HOME/.nvm/versions/node/v22.20.0/bin:\$PATH"
hash -r
cd "$ROOT"
{
  echo "started_at=\$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "node_path=\$(command -v node)"
  echo "node_version=\$(node -v)"
  echo "yarn_version=\$(yarn -v)"
  echo "shell_pid=\$\$"
} | tee "$STATE/dev.log"
yarn dev 2>&1 | tee -a "$STATE/dev.log"
echo "YARN_DEV_EXIT:\${PIPESTATUS[0]}" | tee -a "$STATE/dev.log"
EOF
chmod +x "$STATE/start-dev.sh"

if [[ -f /exec-daemon/tmux.portal.conf ]]; then
  TMUX=(tmux -f "$TMUX_CONF")
else
  TMUX=(tmux)
fi
if "${TMUX[@]}" has-session -t "=$SESSION" 2>/dev/null; then
  echo "launch_exit=5"
  echo "reason=tmux session $SESSION already exists"
  exit 5
fi
"${TMUX[@]}" new-session -d -s "$SESSION" -c "$ROOT" -- bash -l
echo "tmux_new_exit=$?"
"${TMUX[@]}" send-keys -t "$SESSION:0.0" "bash '$STATE/start-dev.sh'" C-m
echo "tmux_send_exit=$?"

ready=0
start_epoch=$(date +%s)
while true; do
  fe_code=$(curl -sS -o "$STATE/fe.body" -w "%{http_code}" --max-time 3 http://localhost:3000/ 2>"$STATE/fe.err" || true)
  api_code=$(curl -sS -o "$STATE/api.body" -w "%{http_code}" --max-time 3 http://localhost:3001/ 2>"$STATE/api.err" || true)
  echo "probe frontend_http=$fe_code api_http=$api_code"
  fe_ok=0
  api_ok=0
  if [[ "$fe_code" == "200" ]] && grep -qi '<!doctype html' "$STATE/fe.body"; then
    fe_ok=1
  fi
  if [[ "$api_code" == "200" ]] && [[ "$(cat "$STATE/api.body")" == "Cypress Realworld App - backend" ]]; then
    api_ok=1
  fi
  if [[ "$fe_ok" -eq 1 && "$api_ok" -eq 1 ]]; then
    ready=1
    echo "ready=1"
    break
  fi
  now=$(date +%s)
  if (( now - start_epoch >= 90 )); then
    echo "ready=0"
    echo "reason=readiness timeout after 90s"
    break
  fi
  sleep 2
done

python3 - <<PY
import os, sys
state = "$STATE"
roots = set()
pane = os.popen("tmux -f '$TMUX_CONF' list-panes -t '$SESSION' -F '#{pane_pid}' 2>/dev/null").read().strip()
if pane.isdigit():
    roots.add(int(pane))
procs = {}
for name in os.listdir("/proc"):
    if not name.isdigit():
        continue
    pid = int(name)
    try:
        data = open(f"/proc/{pid}/stat").read()
        rest = data[data.rfind(")") + 2 :].split()
        procs[pid] = int(rest[1])
    except (OSError, IndexError, ValueError):
        continue
wanted = set(roots)
changed = True
while changed:
    changed = False
    for pid, ppid in procs.items():
        if pid not in wanted and ppid in wanted:
            wanted.add(pid)
            changed = True
if not wanted:
    print("recorded_pids 0", file=sys.stderr)
    sys.exit(7)
with open(os.path.join(state, "pids.txt"), "w") as handle:
    for pid in sorted(wanted):
        handle.write(f"{pid}\n")
print("recorded_pids", len(wanted))
PY
record_exit=$?
if [[ -f "$STATE/dev.log" ]]; then
  shell_pid="$(awk -F= '/^shell_pid=/{print $2}' "$STATE/dev.log" | head -n 1)"
  if [[ "$shell_pid" =~ ^[0-9]+$ ]]; then
    echo "$shell_pid" > "$STATE/pgid"
    echo "recorded_pgid=$shell_pid"
  fi
fi
echo "record_pids_exit=$record_exit"
if [[ "$record_exit" -ne 0 ]]; then
  echo "launch_exit=$record_exit"
  exit "$record_exit"
fi

python3 "$HELPER_DIR/port_owners.py" | tee "$STATE/owners-after.txt"
echo "finished_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [[ "$ready" -ne 1 ]]; then
  echo "launch_exit=6"
  exit 6
fi
echo "launch_exit=0"
exit 0
