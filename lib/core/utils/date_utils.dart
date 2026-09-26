/// Chiave data `YYYY-MM-DD` (come la usa il server per `date`, `due_date`, …).
String dateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Il lunedì della settimana che contiene [date].
DateTime mondayOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return DateTime(day.year, day.month, day.day - (day.weekday - 1));
}
