import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs [body] with `FlutterError.onError` redirected so that **every** error
/// reported while it runs is collected, and returns them.
///
/// Why not `tester.takeException()`: the test binding keeps only the *first*
/// exception of a test, so draining it hides every subsequent one — a screen
/// with a known overflow silently absorbs any new one. Overriding
/// `FlutterError.onError` is the only way to see them all.
///
/// Two traps this deliberately avoids (both hit for real while writing these
/// guards):
///
/// 1. The override is restored in a `finally`, **before** the caller asserts.
///    Asserting while `onError` is still redirected makes the binding's
///    "an error was reported while the test was running" assert
///    (`binding.dart`) fire on the *expect* failure and mask the real error.
/// 2. The collector never throws. An exception thrown inside an
///    `FlutterError.onError` callback makes the whole test run hang forever
///    with no red output.
///
/// The binding restores its own `onError` in `postTest`, so this does not leak
/// into other tests.
Future<List<FlutterErrorDetails>> collectLayoutErrors(
  Future<void> Function() body,
) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details);
  };
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

/// Runs [body] and asserts it reported no layout error at all.
///
/// Not limited to `RenderFlex` overflows on purpose: a `ListTile` whose
/// trailing content cannot be laid out raises a plain assertion instead, and a
/// RenderFlex-only filter would let it pass unfixed.
Future<void> expectNoLayoutErrors(
  Future<void> Function() body, {
  String? reason,
}) async {
  final errors = await collectLayoutErrors(body);
  if (errors.isEmpty) return;
  final summary = errors
      .map((e) => e.exception.toString().split('\n').first)
      .join('\n  - ');
  fail(
    '${reason ?? 'Expected no layout errors'}, but ${errors.length} were '
    'reported:\n  - $summary',
  );
}
