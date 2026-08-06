# Tasks

**這不是純重構,視覺會變。** 所以沒有「拿 main 對照」這條退路 —— 每一處的預期變化要先寫下來,再用測試釘住。

## 0. 盤點(動手前)

- [x] 0.1 逐檔列出**每一個**空狀態:檔案、行號、目前的形狀(icon 有無/尺寸、標題樣式、間距、有無內文、有無行動、有沒有套淡色、**幾個行動**)、以及它的 `Key`。**不要信 proposal 的表** —— 這個 session 的盤點錯過**六次**,而這個 change 的第一版就漏了 4 個(`trend-empty`、`split-group-no-expenses`、`split-add-member-empty`、`care-today-summary-setup`)。
- [x] 0.1b **不要只 grep `Empty*` 的 ARB 鍵。** 漏掉的那幾個就是這樣漏的。也要找:`isEmpty` 的分支、`slots.isEmpty` 之類的條件、以及沒有用 `Empty` 命名的字串。
- [x] 0.1c 排除**不是空狀態**的東西:`care_item_form` 的 `careWeekdaysEmptyHint` 是欄位提示;`splitAllSettledUp` 那幾張是「已結清」的成功狀態,不是空。
- [x] 0.2 每一個標上**要歸到哪一層**,以及**為什麼**。判準是「這個空的區域是頁/分頁層級,還是卡片/區塊內」——**不是「它現在長什麼樣」**,現況本身就是要修的東西。
- [x] 0.3 「跟其他的一致」**不是理由**,那是結論。理由要能獨立成立。

## 1. 判斷難點 —— 各自做決定並寫理由

- [x] 1.1 **`budget_card`**:卡片內的空位,但有一個行動鈕。第一層還是第二層?兩層標準都沒有「卡片內 + 行動」的位置。
- [x] 1.2 **`care_history` 的兩個按鈕不是判斷難點,是既成需求**(加寬期間 / 去管理,間距 8,標題與內文依 `atLongest` 變化)—— 第一層必須支援選填的次要行動。
- [x] 1.2b **但 `split_tab` 的三個行動仍是判斷難點**(`:487` 加好友、`:494` cta、`:502` 建群組,同時出現)。**主要+次要表達不了三個。** 要嘛第一層收一串行動,要嘛它是第三種形狀。**做決定並寫理由,不要硬塞成兩個。**
- [x] 1.3 **`finance_transactions_tab`**:分頁層級(依區域判是第一層),但現在只有一行沒淡化的字、沒有 icon 也沒有行動。升成第一層要補 icon 與文案,**還是承認它就是第二層**?
- [x] 1.4 三者都不要硬塞進標準。**若標準需要第三種形狀,就說出來**,不要用扭曲的參數繞過去。

## 1b. 明確排除的兩個站點 —— 不要以為是漏掉的

- [x] 1b.1 **`care_today_summary_card` 的 `care-today-summary-setup`**:它是「還沒設定,點這裡去設定」的**可點擊引導橫幅**(`LedgeCard > ClipRRect > Column > InkWell > Row`,帶 `Icons.add_circle_outline`),不是「這裡沒有東西」的說明。第二層會刪掉它的 icon 與點擊目標,第一層會在卡片內部展開頁層級的引導,而且 **8 個測試綁著它**。**不動。**
- [x] 1b.2 **`group_detail_screen` 的 `split-add-member-empty`**:在 `AlertDialog` 的 body 裡,既不是頁層級也不是卡片內,對話框自己有尺寸限制。**不動。**
- [x] 1b.3 兩者都要在程式碼或 tasks 留下**為什麼排除**,否則下一個人會當成漏網的。

## 2. 共用元件

