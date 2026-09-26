/// Stati task (dal web reference: open, in_progress, done).
enum TaskStatus { open, inProgress, done }

extension TaskStatusX on TaskStatus {
  String get wire => switch (this) {
    TaskStatus.open => 'open',
    TaskStatus.inProgress => 'in_progress',
    TaskStatus.done => 'done',
  };

  static TaskStatus fromWire(String? value) => switch (value) {
    'in_progress' => TaskStatus.inProgress,
    'done' => TaskStatus.done,
    _ => TaskStatus.open,
  };
}

/// Ordinamento della lista MVP: per due_date (null = ultime).
///
/// Scelta deliberata: il server ordina per stato → priorità → due_date, ma
/// in una lista mobile "cosa scade prima" è più utile di "quanto è urgente".
int compareTasksByDueDate(Task a, Task b) {
  final ad = a.dueDate ?? '9999-99-99';
  final bd = b.dueDate ?? '9999-99-99';
  return ad.compareTo(bd);
}

final class Task {
  const Task({
    required this.id,
    required this.title,
    this.status = TaskStatus.open,
    this.priority = 'none',
    this.dueDate,
    this.startDate,
    this.category,
    this.isRecurring = false,
    this.archivedAt,
  });

  final int id;
  final String title;
  final TaskStatus status;
  final String priority; // urgent|high|medium|low|none
  final String? dueDate; // 'YYYY-MM-DD'
  final String? startDate;
  final String? category;
  final bool isRecurring;
  final String? archivedAt;

  factory Task.fromJson(Map<String, dynamic> json) {
    final recurring = json['is_recurring'];
    final isRecurring = recurring is bool
        ? recurring
        : recurring is num
        ? recurring == 1
        : false;
    return Task(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      status: TaskStatusX.fromWire(json['status'] as String?),
      priority: json['priority'] as String? ?? 'none',
      dueDate: json['due_date'] as String?,
      startDate: json['start_date'] as String?,
      category: json['category'] as String?,
      isRecurring: isRecurring,
      archivedAt: json['archived_at'] as String?,
    );
  }
}
