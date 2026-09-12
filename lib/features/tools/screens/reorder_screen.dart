import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/pdf_tools_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/source_picker.dart';
import '../widgets/tool_history_list.dart';
import '../widgets/tool_result_screen.dart';

class ReorderScreen extends StatefulWidget {
  const ReorderScreen({super.key});
  @override
  State<ReorderScreen> createState() => _ReorderScreenState();
}

class _ReorderScreenState extends State<ReorderScreen> {
  String? _path;
  List<Uint8List> _thumbs = [];
  List<int> _order = [];
  bool _loading = false;
  bool _working = false;

  Future<void> _pickFile() async {
    final picked = await pickSourceFiles(context, allowMultiple: false, extensions: const ['pdf']);
    if (picked.isEmpty) return;
    setState(() { _path = picked.first; _loading = true; });
    try {
      final tools = context.read<PdfToolsService>();
      final thumbs = await tools.renderPageThumbnails(picked.first);
      if (!mounted) return;
      if (thumbs.isEmpty) throw Exception('No readable pages found');
      setState(() {
        _thumbs = thumbs;
        _order = List.generate(thumbs.length, (i) => i);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _path = null; _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't open this PDF. It may be corrupted or password protected."),
      ));
    }
  }

  Future<void> _apply() async {
    if (_path == null) return;
    setState(() => _working = true);
    try {
      final tools = context.read<PdfToolsService>();
      final data = context.read<AppDataController>();
      final baseName = p.basenameWithoutExtension(_path!);
      final outName = '${baseName}_reordered.pdf';
      final file = await tools.reorder(_path!, _order, outputName: outName);
      final pages = await tools.pageCount(file.path);
      final thumb = await tools.generateThumbnail(file.path, type: 'pdf');
      final doc = await data.registerToolResult(
        tmpFile: file,
        fileName: outName,
        toolId: ToolId.reorder.name,
        toolTitle: 'Reordered $baseName',
        type: 'pdf',
        pageCount: pages,
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ToolResultScreen(results: [doc], successTitle: 'Pages reordered!'),
      ));
      setState(() { _path = null; _thumbs = []; _order = []; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reorder failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reorder Pages')),
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
                      icon: Icons.reorder_rounded,
                      title: 'Choose a PDF',
                      message: 'Drag pages into the order you want, then save.',
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
            else if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Text('Drag to reorder ${_order.length} pages', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              ReorderableGridView(
                order: _order,
                thumbs: _thumbs,
                onReorder: _reorder,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _working ? null : _apply,
                  child: _working
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save New Order'),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const ToolHistorySection(toolId: ToolId.reorder),
          ],
        ),
      ),
    );
  }
}

class ReorderableGridView extends StatelessWidget {
  final List<int> order;
  final List<Uint8List> thumbs;
  final void Function(int, int) onReorder;

  const ReorderableGridView({
    super.key,
    required this.order,
    required this.thumbs,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: order.length,
      itemBuilder: (ctx, i) {
        final pageIdx = order[i];
        return DragTarget<int>(
          onWillAcceptWithDetails: (details) => details.data != i,
          onAcceptWithDetails: (details) => onReorder(details.data, i),
          builder: (ctx, candidate, rejected) => LongPressDraggable<int>(
            data: i,
            feedback: Material(
              color: Colors.transparent,
              child: _PageThumb(bytes: thumbs[pageIdx], number: pageIdx + 1, width: 90),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _PageThumb(bytes: thumbs[pageIdx], number: pageIdx + 1),
            ),
            child: _PageThumb(bytes: thumbs[pageIdx], number: pageIdx + 1),
          ),
        );
      },
    );
  }
}

class _PageThumb extends StatelessWidget {
  final Uint8List bytes;
  final int number;
  final double? width;
  const _PageThumb({required this.bytes, required this.number, this.width});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(bytes, fit: BoxFit.cover),
          Positioned(
            bottom: 4, left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
              child: Text('$number', style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}
