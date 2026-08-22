## Why

The assistant's replies are rendered by a hand-written minimal Markdown parser
(`lib/contexts/assistant/presentation/assistant_markdown.dart`) that knows
`**bold**`, bullets and numbered lists — and nothing else. The model routinely
structures a longer answer with `### 標題` / `#### 標題` and separates its
sections with `---`, and an on-device screenshot confirms those reach the user
as the literal characters `### 本月支出` and `---`. The reply's own structure is
the part that turns to noise, and it happens on exactly the long, sectioned
answers where structure matters most.

This is the same failure the parser was built to fix for `**NT$ 23,847**`
(issue #152), one mark later.

## What Changes

- The parser gains **ATX headings**, levels 1 to 4: a line whose first
  non-space run is one to four `#` followed by whitespace becomes a heading
  block carrying its level and its inline content (so `### **總計**` still
  bolds inside the heading). `#####` and beyond, and a `#` with no following
  whitespace (`#tag`), stay literal — the parser's rule that an unrecognised
  mark is shown as typed, never half-eaten, is unchanged.
- The parser gains a **thematic break**: a line that is exactly three or more
  `-` (after trimming) becomes a break block with no text content.
- The widget renders a heading as a single bold line at a size stepped up from
  the body text, with the four levels visually distinguishable from each other
  and every one of them at least as large as body text; it renders a thematic
  break as a thin horizontal rule with breathing room above and below.
- Headings and breaks are laid out like existing non-list blocks — no marker,
  no gutter, no indent — and their type sizes and vertical spacing scale with
  the ambient `TextScaler` like the rest of the widget already does.
- The Semantics behaviour is unchanged in shape: the whole reply is still one
  label in reading order. A heading contributes its text; a thematic break
  contributes no spoken text (it is decoration, like the bullet glyph).
- **BREAKING (spec-level, internal)**: `## 標題` no longer renders literally.
  The existing test `leaves syntax it does not know as literal text` pins
  `'## 標題'` as literal and must be re-pointed at a mark that is still
  genuinely unsupported (table row, code span, `#####`).

Not in scope: tables, links, code spans and fenced code blocks — these stay
literal, deliberately. Setext headings (`===` / `---` under a text line) are
not supported: an underline `---` is read as a thematic break, matching what
the model actually emits. `***` and `___` as thematic breaks are not supported
(`***` already has a tested meaning in the inline bold pass). No change to the
assistant's prompt, API calls, or the user's own message rendering.

## Capabilities

### New Capabilities
- `assistant-markdown`: which Markdown marks the assistant's reply bubble
  renders and which it deliberately leaves literal, how each rendered mark is
  laid out (marker gutter, nesting indent, vertical spacing, text scaling), and
  what a screen reader hears.

### Modified Capabilities

(none — no existing spec under `openspec/specs/` describes reply rendering)

## Impact

- `lib/contexts/assistant/presentation/assistant_markdown.dart` — `MdBlockKind`
  gains heading and thematic-break kinds, `MdBlock` gains a heading level,
  `parseAssistantMarkdown` gains the two line rules, and `AssistantMarkdown`
  gains the heading text style and the rule widget plus their spacing.
- `test/contexts/assistant/presentation/assistant_markdown_test.dart` — new
  parser and widget guards, and the re-pointed "unknown syntax stays literal"
  test.
- These two files change together and must not be split across isolated
  worktrees: the tests import the parser types the same commit introduces.
- No ARB strings (headings and rules carry no app-authored text), no backend
  change, no API-call change, no other call site — `AssistantMarkdown` is used
  only by the assistant bubble.
