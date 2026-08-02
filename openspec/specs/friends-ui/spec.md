# friends-ui Specification

## Purpose
TBD - created by archiving change add-friends-ui. Update Purpose after archive.
## Requirements
### Requirement: Friends list

The app SHALL provide a friends page, reachable from settings, listing the
signed-in user's friends by display name only — never an email address.
While loading, a progress indicator is shown; on load failure, an error
state with a retry action; on `401`, the app's existing re-authentication
exit. A user with no friends SHALL see an empty-state guide that explains
how to add one and offers the invite action, never a blank page.

#### Scenario: Friends are listed by name

- **WHEN** the signed-in user has two friends and opens the friends page
- **THEN** both friends' display names are shown, and no email address
  appears anywhere on the page

#### Scenario: No friends yet

- **WHEN** the signed-in user has no friends
- **THEN** an empty-state message explaining how to add a friend is shown
  together with the invite action, not a blank page

#### Scenario: Loading fails

- **WHEN** loading the friends list fails
- **THEN** an error message with a retry action is shown, and activating
  retry re-requests the list

#### Scenario: Session expired

- **WHEN** loading the friends list answers `401`
- **THEN** the re-authentication exit is shown rather than a generic error

### Requirement: Removing a friend

The friends page SHALL let the user end a friendship, and SHALL ask for
confirmation first. The confirmation SHALL name the friend being removed.
On success the friend disappears from the list; on failure the list is
unchanged and an error is surfaced. While a removal is in flight its
action SHALL be disabled so it cannot be submitted twice.

#### Scenario: Removal is confirmed by name

- **WHEN** the user activates remove on a friend named `Alex`
- **THEN** a confirmation naming `Alex` is shown, and nothing is sent until
  it is confirmed

#### Scenario: Cancelling keeps the friend

- **WHEN** the user dismisses the confirmation
- **THEN** no request is sent and the friend remains listed

#### Scenario: Removal succeeds

- **WHEN** the user confirms removing a friend and the request succeeds
- **THEN** that friend is no longer listed

#### Scenario: Removal fails

- **WHEN** the user confirms removing a friend and the request answers `404`
- **THEN** a message about that friendship no longer existing is shown — not
  the invalid-link copy used for invite failures — and the list is refreshed

### Requirement: Creating an invite link

The friends page SHALL let the user create an invite, and SHALL present the
resulting link as `<origin>/#/invite?token=<token>` — the app serves its
routes from the URL fragment, so a link without `/#/` does not resolve at all
— with an action that copies
it to the clipboard. Copying SHALL give visible confirmation. The link text
SHALL be shown as well, so the user has a fallback when the clipboard is
unavailable. A created link SHALL NOT survive leaving the page: returning to
the friends page later SHALL show no link until a new invite is created —
and because of that, the link SHALL be presented together with its expiry
and an explicit warning that it is shown only this once and cannot be
retrieved afterwards.

#### Scenario: Link is created and copyable

- **WHEN** the user activates the invite action and the backend returns a
  token
- **THEN** the full `<origin>/#/invite?token=…` link is shown, and activating
  copy places that exact link on the clipboard with visible confirmation

#### Scenario: The link says it is shown only once

- **WHEN** an invite link is presented
- **THEN** its expiry is shown alongside it, together with a warning that
  the link is shown only this once and cannot be retrieved later

#### Scenario: A failed refresh does not destroy the link

- **WHEN** the invite is created successfully but the follow-up refresh of
  the lists fails
- **THEN** the invite link stays on screen and the refresh failure is
  reported separately — the page does not fall back to a load-error state

#### Scenario: Invite creation fails

- **WHEN** creating an invite fails
- **THEN** an error message is shown and no link is presented

#### Scenario: The link does not outlive the page

- **WHEN** the user creates an invite link, leaves the friends page, and
  returns to it
- **THEN** no invite link is shown until a new one is created

### Requirement: Outstanding invites

The friends page SHALL list the user's own still-usable invites with their
expiry **and their creation time, so that invites sharing an expiry date can
be told apart**, and SHALL ask for confirmation before revoking one — the
link is already in someone else's hands and revoking silently stops it
working for them. A revoked invite disappears from the list.

#### Scenario: Invites show their expiry

- **WHEN** the user has an outstanding invite expiring on a given date
- **THEN** that invite is listed with its expiry date

#### Scenario: Invites sharing an expiry date are distinguishable

- **WHEN** the user has two outstanding invites that expire on the same date
- **THEN** each is listed with its own creation time, so the rows are not
  identical

#### Scenario: A new invite joins the list

- **WHEN** the user creates an invite while the outstanding-invites list is
  shown
- **THEN** the new invite appears in that list without the user having to
  leave and re-enter the page

#### Scenario: Revoking is confirmed first

- **WHEN** the user activates revoke on an outstanding invite
- **THEN** a confirmation explaining that the shared link will stop working
  is shown, and nothing is sent until it is confirmed

#### Scenario: Revoking removes the invite

- **WHEN** the user confirms revoking an outstanding invite and the request
  succeeds
- **THEN** that invite is no longer listed

