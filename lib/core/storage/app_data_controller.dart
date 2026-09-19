import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/document_item.dart';
import '../../models/trash_item.dart';
import '../../models/tool_history_entry.dart';
import '../services/file_storage_service.dart';
import 'hive_boxes.dart';

/// Single source of truth for Library documents, Recently Deleted items,
/// and per-tool history. Kept as one controller (rather than three
/// separate repositories) because delete/restore inherently need to move
/// data between the library and trash boxes atomically.
class AppDataController extends ChangeNotifier {
  final FileStorageService storage;
  AppDataController(this.storage);

  Box get _libraryBox => Hive.box(HiveBoxes.library);
  Box get _trashBox => Hive.box(HiveBoxes.trash);
  Box get _historyBox => Hive.box(HiveBoxes.history);
  Box get _prefsBox => Hive.box(HiveBoxes.prefs);

  List<DocumentItem> get documents {
    final items = _libraryBox.values
        .map((e) => DocumentItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    items.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return items;
  }

  List<TrashItem> get trashItems {
    final items = _trashBox.values
        .map((e) => TrashItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return items;
  }

  List<ToolHistoryEntry> historyForTool(String toolId) {
    final items = _historyBox.values
        .map((e) => ToolHistoryEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((e) => e.toolId == toolId)
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  /// Searches document names and OCR text.
  List<DocumentItem> searchDocuments(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return documents;
    return documents.where((doc) {
      final name = doc.name.toLowerCase();
      final text = (doc.extractedText ?? '').toLowerCase();
      return name.contains(q) || text.contains(q);
    }).toList();
  }

  Future<void> updateExtractedText(String id, String text) async {
    final doc = documentById(id);
    if (doc == null) return;
    await updateDocument(doc.copyWith(extractedText: text));
  }

  DocumentItem? documentById(String id) {
    final raw = _libraryBox.get(id);
    if (raw == null) return null;
    return DocumentItem.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  // ---------------- Library ----------------

  Future<DocumentItem> addDocument(DocumentItem doc) async {
    await _libraryBox.put(doc.id, doc.toMap());
    notifyListeners();
    return doc;
  }

  Future<void> updateDocument(DocumentItem doc) async {
    await _libraryBox.put(doc.id, doc.toMap());
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final doc = documentById(id);
    if (doc == null) return;
    await updateDocument(doc.copyWith(isFavorite: !doc.isFavorite));
  }

  /// Moves a document to Recently Deleted. The physical file is moved
  /// (not duplicated) so it vanishes from the Library instantly and there
  /// is only ever one on-disk copy — avoiding double-delete / ghost-file
  /// bugs.
  Future<void> deleteDocument(String id) async {
    final doc = documentById(id);
    if (doc == null) return;
    await _libraryBox.delete(id);
    final trashedPath = await storage.moveToTrash(doc.filePath);
    final item = TrashItem(
      id: storage.newId(),
      originalDocumentId: doc.id,
      name: doc.name,
      trashedFilePath: trashedPath,
      thumbnailPath: doc.thumbnailPath,
      sizeBytes: doc.sizeBytes,
      deletedAt: DateTime.now(),
      type: doc.type,
      sourceToolId: doc.sourceToolId,
      isFavorite: doc.isFavorite,
      pageCount: doc.pageCount,
    );
    await _trashBox.put(item.id, item.toMap());
    notifyListeners();
  }

  // ---------------- Trash ----------------

  Future<void> restoreFromTrash(String trashId) async {
    final raw = _trashBox.get(trashId);
    if (raw == null) return;
    final item = TrashItem.fromMap(Map<String, dynamic>.from(raw as Map));
    await _trashBox.delete(trashId);
    final restoredPath = await storage.restoreFromTrash(item.trashedFilePath);
    final doc = DocumentItem(
      id: item.originalDocumentId,
      name: item.name,
      filePath: restoredPath,
      thumbnailPath: item.thumbnailPath,
      sizeBytes: item.sizeBytes,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      type: item.type,
      sourceToolId: item.sourceToolId,
      isFavorite: item.isFavorite,
      pageCount: item.pageCount,
    );
    await _libraryBox.put(doc.id, doc.toMap());
    notifyListeners();
  }

  Future<void> deleteForever(String trashId) async {
    final raw = _trashBox.get(trashId);
    if (raw == null) return;
    final item = TrashItem.fromMap(Map<String, dynamic>.from(raw as Map));
    await _trashBox.delete(trashId);
    await storage.deletePermanently(item.trashedFilePath);
    if (item.thumbnailPath != null) {
      await storage.deletePermanently(item.thumbnailPath!);
    }
    notifyListeners();
  }

  Future<void> emptyTrash() async {
    for (final item in trashItems) {
      await storage.deletePermanently(item.trashedFilePath);
      if (item.thumbnailPath != null) {
        await storage.deletePermanently(item.thumbnailPath!);
      }
    }
    await _trashBox.clear();
    notifyListeners();
  }

  /// Purges trash items older than their retention window. Call on app
  /// start.
  Future<void> purgeExpiredTrash() async {
    final now = DateTime.now();
    for (final item in trashItems) {
      if (item.purgeAt.isBefore(now)) {
        await deleteForever(item.id);
      }
    }
  }

  // ---------------- Tool history ----------------
  // History entries reference a resultDocumentId but are otherwise
  // independent records — removing a history entry never touches the
  // underlying file or its Library entry.

  Future<void> addHistoryEntry(ToolHistoryEntry entry) async {
    await _historyBox.put(entry.id, entry.toMap());
    notifyListeners();
  }

  Future<void> removeHistoryEntry(String id) async {
    await _historyBox.delete(id);
    notifyListeners();
  }

  /// Saves a tool result into the real Library.
  Future<DocumentItem?> saveToolResultToLibrary(DocumentItem doc) async {
    final source = File(doc.filePath);
    if (!await source.exists()) return null;

    final copiedPath = await storage.importIntoLibrary(
      source,
      preferredName: doc.name,
    );
    final size = await storage.fileSize(copiedPath);

    final libraryDoc = doc.copyWith(
      id: storage.newId(),
      filePath: copiedPath,
      sizeBytes: size,
      modifiedAt: DateTime.now(),
    );

    await addDocument(libraryDoc);
    return libraryDoc;
  }

  /// Renames a Library document on disk and in Hive.
  Future<DocumentItem?> renameDocument(String id, String newName) async {
    final doc = documentById(id);
    if (doc == null) return null;
    final cleaned = newName.trim();
    if (cleaned.isEmpty) return null;
    final ext = doc.type == 'pdf' ? '.pdf' : '';
    final finalName = cleaned.toLowerCase().endsWith(ext) || ext.isEmpty
        ? cleaned
        : '$cleaned$ext';
    final source = File(doc.filePath);
    if (!await source.exists()) return null;
    final safe = finalName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final target = File('${source.parent.path}/$safe');
    if (target.path != source.path && await target.exists()) {
      return null;
    }
    final renamed = await source.rename(target.path);
    final updated = doc.copyWith(name: safe, filePath: renamed.path, modifiedAt: DateTime.now());
    await updateDocument(updated);
    return updated;
  }

  /// Renames a tool result and updates its history record.
  Future<DocumentItem> renameToolResult(
    DocumentItem doc,
    String newName,
  ) async {
    final newPath = await storage.renameToolResult(
      doc.filePath,
      newName,
    );

    final keys = _historyBox.keys.toList();
    for (final key in keys) {
      final raw = _historyBox.get(key);
      if (raw == null) continue;

      final map = Map<String, dynamic>.from(raw as Map);

      if (map['resultFilePath'] == doc.filePath) {
        map['resultFilePath'] = newPath;
        map['resultFileName'] = newName;
        await _historyBox.put(key, map);
      }
    }

    notifyListeners();

    return doc.copyWith(
      name: newName,
      filePath: newPath,
    );
  }

  /// Deletes a tool result and its history record.
  Future<void> deleteToolResult(DocumentItem doc) async {
    final keys = _historyBox.keys.toList();

    for (final key in keys) {
      final raw = _historyBox.get(key);
      if (raw == null) continue;

      final map = Map<String, dynamic>.from(raw as Map);

      if (map['resultFilePath'] == doc.filePath) {
        await _historyBox.delete(key);
      }
    }

    await storage.deletePermanently(doc.filePath);
    notifyListeners();
  }


  Future<void> clearHistoryForTool(String toolId) async {
    final keys = _historyBox.keys.where((k) {
      final raw = _historyBox.get(k);
      if (raw == null) return false;
      final map = Map<String, dynamic>.from(raw as Map);
      return map['toolId'] == toolId;
    }).toList();
    for (final k in keys) {
      await _historyBox.delete(k);
    }
    notifyListeners();
  }

  // ---------------- Prefs ----------------

  String get themeModeName => _prefsBox.get('theme_mode', defaultValue: 'system') as String;

  Future<void> setThemeModeName(String value) async {
    final normalized = ['system', 'light', 'dark'].contains(value) ? value : 'system';
    await _prefsBox.put('theme_mode', normalized);
    notifyListeners();
  }

  String get scanQuality => _prefsBox.get('scan_quality', defaultValue: 'high') as String;

  Future<void> setScanQuality(String value) async {
    final normalized = ['standard', 'high', 'ultra'].contains(value) ? value : 'high';
    await _prefsBox.put('scan_quality', normalized);
    notifyListeners();
  }

  String get defaultOcrLanguage => _prefsBox.get('default_ocr_language', defaultValue: 'auto') as String;

  Future<void> setDefaultOcrLanguage(String value) async {
    const allowed = ['auto', 'eng', 'urd', 'ara', 'eng+urd', 'eng+ara'];
    await _prefsBox.put('default_ocr_language', allowed.contains(value) ? value : 'auto');
    notifyListeners();
  }

  bool get autoDocumentDetection => _prefsBox.get('auto_document_detection', defaultValue: true) as bool;

  Future<void> setAutoDocumentDetection(bool value) async {
    await _prefsBox.put('auto_document_detection', value);
    notifyListeners();
  }


  bool get onboardingComplete => _prefsBox.get('onboarding_complete', defaultValue: false) as bool;
  Future<void> setOnboardingComplete() async {
    await _prefsBox.put('onboarding_complete', true);
  }

  // ---------------- Reader: last-page memory ----------------

  int? readerLastPage(String documentId) {
    return _prefsBox.get('reader_last_page_$documentId') as int?;
  }

  Future<void> setReaderLastPage(String documentId, int page) async {
    await _prefsBox.put('reader_last_page_$documentId', page);
  }

  /// Registers a brand-new file produced by a tool in the
  /// private Tool Results storage and creates its tool history entry.
  Future<DocumentItem> registerToolResult({
    required File tmpFile,
    required String fileName,
    required String toolId,
    required String toolTitle,
    required String type,
    int? pageCount,
  }) async {
    // Tool results are deliberately kept OUTSIDE the Library.
    // They live in the app's tool-output storage and are referenced
    // directly by ToolHistoryEntry.
    final finalPath = await storage.commitToolOutput(tmpFile, fileName: fileName);
    final size = await storage.fileSize(finalPath);

    final doc = DocumentItem(
      id: storage.newId(),
      name: fileName,
      filePath: finalPath,
      sizeBytes: size,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      type: type,
      sourceToolId: toolId,
      pageCount: pageCount,
    );

    await addHistoryEntry(ToolHistoryEntry(
      id: storage.newId(),
      toolId: toolId,
      title: toolTitle,
      resultDocumentId: null,
      resultFilePath: finalPath,
      resultFileName: fileName,
      resultSizeBytes: size,
      createdAt: DateTime.now(),
      success: true,
    ));

    return doc;
  }
}
