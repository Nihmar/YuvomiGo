/// Un membro del household (per etichettare i turni).
final class ScheduleMember {
  const ScheduleMember({
    required this.id,
    required this.displayName,
    this.avatarColor,
  });

  final int id;
  final String displayName;
  final String? avatarColor;

  factory ScheduleMember.fromJson(Map<String, dynamic> json) => ScheduleMember(
    id: (json['id'] as num?)?.toInt() ?? -1,
    displayName: json['display_name'] as String? ?? '',
    avatarColor: json['avatar_color'] as String?,
  );
}

/// Un tipo di turno (server: `schedule_shift_types`).
final class ShiftType {
  const ShiftType({
    required this.id,
    required this.name,
    this.shortCode,
    this.startTime,
    this.endTime,
    this.color,
    this.icon,
  });

  final int id;
  final String name;
  final String? shortCode;
  final String? startTime; // 'HH:MM'
  final String? endTime;
  final String? color;
  final String? icon;

  factory ShiftType.fromJson(Map<String, dynamic> json) => ShiftType(
    id: (json['id'] as num?)?.toInt() ?? -1,
    name: json['name'] as String? ?? '',
    shortCode: json['short_code'] as String?,
    startTime: json['start_time'] as String?,
    endTime: json['end_time'] as String?,
    color: json['color'] as String?,
    icon: json['icon'] as String?,
  );
}

/// Un turno risolto per un giorno (server: `GET /schedule/entries`).
final class ScheduleEntry {
  const ScheduleEntry({
    required this.userId,
    required this.dateKey,
    this.source = 'pattern',
    this.shiftType,
    this.note,
    this.isFree = false,
    this.crossesMidnight = false,
  });

  final int userId;
  final String dateKey; // 'YYYY-MM-DD'
  final String source; // pattern|override|extra
  final ShiftType? shiftType;
  final String? note;
  final bool isFree;
  final bool crossesMidnight;

  String get label => isFree || shiftType == null ? 'Riposo' : shiftType!.name;

  /// 'HH:MM–HH:MM', vuoto se il tipo non ha orari.
  String get timeLabel {
    final start = shiftType?.startTime;
    final end = shiftType?.endTime;
    if (start == null || end == null) return '';
    final suffix = crossesMidnight ? ' (+1)' : '';
    return '$start–$end$suffix';
  }

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) {
    final rawType = json['shift_type'];
    return ScheduleEntry(
      userId: (json['user_id'] as num?)?.toInt() ?? -1,
      dateKey: json['date_key'] as String? ?? '',
      source: json['source'] as String? ?? 'pattern',
      shiftType: rawType is Map<String, dynamic>
          ? ShiftType.fromJson(rawType)
          : null,
      note: json['note'] as String?,
      isFree: json['is_free'] == true,
      crossesMidnight: json['crosses_midnight'] == true,
    );
  }
}

/// La settimana risolta (`data.entries` della risposta).
final class ScheduleWeek {
  const ScheduleWeek({this.entries = const []});

  final List<ScheduleEntry> entries;

  factory ScheduleWeek.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final raw = data['entries'] is List ? data['entries'] as List : const [];
    return ScheduleWeek(
      entries: raw
          .whereType<Map<String, dynamic>>()
          .map(ScheduleEntry.fromJson)
          .toList(),
    );
  }
}

/// Ordina i turni di un giorno per orario d'inizio, poi per nome.
int compareScheduleEntries(ScheduleEntry a, ScheduleEntry b) {
  final at = a.shiftType?.startTime ?? '99:99';
  final bt = b.shiftType?.startTime ?? '99:99';
  final byTime = at.compareTo(bt);
  if (byTime != 0) return byTime;
  return a.label.toLowerCase().compareTo(b.label.toLowerCase());
}
