## MODIFIED Requirements

### Requirement: Build the meal in an item tray with adjustable amounts

The full-screen food search SHALL show a current-meal tray of the foods added so
far. Each dictionary tray item SHALL have an amount control combining a −/+
stepper with a typable numeric field (following the empty-zero numeric
convention: an amount of zero shows an empty field with a "0" hint) and a unit
label. The amount control's portion side SHALL always be labeled 份 (a generic
portion word, not a word scraped from the food name). When the item has a defined
base measure the tray item SHALL also offer a portion/measure toggle whose
measure side is labeled by the item's own `measure_unit` — 公克 for a gram item,
毫升 for a millilitre item, and the unit word itself for a household-unit item
(顆/碗/杯), never a bare "g"/"ml"; in measure mode the amount is entered in that
measure unit and converted to a quantity via the item's base amount. Because
household-unit foods now carry a base measure, they too offer this toggle (enter
by 份 or by 顆/碗/杯); only a food with no base measure at all offers unit
quantity (份) only. Each tray item SHALL preview its resulting portions as
category-colored pills, computed on the client as the item's per-unit portions ×
the effective quantity (a measure amount first converted via the base amount),
without a backend round-trip; a manually-entered tray item previews the portions
the user entered directly. The tray SHALL show a running total pill summing all
tray items' previewed portions. A tray item SHALL be removable.

#### Scenario: Amount stepper and typable field
- **WHEN** the user sets a tray item's quantity to 1.5 via the field or the +/− stepper
- **THEN** the item's amount reads 1.5 and its portion preview scales accordingly

#### Scenario: Preview scales with quantity
- **WHEN** a tray item is `飯/1碗` (4 staple portions) with quantity 1.5
- **THEN** its preview shows 6 staple portions

#### Scenario: The after-field unit label reads 份, not a scraped unit word
- **WHEN** the user views any tray item's amount control in portion mode
- **THEN** the unit label after the number field reads 份, regardless of the food's name or unit (the mode-toggle button keeps its own label 份量)

#### Scenario: A gram item labels its measure side 公克
- **WHEN** the user picks `飯/50g` (measure unit g, base amount 50, 1 staple portion) and enters 33 in measure mode
- **THEN** the measure side is labeled 公克 and the preview shows approximately 0.66 staple portions

#### Scenario: A household-unit item can be entered by its unit
- **WHEN** the user picks `櫻桃/9顆` (measure unit 顆, base amount 9, 1 fruit portion) and enters 18 in measure mode
- **THEN** the measure side is labeled 顆, the amount is entered directly, and the preview shows 2 fruit portions

#### Scenario: A food with no base measure offers 份 only
- **WHEN** the user picks a food with no base measure (e.g. 熟肉/掌心大)
- **THEN** the tray item offers a portion quantity in 份 only, with no portion/measure toggle

#### Scenario: Running total across the tray
- **WHEN** the tray has two items previewing 6 and 2 staple portions
- **THEN** the tray total pill shows 8 staple portions