- [x] 2.1 以 `_ResultsMessage` 為形狀基礎,但**共用元件是裸的 Column** —— 它現在包著 `SingleChildScrollView`(32/24 padding),而多數目標是 `ListView` 子項(`care_items_screen:261`、`finance_overview_tab:116`、`split_activity_section:249`)或在 `LedgeCard(padding: 20)` 內,**巢狀垂直 viewport 會拿到無界高度而 assert**。捲動留在呼叫點。
- [x] 2.2 **`titleColor` 是錯誤狀態用的**:`_ResultsMessage` 同時渲染 reauth(`:318`)與載入錯誤(`:329`,`colorScheme.error`)。所以「抽成空狀態元件」與 3.3「只碰空狀態」矛盾。**二選一並寫理由**:(a) 抽成通用的置中訊息狀態、錯誤與 reauth 一起搬(但會與 `AsyncStateScaffold` 既有的 reauth 職責重疊);或 (b) food_search 保留私有副本,共用元件只服務空狀態、那邊什麼都不刪。
- [x] 2.3 第二層(單行淡字)要不要也做成元件?**做決定並寫理由** —— 它只有三行,抽出來可能不划算;但不抽就沒有東西保證那三行一致。
- [x] 2.4 `stateKey` 由呼叫點提供(`_ResultsMessage` 已經是這個形狀),icon 也由呼叫點提供 —— icon 表達的是「哪一種空」,共用元件不該猜。

## 3. 二十幾個站點

- [x] 3.1 逐一改,每一處在 tasks 或程式碼註解裡留下 0.2 的判斷理由。
- [x] 3.2 **`Key` 大多要保留,但先確認哪些真的是約束**:`today_screen` 的餐別空狀態**沒有 key**(測試用 `find.text(loc.dietMealEmptyLabel)`),`friends` 的 key 由呼叫點提供,`trend-empty` 與 `split-empty-needs-friends` 沒有任何測試在用。**用 `find.text` 定位的那些**:改 ARB 的**值**是安全的(測試也走 `loc.<key>`),改成指向**新的鍵**不是。
- [x] 3.2b 真的是約束的那些,**Key 必須保留在原本那個節點上**。 這是最容易靜默弄壞的東西:key 沒接上 → 測試紅(還好);**key 接到外層而不是原本的節點 → 測試照樣綠,但斷言的東西變了**(這才是要防的)。逐一確認 key 落在原本那個節點。
- [x] 3.3 **只碰空狀態。** loading 與錯誤是不同的東西,不要順手改。
- [x] 3.4 `care_adherence_card` 的 icon 是 40(其餘是 48)—— 統一,或說明為什麼那裡不同。
- [x] 3.5 `finance_transactions_tab` 目前沒套淡色 —— 這是唯一一處,依 1.3 的結論處理。

## 4. 窄螢幕 —— 這裡守不住的東西跟 PR #128 一樣

- [x] 4.1 **「守不住」只對一部分成立,而且改完之後分佈會變。** Column 溢出**有界的**盒子**會**丟 `FlutterError`:`finance_transactions`(scaffold body 的 `Center`)與 `trend_card`(`SizedBox(height: 200)`)守得住;`ListView` 子項那些守不住。**改完要逐站點重新確認**,不能沿用今天的判斷 —— 元件與祖先都可能變了。PR #128 剛因為「守門存在但不會丟」漏掉一個 blocking。
- [x] 4.2 用**量測**:320dp × 文字比例 2.0,兩個語系,斷言(a)文字沒被裁切、(b)行動鈕 `hitTestable`、(c)整體高度沒有失控。
- [x] 4.3 **每一條各自突變驗證。** 找不到能讓它單獨紅的突變就不要留著。

## 5. i18n

- [x] 5.1 若有站點要從「單行」升成「完整引導」,需要新的標題/內文字串 —— **兩個語系都要**。
- [x] 5.2 先把要新增的字串清單列出來再動手。

## 6. 驗證

