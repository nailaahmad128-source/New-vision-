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

class MergeScreen extends StatefulWidget {
  final String? initialSourcePath;
  const MergeScreen({super.key, this.initialSourcePath});
  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<String> _paths = [];
  bool _working = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSourcePath != null) _paths.add(widget.initialSourcePath!);
  }

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
    return ProfessionalToolPage(
      title: 'Merge PDF',
      description: 'Combine multiple PDF files into one document in the order you choose.',
      icon: Icons.merge_type_rounded,
      history: const ToolHistorySection(toolId: ToolId.merge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_paths.isEmpty) ...[
            const ProfessionalSectionTitle(
              title: 'Create or Import',
              subtitle: 'Add two or more PDF files to merge.',
            ),
            const SizedBox(height: 16),
            ProfessionalActionGrid(
              children: [
                ProfessionalAction(
                  title: 'Device',
                  subtitle: 'Select PDFs',
                  icon: Icons.folder_rounded,
                  onTap: _addFiles,
                ),
              ],
            ),
          ] else ...[
            ProfessionalSectionTitle(
              title: '${_paths.length} PDF${_paths.length == 1 ? '' : 's'} selected',
              subtitle: 'Drag the files to change their order.',
            ),
            const SizedBox(height: 14),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _paths.length,
              onReorder: _reorder,
              itemBuilder: (ctx, i) => Padding(
                key: ValueKey(_paths[i]),
                padding: const EdgeInsets.only(bottom: 9),
                child: ProfessionalFileCard(
                  name: p.basename(_paths[i]),
                  subtitle: 'Page ${i + 1}',
                  onRemove: () => setState(() => _paths.removeAt(i)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addFiles,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add More PDFs'),
            ),
            const SizedBox(height: 16),
            ProfessionalPrimaryButton(
              label: 'Merge Files',
              icon: Icons.merge_type_rounded,
              loading: _working,
              onPressed: _paths.length >= 2 && !_working ? _merge : null,
            ),
          ],
        ],
      ),
    );
  }
}
