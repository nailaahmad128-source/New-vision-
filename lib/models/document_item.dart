/// A single file tracked by the Library system (imported by the user OR
/// produced by a tool). Stored in Hive as a plain Map to avoid requiring
/// generated TypeAdapters / build_runner in CI.
class DocumentItem {
  final String id;
  final String name;
  final String filePath;
  final String? thumbnailPath;
  final int sizeBytes;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String type; // 'pdf' | 'image'
  final String? sourceToolId; // null if manually imported
  final int? pageCount;
  final bool isFavorite;
  final String? extractedText; // OCR text used for document search

  /// True once OCR has attached real extracted text to this document, so
  /// the Library's "Searchable" filter and per-tile badge reflect only
  /// documents that can actually be found by their scanned text.
  bool get isSearchable => (extractedText ?? '').trim().isNotEmpty;

  const DocumentItem({
    required this.id,
    required this.name,
    required this.filePath,
    required this.sizeBytes,
    required this.createdAt,
    required this.modifiedAt,
    required this.type,
    this.thumbnailPath,
    this.sourceToolId,
    this.pageCount,
    this.isFavorite = false,
    this.extractedText,
  });

  DocumentItem copyWith({
    String? id,
    String? name,
    String? filePath,
    String? thumbnailPath,
    int? sizeBytes,
    DateTime? modifiedAt,
    int? pageCount,
    bool? isFavorite,
    String? extractedText,
  }) {
    return DocumentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      type: type,
      sourceToolId: sourceToolId,
      pageCount: pageCount ?? this.pageCount,
      isFavorite: isFavorite ?? this.isFavorite,
      extractedText: extractedText ?? this.extractedText,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'filePath': filePath,
        'thumbnailPath': thumbnailPath,
        'sizeBytes': sizeBytes,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'type': type,
        'sourceToolId': sourceToolId,
        'pageCount': pageCount,
        'isFavorite': isFavorite,
        'extractedText': extractedText,
      };

  factory DocumentItem.fromMap(Map map) => DocumentItem(
        id: map['id'] as String,
        name: map['name'] as String,
        filePath: map['filePath'] as String,
        thumbnailPath: map['thumbnailPath'] as String?,
        sizeBytes: map['sizeBytes'] as int? ?? 0,
        createdAt: DateTime.parse(map['createdAt'] as String),
        modifiedAt: DateTime.parse(map['modifiedAt'] as String),
        type: map['type'] as String? ?? 'pdf',
        sourceToolId: map['sourceToolId'] as String?,
        pageCount: map['pageCount'] as int?,
        isFavorite: map['isFavorite'] as bool? ?? false,
        extractedText: map['extractedText'] as String?,
      );
}
