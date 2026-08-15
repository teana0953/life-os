// PWA icon generator (NOT a normal test).
//
// Renders the real [Mascot] widget to PNGs on a cream background and writes
// them into `web/icons/` and `web/`. It is GUARDED: it only runs when the
// `GENERATE_PWA_ICONS` environment variable is set, so `flutter test` skips it
// in the normal suite. Regenerate the icons with:
//
//   GENERATE_PWA_ICONS=1 flutter test test/tool/generate_pwa_icons_test.dart
//
// The generated PNGs are committed to the tree; this file stays for
// reproducibility.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/theme/app_theme.dart';
import 'package:life_os/shared/widgets/mascot.dart';

/// Chiikawa cream ground (`groundLight`, `#FBF1E1`). Hard-coded here rather
/// than imported from `app_colors.dart` so the icon background is explicit and
/// matches the manifest `background_color`.
const _cream = Color(0xFFFBF1E1);

Future<void> _renderIcon(
  WidgetTester tester, {
  required double sizePx,
  required double mascotFraction,
  required String path,
}) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(Size(sizePx, sizePx));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      home: RepaintBoundary(
        key: key,
        child: Container(
          width: sizePx,
          height: sizePx,
          color: _cream,
          child: Center(child: Mascot(size: sizePx * mascotFraction)),
        ),
      ),
    ),
  );
  // A static CustomPaint needs no settling; pump one frame so the
  // RepaintBoundary has something to snapshot. `pumpAndSettle` can hang here.
  await tester.pump();

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // PNG encoding is real async work that never completes inside the test's
  // fake-async zone — run it through `runAsync` so the futures resolve.
  final pngBytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(pngBytes!);
}

void main() {
  testWidgets(
    'generate PWA icons from the Mascot',
    (tester) async {
      // Standard icons: mascot with ~12% padding on cream.
      await _renderIcon(tester,
          sizePx: 192, mascotFraction: 0.76, path: 'web/icons/Icon-192.png');
      await _renderIcon(tester,
          sizePx: 512, mascotFraction: 0.76, path: 'web/icons/Icon-512.png');

      // Maskable icons: full-bleed cream, mascot within the ~80% safe zone so
      // the OS mask can crop the corners without clipping the face.
      await _renderIcon(tester,
          sizePx: 192,
          mascotFraction: 0.80,
          path: 'web/icons/Icon-maskable-192.png');
      await _renderIcon(tester,
          sizePx: 512,
          mascotFraction: 0.80,
          path: 'web/icons/Icon-maskable-512.png');

      await _renderIcon(tester,
          sizePx: 64, mascotFraction: 0.76, path: 'web/favicon.png');

      // Apple touch icon: cream background (NO transparency — iOS adds its own
      // rounding), mascot with small padding.
      await _renderIcon(tester,
          sizePx: 180,
          mascotFraction: 0.85,
          path: 'web/icons/apple-touch-icon.png');
    },
    skip: Platform.environment['GENERATE_PWA_ICONS'] == null,
  );
}
