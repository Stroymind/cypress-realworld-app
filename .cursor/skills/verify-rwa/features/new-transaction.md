# New transaction

A signed-in user starts a payment from the New button, picks a person, enters an amount and description, and sees `Transaction Submitted!`. Source: `cypress/tests/ui/new-transaction.spec.ts` and `src/components/NavBar.tsx`.

## Sub-features

- `pay-open` opens `/transaction/new`.
- `pay-search` filters the user list.
- `pay-submit` shows the success alert after submit.

## How to get to it (user POV)

- Sign in and choose the top-bar button labeled `New` (`data-test="nav-top-new-transaction"`, path `/transaction/new`).

## Driving it with Cypress

Preconditions:

- `doctor.sh` printed `doctor_exit=0`.
- The signed-in user has a contact in the seed data. The spec searches `[data-test=user-list-search-input]`.
- This entry was not the executed proof run.

- **Open the form.** `cy.getBySel("nav-top-new-transaction").click()`.
- **Choose a person.** Type the contact's first name into `[data-test=user-list-search-input]` and click the matching `[data-test*=user-list-item]`.
- **Enter payment.** Type the amount into `[data-test*=amount-input]` and the description into `[data-test*=description-input]`, then click `[data-test*=submit-payment]`.
- **Success.** `[data-test=alert-bar-success]` is visible and its text is `Transaction Submitted!`.
- **Home list.** `[data-test=transaction-list]` contains the payment description after returning home.

## Gotchas

- `Transaction Submitted!` is the full alert text in `new-transaction.spec.ts`. A visible alert with different text is not this success state.
- Submitting a payment changes balances and the transaction list. Restore `data/database.json` from the pre-launch snapshot during cleanup.
- An empty search result (`[data-test=users-list]` empty) is a different case in the same spec and is not success.
