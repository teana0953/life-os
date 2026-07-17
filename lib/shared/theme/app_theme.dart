import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Chiikawa-inspired pastel Material 3 theme. See
/// `openspec/changes/add-design-system/design.md` for the design tokens.
///
/// Component themes use the `*ThemeData` types (`CardThemeData`,
/// `InputDecorationTheme`, ...) rather than the deprecated non-`Data`
/// aliases — Flutter 3.35's `ThemeData` constructor expects the `*Data`
/// types, and using the old names trips `flutter analyze`.

const _cardRadius = 22.0;
const _inputRadius = 14.0;
const _pillRadius = 999.0;
const _borderWidth = 2.0;
const _fontFamily = 'Quicksand';

ThemeData get lightTheme => _buildTheme(
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: hachiwareBlue,
        onPrimary: onPrimaryLight,
        secondary: blushPinkLight,
        onSecondary: onPrimaryLight,
        tertiary: usagiYellowLight,
        onTertiary: onPrimaryLight,
        error: softError,
        onError: onPrimaryLight,
        surface: surfaceLight,
        onSurface: inkLight,
        outline: outlineLight,
        surfaceContainerHighest: groundLight,
        onSurfaceVariant: mutedInkLight,
      ),
      scaffoldBackground: groundLight,
      ink: inkLight,
      outline: outlineLight,
    );

ThemeData get darkTheme => _buildTheme(
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: hachiwareBlue,
        onPrimary: onPrimaryDark,
        secondary: blushPinkDark,
        onSecondary: onPrimaryDark,
        tertiary: usagiYellowDark,
        onTertiary: onPrimaryDark,
        error: softError,
        onError: onPrimaryDark,
        surface: surfaceDark,
        onSurface: inkDark,
        outline: outlineDark,
        surfaceContainerHighest: groundDark,
        onSurfaceVariant: mutedInkDark,
      ),
      scaffoldBackground: groundDark,
      ink: inkDark,
      outline: outlineDark,
    );

ThemeData _buildTheme({
  required ColorScheme colorScheme,
  required Color scaffoldBackground,
  required Color ink,
  required Color outline,
}) {
  final textTheme = _textTheme(ink);
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBackground,
    fontFamily: _fontFamily,
    textTheme: textTheme,
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
        side: BorderSide(color: outline, width: _borderWidth),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: BorderSide(color: outline, width: _borderWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: BorderSide(color: outline, width: _borderWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: const BorderSide(color: primaryDeep, width: _borderWidth),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_pillRadius),
          side: BorderSide(color: outline, width: _borderWidth),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        side: BorderSide(color: outline, width: _borderWidth),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_pillRadius),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
  );
}

TextTheme _textTheme(Color ink) {
  return TextTheme(
    headlineMedium: TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 28,
      height: 1.3,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 20,
      height: 1.3,
      color: ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: ink),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: ink),
    labelLarge: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
  );
}

/// The "toy ledge" shadow used under cards and primary buttons: a soft,
/// downward-offset shadow rather than a symmetric `elevation` blur. Wrap a
/// `Container`/`Material` with this via `BoxDecoration.boxShadow`.
List<BoxShadow> ledgeShadow(Color outline) => [
      BoxShadow(
        color: outline.withValues(alpha: 0.55),
        offset: const Offset(0, 4),
        blurRadius: 0,
      ),
    ];
