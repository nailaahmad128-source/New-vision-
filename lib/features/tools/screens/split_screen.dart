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

enum _SplitMode { everyPage, ranges }

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});
  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  String? _path;
  int _pageCount = 0;
  _SplitMode _mode = _SplitMode.everyPage;
  final _rangesController = TextEditingController();
  bool _working = false;

  Future<void> _pickFile() async {
    final picked = await pickSourceFiles(context, allowMultiple: false, extensions: const ['pdf']);
    if (picked.isEmpty) return;
    try {
      final tools = context.read<PdfToolsService>();
      final count = await tools.pageCount(picked.first);
      if (!mounted) return;
      setState(() {
        _path = picked.first;
        _pageCount = count;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't open this PDF. It may be corrupted or password protected."),
      ));
    }
  }

  List<List<int>> _parseRanges() {
    if (_mode == _SplitMode.everyPage) {
      return List.generate(_pageCount, (i) => [i + 1, i + 1]);
    }
    final ranges = <List<int>>[];
    for (final part in _rangesController.text.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.contains('-')) {
        final bits = trimmed.split('-');
        final start = int.tryParse(bits[0].trim());
        final end = int.tryParse(bits[1].trim());
        if (start != null && end != null) ranges.add([start, end]);
      } else {
        final n = int.tryParse(trimmed);
        if (n != null) ranges.add([n, n]);
      }
    }
    return ranges;
  }

  Future<void> _split() async {
    if (_path == null) return;
    final ranges = _parseRanges();
    if (ranges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid page ranges, e.g. 1-3, 5, 7-9')));
      return;
    }
    setState(() => _working = true);
    try {
      final tools = context.read<PdfToolsService>();
      final data = context.read<AppDataController>();
      final baseName = p.basenameWithoutExtension(_path!);
      final files = await tools.split(_path!, ranges: ranges, baseOutputName: baseName);
      final results = <DocumentItem>[];
      for (final f in files) {
        final pages = await tools.pageCount(f.path);
        final thumb = await tools.generateThumbnail(f.path, type: 'pdf');
        final doc = await data.registerToolResult(
          tmpFile: f,
          fileName: p.basename(f.path),
          toolId: ToolId.split.name,
          toolTitle: 'Split from $baseName',
          type: 'pdf',
          pageCount: pages,
        );
        results.add(data.documentById(doc.id) ?? doc);
      }
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ToolResultScreen(
          results: results,
          successTitle: 'PDF split into ${results.length} files!',
        ),
      ));
      setState(() {
        _path = null;
        _pageCount = 0;
        _rangesController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Split failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Split PDF')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_path == null)
              Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: EmptyState(
                      icon: Icons.call_split_rounded,
                      title: 'Choose a PDF to split',
                      message: 'Split it into individual pages or custom page ranges.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Choose PDF'),
                    ),
                  ),
                ],
              )
            else ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf_rounded),
                  title: Text(p.basename(_path!), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('$_pageCount pages'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() { _path = null; _pageCount = 0; }),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<_SplitMode>(
                segments: const [
                  ButtonSegment(value: _SplitMode.everyPage, label: Text('Every page')),
                  ButtonSegment(value: _SplitMode.ranges, label: Text('Custom ranges')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              if (_mode == _SplitMode.ranges) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _rangesController,
                  decoration: const InputDecoration(
                    labelText: 'Page ranges',
                    hintText: 'e.g. 1-3, 5, 7-9',
                  ),
                  keyboardType: TextInputType.text,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _working ? null : _split,
                  child: _working
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Split PDF'),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const ToolHistorySection(toolId: ToolId.split),
          ],
        ),
      ),
    );
  }
}
