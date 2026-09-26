/// Un compleanno (server: tabella `birthdays` + campi idratati).
final class Birthday {
  const Birthday({
    required this.id,
    required this.name,
    required this.birthDate,
    this.notes,
    this.daysUntil,
    this.nextAge,
    this.nextBirthday,
  });

  final int id;
  final String name;
  final String birthDate; // 'YYYY-MM-DD'
  final String? notes;

  /// Giorni al prossimo compleanno (calcolati dal server).
  final int? daysUntil;

  /// Età che compirà (null se l'anno di nascita non è noto).
  final int? nextAge;

  /// Data del prossimo compleanno ('YYYY-MM-DD').
  final String? nextBirthday;

  factory Birthday.fromJson(Map<String, dynamic> json) => Birthday(
    id: (json['id'] as num?)?.toInt() ?? -1,
    name: json['name'] as String? ?? '',
    birthDate: json['birth_date'] as String? ?? '',
    notes: json['notes'] as String?,
    daysUntil: (json['days_until'] as num?)?.toInt(),
    nextAge: (json['next_age'] as num?)?.toInt(),
    nextBirthday: json['next_birthday'] as String?,
  );
}

/// Testo del countdown ("oggi", "domani", "tra N giorni").
String birthdayCountdown(int? daysUntil) => switch (daysUntil) {
  null => '',
  0 => 'oggi',
  1 => 'domani',
  final n when n < 0 => 'passato',
  final n => 'tra $n giorni',
};

/// Ordinamento per prossimo compleanno (i senza data in fondo).
int compareBirthdays(Birthday a, Birthday b) {
  final da = a.daysUntil ?? 9999;
  final db = b.daysUntil ?? 9999;
  final byDays = da.compareTo(db);
  if (byDays != 0) return byDays;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}
