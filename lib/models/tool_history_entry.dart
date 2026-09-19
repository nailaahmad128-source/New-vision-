/// A record of a tool run, shown in that tool's own history list.
/// Deleting a history entry only removes the history record.
  /// The underlying Tool Result file remains untouched.
class ToolHistoryEntry {
  final String id;
  final String toolId;
  final String title;
  final String? resultDocumentId;
  final String? resultFilePath;
  final String? resultFileName;
  final int? resultSizeBytes;
  final DateTime createdAt;
  final bool success;
  final String? note;

  const ToolHistoryEntry({
    required this.id,
    required this.toolId,
    required this.title,
    required this.createdAt,
    required this.success,
    this.resultDocumentId,
    this.resultFilePath,
    this.resultFileName,
    this.resultSizeBytes,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'toolId': toolId,
        'title': title,
        'resultDocumentId': resultDocumentId,
        'resultFilePath': resultFilePath,
        'resultFileName': resultFileName,
        'resultSizeBytes': resultSizeBytes,
        'createdAt': createdAt.toIso8601String(),
        'success': success,
        'note': note,
      };

  factory ToolHistoryEntry.fromMap(Map map) => ToolHistoryEntry(
        id: map['id'] as String,
        toolId: map['toolId'] as String,
        title: map['title'] as String,
        resultDocumentId: map['resultDocumentId'] as String?,
        resultFilePath: map['resultFilePath'] as String?,
        resultFileName: map['resultFileName'] as String?,
        resultSizeBytes: map['resultSizeBytes'] as int?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        success: map['success'] as bool? ?? true,
        note: map['note'] as String?,
      );
}
