import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/pdf_tools_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/document_item.dart';
import '../widgets/source_picker.dart';
import '../widgets/tool_history_list.dart';
import '../widgets/tool_result_screen.dart';

enum PageSelectionMode { extract, delete }

class PageSelectionToolScreen extends StatefulWidget {
  final PageSelectionMode mode;
  const PageSelectionToolScreen({super.key, required this.mode});

  @override
  State<PageSelectionToolScreen> createState() => _PageSelectionToolScreenState();
}

class _PageSelectionToolScreenState extends State<PageSelectionToolScreen> {
  String? _path;
  int _pageCount = 0;
  final Set<int> _selected = <int>{};
  bool _working = false;

  bool get _isExtract => widget.mode == PageSelectionMode.extract;
  ToolId get _toolId => _isExtract ? ToolId.extractPages : ToolId.deletePages;
  String get _title => _isExtract ? 'Extract Pages' : 'Delete Pages';

  Future<void> _pick() async {
    final picked = await pickSourceFiles(context, allowMultiple: false, extensions: const ['pdf']);
    if (picked.isEmpty) return;
    try {
      final count = await context.read<PdfToolsService>().pageCount(picked.first);
      if (!mounted) return;
      setState(() {
        _path = picked.first;
        _pageCount = count;
        _selected.clear();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open this PDF.")));
      }
    }
  }

  Future<void> _run() async {
    if (_path == null || _selected.isEmpty) return;
    if (!_isExtract && _selected.length >= _pageCount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least one page must remain.')));
      return;
    }
    setState(() => _working = true);
    try {
      final tools = context.read<PdfToolsService>();
      final data = context.read<AppDataController>();
      final base = p.basenameWithoutExtension(_path!);
      final indexes = _selected.toList()..sort();
      final file = _isExtract
          ? await tools.extractPages(_path!, pageIndexes: indexes, outputName: '${base}_extracted.pdf')
          : await tools.deletePages(_path!, pageIndexes: indexes, outputName: '${base}_pages_removed.pdf');
      final pages = await tools.pageCount(file.path);
      final doc = await data.registerToolResult(
        tmpFile: file,
        fileName: p.basename(file.path),
        toolId: _toolId.name,
        toolTitle: _title,
        type: 'pdf',
        pageCount: pages,
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ToolResultScreen(
        results: [data.documentById(doc.id) ?? doc],
        successTitle: _isExtract ? 'Pages extracted successfully!' : 'Pages deleted successfully!',
      )));
      setState(() {
        _path = null;
        _pageCount = 0;
        _selected.clear();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$_title failed: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_path == null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: _isExtract ? Icons.content_cut_rounded : Icons.delete_sweep_rounded,
                  title: 'Choose a PDF',
                  message: _isExtract ? 'Select pages and save them as a new PDF.' : 'Select pages to remove from a copy of the PDF.',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _pick, icon: const Icon(Icons.upload_file_rounded), label: const Text('Choose PDF'))),
            ] else ...[
              Card(child: ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded),
                title: Text(p.basename(_path!), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('$_pageCount pages • ${_selected.length} selected'),
                trailing: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() { _path = null; _pageCount = 0; _selected.clear(); })),
              )),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => setState(() => _selected.addAll(List.generate(_pageCount, (i) => i))), child: const Text('Select all'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: () => setState(_selected.clear), child: const Text('Clear'))),
              ]),
              const SizedBox(height: 14),
              ...List.generate(_pageCount, (index) {
                final selected = _selected.contains(index);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: CheckboxListTile(
                    value: selected,
                    onChanged: (_) => setState(() => selected ? _selected.remove(index) : _selected.add(index)),
                    title: Text('Page ${index + 1}'),
                    subtitle: Text(_isExtract ? (selected ? 'Will be included' : 'Not selected') : (selected ? 'Will be removed' : 'Will remain')),
                    secondary: CircleAvatar(child: Text('${index + 1}')),
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _working || _selected.isEmpty ? null : _run,
                icon: _working ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_isExtract ? Icons.content_cut_rounded : Icons.delete_sweep_rounded),
                label: Text(_working ? 'Processing…' : _title),
              )),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            ToolHistorySection(toolId: _toolId),
          ],
        ),
      ),
    );
  }
}
