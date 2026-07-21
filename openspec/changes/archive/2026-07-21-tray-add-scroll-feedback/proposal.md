## Why

In the full-screen food search, tapping a result appends the food to the
current-meal tray — but the tray is a fixed-height (260px) scrollable list with
no scroll-to-new behavior, so once it holds a couple of items the newly added
one lands below the fold. Nothing visibly moves at the moment of adding (only the
header total pill quietly updates), so users think the add did not work and tap
again. The add needs immediate, visible feedback.

Frontend-only, presentation-layer. No DTO, API, or domain change.

## What Changes

- **Auto-scroll to the newest item**: after a food is added to the tray (whether
  by tapping a search result or via manual entry), the tray scrolls to reveal the
  newly added item (animating to the end), so the user sees it land. When the tray
  is not overflowing the scroll is a no-op.
- **Brief highlight on the new row**: the newly added tray row briefly shows a
  soft (low-opacity primary/accent) background that fades out (~0.9s), drawing the
  eye to the item that was just added. Only the just-added row highlights.
- **Only real adds trigger feedback**: removing an item or changing an item's
  amount does NOT scroll or highlight.
- `CreateMealController` gains a lightweight presentation-layer "an item was just
  added" signal (a monotonically increasing add tick plus the added entry) so the
  tray view can distinguish a genuine add from a remove/amount change. `_TrayPanel`
  becomes stateful to own the `ScrollController` and drive the scroll + highlight.

## Capabilities

### Modified Capabilities

- `health-diet`: adding a food to the current-meal tray now gives immediate visible
  feedback — the tray scrolls to reveal the newly added item and briefly highlights
  its row — while removing an item or changing an amount does not.
