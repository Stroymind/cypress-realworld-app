# Sign up

A visitor opens the sign-up form from the sign-in page, enters name, username, and matching passwords, and submits. The form title is `Sign Up`. Source: `cypress/tests/ui/auth.spec.ts` and `src/components/SignUpForm.tsx`.

## Sub-features

- `signup-open` shows the title `Sign Up`.
- `signup-required` shows required-field helper text and disables submit when the passwords differ.
- `signup-create` posts the new user and then signs in.

## How to get to it (user POV)

- On the sign-in page, choose the link `Don't have an account? Sign Up` (`data-test="signup"`).
- Open `http://localhost:3000/signup`.

## Driving it with Cypress

Preconditions:

- `doctor.sh` printed `doctor_exit=0`.
- This entry was not the executed proof run. Follow these commands only on a later run.

- **Open the form.** `cy.visit("/")`, then `cy.getBySel("signup").click()`. `[data-test=signup-title]` is visible and contains `Sign Up`.
- **Fill the account.** Type first name, last name, username, password, and confirm password into `[data-test=signup-first-name]`, `[data-test=signup-last-name]`, `[data-test=signup-username]`, `[data-test=signup-password]`, and `[data-test=signup-confirmPassword]`. The auth spec uses password `s3cret` for the created user.
- **Submit.** `cy.getBySel("signup-submit").click()` and wait for the `POST /users` alias used by `auth.spec.ts`.
- **Required errors.** On `/signup`, clear each field and blur. `#firstName-helper-text` contains `First Name is required`, `#lastName-helper-text` contains `Last Name is required`, `#username-helper-text` contains `Username is required`, `#password-helper-text` contains `Enter your password`. Type `DIFFERENT PASSWORD` into confirm password. `#confirmPassword-helper-text` contains `Password does not match`. `[data-test=signup-submit]` is disabled.

## Gotchas

- Creating `PainterJoy90` mutates the seeded database. Cleanup must restore `data/database.json` from the pre-launch snapshot.
- Do not report sign-up as verified because the invalid-credentials proof passed.
