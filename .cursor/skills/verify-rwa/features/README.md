# Cypress Real World App verification map

This directory is the maintained source for verifying user-facing behavior of the Cypress Real World App. Read the index before driving the app, then use the matching feature file as the recipe.

The primary surface is the web UI at `http://localhost:3000` with the API at `http://localhost:3001`. Authentication is the first map entry and the one the generated skill executes.

## Baseline preconditions

- Repository origin is `https://github.com/Stroymind/cypress-realworld-app`. Do not drive a checkout whose origin is `cypress-io/cypress-realworld-app`.
- Node is `v22.20.0` and Yarn Classic is `1.22.22`.
- Launch with `VERIFY_RWA_RUN_ID` set and `bash .cursor/skills/verify-rwa/helpers/launch.sh`.
- Run `bash .cursor/skills/verify-rwa/helpers/doctor.sh` and require `doctor_exit=0` before any Cypress command.
- Never drive or stop a listener on 3000 or 3001 that doctor does not attribute to this run.

## Driving conventions

- Start from the seeded database (`data/database-seed.json`, reapplied by `yarn dev` and by `cy.task("db:seed")`).
- Use the existing commands in `cypress/support/commands.ts`: `cy.getBySel` is `[data-test=<name>]`, `cy.login` visits `/signin` when needed and submits the sign-in form.
- Treat selector names and expected strings as literal.
- Keep screenshots and `commands.log` under `.cursor/skills/verify-rwa/evidence/<VERIFY_RWA_RUN_ID>/`.

## Proof and skip reporting

- Exercise the sign-in form. Do not set auth state through a test-only setter.
- Capture the Cypress command log, the numeric exit code, and a screenshot of the resulting alert.
- Record the feature ID with the artifact.
- If doctor refuses, report the refusal and do not claim the feature passed.

## Feature entry contract

Each feature file starts with an H1 and one paragraph, then exactly these H2 sections in order: `Sub-features`, `How to get to it (user POV)`, `Driving it with Cypress`, `Gotchas`. The driving section starts with `Preconditions:`.

## Features

- [Authentication](./authentication.md) covers the sign-in form, including the invalid-credentials error this skill executes.
- [Sign up](./sign-up.md) covers the sign-up form reached from the sign-in page.
- [Bank accounts](./bank-accounts.md) covers the signed-in Bank Accounts page.
- [Notifications](./notifications.md) covers the signed-in notifications list.
- [New transaction](./new-transaction.md) covers creating a payment from the New button.
