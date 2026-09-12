import 'dart:io';
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

class WatermarkScreen extends StatefulWidget {
  final String? initialSourcePath;
  const WatermarkScreen({super.key, this.initialSourcePath});
  @override State<WatermarkScreen> createState() => _WatermarkScreenState();
}

class _WatermarkScreenState extends State<WatermarkScreen> {
  String? _path;
  final _text = TextEditingController(text: 'PDF Master Tools');
  double _size = 24;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSourcePath != null) _path = widget.initialSourcePath;
  }

  @override
  void dispose() { _text.dispose(); super.dispose(); }

  Future<void> _pick() async {
    final picked = await pickSourceFiles(context, allowMultiple: false, extensions: const ['pdf']);
    if (picked.isNotEmpty && mounted) setState(() => _path = picked.first);
  }

  Future<void> _apply() async {
    final path = _path;
    final text = _text.text.trim();
    if (path == null || text.isEmpty) return;
    setState(() => _working = true);
    try {
      final tools = context.read<PdfToolsService>();
      final data = context.read<AppDataController>();
      final base = p.basenameWithoutExtension(path);
      final name = '${base}_watermarked.pdf';
      final file = await tools.watermark(path, text: text, fontSize: _size, outputName: name);
      final pages = await tools.pageCount(file.path);
      final doc = await data.registerToolResult(
        tmpFile: file, fileName: name, toolId: ToolId.watermark.name,
        toolTitle: 'Watermarked $base', type: 'pdf', pageCount: pages,
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ToolResultScreen(results: [doc], successTitle: 'Watermark added!')));
      setState(() => _path = null);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Watermark failed: $e')));
    } finally { if (mounted) setState(() => _working = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Watermark PDF')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
        if (_path == null) ...[
          const EmptyState(icon: Icons.branding_watermark_rounded, title: 'Add a watermark', message: 'Place a subtle custom label on every page of a PDF.'),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _pick, icon: const Icon(Icons.upload_file_rounded), label: const Text('Choose PDF'))),
        ] else ...[
          Card(child: ListTile(leading: const Icon(Icons.picture_as_pdf_rounded), title: Text(p.basename(_path!), maxLines: 2, overflow: TextOverflow.ellipsis), trailing: IconButton(onPressed: _pick, icon: const Icon(Icons.swap_horiz_rounded)))),
          const SizedBox(height: 16),
          TextField(controller: _text, decoration: const InputDecoration(labelText: 'Watermark text', prefixIcon: Icon(Icons.text_fields_rounded))),
          const SizedBox(height: 16),
          Text('Text size: ${_size.round()}'),
          Slider(value: _size, min: 12, max: 48, divisions: 12, onChanged: (v) => setState(() => _size = v)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _working ? null : _apply, icon: _working ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded), label: Text(_working ? 'Applying…' : 'Add Watermark')),
        ],
        const SizedBox(height: 32), const Divider(), const SizedBox(height: 16),
        const ToolHistorySection(toolId: ToolId.watermark),
      ]),
    );
  }
}
