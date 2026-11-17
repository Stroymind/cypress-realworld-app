# Notifications

A signed-in user opens Notifications from the side navigation. With none, the page shows `No Notifications`. The top bar badge is `[data-test=nav-top-notifications-count]`. Source: `cypress/tests/ui/notifications.spec.ts` and `src/components/NavDrawer.tsx`.

## Sub-features

- `notifications-open` opens `/notifications` from the side nav.
- `notifications-empty` shows the empty header when the list is absent.
- `notifications-count` shows the badge count on the top bar.

## How to get to it (user POV)

- Sign in and choose `Notifications` (`data-test="sidenav-notifications"`).
- Use the top-bar notifications link (`data-test="nav-top-notifications-link"`, path `/notifications`).

## Driving it with Cypress

Preconditions:

- `doctor.sh` printed `doctor_exit=0`.
- This entry was not the executed proof run.

- **Open the page.** After sign-in, click `[data-test=sidenav-notifications]`. On a mobile viewport, click `[data-test=sidenav-toggle]` first.
- **Empty state.** `[data-test=notification-list]` does not exist and `[data-test=empty-list-header]` contains `No Notifications`.
- **Badge.** `[data-test=nav-top-notifications-count]` has the text of the notification count asserted by `notifications.spec.ts`.

## Gotchas

- The empty header string is `No Notifications`, which is a different string from the bank-account empty header.
- Do not treat the badge's presence during onboarding (`auth.spec.ts`) as proof of this page.
