final class NoteCategory {
  const NoteCategory({
    required this.id,
    required this.name,
    required this.scope,
    required this.sortOrder,
    this.ownerUserId,
  });

  final int id;
  final String name;
  final String scope; // 'personal' | 'household'
  final int? ownerUserId;
  final int sortOrder;

  factory NoteCategory.fromJson(Map<String, dynamic> json) => NoteCategory(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    scope: json['scope'] as String,
    ownerUserId: (json['owner_user_id'] as num?)?.toInt(),
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  );
}

final class Note {
  const Note({
    required this.id,
    required this.content,
    this.title,
    this.color,
    this.pinned = false,
    this.createdBy,
    this.creatorName,
    this.categories = const [],
  });

  final int id;
  final String? title;
  final String content;
  final String? color;
  final bool pinned;
  final int? createdBy;
  final String? creatorName;
  final List<NoteCategory> categories;

  factory Note.fromJson(Map<String, dynamic> json) {
    final cats = (json['categories'] as List<dynamic>? ?? const [])
        .map((e) => NoteCategory.fromJson(e as Map<String, dynamic>))
        .toList();
    return Note(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      color: json['color'] as String?,
      pinned: (json['pinned'] as num?)?.toInt() == 1,
      createdBy: (json['created_by'] as num?)?.toInt(),
      creatorName: json['creator_name'] as String?,
      categories: cats,
    );
  }
}
