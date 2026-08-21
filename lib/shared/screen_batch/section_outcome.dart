/// How one section of a batch screen-read response ended up.
///
/// Three-valued rather than nullable on purpose (design D2): a card has to
/// tell "the backend answered with no data" from "this section failed", and
/// a `401` is a fourth thing again — the re-authentication exit, which only a
/// request-level failure can produce.
///
/// [SectionUnavailable] covers both `{ ok: false }` and a `data` that fails
/// to decode: no card can act differently on them.
sealed class SectionOutcome<T> {
  const SectionOutcome();

  const factory SectionOutcome.ok(T value) = SectionOk<T>;

  const factory SectionOutcome.unavailable() = SectionUnavailable<T>;

  const factory SectionOutcome.reauth() = SectionReauth<T>;
}

final class SectionOk<T> extends SectionOutcome<T> {
  final T value;

  const SectionOk(this.value);
}

final class SectionUnavailable<T> extends SectionOutcome<T> {
  const SectionUnavailable();
}

final class SectionReauth<T> extends SectionOutcome<T> {
  const SectionReauth();
}

/// Decodes one `{ ok, data }` section envelope with [decode].
///
/// Anything that is not an `ok: true` envelope whose `data` decodes cleanly —
/// a missing key, `{ ok: false }`, a payload of the wrong shape — becomes
/// [SectionUnavailable], which is the one failure state a card has for a
/// section it could not read.
SectionOutcome<T> decodeSection<T>(
  Object? raw,
  T Function(Object? data) decode,
) {
  if (raw is! Map<String, dynamic>) return SectionUnavailable<T>();
  if (raw['ok'] != true) return SectionUnavailable<T>();
  try {
    return SectionOk<T>(decode(raw['data']));
  } catch (_) {
    return SectionUnavailable<T>();
  }
}

/// The outcome every section of a screen gets when the *request* failed:
/// [SectionReauth] for a `401`, [SectionUnavailable] for everything else
/// (design D5 — there is one apply path, not a success path and a separate
/// failure path).
SectionOutcome<T> requestFailureOutcome<T>({required bool reauth}) =>
    reauth ? SectionReauth<T>() : SectionUnavailable<T>();
