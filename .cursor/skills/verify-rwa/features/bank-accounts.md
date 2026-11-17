# Bank accounts

A signed-in user opens Bank Accounts from the side navigation and can start a new account form. With no accounts, the page shows `No Bank Accounts`. Source: `cypress/tests/ui/bankaccounts.spec.ts`, `src/components/NavDrawer.tsx`, and `src/components/BankAccountForm.tsx`.

## Sub-features

- `bank-open` opens the bank accounts route from the side nav.
- `bank-empty` shows the empty header when the user has no accounts.
- `bank-new` opens the new-account form.

## How to get to it (user POV)

- Sign in, open the side navigation when the viewport is mobile (`data-test="sidenav-toggle"`), and choose `Bank Accounts` (`data-test="sidenav-bankaccounts"`, path `/bankaccounts`).
- Choose `data-test="bankaccount-new"` to open the form.

## Driving it with Cypress

Preconditions:

- `doctor.sh` printed `doctor_exit=0`.
- A seeded user can sign in with password `s3cret`.
- This entry was not the executed proof run.

- **Open the list.** After `cy.login`, click `[data-test=sidenav-bankaccounts]`.
- **Empty state.** `[data-test=empty-list-header]` contains `No Bank Accounts` when the spec's user has no accounts, and `[data-test=bankaccount-list]` does not exist.
- **New form.** Click `[data-test=bankaccount-new]`. The form fields are `[data-test=bankaccount-bankName-input]`, `[data-test=bankaccount-routingNumber-input]`, `[data-test=bankaccount-accountNumber-input]`, and submit `[data-test=bankaccount-submit]`.

## Gotchas

- On a mobile viewport the side nav is closed until `[data-test=sidenav-toggle]` is clicked (`bankaccounts.spec.ts`).
- An empty list is not proof that the new-account form saves. Saving is a separate action and was not executed here.