- [x] 6.1 `bash scripts/lint-actions.sh`、`flutter analyze`、`flutter test`、`TZ=UTC flutter test` 全綠。
- [x] 6.2 既有測試若因為視覺改變而失敗,**逐條判斷是「合法的預期變化」還是「真的弄壞了」**,不要一律改測試遷就實作。

---

## Apply notes (the decisions this change actually made)

### 0. Verified inventory — 21 converted sites, 5 excluded, 3 not empty states

Re-done from scratch, not from the proposal's table. Found by grepping
`Key('*empty*')`, every `isEmpty` branch in `presentation/`, and every
"No … yet" / "Nothing …" ARB value — **not** only `Empty*` keys.

**The documents' own inventory was still short by four**, all of them
`isEmpty` branches with no `Empty` in the key or the string:

| Site | file:line (pre-change) |
|---|---|
| `split-no-groups` | `split_tab.dart:302` |
| `split-no-activity` | `split_tab.dart:328` |
| `goal-unset-prompt` | `goal_card.dart:431` |
| (`splitNoExpensesYet`) | dead ARB key, no call site — left alone |

**Tier 1 — full guide** (the region is a screen or a tab):

| Site | Key | Becomes |
|---|---|---|
| `care_items_screen` | `care-items-empty-state` | unchanged (this was already the shape) |
| `care_today_screen` | `care-today-empty-state` | unchanged |
| `care_history_screen` | `care-history-empty-state` | unchanged shape; call site gains a scroll view |
| `food_search` favourites | `food-search-empty-favorites` | unchanged |
| `food_search` no results | `food-search-empty-no-results` | unchanged |
| `finance_overview_tab` | `finance-empty-title` | **+ icon; title bodyLarge → titleMedium** |
| `networth_tab` | `networth-empty-title` | **+ icon; bodyLarge → titleMedium; gap 12 → 16** |
| `finance_transactions_tab` | `finance-transactions-empty` | **+ icon; bare unmuted line → titleMedium heading** |
| `split_tab` | `split-empty-title` | **+ icon; bodyLarge → titleMedium; "no friends yet" becomes the muted body; gaps 8/12/8 → 4/16/8/8** |
| `split_activity_section` | `split-activity-empty` | **+ icon; titleLarge → titleMedium; body muted; gap 8 → 4** |
| `friends_screen` | `friends-empty-state` (from the call site) | **+ icon; body muted; gap 8 → 4** |

**Tier 2 — inline note** (the region is inside a card or a section):

| Site | Key | Becomes |
|---|---|---|
| `exercise_screen` | `exercise-empty` | unchanged |
| `menstrual_screen` | `menstrual-empty-hint` | unchanged |
| `trend_card` | `trend-empty` | + centred |
| `today_screen` meal | *(none — located by text)* | + centred |
| `care_adherence_card` | `care-adherence-empty-state` | **guide → note: icon dropped, body line dropped; CTA kept beside it** |
| `budget_card` | `budget-empty-title` | **+ muted, + centred; gap 12 → 16** |
| `goal_card` | `goal-unset-prompt` | + centred |
| `split_tab` groups | `split-no-groups` | **+ muted, + centred** |
| `split_tab` activity | `split-no-activity` | **+ muted, + centred** |
| `group_detail_screen` | `split-group-no-expenses` | **+ muted, + centred** |

**Excluded, by judgment** — `care-today-summary-setup` (a tappable prompt,
not an explanation), `split-add-member-empty` (an `AlertDialog` body).

**Not empty states at all** — `careWeekdaysEmptyHint` (a field hint),
`splitAllSettledUp` ×3 (a settled-up *success* state), and
`goalNoData` / `healthCalendarNoData` / `nextPeriodNoRecords` (value
placeholders *inside* a ring or a calendar, not empty regions).

### 1.1 `budget_card` — tier 2, with the action kept beside the note

