import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/theme/app_colors.dart';
import 'package:life_os/shared/theme/app_theme.dart';

/// WCAG 2.x relative luminance / contrast ratio, used to assert AA
/// compliance (>= 4.5:1 for body text) of theme colors against the
/// surfaces they're actually drawn on.
double _relativeLuminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  final r = channel(color.r);
  final g = channel(color.g);
  final b = channel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('lightTheme', () {
    test('uses Material 3', () {
      expect(lightTheme.useMaterial3, isTrue);
    });

    test('color scheme primary is the Hachiware blue', () {
      expect(lightTheme.colorScheme.primary, hachiwareBlue);
    });

    test('color scheme brightness is light', () {
      expect(lightTheme.colorScheme.brightness, Brightness.light);
    });

    // login_screen.dart and home_screen.dart both paint error messages
    // directly with `theme.colorScheme.error` as the foreground text
    // color. In light mode that text sits on `colorScheme.surface`
    // (login's card) or on the scaffold background `groundLight` (home's
    // error state) — both light, cream-ish surfaces — so the error color
    // must be a foreground-safe AA color (>= 4.5:1), not the pastel
    // `softError` swatch used for borders/fills.
    test('error text color meets AA contrast on surface', () {
      expect(
        _contrastRatio(lightTheme.colorScheme.error, surfaceLight),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('error text color meets AA contrast on the ground background', () {
      expect(
        _contrastRatio(lightTheme.colorScheme.error, groundLight),
        greaterThanOrEqualTo(4.5),
      );
    });

    // onSurfaceVariant (mutedInkLight) is used for subtitles/labels drawn
    // on `colorScheme.surface` (e.g. the "Sign in to Life OS" subtitle and
    // the profile id text) and must stay readable.
    test('onSurfaceVariant text color meets AA contrast on surface', () {
      expect(
        _contrastRatio(lightTheme.colorScheme.onSurfaceVariant, surfaceLight),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('darkTheme', () {
    test('uses Material 3', () {
      expect(darkTheme.useMaterial3, isTrue);
    });

    test('color scheme primary is the Hachiware blue', () {
      expect(darkTheme.colorScheme.primary, hachiwareBlue);
    });

    test('color scheme brightness is dark', () {
      expect(darkTheme.colorScheme.brightness, Brightness.dark);
    });

    // Dark mode error text contrast is already fine (per uiux review) —
    // lock in that it keeps using the pastel `softError` swatch rather
    // than picking up the new light-mode-only deep error text color.
    test('error color stays the pastel softError swatch', () {
      expect(darkTheme.colorScheme.error, softError);
    });
  });

  group('filledButtonTheme disabled state', () {
    test(
      'light theme disabled fill is a soft primary tint, not Material grey',
      () {
        final style = lightTheme.filledButtonTheme.style!;
        final disabledBg = style.backgroundColor?.resolve({
          WidgetState.disabled,
        });
        expect(disabledBg, hachiwareBlue.withValues(alpha: 0.18));
      },
    );

    test('light theme disabled foreground uses the outline color', () {
      final style = lightTheme.filledButtonTheme.style!;
      final disabledFg = style.foregroundColor?.resolve({
        WidgetState.disabled,
      });
      expect(disabledFg, outlineLight);
    });
  });

  // The chaodays import screen locks its checkboxes while a run is under way,
  // and the box is then the only thing saying "this one is queued" rather than
  // "this one was left out". M3 paints both disabled states with
  // onSurface@38% — 1.91:1 on the cream card — so the two are pulled apart
  // into opaque colors here.
  group('checkboxTheme disabled state', () {
    Color? disabledFill(ThemeData theme) => theme.checkboxTheme.fillColor
        ?.resolve({WidgetState.disabled, WidgetState.selected});

    Color? disabledOutline(ThemeData theme) =>
        WidgetStateProperty.resolveAs<BorderSide?>(theme.checkboxTheme.side, {
          WidgetState.disabled,
        })?.color;

    test('light theme disabled fill and outline are different colors', () {
      expect(disabledFill(lightTheme), isNotNull);
      expect(disabledOutline(lightTheme), isNotNull);
      expect(disabledFill(lightTheme), isNot(disabledOutline(lightTheme)));
    });

    test('light theme disabled fill and outline each clear 3:1 on the card', () {
      // Non-text graphics need 3:1. The filled box is 8.32:1 on surfaceLight,
      // the hollow one's outline 5.17:1 — and 1.61:1 apart from each other,
      // on top of the solid-vs-hollow difference.
      expect(
        _contrastRatio(disabledFill(lightTheme)!, surfaceLight),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrastRatio(disabledOutline(lightTheme)!, surfaceLight),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('dark theme keeps the Material defaults', () {
      // 3.06:1 there already, so it needs no help — and _buildTheme is shared,
      // so this pins that the override forks by brightness.
      expect(darkTheme.checkboxTheme, const CheckboxThemeData());
    });
  });

  group('DietCategoryColors', () {
    test('is registered on the light theme with the light palette', () {
      final colors = lightTheme.extension<DietCategoryColors>();
      expect(colors, isNotNull);
      expect(colors!.staple, dietStapleLight);
      expect(colors.meat, dietMeatLight);
      expect(colors.fruit, dietFruitLight);
      expect(colors.veg, dietVegLight);
    });

    test('is registered on the dark theme with the dark palette', () {
      final colors = darkTheme.extension<DietCategoryColors>();
      expect(colors, isNotNull);
      expect(colors!.staple, dietStapleDark);
      expect(colors.meat, dietMeatDark);
      expect(colors.fruit, dietFruitDark);
      expect(colors.veg, dietVegDark);
    });

    test('lerp interpolates between two instances', () {
      const a = DietCategoryColors(
        staple: Color(0xFF000000),
        meat: Color(0xFF000000),
        fruit: Color(0xFF000000),
        veg: Color(0xFF000000),
      );
      const b = DietCategoryColors(
        staple: Color(0xFFFFFFFF),
        meat: Color(0xFFFFFFFF),
        fruit: Color(0xFFFFFFFF),
        veg: Color(0xFFFFFFFF),
      );

      final result = a.lerp(b, 1.0);

      expect(result.staple, const Color(0xFFFFFFFF));
    });
  });
}
