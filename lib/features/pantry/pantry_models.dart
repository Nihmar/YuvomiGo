/// Un articolo di dispensa (server: `pantry_items` + nome del luogo).
final class PantryItem {
  const PantryItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.unit = 'pcs',
    this.locationId,
    this.locationName,
    this.category = '',
    this.expiresOn,
    this.minQuantity,
    this.notes,
  });

  final int id;
  final String name;
  final double quantity;
  final String unit;
  final int? locationId;
  final String? locationName;
  final String category;
  final String? expiresOn; // 'YYYY-MM-DD'
  final double? minQuantity;
  final String? notes;

  bool get isLowStock => minQuantity != null && quantity <= minQuantity!;

  factory PantryItem.fromJson(Map<String, dynamic> json) => PantryItem(
    id: (json['id'] as num?)?.toInt() ?? -1,
    name: json['name'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
    unit: json['unit'] as String? ?? 'pcs',
    locationId: (json['location_id'] as num?)?.toInt(),
    locationName: json['location_name'] as String?,
    category: json['category'] as String? ?? '',
    expiresOn: json['expires_on'] as String?,
    minQuantity: (json['min_quantity'] as num?)?.toDouble(),
    notes: json['notes'] as String?,
  );
}

/// Un luogo di dispensa (server: `pantry_locations`).
final class PantryLocation {
  const PantryLocation({required this.id, required this.name});

  final int id;
  final String name;

  factory PantryLocation.fromJson(Map<String, dynamic> json) => PantryLocation(
    id: (json['id'] as num?)?.toInt() ?? -1,
    name: json['name'] as String? ?? '',
  );
}

/// Risposta di `GET /api/v1/pantry`.
final class PantryData {
  const PantryData({
    this.items = const [],
    this.locations = const [],
    this.categories = const [],
  });

  final List<PantryItem> items;
  final List<PantryLocation> locations;
  final List<String> categories;
}

/// Etichette italiane delle unità canoniche del server.
const Map<String, String> pantryUnitLabels = {
  'pcs': 'pz',
  'g': 'g',
  'kg': 'kg',
  'ml': 'ml',
  'l': 'l',
  'pkg': 'conf.',
  'can': 'lattina',
  'bottle': 'bottiglia',
  'jar': 'barattolo',
  'bag': 'sacchetto',
};

String pantryUnitLabel(String unit) => pantryUnitLabels[unit] ?? unit;

/// Quantità formattata senza decimali inutili (2 invece di 2.0).
String pantryQuantityLabel(double quantity) {
  if (quantity == quantity.roundToDouble()) {
    return quantity.round().toString();
  }
  return quantity.toStringAsFixed(1);
}
