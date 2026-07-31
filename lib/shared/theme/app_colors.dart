import 'package:flutter/material.dart';

/// Chiikawa-inspired pastel design tokens (see
/// `openspec/changes/add-design-system/design.md` for the source of truth).
/// Text/backgrounds never use pure black or pure white.

// Primary — Hachiware pale blue. Same hue in light and dark; only the
// on-primary ink and the surrounding surfaces shift.
const hachiwareBlue = Color(0xFF8FD3E6);
const onPrimaryLight = Color(0xFF284A54);
const onPrimaryDark = Color(0xFF173038);
const primaryDeep = Color(0xFF5EB5D3); // focus/border accent

// Accents — blush pink and Usagi yellow.
const blushPinkLight = Color(0xFFF6B0C1);
const blushPinkDark = Color(0xFFEE9DB0);
const usagiYellowLight = Color(0xFFFBE08A);
const usagiYellowDark = Color(0xFFEFCE78);

// Grounds and surfaces.
const groundLight = Color(0xFFFBF1E1);
const groundDark = Color(0xFF231D19);
const surfaceLight = Color(0xFFFFFDF8);
const surfaceDark = Color(0xFF2E2721);

// Ink (text) — soft brown, never pure black/white.
const inkLight = Color(0xFF5A4A3E);
const inkDark = Color(0xFFF3E9DC);
// Darkened from #96836F so subtitles/labels clear AA contrast (>= 4.5:1)
// on light surfaces; was ~3.58:1.
const mutedInkLight = Color(0xFF7C6952);
const mutedInkDark = Color(0xFFB6A695);

// Outline — soft brown border, echoes the hand-drawn line.
const outlineLight = Color(0xFFD8C3A6);
const outlineDark = Color(0xFF463A31);

// Semantic colors (kept separate from the brand palette).
const sageSuccess = Color(0xFF8FC79A);
const honeyWarning = Color(0xFFE0A94E);
const softError = Color(0xFFE98A94);
// Deeper AA-safe red for error *text* on light surfaces — `softError` is a
// pastel meant for borders/fills, not foreground text (~2.2-2.4:1 there).
const errorTextLight = Color(0xFFB4453D);

// Same idea as `errorTextLight`, for the chaodays import screen's per-type
// status icons: on the light card (`surfaceLight` #FFFDF8) the pastels they
// would otherwise use are far under the 3:1 that non-text graphics need
// (tertiary 1.28:1, primary 1.64:1 — and no pastel in this palette clears it:
// sage 1.91, honey 2.08, primaryDeep 2.29). These keep each icon's hue and
// drop lightness until it does. Dark theme keeps the pastels (8.8-9.6:1).
const importSuccessIconLight = Color(0xFFA88428); // 3.45:1 on #FFFDF8
const importRunningIconLight = Color(0xFF3F8FA6); // 3.63:1 on #FFFDF8

// Same idea again, for the finance ledger's income amounts (design.md):
// `sageSuccess` is a pastel meant for borders/fills, not foreground text —
// only ~1.9:1 on the light card, far under AA. `financeIncomeTextLight`
// keeps the sage hue and drops lightness to clear AA (6.26:1 on
// `surfaceLight`). The dark theme's pastel already clears AA there and is
// kept as-is (see `financeIncomeColor` in `app_theme.dart`).
const financeIncomeTextLight = Color(0xFF2E6B41); // 6.26:1 on #FFFDF8

// Same idea again, for the finance budget card's "approaching the limit"
// (>= 80%) warning row (design.md): `honeyWarning` is a pastel meant for
// borders/fills, not foreground text — only ~2.08:1 on the light card, far
// under AA. `financeBudgetWarningTextLight` keeps the honey hue and drops
// lightness to clear AA (4.96:1 on `surfaceLight`). The dark theme's pastel
// already clears AA there (6.97:1) and is kept as-is (see
// `financeBudgetWarningColor` in `app_theme.dart`).
const financeBudgetWarningTextLight = Color(0xFF8A6A1E); // 4.96:1 on #FFFDF8

// Diet category colors (staple/meat/fruit/veg) — exposed via the
// `DietCategoryColors` ThemeExtension in `app_theme.dart`, never referenced
// directly from screens.
const dietStapleLight = usagiYellowLight;
const dietStapleDark = usagiYellowDark;
const dietMeatLight = blushPinkLight;
const dietMeatDark = blushPinkDark;
const dietFruitLight = Color(0xFFF7B98C);
const dietFruitDark = Color(0xFFE0A374);
const dietVegLight = Color(0xFFA8D5B0);
const dietVegDark = Color(0xFF7FAF8C);
