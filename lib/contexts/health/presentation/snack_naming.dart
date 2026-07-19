/// The next name in a day's snack series (D5 in design.md): pure and
/// widget-independent so it's unit-testable without a controller/widget.
///
/// [mealNames] is the day's existing meal group names (standard meals and
/// snack groups alike — the call site passes `dayLog.meals.map((m) =>
/// m.meal)`). [snackWord] is the localized base snack word (e.g.
/// "點心"/"Snack").
///
/// A group counts toward the series only when its name is exactly
/// [snackWord] or [snackWord] followed by digits (a rename like "下午茶" and
/// the three standard meals don't match and are ignored). The result is the
/// base word alone when no series group exists yet, otherwise the base word
/// followed by (the highest number seen, treating a bare base word as `1`)
/// plus one — using max+1 rather than a plain count so a new session can't
/// collide with an existing group after an earlier one was deleted.
String nextSnackName(List<String> mealNames, String snackWord) {
  final pattern = RegExp('^${RegExp.escape(snackWord)}(\\d+)?\$');
  int? maxNumber;
  for (final name in mealNames) {
    final match = pattern.firstMatch(name);
    if (match == null) continue;
    final numberText = match.group(1);
    final number = numberText == null ? 1 : int.parse(numberText);
    if (maxNumber == null || number > maxNumber) maxNumber = number;
  }
  return maxNumber == null ? snackWord : '$snackWord${maxNumber + 1}';
}
