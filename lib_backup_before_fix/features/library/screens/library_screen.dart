import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/widgets/document_tile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/banner_ad_slot.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/document_item.dart';
import '../../document/screens/document_detail_screen.dart';
import '../../scanner/screens/smart_scanner_screen.dart';

enum _LibraryFilter { all, pdf, image, searchable, favorites }
enum _LibrarySort { recent, name, size }

class LibraryScreen extends StatefulWidget {
  final String initialQuery;
  const LibraryScreen({super.key, this.initialQuery = ''});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  _LibraryFilter _filter = _LibraryFilter.all;
  _LibrarySort _sort = _LibrarySort.recent;
  String _query = '';
  bool _grid = false;
  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _searchController = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _rename(DocumentItem doc) async {
    final controller = TextEditingController(text: p.basenameWithoutExtension(doc.name));
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Document name'),
          onSubmitted: (v) => Navigator.pop(context, v),
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
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: true,
    );
    if (result == null || !mounted) return;

    final storage = context.read<FileStorageService>();
    final data = context.read<AppDataController>();
    var imported = 0;

    for (final f in result.files) {
      final sourcePath = f.path;
      if (sourcePath == null) continue;
      final source = File(sourcePath);
      if (!await source.exists()) continue;

      final isPdf = p.extension(f.name).toLowerCase() == '.pdf';
      final copied = await storage.importIntoLibrary(source, preferredName: f.name);
      final size = await storage.fileSize(copied);
      String? thumbnail;

      if (!isPdf) {
        try {
          final bytes = await File(copied).readAsBytes();
          final decoded = img.decodeImage(bytes);
          if (decoded != null) {
            final thumb = img.copyResize(decoded, width: 320);
            thumbnail = await storage.saveThumbnail(img.encodeJpg(thumb, quality: 82), name: p.basename(copied));
          }
        } catch (_) {
          // A missing thumbnail must never prevent the source image import.
        }
      }

      final now = DateTime.now();
      await data.addDocument(DocumentItem(
        id: storage.newId(),
        name: f.name,
        filePath: copied,
        thumbnailPath: thumbnail,
        sizeBytes: size,
        createdAt: now,
        modifiedAt: now,
        type: isPdf ? 'pdf' : 'image',
        pageCount: 1,
      ));
      imported++;
    }