The tier is decided by the region, and the region is the budget rows inside
one card of a populated overview. So: the inline note. The CTA stays, as a
sibling of the note rather than part of it — the two tiers describe **how
emptiness is explained**, not whether a card may carry a button. `goal_card`
(found by this inventory) was already exactly that shape, which is what
makes it the repo's answer rather than an invention.

### 1.1b `care_adherence_card` — tier 2 as well (corrected after QA)

It was first filed as tier 1, and the inventory row said why: "the guide
shape, but with icon 40". That is a classification by **how it already
looked**, which 0.2 forbids in as many words. Adjudicated by region instead,
it lands in the same place as 1.1: the card draws its own header —
`titleLarge` title, "view history" button, 7/30/90 selector — *above this,
unconditionally*, and the card is one of two in the trends tab's `ListView`
with `TrendCard` directly above. The empty area is a region inside a
populated card, not a screen or a tab. Identical to `trend_card`,
`goal_card` and `budget_card`.

So: the note, with the CTA kept as its sibling per 1.1. The guide's second
line goes — tier 2 is one line, and "go to care management" carries the rest.
This also settles **3.4** (the icon that was 40 where everything else was 48):
tier 2 has no icon, so there is nothing left to reconcile.

One structural difference from `budget_card`/`goal_card`, which is why it is
not a copy of them: their parent columns are already
`crossAxisAlignment.stretch`, so the note's `TextAlign.center` has the card's
width to centre within. This card's parent column is
`crossAxisAlignment.start` (it left-aligns the header), under which a `Text`
shrink-wraps to its glyphs and the centring would be a no-op. The note and
its button therefore sit in their own `stretch` column. The card test
measures the note's painted width against the card's, so dropping that
alignment reddens it (verified: 242.25 vs 756.0).

### 1.1c The two neighbours on the finance overview — adjudicated by header

Review's sharpest finding: the budget card's tier-2 note and the month's
tier-1 guide sit ~16dp apart answering the same "new account, nothing here
yet", and the region argument that made `split_tab`'s Groups section tier 2
appeared to apply to the month guide too — two neighbouring screens answering
the same question oppositely.

It is not the same question, and the distinction is now written down as
**design D1b**: the tier follows *whether anything still on screen names the
region once it is empty*. Budget rows keep their card header; Groups keeps its
heading and its New group button (rendered outside the `isEmpty` branch); the
month's transactions keep nothing — the month header names the month, the
budget card names budgets. So the guide stays tier 1 and the note stays
tier 2, and D1b's table shows every other site lands the same way (it is also
exactly the argument 1.1b already used for `care_adherence_card`).

Pinned, one test per side, both mutation-verified:

| Test | Reddens when |
|---|---|
| `split_tab_test` "splits balances into owed-to-me…" | the Groups heading moves inside the `isEmpty` branch (verified: `Found 0 widgets with text "Groups"`) |
| `finance_overview_tab_test` "…different tiers because only one of the two regions is named by a header" | the month guide is demoted to a note (verified: `Found 0 widgets with type "EmptyStateGuide"`), or ends up inside a titled card |

### 1.2b `split_tab`'s three actions — the guide takes a *list*

A primary/secondary pair cannot express three, and a third shape would give
the standard an exception on its second day. `EmptyStateGuide.actions` is a
`List<Widget>`, 16 below the text and 8 apart — which is exactly what
`care_history` (two) and `split_tab` (three) already painted. Reading order
at `split_tab` is unchanged.

**One primary, the rest secondary** (added after review). The list shipped
with two `FilledButton`s — add-friend and record-an-expense — while the body
directly above says a friend is needed first, and the site's own comment
records that the record sheet cannot be saved in that state. Two equal-weight
first moves, one of which leads nowhere. `care_history` had it right all
along (`FilledButton` + `OutlinedButton`), so `split_tab` now follows it: the
record CTA is a `FilledButton` only when there are friends, and an
`OutlinedButton` while there are not. Keys unchanged on both.

