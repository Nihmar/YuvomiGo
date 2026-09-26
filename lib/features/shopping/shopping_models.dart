final class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.name,
    this.itemTotal = 0,
    this.itemChecked = 0,
  });

  final int id;
  final String name;

  /// Numero totale di articoli (solo nella summary di `GET /api/v1/shopping`).
  final int itemTotal;

  /// Numero di articoli spuntati (solo nella summary).
  final int itemChecked;

  int get openCount => itemTotal - itemChecked;

  ShoppingList copyWith({int? itemTotal, int? itemChecked}) => ShoppingList(
    id: id,
    name: name,
    itemTotal: itemTotal ?? this.itemTotal,
    itemChecked: itemChecked ?? this.itemChecked,
  );

  factory ShoppingList.fromJson(Map<String, dynamic> json) => ShoppingList(
    id: _asInt(json['id']) ?? -1,
    name: json['name'] as String? ?? '',
    itemTotal: _asInt(json['item_total']) ?? 0,
    itemChecked: _asInt(json['item_checked']) ?? 0,
  );
}

final class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    this.quantity,
    this.category = 'Sonstiges',
    this.isChecked = false,
  });

  final int id;
  final String name;
  final String? quantity;
  final String category;
  final bool isChecked;

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
    id: _asInt(json['id']) ?? -1,
    name: json['name'] as String? ?? '',
    quantity: json['quantity'] as String?,
    category: json['category'] as String? ?? 'Sonstiges',
    isChecked: _asBool(json['is_checked']),
  );
}

int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

bool _asBool(Object? v) =>
    v == true || (v is num && v != 0) || (v is String && v == '1');
