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

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});
  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<String> _paths = [];
  bool _working = false;

  Future<void> _addFiles() async {
    final picked = await pickSourceFiles(context, allowMultiple: true, extensions: const ['pdf']);
    if (picked.isEmpty) return;
    setState(() => _paths.addAll(picked));
  }

  Future<void> _merge() async {
    if (_paths.length < 2) return;
    setState(() => _working = true);
    try {
      final tools = context.read<PdfToolsService>();
      final data = context.read<AppDataController>();
      final outName = 'Merged_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = await tools.merge(_paths, outputName: outName);
      final pages = await tools.pageCount(file.path);
      final thumb = await tools.generateThumbnail(file.path, type: 'pdf');
      final doc = await data.registerToolResult(
        tmpFile: file,
        fileName: outName,
        toolId: ToolId.merge.name,
        toolTitle: 'Merged ${_paths.length} files',
        type: 'pdf',
        pageCount: pages,
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ToolResultScreen(results: [doc], successTitle: 'PDFs merged!'),
      ));
      setState(() => _paths.clear());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Merge failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _paths.removeAt(oldIndex);
      _paths.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merge PDF')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFiles,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add PDFs'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (_paths.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.merge_type_rounded,
                  title: 'Add PDFs to merge',
                  message: 'Pick two or more PDF files. Drag to set the order they\'ll be combined in.',
                ),
              )
            else ...[
              Text('${_paths.length} file${_paths.length == 1 ? '' : 's'} · drag to reorder',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _paths.length,
                onReorder: _reorder,
                itemBuilder: (ctx, i) => Card(
                  key: ValueKey(_paths[i]),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(p.basename(_paths[i]), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _paths.removeAt(i)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _paths.length >= 2 && !_working ? _merge : null,
                  child: _working
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Merge Files'),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const ToolHistorySection(toolId: ToolId.merge),
          ],
        ),
      ),
    );
  }
}
