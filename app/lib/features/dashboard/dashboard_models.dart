final class DashboardData {
  const DashboardData({
    this.upcomingEvents = const [],
    this.urgentTasks = const [],
    this.openTaskCount,
    this.overdueTaskCount,
    this.pinnedNotes = const [],
    this.pinnedNotesCount = 0,
    this.shoppingLists = const [],
    this.shoppingOpenCount,
    this.shoppingOpenLists = 0,
    this.todayMeals = const [],
  });

  /// Prossimi 5 eventi (calendario).
  final List<DashEvent> upcomingEvents;

  /// Task urgenti/overdue (max 5).
  final List<DashTask> urgentTasks;

  /// Numero di task aperti (null = non disponibile).
  final int? openTaskCount;

  /// Numero di task overdue (null = non disponibile).
  final int? overdueTaskCount;

  /// Notizen pinnate / recenti (max 5).
  final List<DashNote> pinnedNotes;

  /// Numero reale di note pinnate.
  final int pinnedNotesCount;

  /// Liste di spesa con articoli aperti (max 3).
  final List<DashShoppingList> shoppingLists;

  /// Numero di articoli di spesa aperti (null = non disponibile).
  final int? shoppingOpenCount;

  /// Numero di liste con articoli aperti.
  final int shoppingOpenLists;

  /// Pasti di oggi (dal widget omonimo del server).
  final List<DashMeal> todayMeals;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    List<T> asList<T>(Object? v, T Function(Map<String, dynamic>) from) {
      if (v is! List) return const [];
      return v.whereType<Map<String, dynamic>>().map(from).toList();
    }

    return DashboardData(
      upcomingEvents: asList(json['upcomingEvents'], DashEvent.fromJson),
      urgentTasks: asList(json['urgentTasks'], DashTask.fromJson),
      openTaskCount: asInt(json['openTaskCount']),
      overdueTaskCount: asInt(json['overdueTaskCount']),
      pinnedNotes: asList(json['pinnedNotes'], DashNote.fromJson),
      pinnedNotesCount: asInt(json['pinnedNotesCount']) ?? 0,
      shoppingLists: asList(json['shoppingLists'], DashShoppingList.fromJson),
      shoppingOpenCount: asInt(json['shoppingOpenCount']),
      shoppingOpenLists: asInt(json['shoppingOpenLists']) ?? 0,
      todayMeals: asList(json['todayMeals'], DashMeal.fromJson),
    );
  }
}

/// Un task (riga DB `tasks` + colonne aggiunte dal server).
final class DashTask {
  const DashTask({
    required this.id,
    required this.title,
    this.priority = 'none',
    this.status = 'open',
    this.dueDate,
    this.dueTime,
    this.assignedName,
    this.assignedColor,
  });

  final int id;
  final String title;
  final String priority;
  final String status;
  final String? dueDate;
  final String? dueTime;
  final String? assignedName;
  final String? assignedColor;

  factory DashTask.fromJson(Map<String, dynamic> json) => DashTask(
    id: json['id'] is int ? json['id'] as int : -1,
    title: json['title'] as String? ?? '',
    priority: json['priority'] as String? ?? 'none',
    status: json['status'] as String? ?? 'open',
    dueDate: json['due_date'] as String?,
    dueTime: json['due_time'] as String?,
    assignedName: json['assigned_name'] as String?,
    assignedColor: json['assigned_color'] as String?,
  );
}

/// Un evento (riga DB `calendar_events`, serializzata dal server).
final class DashEvent {
  const DashEvent({
    required this.id,
    required this.title,
    this.startDatetime,
    this.allDay = false,
    this.location,
    this.color,
  });

  final int id;
  final String title;
  final String? startDatetime;
  final bool allDay;
  final String? location;
  final String? color;

  factory DashEvent.fromJson(Map<String, dynamic> json) => DashEvent(
    id: json['id'] is int ? json['id'] as int : -1,
    title: json['title'] as String? ?? '',
    startDatetime: json['start_datetime'] as String?,
    allDay: _asBool(json['all_day']),
    location: json['location'] as String?,
    color: json['color'] as String?,
  );
}

/// Una nota (riga DB `notes` + colonne autore).
final class DashNote {
  const DashNote({
    required this.id,
    this.title,
    required this.content,
    this.pinned = false,
    this.color,
    this.authorName,
    this.updatedAt,
  });

  final int id;
  final String? title;
  final String content;
  final bool pinned;
  final String? color;
  final String? authorName;
  final String? updatedAt;

  factory DashNote.fromJson(Map<String, dynamic> json) => DashNote(
    id: json['id'] is int ? json['id'] as int : -1,
    title: json['title'] as String?,
    content: json['content'] as String? ?? '',
    pinned: _asBool(json['pinned']),
    color: json['color'] as String?,
    authorName: json['author_name'] as String?,
    updatedAt: json['updated_at'] as String?,
  );
}

/// Una lista di spesa con gli articoli aperti.
final class DashShoppingList {
  const DashShoppingList({
    required this.id,
    required this.name,
    this.openCount = 0,
    this.totalCount = 0,
    this.items = const [],
  });

  final int id;
  final String name;
  final int openCount;
  final int totalCount;
  final List<DashShoppingItem> items;

  factory DashShoppingList.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] is List)
        ? (json['items'] as List)
              .whereType<Map<String, dynamic>>()
              .map(DashShoppingItem.fromJson)
              .toList()
        : const <DashShoppingItem>[];
    return DashShoppingList(
      id: json['id'] is int ? json['id'] as int : -1,
      name: json['name'] as String? ?? '',
      openCount: _asInt(json['open_count']) ?? 0,
      totalCount: _asInt(json['total_count']) ?? 0,
      items: items,
    );
  }
}

/// Un articolo di spesa.
final class DashShoppingItem {
  const DashShoppingItem({
    required this.id,
    required this.name,
    this.quantity,
    this.isChecked = false,
  });

  final int id;
  final String name;
  final String? quantity;
  final bool isChecked;

  factory DashShoppingItem.fromJson(Map<String, dynamic> json) =>
      DashShoppingItem(
        id: json['id'] is int ? json['id'] as int : -1,
        name: json['name'] as String? ?? '',
        quantity: json['quantity'] as String?,
        isChecked: _asBool(json['is_checked']),
      );
}

/// Un pasto di oggi (riga DB `meals`).
final class DashMeal {
  const DashMeal({
    required this.id,
    required this.mealType,
    required this.title,
  });

  final int id;
  final String mealType;
  final String title;

  factory DashMeal.fromJson(Map<String, dynamic> json) => DashMeal(
    id: _asInt(json['id']) ?? -1,
    mealType: json['meal_type'] as String? ?? '',
    title: json['title'] as String? ?? '',
  );
}

bool _asBool(Object? v) =>
    v == true || (v is num && v != 0) || (v is String && v == '1');

int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
