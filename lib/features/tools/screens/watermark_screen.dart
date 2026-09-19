import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/pdf_tools_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/source_picker.dart';
import '../widgets/professional_tool_page.dart';
import '../widgets/tool_history_list.dart';
import '../widgets/tool_result_screen.dart';

class WatermarkScreen extends StatefulWidget {
  final String? initialSourcePath;
  const WatermarkScreen({super.key, this.initialSourcePath});
  @override State<WatermarkScreen> createState() => _WatermarkScreenState();
}

class _WatermarkScreenState extends State<WatermarkScreen> {
  String? _path;
  final _text = TextEditingController(text: 'ScanFlow');
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
    return ProfessionalToolPage(
      title: 'Watermark PDF',
      description: 'Add a subtle custom watermark to every page of your PDF.',
      icon: Icons.branding_watermark_rounded,
      history: const ToolHistorySection(toolId: ToolId.watermark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_path == null) ...[
            const ProfessionalSectionTitle(
              title: 'Create or Import',
              subtitle: 'Choose the PDF you want to watermark.',
            ),
            const SizedBox(height: 16),
            ProfessionalActionGrid(
              children: [
                ProfessionalAction(
                  title: 'Device',
                  subtitle: 'Choose PDF',
                  icon: Icons.folder_rounded,
                  onTap: _pick,
                ),
              ],
            ),
          ] else ...[
            ProfessionalFileCard(
              name: p.basename(_path!),
              onChange: _pick,
              onRemove: () => setState(() => _path = null),
            ),
            const SizedBox(height: 20),
            const ProfessionalSectionTitle(
              title: 'Watermark',
              subtitle: 'Customize the text that will appear on every page.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _text,
              decoration: const InputDecoration(
                labelText: 'Watermark text',
                prefixIcon: Icon(Icons.text_fields_rounded),
              ),
            ),
            const SizedBox(height: 14),
            Text('Text size: ${_size.round()}'),
            Slider(
              value: _size,
              min: 12,
              max: 48,
              divisions: 12,
              onChanged: (v) => setState(() => _size = v),
            ),
            const SizedBox(height: 14),
            ProfessionalPrimaryButton(
              label: 'Add Watermark',
              icon: Icons.auto_awesome_rounded,
              loading: _working,
              onPressed: _working ? null : _apply,
            ),
          ],
        ],
      ),
    );
  }
}
