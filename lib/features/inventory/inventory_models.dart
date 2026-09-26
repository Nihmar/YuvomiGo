/// Una data tracciata per un oggetto (garanzia, scadenza, …).
final class InventoryTrackedDate {
  const InventoryTrackedDate({
    required this.id,
    required this.label,
    required this.date,
    this.reminderOffsetDays = 0,
  });

  final int id;
  final String label;
  final String date; // 'YYYY-MM-DD'
  final int reminderOffsetDays;

  factory InventoryTrackedDate.fromJson(Map<String, dynamic> json) =>
      InventoryTrackedDate(
        id: (json['id'] as num?)?.toInt() ?? -1,
        label: json['label'] as String? ?? '',
        date: json['date'] as String? ?? '',
        reminderOffsetDays:
            (json['reminder_offset_days'] as num?)?.toInt() ?? 0,
      );
}

/// Un oggetto registrato in inventario (server: `inventory_items`).
final class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    this.brand,
    this.model,
    this.serialNumber,
    this.category = '',
    this.categoryName,
    this.locationPath,
    this.purchaseDate,
    this.purchasePrice,
    this.currency,
    this.vendor,
    this.warrantyMonths,
    this.condition = 'good',
    this.status = 'active',
    this.notes,
    this.trackedDates = const [],
    this.linkedEntriesTotal = 0,
  });

  final int id;
  final String name;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final String category;
  final String? categoryName;
  final String? locationPath;
  final String? purchaseDate;
  final double? purchasePrice;
  final String? currency;
  final String? vendor;
  final int? warrantyMonths;
  final String condition;
  final String status;
  final String? notes;
  final List<InventoryTrackedDate> trackedDates;
  final double linkedEntriesTotal;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    final rawDates = json['tracked_dates'] is List
        ? json['tracked_dates'] as List
        : const [];
    return InventoryItem(
      id: (json['id'] as num?)?.toInt() ?? -1,
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      serialNumber: json['serial_number'] as String?,
      category: json['category'] as String? ?? '',
      categoryName: json['category_name'] as String?,
      locationPath: json['location_path'] as String?,
      purchaseDate: json['purchase_date'] as String?,
      purchasePrice: (json['purchase_price'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      vendor: json['vendor'] as String?,
      warrantyMonths: (json['warranty_months'] as num?)?.toInt(),
      condition: json['condition'] as String? ?? 'good',
      status: json['status'] as String? ?? 'active',
      notes: json['notes'] as String?,
      trackedDates: rawDates
          .whereType<Map<String, dynamic>>()
          .map(InventoryTrackedDate.fromJson)
          .toList(),
      linkedEntriesTotal:
          (json['linked_entries_total'] as num?)?.toDouble() ?? 0,
    );
  }
}

String inventoryStatusLabel(String status) => switch (status) {
  'active' => 'In uso',
  'sold' => 'Venduto',
  'disposed' => 'Smaltito',
  'lost' => 'Perso',
  _ => status,
};

String inventoryConditionLabel(String condition) => switch (condition) {
  'new' => 'Nuovo',
  'good' => 'Buono',
  'fair' => 'Discreto',
  'poor' => 'Da sostituire',
  _ => condition,
};
