/// Un documento di famiglia (server: `family_documents`).
final class DocumentItem {
  const DocumentItem({
    required this.id,
    required this.name,
    this.description,
    this.category = '',
    this.status = 'active',
    this.originalName,
    this.mimeType,
    this.fileSize,
    this.folderId,
    this.folderName,
    this.creatorName,
    this.externalUrl,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String? description;
  final String category;
  final String status;
  final String? originalName;
  final String? mimeType;
  final int? fileSize;
  final int? folderId;
  final String? folderName;
  final String? creatorName;
  final String? externalUrl;
  final String? createdAt;
  final String? updatedAt;

  factory DocumentItem.fromJson(Map<String, dynamic> json) => DocumentItem(
    id: (json['id'] as num?)?.toInt() ?? -1,
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    category: json['category'] as String? ?? '',
    status: json['status'] as String? ?? 'active',
    originalName: json['original_name'] as String?,
    mimeType: json['mime_type'] as String?,
    fileSize: (json['file_size'] as num?)?.toInt(),
    folderId: (json['folder_id'] as num?)?.toInt(),
    folderName: json['folder_name'] as String?,
    creatorName: json['creator_name'] as String?,
    externalUrl: json['external_url'] as String?,
    createdAt: json['created_at'] as String?,
    updatedAt: json['updated_at'] as String?,
  );
}

/// Etichette italiane delle categorie documento del server.
const List<String> documentCategories = [
  'medical',
  'school',
  'identity',
  'insurance',
  'finance',
  'home',
  'vehicle',
  'legal',
  'travel',
  'pets',
  'warranty',
  'taxes',
  'work',
  'other',
];

String documentCategoryLabel(String category) => switch (category) {
  'medical' => 'Salute',
  'school' => 'Scuola',
  'identity' => 'Identità',
  'insurance' => 'Assicurazioni',
  'finance' => 'Finanze',
  'home' => 'Casa',
  'vehicle' => 'Veicoli',
  'legal' => 'Legale',
  'travel' => 'Viaggi',
  'pets' => 'Animali',
  'warranty' => 'Garanzie',
  'taxes' => 'Tasse',
  'work' => 'Lavoro',
  'other' => 'Altro',
  _ => category,
};

/// Dimensione file leggibile (B/KB/MB).
String formatFileSize(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// MIME ammessi dal server, per estensione.
const Map<String, String> _mimeByExtension = {
  'pdf': 'application/pdf',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

/// MIME dedotto dall'estensione; null se il tipo non è ammesso.
String? documentMimeForName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return null;
  return _mimeByExtension[name.substring(dot + 1).toLowerCase()];
}
