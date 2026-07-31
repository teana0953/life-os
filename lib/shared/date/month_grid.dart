/// [month]'s day cells, grouped into weeks (`null` for the leading/trailing
/// blanks), Sunday-first. Only [month]'s year and month components are used.
List<List<int?>> monthWeeks(DateTime month) {
  final firstOfMonth = DateTime(month.year, month.month, 1);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final leadingBlanks = firstOfMonth.weekday % 7; // DateTime.sunday == 7
  final cells = <int?>[
    for (var i = 0; i < leadingBlanks; i++) null,
    for (var day = 1; day <= daysInMonth; day++) day,
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
}
