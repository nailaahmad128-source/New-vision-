import 'dart:io';
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

class RotateScreen extends StatefulWidget {
  const RotateScreen({super.key});
  @override
  State<RotateScreen> createState() => _RotateScreenState();
}

class _RotateScreenState extends State<RotateScreen> {
  String? _path;
  List<Uint8List> _thumbs = [];
  final Map<int, int> _rotations = {}; // pageIndex -> degrees (0/90/180/270)
  final Set<int> _selected = {};
  bool _loading = false;
  bool _working = false;
  bool _allSelected = true;

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
        _loading = false;
        _selected.clear();
        _selected.addAll(List.generate(thumbs.length, (i) => i));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _path = null; _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't open this PDF. It may be corrupted or password protected."),
      ));
    }
  }

  void _rotateSelection() {
    setState(() {
      for (final i in _selected) {
        _rotations[i] = ((_rotations[i] ?? 0) + 90) % 360;
      }
    });
  }

  Future<void> _apply() async {
    if (_path == null) return;
    final targets = _rotations.entries.where((e) => e.value != 0).map((e) => e.key).toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select pages and rotate them before saving.')));
      return;
    }
    setState(() => _working = true);
    try {
      final tools = context.read<PdfToolsService>();
      final data = context.read<AppDataController>();
      final baseName = p.basenameWithoutExtension(_path!);
      final outName = '${baseName}_rotated.pdf';
      // Apply rotation per distinct degree group to keep it simple/correct.
      String currentPath = _path!;
      File? intermediate;
      final grouped = <int, List<int>>{};
      for (final entry in _rotations.entries) {
        if (entry.value == 0) continue;
        grouped.putIfAbsent(entry.value, () => []).add(entry.key);
      }
      for (final group in grouped.entries) {
        final result = await tools.rotate(
          currentPath,
          degrees: group.key,
          pageIndexes: group.value,
          outputName: outName,
        );
        intermediate = result;
        currentPath = result.path;
      }
      final file = intermediate!;
      final pages = await tools.pageCount(file.path);
      final thumb = await tools.generateThumbnail(file.path, type: 'pdf');
      final doc = await data.registerToolResult(
        tmpFile: file,
        fileName: outName,
        toolId: ToolId.rotate.name,
        toolTitle: 'Rotated $baseName',
        type: 'pdf',
        pageCount: pages,
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ToolResultScreen(results: [doc], successTitle: 'Pages rotated!'),
      ));
      setState(() { _path = null; _thumbs = []; _rotations.clear(); _selected.clear(); });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rotate failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rotate PDF'),
        actions: _thumbs.isNotEmpty
            ? [
                IconButton(
                  icon: Icon(_allSelected ? Icons.deselect_rounded : Icons.select_all_rounded),
                  tooltip: _allSelected ? 'Deselect all' : 'Select all',
                  onPressed: () => setState(() {
                    _allSelected = !_allSelected;
                    _selected.clear();
                    if (_allSelected) _selected.addAll(List.generate(_thumbs.length, (i) => i));
                  }),
                ),
              ]
            : null,
      ),
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
                      icon: Icons.rotate_right_rounded,
                      title: 'Choose a PDF',
                      message: 'Select pages and rotate the sideways or upside-down ones.',
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
              Text('Tap pages to select, then rotate', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.72,
                ),
                itemCount: _thumbs.length,
                itemBuilder: (ctx, i) {
                  final isSelected = _selected.contains(i);
                  final rotation = _rotations[i] ?? 0;
                  return GestureDetector(
                    onTap: () => setState(() {
                      isSelected ? _selected.remove(i) : _selected.add(i);
                    }),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Transform.rotate(
                            angle: rotation * 3.14159265 / 180,
                            child: Image.memory(_thumbs[i], fit: BoxFit.cover),
                          ),
                          Positioned(
                            bottom: 4, left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                              child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 4, right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selected.isEmpty ? null : _rotateSelection,
                      icon: const Icon(Icons.rotate_right_rounded),
                      label: const Text('Rotate 90°'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _working ? null : _apply,
                      child: _working
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const ToolHistorySection(toolId: ToolId.rotate),
          ],
        ),
      ),
    );
  }
}
