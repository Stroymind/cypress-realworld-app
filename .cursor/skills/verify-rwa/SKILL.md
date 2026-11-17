---
name: verify-rwa
description: Launch and drive the Cypress Real World App web UI with its existing Cypress harness. Use to prove local sign-in behavior, capture screenshots and command logs, and stop only the servers this run started.
---

# Verify the Cypress Real World App

The user-facing surface is the React app on port 3000, backed by the Express API on port 3001. Drive it with the repo's Cypress harness (`cypress/support/commands.ts`) and the feature map in `features/`. This skill was generated from the vendored `create-verification-skill` workflow and proved once against invalid sign-in.

Proof artifacts live in `.cursor/skills/verify-rwa/evidence/<VERIFY_RWA_RUN_ID>/` and must remain after cleanup. Runtime identity lives in `/tmp/verify-rwa-<VERIFY_RWA_RUN_ID>/`.

## Launch

From the repository root, with `VERIFY_RWA_RUN_ID` set to a token of letters, numbers, `.`, `_`, or `-`:

```bash
export VERIFY_RWA_RUN_ID=proof-auth-001
bash .cursor/skills/verify-rwa/helpers/launch.sh
echo "launch_exit=$?"
```

`launch.sh` does all of the following:

1. Copy `data/database.json` to `/tmp/verify-rwa-$VERIFY_RWA_RUN_ID/database.json.before` before the app rewrites it.
2. `nvm install 22.20.0` and `nvm use 22.20.0` (`.node-version` and `.nvmrc`). Put `$HOME/.nvm/versions/node/v22.20.0/bin` first on `PATH`. The default `node` on this image can be a different 22.x build.
3. Require `node -v` `v22.20.0` and `yarn -v` `1.22.22` (Yarn Classic, `package.json` `packageManager`).
4. `yarn install --frozen-lockfile`.
5. Refuse to start when `helpers/port_owners.py` already sees a listener on 3000 or 3001.
6. Start `yarn dev` in tmux session `verify-rwa-$VERIFY_RWA_RUN_ID`. `yarn dev` runs `predev`, which copies `data/database-seed.json` onto `data/database.json` and copies the mock AWS export files. Those AWS files are gitignored.
7. Record the tmux pane PID and its descendants in `/tmp/verify-rwa-$VERIFY_RWA_RUN_ID/pids.txt`, plus cwd, `HEAD`, and origin in `identity.env`.

Ready means both of these HTTP checks pass within 90 seconds:

- `http://localhost:3000/` returns HTTP 200 and an HTML document whose body contains `<!doctype html`.
- `http://localhost:3001/` returns HTTP 200 and the body `Cypress Realworld App - backend`.

`localhost` on this image resolves to `::1`. Vite listens on `[::1]:3000`. `http://127.0.0.1:3000/` is connection refused and is not the readiness check. The API listens on `:::3001` and answers on both `localhost` and `127.0.0.1`.

Seed data is the committed `data/database-seed.json`. The dev script reseeds `data/database.json` on startup. Cypress `cy.task("db:seed")` reseeds again through `POST http://localhost:3001/testData/seed`. The default password for seeded users is `s3cret` (README and `cypress/tests/ui/auth.spec.ts`).

`launch.sh` prints `launch_exit=0` on success. Any other `launch_exit` means the app is not ready to drive. Run cleanup anyway.

## Doctor

```bash
export VERIFY_RWA_RUN_ID=proof-auth-001
bash .cursor/skills/verify-rwa/helpers/doctor.sh
echo "doctor_exit=$?"
```

Doctor is read-only. It passes only when every check below is true:

- `/tmp/verify-rwa-$VERIFY_RWA_RUN_ID/identity.env` exists and its `cwd` is the live repository root.
- `git rev-parse HEAD` equals the commit recorded at launch.
- `origin` contains `Stroymind/cypress-realworld-app` and does not contain `cypress-io/cypress-realworld-app`.
- tmux session `verify-rwa-$VERIFY_RWA_RUN_ID` exists.
- `/tmp/verify-rwa-$VERIFY_RWA_RUN_ID/dev.log` contains `node_version=v22.20.0`.
- Ports 3000 and 3001 each have a listener, and every listener PID is in `pids.txt`.

