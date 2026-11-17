#!/usr/bin/env bash
# Drive invalid-credentials through the existing Cypress harness.
# Does not start if doctor refuses the running instance.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
RUN_ID="${VERIFY_RWA_RUN_ID:?Set VERIFY_RWA_RUN_ID}"
STATE="/tmp/verify-rwa-${RUN_ID}"
EVIDENCE="$ROOT/.cursor/skills/verify-rwa/evidence/${RUN_ID}"
mkdir -p "$EVIDENCE"
export PATH="$HOME/.nvm/versions/node/v22.20.0/bin:$PATH"
hash -r
echo "command=doctor.sh" | tee "$EVIDENCE/commands.log"
bash "$(dirname "$0")/doctor.sh" | tee -a "$EVIDENCE/commands.log" "$STATE/doctor.log"
doctor_exit=${PIPESTATUS[0]}
echo "doctor_exit=$doctor_exit" | tee -a "$EVIDENCE/commands.log"
if [[ "$doctor_exit" -ne 0 ]]; then
  echo "drive_exit=1" | tee -a "$EVIDENCE/commands.log"
  echo "reason=doctor refused; Cypress was not started" | tee -a "$EVIDENCE/commands.log"
  exit 1
fi
SPEC=".cursor/skills/verify-rwa/helpers/invalid-credentials.cy.ts"
echo "command=yarn cypress:run --spec $SPEC" | tee -a "$EVIDENCE/commands.log"
echo "node_version=$(node -v)" | tee -a "$EVIDENCE/commands.log"
echo "yarn_version=$(yarn -v)" | tee -a "$EVIDENCE/commands.log"
set +e
timeout -k 20s 900s yarn cypress:run \
  --spec "$SPEC" \
  --config "screenshotsFolder=${EVIDENCE}/screenshots,specPattern=${SPEC}" \
  > "$EVIDENCE/cypress.log" 2>&1
cypress_exit=$?
set -e
echo "cypress_exit=$cypress_exit" | tee -a "$EVIDENCE/commands.log"
if [[ "$cypress_exit" -eq 124 || "$cypress_exit" -eq 137 ]]; then
  echo "reason=Cypress did not finish before the 900s bound" | tee -a "$EVIDENCE/commands.log"
fi
echo "drive_exit=$cypress_exit" | tee -a "$EVIDENCE/commands.log"
exit "$cypress_exit"
