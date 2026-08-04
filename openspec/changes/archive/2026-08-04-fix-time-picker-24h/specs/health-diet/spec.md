## MODIFIED Requirements

### Requirement: Today's diet log by meal in eaten order

The Today section SHALL read the day's meals from the meals API and present each
meal as a card. It SHALL order all meals that exist — the standard meals
(breakfast, lunch, dinner) and snacks alike — together by each meal's single
eaten-at `time`, earliest first, so a snack eaten between two meals appears
between them. Standard meals that have no meal for the day SHALL be shown after
the ordered meals as empty cards in breakfast, lunch, dinner order. It SHALL show
per-category portion progress — staple, meat, fruit, and vegetable — as a
per-category progress bar (a filled track proportional to consumed-over-target),
where consumed is the day's meal portion totals and target is the day's effective
target, alongside the used / target numbers. A meal card SHALL be labeled with
the meal — an emoji plus a localized name for the standard meals, and the snack's
own name (which a snack meal already carries as its `meal` value) for a snack — and
the meal's `time`, and SHALL show a total pill summing the meal's consumed
portions. A meal card SHALL also offer a control to change the meal's time — presenting a
24-hour clock regardless of the device locale, matching the 24-hour form the
card displays the time in — and a control to delete the whole meal behind a
confirmation.
For each of the meal's items the card SHALL show the item's consumed portions
across every food group it contributes to — labeled and color-coded by category,
omitting groups whose portion is zero — together with the item's consumed amount
(its measure or quantity). The item rows SHALL be **editable**: tapping an item
reveals an inline amount control to adjust it, and each item offers a way to
delete it. An empty meal card SHALL show the meal and an empty indication. Each
meal card SHALL offer a way to add a food into that meal, and the Today section
SHALL offer a way to start a new snack, without leaving to re-select the meal.

#### Scenario: Meals and snacks ordered by meal time
- **WHEN** the day has breakfast at 08:00, a snack "點心2" at 10:30, lunch at 12:30, a snack at 15:00, and dinner at 19:00
- **THEN** the Today section shows those cards in that eaten-at order, with the 10:30 and 15:00 snacks interleaved between the meals

#### Scenario: Empty standard meals shown after existing meals
- **WHEN** the day has only a lunch meal
- **THEN** the Today section shows the lunch card, then empty breakfast and dinner cards after it, each still offering a way to add a food into that meal

#### Scenario: Snack card labeled with the snack's own name
- **WHEN** the day has a snack meal named "點心2"
- **THEN** its card is labeled "點心2" (the snack's own name), with the snack emoji

#### Scenario: Per-category progress from day totals
- **WHEN** the day has an effective target of 12 staple and the day's meal totals are 9 staple portions
- **THEN** the Today section shows staple progress as 9 of 12 with a bar filled to three-quarters

#### Scenario: Meal card shows its time and total
- **WHEN** a breakfast meal has time 08:10 and its items consume 4 staple and 1 meat portions in total
- **THEN** the breakfast card shows the time 08:10 and a total pill of 4 staple and 1 meat

#### Scenario: An item shows its consumed portions and amount, and is editable
- **WHEN** a meal item consumes 0 staple and 1 meat portion (e.g. 蛋/1個)
- **THEN** its row shows a "meat 1" portion pill, does not show a lone "0" staple value, shows its consumed amount, and is tappable to edit in place

#### Scenario: Add a food into a specific meal from Today
- **WHEN** the user taps the add control on the lunch card
- **THEN** the full-screen food search opens with the target meal set to lunch, ready to pick a food, without the user re-selecting the meal

#### Scenario: The meal-time control matches the format the card shows

- **WHEN** a user on a 12-hour locale opens a meal card's time control
- **THEN** it offers a 24-hour clock — otherwise they would pick "9:30 PM"
  and the card would read back "21:30", with nothing indicating why