    if (mounted && imported > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $imported file${imported == 1 ? '' : 's'}')));
    }
  }

  List<DocumentItem> _filtered(List<DocumentItem> source) {
    var docs = switch (_filter) {
      _LibraryFilter.all => [...source],
      _LibraryFilter.pdf => source.where((d) => d.type == 'pdf').toList(),
      _LibraryFilter.image => source.where((d) => d.type == 'image').toList(),
      _LibraryFilter.searchable => source.where((d) => (d.extractedText ?? '').trim().isNotEmpty).toList(),
      _LibraryFilter.favorites => source.where((d) => d.isFavorite).toList(),
    };

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      docs = docs.where((d) {
        return d.name.toLowerCase().contains(q) || (d.extractedText ?? '').toLowerCase().contains(q);
      }).toList();
    }

    switch (_sort) {
      case _LibrarySort.recent:
        docs.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        break;
      case _LibrarySort.name:
        docs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _LibrarySort.size:
        docs.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
        break;
    }
    return docs;
  }

  String _sortLabel() => switch (_sort) {
        _LibrarySort.recent => 'Recent',
        _LibrarySort.name => 'Name',
        _LibrarySort.size => 'Size',
      };

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _startSelection(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _shareSelected(List<DocumentItem> docs) async {
    final files = docs.where((d) => File(d.filePath).existsSync()).map((d) => XFile(d.filePath)).toList();
    if (files.isEmpty) return;
    await Share.shareXFiles(files, subject: 'PDF Master Tools documents');
  }

  Future<void> _deleteSelected(List<DocumentItem> docs) async {
    if (docs.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Move ${docs.length} document${docs.length == 1 ? '' : 's'} to Recently Deleted?'),
        content: const Text('You can recover them later from Recently Deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('Move to Deleted')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final data = context.read<AppDataController>();
    for (final doc in docs) {
      await data.deleteDocument(doc.id);
    }
    if (mounted) _clearSelection();
  }

  Future<void> _toggleSelectedFavorites(List<DocumentItem> docs) async {
    if (docs.isEmpty) return;
    final data = context.read<AppDataController>();
    final makeFavorite = docs.any((d) => !d.isFavorite);
    for (final doc in docs) {
      if (doc.isFavorite != makeFavorite) await data.toggleFavorite(doc.id);
    }
    if (mounted) _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = context.watch<AppDataController>();
    final docs = _filtered(data.documents);
    final all = data.documents;

    return Scaffold(
      appBar: AppBar(
        title: _selectionMode ? Text('${_selectedIds.length} selected') : const Text('Library'),
        leading: _selectionMode
            ? IconButton(tooltip: 'Cancel selection', onPressed: _clearSelection, icon: const Icon(Icons.close_rounded))
            : null,
        actions: _selectionMode
            ? [
                IconButton(tooltip: 'Select all', onPressed: () => setState(() { _selectedIds..clear()..addAll(docs.map((d) => d.id)); }), icon: const Icon(Icons.select_all_rounded)),
                IconButton(tooltip: 'Share selected', onPressed: () => _shareSelected(docs.where((d) => _selectedIds.contains(d.id)).toList()), icon: const Icon(Icons.share_rounded)),
                IconButton(tooltip: 'Favorite selected', onPressed: () => _toggleSelectedFavorites(docs.where((d) => _selectedIds.contains(d.id)).toList()), icon: const Icon(Icons.star_border_rounded)),
                IconButton(tooltip: 'Delete selected', onPressed: () => _deleteSelected(docs.where((d) => _selectedIds.contains(d.id)).toList()), icon: const Icon(Icons.delete_outline_rounded)),
              ]
            : [
                IconButton(tooltip: 'Select documents', onPressed: () => setState(() => _selectionMode = true), icon: const Icon(Icons.checklist_rounded)),
                IconButton(tooltip: _grid ? 'List view' : 'Grid view', onPressed: () => setState(() => _grid = !_grid), icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded)),
                IconButton(tooltip: 'Recently Deleted', onPressed: () => Navigator.pushNamed(context, '/trash'), icon: const Icon(Icons.delete_sweep_outlined)),
              ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search file name or scanned text',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? IconButton(onPressed: _importFiles, tooltip: 'Import', icon: const Icon(Icons.add_rounded))
                      : IconButton(onPressed: () { _searchController.clear(); setState(() => _query = ''); }, tooltip: 'Clear', icon: const Icon(Icons.close_rounded)),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip(label: 'All ${all.length}', selected: _filter == _LibraryFilter.all, onTap: () => setState(() => _filter = _LibraryFilter.all)),
                  _FilterChip(label: 'PDF ${all.where((d) => d.type == 'pdf').length}', selected: _filter == _LibraryFilter.pdf, onTap: () => setState(() => _filter = _LibraryFilter.pdf)),
                  _FilterChip(label: 'Images ${all.where((d) => d.type == 'image').length}', selected: _filter == _LibraryFilter.image, onTap: () => setState(() => _filter = _LibraryFilter.image)),
                  _FilterChip(label: 'Searchable ${all.where((d) => (d.extractedText ?? '').trim().isNotEmpty).length}', selected: _filter == _LibraryFilter.searchable, onTap: () => setState(() => _filter = _LibraryFilter.searchable)),
                  _FilterChip(label: 'Favorites ${all.where((d) => d.isFavorite).length}', selected: _filter == _LibraryFilter.favorites, onTap: () => setState(() => _filter = _LibraryFilter.favorites)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Row(
                children: [
                  Text('${docs.length} ${docs.length == 1 ? 'document' : 'documents'}', style: theme.textTheme.bodySmall),
                  const Spacer(),
                  PopupMenuButton<_LibrarySort>(
                    tooltip: 'Sort',
                    onSelected: (v) => setState(() => _sort = v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: _LibrarySort.recent, child: Text('Recently modified')),
                      PopupMenuItem(value: _LibrarySort.name, child: Text('Name')),
                      PopupMenuItem(value: _LibrarySort.size, child: Text('File size')),
                    ],
                    child: Row(children: [const Icon(Icons.sort_rounded, size: 18), const SizedBox(width: 5), Text(_sortLabel(), style: theme.textTheme.labelLarge)]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: docs.isEmpty
                  ? EmptyState(
                      icon: Icons.folder_open_rounded,
                      title: data.documents.isEmpty ? 'Your Library is empty' : 'No matches',
                      message: data.documents.isEmpty
                          ? 'Scan a document or import a PDF/image to build your library.'
                          : 'Try another file name, word, or filter.',
                      action: data.documents.isEmpty
                          ? FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartScannerScreen())), icon: const Icon(Icons.document_scanner_rounded), label: const Text('Scan a document'))
                          : null,
                    )
                  : _grid
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .78),
                          itemCount: docs.length,
                          itemBuilder: (_, i) {
                            final doc = docs[i];
                            return GestureDetector(
                              onLongPress: () => _startSelection(doc.id),
                              child: Stack(
                                children: [
                                  _GridDocumentCard(
                                    doc: doc,
                                    onTap: () => _selectionMode
                                        ? _toggleSelection(doc.id)
                                        : Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentDetailScreen(doc: doc))),
                                    onFavorite: () => data.toggleFavorite(doc.id),
                                  ),
                                  if (_selectionMode) Positioned(left: 8, top: 8, child: IgnorePointer(child: Checkbox(value: _selectedIds.contains(doc.id), onChanged: null))),
                                ],
                              ),
                            );
                          },
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final doc = docs[i];
                            return GestureDetector(
                              onLongPress: () => _startSelection(doc.id),
                              child: Stack(
                                children: [
                                  DocumentTile(
                                    doc: doc,
                                    onTap: () => _selectionMode
                                        ? _toggleSelection(doc.id)
                                        : Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentDetailScreen(doc: doc))),
                                    onDelete: () => data.deleteDocument(doc.id),
                                    onToggleFavorite: () => data.toggleFavorite(doc.id),
                                    onRename: () => _rename(doc),
                                  ),
                                  if (_selectionMode) Positioned(left: 10, top: 10, child: IgnorePointer(child: Checkbox(value: _selectedIds.contains(doc.id), onChanged: null))),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            const BannerAdSlot(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importFiles,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Import'),
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

class _GridDocumentCard extends StatelessWidget {
  final DocumentItem doc;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  const _GridDocumentCard({required this.doc, required this.onTap, required this.onFavorite});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _GridPreview(doc: doc)),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: theme.colorScheme.surface.withValues(alpha: .92),
                      shape: const CircleBorder(),
                      child: IconButton(onPressed: onFavorite, icon: Icon(doc.isFavorite ? Icons.star_rounded : Icons.star_border_rounded, color: doc.isFavorite ? Colors.amber : null), tooltip: 'Favorite'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: Text(doc.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text('${doc.pageCount ?? 1} page${(doc.pageCount ?? 1) == 1 ? '' : 's'} · ${doc.type.toUpperCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPreview extends StatelessWidget {
  final DocumentItem doc;
  const _GridPreview({required this.doc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = doc.thumbnailPath;
    if (path != null && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback(theme));
    }
    return _fallback(theme);
  }

  Widget _fallback(ThemeData theme) {
    return Container(
      color: theme.colorScheme.primary.withValues(alpha: .07),
      alignment: Alignment.center,
      child: Icon(doc.type == 'image' ? Icons.image_rounded : Icons.picture_as_pdf_rounded, size: 54, color: AppColors.brandPrimary),
    );
  }
}
