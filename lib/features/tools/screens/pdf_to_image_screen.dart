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

class PdfToImageScreen extends StatefulWidget {
  const PdfToImageScreen({super.key});
  @override
  State<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends State<PdfToImageScreen> {
  String? _path;
  int _pageCount = 0;
  double _dpi = 150;
  bool _working = false;

  Future<void> _pickFile() async {
    final picked = await pickSourceFiles(context, allowMultiple: false, extensions: const ['pdf']);
    if (picked.isEmpty) return;
    try {
      final tools = context.read<PdfToolsService>();
      final count = await tools.pageCount(picked.first);
      if (!mounted) return;
      setState(() { _path = picked.first; _pageCount = count; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't open this PDF. It may be corrupted or password protected."),
      ));
    }
  }

  Future<void> _convert() async {
    if (_path == null) return;
    setState(() => _working = true);
    try {
      final tools = context.read<PdfToolsService>();
      final data = context.read<AppDataController>();
      final baseName = p.basenameWithoutExtension(_path!);
      final files = await tools.pdfToImages(_path!, baseOutputName: baseName, dpi: _dpi);
      final results = <DocumentItem>[];
      for (final f in files) {
        final doc = await data.registerToolResult(
          tmpFile: f,
          fileName: p.basename(f.path),
          toolId: ToolId.pdfToImage.name,
          toolTitle: 'Images from $baseName',
          type: 'image',
        );
        results.add(data.documentById(doc.id) ?? doc);
      }
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ToolResultScreen(
          results: results,
          successTitle: 'Exported ${results.length} images!',
        ),
      ));
      setState(() { _path = null; _pageCount = 0; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF to Image')),
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
                      icon: Icons.photo_library_rounded,
                      title: 'Choose a PDF to export',
                      message: 'Every page will be saved as a separate JPEG image.',
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
              const SizedBox(height: 20),
              Text('Image quality', style: Theme.of(context).textTheme.titleMedium),
              Slider(
                value: _dpi,
                min: 72,
                max: 300,
                divisions: 4,
                label: '${_dpi.round()} DPI',
                onChanged: (v) => setState(() => _dpi = v),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _working ? null : _convert,
                  child: _working
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Export Images'),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const ToolHistorySection(toolId: ToolId.pdfToImage),
          ],
        ),
      ),
    );
  }
}