The old 12dp break that weakly grouped add-friend with its reason is **not**
restored: the emphasis now carries that grouping, and a per-action gap would
mean widening the shared widget's API for one call site.

Pinned by the two existing empty-tab tests, each asserting the guide holds
exactly one `FilledButton` and which one it is. Mutation-verified: with the
pre-fix code (both `FilledButton`) the friendless test reddens with `Found 2
widgets with type "FilledButton"`.

### 1.3 `finance_transactions_tab` — promoted to tier 1, with no action

Tier by region: this fills the whole tab body. The absence of an action does
not demote it — tier 1's actions are optional. It gets **no** CTA because the
tab is handed no way to add a transaction, and plumbing one is a different
change. No new copy: it already shares `financeEmptyTitle` with the overview
tab, which does have the CTA.

### 2.2 `titleColor` — option (b): `food_search` keeps a private copy

`_ResultsMessage` stays, private, for the dictionary's **re-auth** and
**load-error** states, which is what `titleColor` was always for. Generalising
it would have moved re-auth into a shared empty-state widget whose re-auth job
already belongs to `AsyncStateScaffold` — two shared widgets owning re-auth is
worse than one 30-line private class. Its now-orphaned `body` parameter was
removed; nothing else there was touched.

### 2.3 Tier 2 *is* a widget

Three lines, and worth it: of the **ten** tier-2 sites in the table above,
nine were already this shape, and of those four had lost the muted colour and
**seven** the centring. Nothing but a shared widget stops the eleventh.

(The earlier "nine sites / four centring / the tenth" did not match the
table it sat under — corrected against it.)

### 3.2 One key was deleted: `split-empty-needs-friends`

Every other key survived on its original node. This one did not, and it is
recorded here rather than left to be discovered: `split_tab`'s "you have no
friends yet" line became `EmptyStateGuide.body`, and the guide takes its body
as a `String`, so there is no node left to hang a key on. Restoring it would
mean widening the shared widget's API (a `bodyKey`, used once) for a hook
**no test used** — 3.2 checked, and nothing referenced it. The copy is still
asserted, by `find.text(loc.splitNoFriendsYet)`, and the guide as a whole is
still located by `split-empty-title`.

Not a regression, but a deleted hook all the same: if a future test needs to
target that line specifically, add `bodyKey` to `EmptyStateGuide` — don't
re-split the body back out at the call site.

### 4. Narrow screens — the distribution moved, as predicted

Re-derived **after** the edits: every remaining tier-1 site is now either a
`ListView` child or sits in a scroll view (`food_search`, `care_history`),
**except `finance_transactions_tab`**, which is still a bare guide inside a
bounded `Center`.

That makes `finance_transactions_tab` the only **empty state this change
converted** whose `expectNoLayoutErrors` can still fire. It does **not** mean
nothing else in the app can throw — an earlier draft of this note said "only
`finance_transactions` can throw", which is false and would have sent the
next person looking in the wrong place. Concretely, QA found a **pre-existing**
horizontal overflow that has nothing to do with empty states:

> `care_adherence_card.dart:190` — the card's header `Row` (title +
> "view history" `TextButton.icon`) overflows by 131px at 320dp × textScale
> 2.0 in English. It predates this change (the header was not touched) and is
> **out of scope here**. Follow-up: the title needs to wrap or the button
> needs to collapse to its icon at that width.

`care_history` moved the other way: it *used* to be bounded and throwing;
adding the scroll view it needs at 320dp × 2.0 disarmed that guard, so its
narrow test measures instead (glyphs painted in full, both actions
`hitTestable` after scrolling).

**The measurement itself had to be redone.** The narrow tests originally
read `RenderParagraph.didExceedMaxLines` for "not ellipsized" — a flag that
is only ever true when `maxLines` is set, and `EmptyStateGuide`'s texts set
neither `maxLines` nor `overflow`. Structurally false, i.e. a guard that
cannot fail, of exactly the kind 4.3 exists to catch. Replaced by
`expectPaintedInFull` (`test/support/layout_guard.dart`), which asserts every
non-whitespace character actually painted a glyph.

