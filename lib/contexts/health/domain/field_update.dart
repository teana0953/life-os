/// Distinguishes a field left untouched (absent from a PATCH body — the
/// backend treats an absent key as "leave alone") from a field explicitly
/// set, including explicitly set to `null` (which clears it). Plain
/// nullable fields can't express this: `null` would be ambiguous between
/// "not supplied" and "clear it".
class FieldUpdate<T> {
  final bool isSet;
  final T? value;

  const FieldUpdate.unset() : isSet = false, value = null;
  const FieldUpdate.set(this.value) : isSet = true;
}