#### Scenario: A failed mutation is visible wherever it was triggered

- **WHEN** revoking an invite fails
- **THEN** the failure is surfaced in a transient message overlaying the
  page, not as text that may be scrolled out of view

### Requirement: Accepting an invite

Opening `/invite?token=<token>` SHALL preview the invite before consuming
it: the page requests a preview and shows who is inviting, with an explicit
accept action. The invite SHALL be consumed only when the user activates
accept. On success the user is taken to the friends list, which then
includes the new friend. While accept is in flight the action SHALL be
disabled.

#### Scenario: Preview then accept

- **WHEN** a signed-in user opens an invite link from `Alex`
- **THEN** the page shows that `Alex` is inviting them and an accept action,
  and no accept request has been sent

#### Scenario: Accepting creates the friendship

- **WHEN** the user activates accept and the request succeeds
- **THEN** the friends list is shown and includes the new friend

#### Scenario: Re-opening an accepted link

- **WHEN** the user opens an invite link they have already accepted
- **THEN** the already-friends state is shown, not an error

#### Scenario: Already friends

- **WHEN** the invite belongs to someone the user is already friends with
- **THEN** the page says they are already friends and offers a way back to
  the friends list, with wording distinct from a fresh acceptance

### Requirement: Invite failures are explained and actionable

Each invite failure SHALL be told apart and explained in terms the user can
act on, never as a raw status code: expired, already used, revoked, the
user's own invite, and an unknown/invalid link SHALL each produce their own
message, together with a way back to the friends list.

#### Scenario: Expired invite

- **WHEN** the preview or accept answers `invite_expired`
- **THEN** the page says the invite has expired and suggests asking for a
  new link, and offers a way back to the friends list

#### Scenario: Already used invite

- **WHEN** the preview or accept answers `invite_already_used`
- **THEN** the page says the invite has already been used, distinctly from
  the expired message

#### Scenario: Revoked invite

- **WHEN** the preview or accept answers `invite_revoked`
- **THEN** the page says the invite was revoked, distinctly from the expired
  and already-used messages

#### Scenario: Own invite is only detected on accept

- **WHEN** the user opens their own invite link
- **THEN** the preview succeeds and shows the accept action, and only after
  the user activates accept — which answers `cannot_friend_self` — does the
  page explain this is the user's own invite

#### Scenario: Unknown link

- **WHEN** the preview or accept answers `404`
- **THEN** the page says the link is invalid and suggests checking it was
  copied in full

#### Scenario: A second invite link replaces the first

- **WHEN** the user opens one invite link and then, without leaving the app,
  opens a different invite link
- **THEN** the second inviter is shown, and accepting consumes the second
  invite — never the first

#### Scenario: Missing or blank token

- **WHEN** `/invite` is opened with no `token` query parameter or a blank one
- **THEN** the page shows the same invalid-link message, without sending a
  preview request

### Requirement: Invite links survive signing in

An invite link opened while signed out SHALL be honoured after the user
signs in or registers: the destination, **including its `token` query
parameter**, is remembered across the auth bootstrap and replayed once
authentication resolves, instead of landing on the home screen.

#### Scenario: Cold start signed out

- **WHEN** a signed-out user opens `/invite?token=abc` and then signs in
- **THEN** the invite page for token `abc` is shown, not the home screen

#### Scenario: Token is not dropped

- **WHEN** the pending destination is replayed after authentication
- **THEN** the replayed location still carries the same `token` query
  parameter

### Requirement: Invite tokens are not exposed in requests

Every call carrying an invite token SHALL send it in the request body, never
in a URL path or query string.

#### Scenario: Preview sends the token in the body

- **WHEN** the app previews an invite
- **THEN** the request is a POST whose body carries the token and whose URL
  contains no token

#### Scenario: Accept sends the token in the body

- **WHEN** the app accepts an invite
- **THEN** the request is a POST whose body carries the token and whose URL
  contains no token

### Requirement: Friends UI is localized and lays out on small screens

All friends and invite copy SHALL come from the app's localizations in
English and Traditional Chinese — no hard-coded user-facing strings. Both
pages SHALL lay out without layout errors at 320dp and 360dp wide, in each
supported locale, at text scales 1.0 and 2.0.

#### Scenario: Narrow screens stay clean

- **WHEN** the friends page or the invite page is rendered at 320dp or 360dp
  in any supported locale at text scale 1.0 or 2.0
- **THEN** no layout error is raised and no content overflows its bounds

#### Scenario: The invite page can always be left

- **WHEN** the invite page is reached without anything to go back to (a
  cold start from an externally shared link), in any of its states
- **THEN** it offers a way out that lands on the home screen, so accepting
  is never the only available action

#### Scenario: The friends page can always be left

- **WHEN** the friends page is reached without anything to go back to (opened
  directly by URL, or after accepting an invite)
- **THEN** it still offers a way out that lands on the home screen, rather
  than showing no back affordance at all

#### Scenario: Long friend names do not push actions out

- **WHEN** a friend's display name is longer than the row can fit
- **THEN** the name wraps or shrinks and the row's action stays fully
  visible and tappable

