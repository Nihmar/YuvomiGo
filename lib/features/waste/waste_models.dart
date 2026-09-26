/// Prossima raccolta per tipo (server: `GET /waste/occurrences/next`).
final class WasteNextPickup {
  const WasteNextPickup({
    required this.typeId,
    required this.typeName,
    this.typeIcon,
    this.typeColor,
    this.dateKey,
    this.moved = false,
  });

  final int typeId;
  final String typeName;
  final String? typeIcon;
  final String? typeColor;

  /// 'YYYY-MM-DD' della prossima raccolta; null se non pianificata.
  final String? dateKey;
  final bool moved;

  bool get hasNext => dateKey != null;

  factory WasteNextPickup.fromJson(Map<String, dynamic> json) {
    final type = json['type'] is Map<String, dynamic>
        ? json['type'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final next = json['next'] is Map<String, dynamic>
        ? json['next'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return WasteNextPickup(
      typeId: (type['id'] as num?)?.toInt() ?? -1,
      typeName: type['name'] as String? ?? '',
      typeIcon: type['icon'] as String?,
      typeColor: type['color'] as String?,
      dateKey: next['date_key'] as String?,
      moved: next['moved'] == true,
    );
  }
}

/// Etichetta relativa della prossima raccolta.
String wasteCountdown(String? dateKey) {
  final date = dateKey == null ? null : DateTime.tryParse(dateKey);
  if (date == null) return 'non pianificata';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = date.difference(today).inDays;
  return switch (days) {
    < 0 => 'passata',
    0 => 'oggi',
    1 => 'domani',
    _ => 'tra $days giorni',
  };
}

/// Ordinamento: prima le raccolte più vicine, poi quelle senza data.
int compareWastePickups(WasteNextPickup a, WasteNextPickup b) {
  final ad = a.dateKey ?? '9999-99-99';
  final bd = b.dateKey ?? '9999-99-99';
  final byDate = ad.compareTo(bd);
  if (byDate != 0) return byDate;
  return a.typeName.toLowerCase().compareTo(b.typeName.toLowerCase());
}
