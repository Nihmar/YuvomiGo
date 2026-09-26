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
