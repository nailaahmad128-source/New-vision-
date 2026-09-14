import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/widgets/document_tile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/banner_ad_slot.dart';
import '../../../models/document_item.dart';
import '../../reader/screens/pdf_reader_screen.dart';
import '../../document/screens/document_detail_screen.dart';

enum _LibraryFilter { all, pdf, image, searchable, favorites }
enum _SortOption { recent, nameAsc, sizeDesc }

class LibraryScreen extends StatefulWidget {
  final String initialQuery;
  const LibraryScreen({super.key, this.initialQuery = ''});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  _LibraryFilter _filter = _LibraryFilter.all;
  _SortOption _sort = _SortOption.recent;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
  }

  Future<void> _rename(DocumentItem doc) async {
    final controller = TextEditingController(text: doc.name.replaceFirst(RegExp(r'\.pdf$'), ''));
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'Document name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || name == null || name.trim().isEmpty) return;
    final updated = await context.read<AppDataController>().renameDocument(doc.id, name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated == null ? 'A file with that name already exists.' : 'Document renamed.')),
    );
  }

  Future<void> _importFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
    );
    if (result == null || !mounted) return;
    final storage = context.read<FileStorageService>();
    final data = context.read<AppDataController>();
    for (final f in result) {
      if (f.path == null) continue;
      final copied = await storage.importIntoLibrary(File(f.path!), preferredName: f.name);
      final size = await storage.fileSize(copied);
      final doc = DocumentItem(
        id: storage.newId(),
        name: f.name,
        filePath: copied,
        sizeBytes: size,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        type: 'pdf',
      );
      await data.addDocument(doc);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${result.length} file(s)')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppDataController>();
    // AppDataController.searchDocuments already matches filename + OCR
    // text; reuse it here instead of re-implementing the same match logic
    // so the two never drift out of sync.
    var docs = _query.isEmpty ? data.documents : data.searchDocuments(_query);

    docs = switch (_filter) {
      _LibraryFilter.all => docs,
      _LibraryFilter.pdf => docs.where((d) => d.type == 'pdf').toList(),
      _LibraryFilter.image => docs.where((d) => d.type == 'image').toList(),
      _LibraryFilter.searchable => docs.where((d) => d.isSearchable).toList(),
      _LibraryFilter.favorites => docs.where((d) => d.isFavorite).toList(),
    };

    docs = List.of(docs);
    switch (_sort) {
      case _SortOption.recent:
        docs.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      case _SortOption.nameAsc:
        docs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _SortOption.sizeDesc:
        docs.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          PopupMenuButton<_SortOption>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _SortOption.recent, child: Text('Most recent')),
              PopupMenuItem(value: _SortOption.nameAsc, child: Text('Name (A–Z)')),
              PopupMenuItem(value: _SortOption.sizeDesc, child: Text('Largest first')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Import PDF',
            onPressed: _importFiles,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search files and scanned text',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip(label: 'All', selected: _filter == _LibraryFilter.all,
                      onTap: () => setState(() => _filter = _LibraryFilter.all)),
                  _FilterChip(label: 'PDFs', selected: _filter == _LibraryFilter.pdf,
                      onTap: () => setState(() => _filter = _LibraryFilter.pdf)),
                  _FilterChip(label: 'Images', selected: _filter == _LibraryFilter.image,
                      onTap: () => setState(() => _filter = _LibraryFilter.image)),
                  _FilterChip(label: 'Searchable', selected: _filter == _LibraryFilter.searchable,
                      onTap: () => setState(() => _filter = _LibraryFilter.searchable)),
                  _FilterChip(label: 'Favorites', selected: _filter == _LibraryFilter.favorites,
                      onTap: () => setState(() => _filter = _LibraryFilter.favorites)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: docs.isEmpty
                  ? EmptyState(
                      icon: Icons.folder_open_rounded,
                      title: data.documents.isEmpty ? 'Your Library is empty' : 'No matches',
                      message: data.documents.isEmpty
                          ? 'Import your own PDF files here to read them in the PDF Reader.'
                          : 'Try another word, file name, or extracted text.',
                      action: data.documents.isEmpty
                          ? FilledButton.icon(
                              onPressed: _importFiles,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Import a PDF'),
                            )
                          : null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final doc = docs[i];
                        return DocumentTile(
                          doc: doc,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => DocumentDetailScreen(doc: doc)));
                          },
                          onDelete: () => data.deleteDocument(doc.id),
                          onToggleFavorite: () => data.toggleFavorite(doc.id),
                          onRename: () => _rename(doc),
                        );
                      },
                    ),
            ),
            const BannerAdSlot(),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}
