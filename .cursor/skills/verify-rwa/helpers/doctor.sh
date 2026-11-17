#!/usr/bin/env bash
# Read-only check that the running app belongs to this verification run.
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
echo "command=doctor.sh"
echo "run_id=$RUN_ID"
if [[ ! -f "$STATE/identity.env" || ! -f "$STATE/pids.txt" ]]; then
  echo "doctor_exit=2"
  echo "reason=missing launch identity for $RUN_ID"
  exit 2
fi
# shellcheck disable=SC1090
. "$STATE/identity.env"
live_cwd="$(pwd)"
live_commit="$(git rev-parse HEAD)"
live_origin="$(git config --get remote.origin.url || true)"
case "$live_origin" in
  *x-access-token*|*ghp_*|*github_pat*)
    live_origin="https://github.com/Stroymind/cypress-realworld-app"
    ;;
esac
echo "expected_cwd=$cwd"
echo "live_cwd=$live_cwd"
echo "expected_commit=$commit"
echo "live_commit=$live_commit"
echo "expected_origin=$origin"
echo "live_origin=$live_origin"
echo "expected_session=$session"
fail=0
if [[ "$live_cwd" != "$cwd" ]]; then
  echo "reason=cwd does not match the launch identity"
  fail=1
fi
if [[ "$live_commit" != "$commit" ]]; then
  echo "reason=HEAD does not match the launch identity"
  fail=1
fi
case "$live_origin" in
  *Stroymind/cypress-realworld-app*) ;;
  *)
    echo "reason=origin is not Stroymind/cypress-realworld-app"
    fail=1
    ;;
esac
case "$live_origin" in
  *cypress-io/cypress-realworld-app*)
    echo "reason=origin points at upstream"
    fail=1
    ;;
esac
if ! "${TMUX[@]}" has-session -t "=$session" 2>/dev/null; then
  echo "reason=tmux session $session is not running"
  fail=1
fi
if [[ ! -f "$STATE/dev.log" ]] || ! grep -q 'node_version=v22.20.0' "$STATE/dev.log"; then
  echo "reason=dev log does not show Node v22.20.0"
  fail=1
fi

python3 "$HELPER_DIR/port_owners.py" | tee "$STATE/owners-doctor.txt"
python3 - <<PY
import pathlib, sys
state = pathlib.Path("$STATE")
owned = {int(line) for line in state.joinpath("pids.txt").read_text().split() if line.isdigit()}
text = state.joinpath("owners-doctor.txt").read_text().strip().splitlines()
by_port = {3000: [], 3001: []}
for line in text:
    if not line.strip():
        continue
    port_s, pid_s, addr = line.split(maxsplit=2)
    port = int(port_s)
    pid = None if pid_s == "-" else int(pid_s)
    by_port[port].append((pid, addr))
    if pid is None or pid not in owned:
        print(f"reason=port {port} listener pid {pid_s} addr {addr} is not owned by run $RUN_ID")
        sys.exit(3)
for port in (3000, 3001):
    if not by_port[port]:
        print(f"reason=port {port} has no listener")
        sys.exit(4)
print("port_owners=match")
PY
owner_exit=$?
if [[ "$owner_exit" -ne 0 ]]; then
  fail=1
fi
if [[ "$fail" -ne 0 ]]; then
  echo "doctor_exit=1"
  echo "reason=refusing to drive this instance"
  exit 1
fi
echo "doctor_exit=0"
exit 0
