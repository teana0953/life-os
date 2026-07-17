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
