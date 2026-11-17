# Authentication

A visitor who is not signed in is sent to the sign-in page. Submitting a username and password that the API rejects shows an error alert on that form. Source: `cypress/tests/ui/auth.spec.ts`, `cypress/support/commands.ts` (`login`), `src/components/SignInForm.tsx`, and `src/machines/authMachine.ts` (`performLogin`).

## Sub-features

- `auth-redirect` sends an unauthenticated visit of `/personal` to `/signin`.
- `auth-invalid-credentials` shows the invalid username or password error. This is the entry the skill executes.
- `auth-field-errors` shows required-field and short-password helper text and disables submit.
- `auth-signout` returns a signed-in user to `/signin` from `sidenav-signout`.

## How to get to it (user POV)

- Open `http://localhost:3000/`. The home route renders the sign-in form when no session exists (`cy.visit("/")` in the invalid-user test).
- Open `http://localhost:3000/signin`.
- Open `http://localhost:3000/personal` while signed out. The app changes the path to `/signin`.
- Choose `Don't have an account? Sign Up` (`data-test="signup"`) only when leaving for sign-up. That is a different feature.

## Driving it with Cypress

Preconditions:

- `doctor.sh` printed `doctor_exit=0` for this `VERIFY_RWA_RUN_ID`.
- Frontend `http://localhost:3000/` is the HTML app and `http://localhost:3001/` body is `Cypress Realworld App - backend`.
- `cy.task("db:seed")` can reseed from the running API.

- **Unknown user.** Run `bash .cursor/skills/verify-rwa/helpers/drive.sh`. The helper spec calls `cy.login("invalidUserName", "invalidPa$$word")`, which types `[data-test=signin-username]`, types `[data-test=signin-password]`, and clicks `[data-test=signin-submit]`. `[data-test=signin-error]` is visible and its text is exactly `Username or password is invalid`.
- **Existing user, bad password.** The same spec loads a seeded user with `cy.database("find", "users")` and calls `cy.login(user.username, "INVALID")`. `[data-test=signin-error]` is again exactly `Username or password is invalid`.
- **Proof.** `drive.sh` writes `evidence/<VERIFY_RWA_RUN_ID>/cypress.log`, `commands.log`, and screenshots `invalid-user-error` and `invalid-password-error`.
- **Redirect entry, not executed by the proof run.** `cy.visit("/personal")` then `cy.location("pathname")` equals `/signin` (`auth.spec.ts`).
- **Empty username.** Type into `[data-test=signin-username]`, clear the input, and blur it. `#username-helper-text` contains `Username is required` (`SignInForm.tsx` schema and `auth.spec.ts`).
- **Short password.** Type `abc` into `[data-test=signin-password]` and blur. `#password-helper-text` contains `Password must contain at least 4 characters`. `[data-test=signin-submit]` is disabled.

## Gotchas

- Assert `have.text` `Username or password is invalid`, not a shorter substring. The string is thrown by `performLogin` and rendered as `{authState.context.message}` inside `[data-test=signin-error]`.
- `cy.login` waits on `POST /login`. A doctor failure must skip Cypress rather than submitting against an unrelated server.
- Readiness is `http://localhost:3000/`. `http://127.0.0.1:3000/` is refused because Vite binds `[::1]:3000`.
- `yarn dev` and `db:seed` rewrite `data/database.json`. Cleanup restores the pre-launch bytes. Do not commit that file from a verification run.
- Field-error and redirect entries are mapped and were not the executed proof. Do not report them as passed because invalid credentials passed.
