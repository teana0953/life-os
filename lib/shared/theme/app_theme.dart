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

/// Per-food-group colors for the diet module (staple/meat/fruit/veg),
/// registered as a `ThemeData.extensions` entry on both themes. Screens read
/// it via `Theme.of(context).extension<DietCategoryColors>()` rather than
/// hard-coding the raw tokens from `app_colors.dart`.
class DietCategoryColors extends ThemeExtension<DietCategoryColors> {
  final Color staple;
  final Color meat;
  final Color fruit;
  final Color veg;

  const DietCategoryColors({
    required this.staple,
    required this.meat,
    required this.fruit,
    required this.veg,
  });

  @override
  DietCategoryColors copyWith({
    Color? staple,
    Color? meat,
    Color? fruit,
    Color? veg,
  }) {
    return DietCategoryColors(
      staple: staple ?? this.staple,
      meat: meat ?? this.meat,
      fruit: fruit ?? this.fruit,
      veg: veg ?? this.veg,
    );
  }

  @override
  DietCategoryColors lerp(ThemeExtension<DietCategoryColors>? other, double t) {
    if (other is! DietCategoryColors) return this;
    return DietCategoryColors(
      staple: Color.lerp(staple, other.staple, t)!,
      meat: Color.lerp(meat, other.meat, t)!,
      fruit: Color.lerp(fruit, other.fruit, t)!,
      veg: Color.lerp(veg, other.veg, t)!,
    );
  }
}

const _dietCategoryColorsLight = DietCategoryColors(
  staple: dietStapleLight,
  meat: dietMeatLight,
  fruit: dietFruitLight,
  veg: dietVegLight,
);

const _dietCategoryColorsDark = DietCategoryColors(
  staple: dietStapleDark,
  meat: dietMeatDark,
  fruit: dietFruitDark,
  veg: dietVegDark,
);

ThemeData get lightTheme => _buildTheme(
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: hachiwareBlue,
        onPrimary: onPrimaryLight,
        secondary: blushPinkLight,
        onSecondary: onPrimaryLight,
        tertiary: usagiYellowLight,
        onTertiary: onPrimaryLight,
        // `softError` is a pastel meant for borders/fills; error *text*
        // (login/home error messages) needs the deeper AA-safe red.
        error: errorTextLight,
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
      dietCategoryColors: _dietCategoryColorsLight,
      checkboxTheme: _checkboxThemeLight,
    );

/// Light-theme disabled checkbox. Material 3 paints both disabled states with
/// `onSurface` at 38% — 1.91:1 on the cream card — leaving "checked but
/// locked" and "left out of this run" almost indistinguishable, which the
/// chaodays import screen relies on while a run is under way. Opaque colors
/// instead: an ink-filled box (8.32:1 on `surfaceLight`) against a muted-ink
/// outline (5.17:1). Both resolvers return null outside the disabled state so
/// every other state keeps the Material defaults; the dark theme sets no
/// override at all. Note the dark side is NOT verified as *distinguishable*:
/// its two disabled states are the same colour (1.00:1 apart). The 3.06:1
/// often quoted for it measures visibility against the card, which is a
/// different question — see the change's design D4.
final _checkboxThemeLight = CheckboxThemeData(
  fillColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled) &&
            states.contains(WidgetState.selected)
        ? inkLight
        : null,
  ),
  side: WidgetStateBorderSide.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? const BorderSide(color: mutedInkLight, width: _borderWidth)
        : null,
  ),
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
      dietCategoryColors: _dietCategoryColorsDark,
    );

ThemeData _buildTheme({
  required ColorScheme colorScheme,
  required Color scaffoldBackground,
  required Color ink,
  required Color outline,
  required DietCategoryColors dietCategoryColors,
  CheckboxThemeData? checkboxTheme,
}) {
  final textTheme = _textTheme(ink);
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBackground,
    fontFamily: _fontFamily,
    textTheme: textTheme,
    extensions: [dietCategoryColors],
    checkboxTheme: checkboxTheme,
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
        // Themed disabled state (soft primary tint + outline ink) instead
        // of Material's default onSurface-grey fallback, so it stays
        // visually consistent with the rest of the palette.
        disabledBackgroundColor: colorScheme.primary.withValues(alpha: 0.18),
        disabledForegroundColor: outline,
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

/// Color for the chaodays import screen's "this type succeeded" icon. The
/// pastel `tertiary` it would otherwise use is 1.28:1 on the light card, far
/// under the 3:1 a non-text graphic needs, so the light theme swaps in the
/// deeper [importSuccessIconLight] (3.45:1); the dark theme's pastel already
/// clears it (9.64:1) and is kept.
Color importSuccessIconColor(ColorScheme scheme) =>
    scheme.brightness == Brightness.light
        ? importSuccessIconLight
        : scheme.tertiary;

/// Same as [importSuccessIconColor] for the "this type is running" spinner:
/// `primary` is 1.64:1 on the light card, [importRunningIconLight] is 3.63:1.
Color importRunningIconColor(ColorScheme scheme) =>
    scheme.brightness == Brightness.light
        ? importRunningIconLight
        : scheme.primary;

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
