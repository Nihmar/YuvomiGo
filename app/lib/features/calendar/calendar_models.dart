final class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startDatetime,
    this.endDatetime,
    this.allDay = false,
    this.calendarName,
  });

  final int id;
  final String title;
  final String startDatetime; // ISO 8601
  final String? endDatetime;
  final bool allDay;
  final String? calendarName;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final allDayRaw = json['all_day'];
    final allDay = allDayRaw is bool
        ? allDayRaw
        : allDayRaw is num
        ? allDayRaw == 1
        : false;
    return CalendarEvent(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      startDatetime: json['start_datetime'] as String? ?? '',
      endDatetime: json['end_datetime'] as String?,
      allDay: allDay,
      calendarName: json['cal_name'] as String?,
    );
  }
}

/// Ordina per istante di inizio: confronta i `DateTime` (non le stringhe),
/// così eventi locali e instant con zona restano nell'ordine giusto.
/// Le date non parsabili finiscono in fondo.
int compareEventsByStart(CalendarEvent a, CalendarEvent b) {
  final ad = DateTime.tryParse(a.startDatetime);
  final bd = DateTime.tryParse(b.startDatetime);
  if (ad == null && bd == null) return 0;
  if (ad == null) return 1;
  if (bd == null) return -1;
  return ad.compareTo(bd);
}