`doctor_exit=0` is the only result that may be driven. Any other result means refuse: do not start Cypress and do not kill the unrelated listener.

## Drive

Drive the authentication map entry `auth-invalid-credentials` with the existing Cypress commands (`cy.login`, `cy.getBySel`, `cy.database`, `cy.task("db:seed")`). The helper spec repeats the two invalid-credential assertions from `cypress/tests/ui/auth.spec.ts` and does not change that file.

```bash
export VERIFY_RWA_RUN_ID=proof-auth-001
bash .cursor/skills/verify-rwa/helpers/drive.sh
echo "drive_exit=$?"
```

`drive.sh` runs doctor first. When doctor exits non-zero it does not start Cypress and exits 1. Otherwise it runs:

```bash
yarn cypress:run \
  --spec .cursor/skills/verify-rwa/helpers/invalid-credentials.cy.ts \
  --config "screenshotsFolder=.cursor/skills/verify-rwa/evidence/$VERIFY_RWA_RUN_ID/screenshots,specPattern=.cursor/skills/verify-rwa/helpers/invalid-credentials.cy.ts"
```

wrapped in `timeout -k 20s 900s`. Expected assertions, both `have.text` (the whole string):

- Unknown user `invalidUserName` / `invalidPa$$word` shows `[data-test=signin-error]` with `Username or password is invalid`.
- A seeded user's username with password `INVALID` shows the same `[data-test=signin-error]` text.

Screenshots are `invalid-user-error` and `invalid-password-error`. Cypress stdout is `evidence/$VERIFY_RWA_RUN_ID/cypress.log`. Numeric exits are appended to `evidence/$VERIFY_RWA_RUN_ID/commands.log`.

## Evidence

Keep this directory after cleanup:

`.cursor/skills/verify-rwa/evidence/<VERIFY_RWA_RUN_ID>/`

It should contain `commands.log`, `cypress.log`, and `screenshots/`. Also keep `/tmp/verify-rwa-<VERIFY_RWA_RUN_ID>/launch.log`, `dev.log`, `identity.env`, and `pids.txt` until the proof is copied into the evidence directory if you need them in git. The proof standard for this run is the real sign-in form: type credentials, submit, and read the alert the app renders. Do not satisfy it by setting auth state in memory.

## Cleanup

```bash
export VERIFY_RWA_RUN_ID=proof-auth-001
bash .cursor/skills/verify-rwa/helpers/cleanup.sh
echo "cleanup_exit=$?"
```

Cleanup stops tmux session `verify-rwa-$VERIFY_RWA_RUN_ID` and then signals only PIDs listed in that run's `pids.txt`. It does not kill by process name and does not kill a listener whose PID is absent from `pids.txt`. It restores `data/database.json` from the pre-launch snapshot when the bytes differ, so a reseed does not drop an unrelated working-tree change. It does not delete `evidence/`.

After cleanup, `port_owners.py` should print nothing and none of the recorded PIDs should remain. `cleanup_exit=0` means that. `cleanup_exit=1` means one of our processes or an unrelated listener was still present; the unrelated listener is reported and left running.

Run cleanup after a failed launch or drive too.

## Helpers

| Helper | Invocation |
| --- | --- |
| `helpers/launch.sh` | `VERIFY_RWA_RUN_ID=... bash .cursor/skills/verify-rwa/helpers/launch.sh` |
| `helpers/doctor.sh` | `VERIFY_RWA_RUN_ID=... bash .cursor/skills/verify-rwa/helpers/doctor.sh` |
| `helpers/drive.sh` | `VERIFY_RWA_RUN_ID=... bash .cursor/skills/verify-rwa/helpers/drive.sh` |
| `helpers/cleanup.sh` | `VERIFY_RWA_RUN_ID=... bash .cursor/skills/verify-rwa/helpers/cleanup.sh` |
| `helpers/port_owners.py` | `python3 .cursor/skills/verify-rwa/helpers/port_owners.py` |
| `helpers/invalid-credentials.cy.ts` | passed to `yarn cypress:run --spec` by `drive.sh` |

## Maintenance

When the app changes, use `/maintain-verification-skill` to keep this map aligned with the source. That skill is not vendored in this repo.
