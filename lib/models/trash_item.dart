/// A file that was deleted from the Library. It is moved (not copied) into
/// the app's trash directory so it disappears from Library storage
/// immediately and atomically — this avoids the classic bug where a file
/// stays visible after deletion or needs deleting twice, because there is
/// only ever one on-disk copy and one source of truth (this record).
class TrashItem {
  final String id;
  final String originalDocumentId;
  final String name;
  final String trashedFilePath;
  final String? thumbnailPath;
  final int sizeBytes;
  final DateTime deletedAt;
  final String type;
  final String? sourceToolId;
  final bool isFavorite;
  final int? pageCount;

  const TrashItem({
    required this.id,
    required this.originalDocumentId,
    required this.name,
    required this.trashedFilePath,
    required this.sizeBytes,
    required this.deletedAt,
    required this.type,
    this.thumbnailPath,
    this.sourceToolId,
    this.isFavorite = false,
    this.pageCount,
  });

  /// Auto-purge after 30 days, mirroring standard OS trash conventions.
  DateTime get purgeAt => deletedAt.add(const Duration(days: 30));

  Map<String, dynamic> toMap() => {
        'id': id,
        'originalDocumentId': originalDocumentId,
        'name': name,
        'trashedFilePath': trashedFilePath,
        'thumbnailPath': thumbnailPath,
        'sizeBytes': sizeBytes,
        'deletedAt': deletedAt.toIso8601String(),
        'type': type,
        'sourceToolId': sourceToolId,
        'isFavorite': isFavorite,
        'pageCount': pageCount,
      };

  factory TrashItem.fromMap(Map map) => TrashItem(
        id: map['id'] as String,
        originalDocumentId: map['originalDocumentId'] as String,
        name: map['name'] as String,
        trashedFilePath: map['trashedFilePath'] as String,
        thumbnailPath: map['thumbnailPath'] as String?,
        sizeBytes: map['sizeBytes'] as int? ?? 0,
        deletedAt: DateTime.parse(map['deletedAt'] as String),
        type: map['type'] as String? ?? 'pdf',
        sourceToolId: map['sourceToolId'] as String?,
        isFavorite: map['isFavorite'] as bool? ?? false,
        pageCount: map['pageCount'] as int?,
      );
}
