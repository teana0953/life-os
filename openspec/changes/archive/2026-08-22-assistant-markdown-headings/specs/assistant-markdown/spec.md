## Purpose

Defines which Markdown marks the AI assistant's reply bubble renders and which
it deliberately leaves as literal text, how each rendered mark is laid out and
scaled, and what a screen-reader user hears — so a structured reply reads as
structure instead of as punctuation.

## ADDED Requirements

### Requirement: ATX headings are rendered

A reply line whose leading content is one to four `#` characters followed by at
least one space or tab SHALL be rendered as a heading of the corresponding
level, with the `#` characters and the space after them removed from what the
user sees. The heading's remaining text SHALL go through the same inline pass
as any other line, so `**bold**` inside a heading is bold and an unmatched `**`
inside a heading stays literal.

#### Scenario: A third-level heading loses its hashes

- **WHEN** the reply contains the line `### 本月支出`
- **THEN** the bubble shows `本月支出` on its own line
- **AND** no `#` character appears anywhere on screen for that line

#### Scenario: Every supported level is recognised

- **WHEN** the reply contains `# 一`, `## 二`, `### 三` and `#### 四` on
  separate lines
- **THEN** each is rendered as a heading carrying its own level (1, 2, 3, 4
  respectively)

#### Scenario: Inline marks still apply inside a heading

- **WHEN** the reply contains the line `### 本月**總計**`
- **THEN** the heading reads `本月總計`
- **AND** `總計` is rendered heavier than the rest of the heading

### Requirement: Headings are visually distinguishable by level

A rendered heading SHALL be a single bold line whose font size is at least the
body text's size, and each of the four levels SHALL be rendered at a size
different from every other level, decreasing as the level number increases, so
a reader can tell a section from a sub-section without reading the words. A
heading SHALL be separated from the block above it by more vertical space than
two ordinary wrapped lines have between them.

#### Scenario: Level sizes are ordered and above body text

- **WHEN** a reply contains all four heading levels and a paragraph
- **THEN** the rendered size of level 1 > level 2 > level 3 > level 4
- **AND** the level-4 size is greater than or equal to the paragraph's size

#### Scenario: A heading is bold even when its source has no bold marks

- **WHEN** the reply contains `### 本月支出` with no `**` in it
- **THEN** the heading text is rendered at a heavier weight than a paragraph's
  text

### Requirement: A thematic break is rendered as a rule

A reply line that consists only of three or more `-` characters, ignoring
leading and trailing whitespace, SHALL be rendered as a thin horizontal
dividing line spanning the bubble's available width, carrying no text, with
vertical space above and below it.

#### Scenario: Three dashes become a rule

- **WHEN** the reply contains a line `---` between two paragraphs
- **THEN** a horizontal divider is drawn between the two paragraphs
- **AND** the characters `---` do not appear on screen

#### Scenario: A longer run of dashes is still one rule

- **WHEN** the reply contains a line `-----`
- **THEN** exactly one divider is drawn and no `-` character is shown

#### Scenario: A dash line that is also a list item stays a list item

- **WHEN** the reply contains `- 醫療` (a dash, a space, then text)
- **THEN** it is rendered as a bullet list item, not as a divider

### Requirement: Unsupported marks stay literal

Marks outside the supported set SHALL be shown to the user exactly as the model
wrote them, never partially consumed and never silently dropped. This
explicitly includes tables, links, code spans, fenced code blocks, headings
deeper than level 4, and a `#` run not followed by whitespace.

#### Scenario: A fifth-level heading is not a heading

- **WHEN** the reply contains `##### 太深`
- **THEN** the line is shown as the literal text `##### 太深`

#### Scenario: A hash with no space is not a heading

- **WHEN** the reply contains `#tag`
- **THEN** the line is shown as the literal text `#tag`

#### Scenario: Tables and code spans are unchanged by this capability

- **WHEN** the reply contains `| a | b |` and `` `code` `` on separate lines
- **THEN** both lines are shown as literal text

### Requirement: Headings and rules do not disturb list layout

A heading and a thematic break SHALL be laid out as full-width blocks with no
list marker, no marker gutter of their own and no nesting indent. Their
presence in a reply SHALL NOT change the marker gutter width or the indent
applied to the list items around them, and list items before and after a
heading or rule SHALL keep the alignment they would have without it.

#### Scenario: A heading between two bullets leaves the gutter alone

- **WHEN** a reply contains a bullet list, then `### 小計`, then another bullet
  list whose widest marker is unchanged
- **THEN** the bullets after the heading start at the same horizontal offset as
  the bullets before it

#### Scenario: A heading is not indented by a preceding nested item

- **WHEN** a reply contains a level-2 nested bullet followed by `### 小計`
- **THEN** the heading starts at the block's leading edge, not at the nested
  item's indent

### Requirement: Headings and rules scale with the ambient text scale

Heading font sizes, and the vertical space around headings and thematic breaks,
SHALL scale with the platform text scale in the same way the rest of the reply
already does, so that at a large accessibility text scale a heading remains
larger than body text and its surrounding space remains proportionate.

#### Scenario: Headings grow with the text scale

- **WHEN** the same reply is rendered at text scale 1.0 and at text scale 2.0
- **THEN** each heading's painted height at 2.0 is greater than at 1.0
- **AND** at 2.0 every heading is still at least as tall as body text

### Requirement: The reply remains one screen-reader announcement

The rendered reply SHALL continue to expose exactly one accessibility label
covering the whole bubble in reading order, with the rendered widget tree
excluded from the semantics tree. A heading SHALL contribute its own text to
that label; a thematic break SHALL contribute no spoken text.

#### Scenario: A heading is spoken, a rule is not

- **WHEN** a reply contains a paragraph, `### 本月支出`, `---` and another
  paragraph
- **THEN** the bubble exposes a single semantics label
- **AND** that label contains `本月支出` and contains no `-` run or `#`
  character originating from those two lines
