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
    return ProfessionalToolPage(
      title: 'PDF to Image',
      description: 'Export every PDF page as a high-quality JPEG image.',
      icon: Icons.photo_library_rounded,
      history: const ToolHistorySection(toolId: ToolId.pdfToImage),
      child: _path == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  title: 'Image quality',
                  subtitle: 'Higher DPI gives more detail but creates larger images.',
                ),
                Slider(
                  value: _dpi,
                  min: 72,
                  max: 300,
                  divisions: 4,
                  label: '${_dpi.round()} DPI',
                  onChanged: (v) => setState(() => _dpi = v),
                ),
                const SizedBox(height: 14),
                ProfessionalPrimaryButton(
                  label: 'Export Images',
                  icon: Icons.photo_library_rounded,
                  loading: _working,
                  onPressed: _working ? null : _convert,
                ),
              ],
            ),
    );
  }
}
