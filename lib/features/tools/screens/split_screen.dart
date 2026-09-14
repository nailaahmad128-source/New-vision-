import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/pdf_tools_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/document_item.dart';
import '../widgets/source_picker.dart';
import '../widgets/professional_tool_page.dart';
import '../widgets/tool_history_list.dart';
import '../widgets/tool_result_screen.dart';

enum _SplitMode { everyPage, ranges }

class SplitScreen extends StatefulWidget {
  final String? initialSourcePath;
  const SplitScreen({super.key, this.initialSourcePath});
  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  String? _path;
  int _pageCount = 0;
  _SplitMode _mode = _SplitMode.everyPage;
  final _rangesController = TextEditingController();
  bool _working = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSourcePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadFile(widget.initialSourcePath!));
    }
  }

  Future<void> _pickFile() async {
    final picked = await pickSourceFiles(context, allowMultiple: false, extensions: const ['pdf']);
    if (picked.isEmpty) return;
    await _loadFile(picked.first);
  }

  Future<void> _loadFile(String path) async {
    try {
      final tools = context.read<PdfToolsService>();
      final count = await tools.pageCount(path);
      if (!mounted) return;
      setState(() {
        _path = path;
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
    return ProfessionalToolPage(
      title: 'Split PDF',
      description: 'Split a PDF into individual pages or custom page ranges.',
      icon: Icons.call_split_rounded,
      history: const ToolHistorySection(toolId: ToolId.split),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_path == null) ...[
            const ProfessionalSectionTitle(
              title: 'Create or Import',
              subtitle: 'Choose a PDF from your device.',
            ),
            const SizedBox(height: 16),
            ProfessionalActionGrid(
              children: [
                ProfessionalAction(
                  title: 'Device',
                  subtitle: 'Choose PDF',
                  icon: Icons.folder_rounded,
                  onTap: _pickFile,
                ),
              ],
            ),
          ] else ...[
            ProfessionalFileCard(
              name: p.basename(_path!),
              subtitle: '$_pageCount pages',
              onRemove: () => setState(() {
                _path = null;
                _pageCount = 0;
              }),
            ),
            const SizedBox(height: 20),
            const ProfessionalSectionTitle(
              title: 'Split options',
              subtitle: 'Choose how you want to divide this PDF.',
            ),
            const SizedBox(height: 14),
            SegmentedButton<_SplitMode>(
              segments: const [
                ButtonSegment(
                  value: _SplitMode.everyPage,
                  label: Text('Every page'),
                ),
                ButtonSegment(
                  value: _SplitMode.ranges,
                  label: Text('Custom ranges'),
                ),
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
                  prefixIcon: Icon(Icons.format_list_numbered_rounded),
                ),
              ),
            ],
            const SizedBox(height: 22),
            ProfessionalPrimaryButton(
              label: 'Split PDF',
              icon: Icons.call_split_rounded,
              loading: _working,
              onPressed: _working ? null : _split,
            ),
          ],
        ],
      ),
    );
  }
}
