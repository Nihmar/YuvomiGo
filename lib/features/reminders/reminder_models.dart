/// Un promemoria in scadenza (server: tabella `reminders` + titolo entità).
final class Reminder {
  const Reminder({
    required this.id,
    required this.entityType,
    required this.remindAt,
    this.entityTitle,
  });

  final int id;
  final String entityType;
  final String remindAt; // ISO 8601
  final String? entityTitle;

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
    id: (json['id'] as num?)?.toInt() ?? -1,
    entityType: json['entity_type'] as String? ?? '',
    remindAt: json['remind_at'] as String? ?? '',
    entityTitle: json['entity_title'] as String?,
  );
}

/// Etichetta breve dell'origine del promemoria.
String reminderOriginLabel(String entityType) => switch (entityType) {
  'task' => 'Task',
  'event' => 'Evento',
  'subscription' => 'Abbonamento',
  'inventory_item' => 'Scorte',
  'inventory_tracked_date' => 'Scorte',
  'pantry_item' => 'Dispensa',
  'waste_pickup' => 'Rifiuti',
  'schedule_entry' => 'Turno',
  'schedule_extra_entry' => 'Turno extra',
  'cycle_period' => 'Ciclo',
  'cycle_log_nudge' => 'Ciclo',
  _ => entityType,
};