**This note used to say "both narrow tests", i.e. that the defect was gone.
It was not — there were three, and the third was the shared widget's own**
(`test/shared/widgets/empty_state_test.dart`, five assertions: the guide's
title, its body and three action labels). Found by review, after the two
screen-level ones had been fixed and written up as if that were all of them.
Now also on `expectPaintedInFull`. Mutation-verified per instance:

| Mutation | Reddens |
|---|---|
| guide's title + body get `maxLines: 1` + ellipsis | the shared widget's narrow test, both locales (`-2`) |
| the test's own action labels get `maxLines: 1` + ellipsis | the same test's action-label assertions, en |

The lesson worth keeping is not the flag: it is that "fixed in both places"
was written without checking whether there were only two places.

`finance_transactions` was briefly given a scroll view too — then it was
taken back out, because no mutation could redden the guard while it was
there. The guide there is one short title and no action; it fits.

### 5. i18n — no new strings

Every promoted site reused copy it already had. Both ARB files are untouched.

### Follow-ups — seen, judged out of scope, not fixed here

Each of these is a real observation from review; none is a defect this change
introduced, and each would widen it past "unify the empty states".

1. **A guide's title + body are two utterances to a screen reader.** Wrapping
   them in a `MergeSemantics` would make it one — but only the *pair*, not the
   actions (those must stay separately focusable), so it means nesting the two
   `Text`s in their own column. That moves them out of `EmptyStateGuide`'s
   flat children list, which is what three of the widget's own tests index
   into (`_gapBefore`, and the "omits the body" length check). Worth doing;
   worth doing with its own tests rather than as a rider here.
2. **`Icons.call_split` on `split_tab`'s guide puns on the API name**, not on
   the concept — it is the flowchart branch glyph, not "sharing a bill".
   Picking the right icon is a copy/iconography decision, not a layout one.
3. **The four tier-2 notes now float centred under left-aligned headers**
   (`split-no-groups`, `split-no-activity`, `split-group-no-expenses`,
   `budget-empty-title`). The centring is the tier's rule and was the thing
   they were missing; whether a note under a left-aligned header should be
   left-aligned instead is a change to the *tier*, and would have to be
   applied to all ten sites at once.
4. **`finance_transactions_tab` renders identically to the overview guide but
   without its CTA** — same title, same icon, no way to act. Per 1.3 that is
   deliberate (the tab is handed no add path), but the duplicate-looking
   screen with a missing button is the kind of thing that reads as a bug.
   Plumbing the add path there is the fix, and it is a different change.

## 11. 「依區域判」花了四輪才變成一條真的規則

D1 從第一版就寫著「判準是區域,不是它現在長什麼樣」,而且我在四輪 proposal review 裡反覆強調。**但「區域」當時只是一個方向,不是判準** —— 結果是同一個詞被套出三種答案:

- apply 按「區域」判了 21 個站點,自己覺得一致;
- QA 第 1 輪用「區域」重判,抓到 `care_adherence_card` 判錯(而它當初是**按「它長得像引導」**分類的 —— 正是 0.2 明令禁止的);
- uiux leg 用「區域」再看,發現**兩個相鄰的財務畫面被判成相反的層**。

D1b 是第一個可檢查的版本(「空掉之後還有沒有東西替這塊區域命名」),而 QA 第 3 輪指出它**仍然不夠**:沒說「命名」算哪些東西,照字面讀 AppBar 標題會翻掉七個站點 —— 判別力來自套用的人,不是文字。補上「內容算、框架不算」之後才完整。

**規則要能被兩個不同的人套出同一個答案,才算規則。** 在此之前它只是寫的人心裡的直覺,而那個直覺被當成標準寫進了設計文件。
