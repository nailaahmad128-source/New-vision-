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

class PdfToLongImageScreen extends StatefulWidget {
  const PdfToLongImageScreen({super.key});

  @override
  State<PdfToLongImageScreen> createState() => _PdfToLongImageScreenState();
}

class _PdfToLongImageScreenState extends State<PdfToLongImageScreen> {
  String? _path;
  int _pageCount = 0;
  double _dpi = 100;
  bool _working = false;

  Future<void> _pickFile() async {
    final picked = await pickSourceFiles(
      context,
      allowMultiple: false,
      extensions: const ['pdf'],
    );

    if (picked.isEmpty) return;

    try {
      final tools = context.read<PdfToolsService>();
      final count = await tools.pageCount(picked.first);

      if (!mounted) return;

      setState(() {
        _path = picked.first;
        _pageCount = count;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't open this PDF. It may be corrupted or password protected.",
          ),
        ),
      );
    }
  }

  Future<void> _convert() async {
    if (_path == null || _pageCount == 0) return;

    setState(() => _working = true);

    try {
      final tools = context.read<PdfToolsService>();
      final data = context.read<AppDataController>();

      final baseName = p.basenameWithoutExtension(_path!);

      final file = await tools.pdfToLongImage(
        _path!,
        baseOutputName: baseName,
        dpi: _dpi,
      );

      final doc = await data.registerToolResult(
        tmpFile: file,
        fileName: p.basename(file.path),
        toolId: ToolId.pdfToLongImage.name,
        toolTitle: 'Long Image from $baseName',
        type: 'image',
      );

      final result = data.documentById(doc.id) ?? doc;

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ToolResultScreen(
            results: [result],
            successTitle: 'Long image created!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Long image creation failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return ProfessionalToolPage(
      title: 'PDF to Long Image',
      description: 'Join all PDF pages vertically into one continuous image.',
      icon: Icons.view_agenda_rounded,
      history: const ToolHistorySection(toolId: ToolId.pdfToLongImage),
      child: _path == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ProfessionalSectionTitle(
                  title: 'Create or Import',
                  subtitle: 'Choose the PDF you want to turn into one long image.',
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
                  subtitle: '$_pageCount pages will be joined',
                  onRemove: _working
                      ? null
                      : () => setState(() {
                            _path = null;
                            _pageCount = 0;
                          }),
                ),
                const SizedBox(height: 20),
                const ProfessionalSectionTitle(
                  title: 'Image quality',
                  subtitle: 'Lower DPI creates a smaller image and uses less memory.',
                ),
                Slider(
                  value: _dpi,
                  min: 72,
                  max: 150,
                  divisions: 3,
                  label: '${_dpi.round()} DPI',
                  onChanged: _working
                      ? null
                      : (v) => setState(() => _dpi = v),
                ),
                const SizedBox(height: 14),
                ProfessionalPrimaryButton(
                  label: 'Create Long Image',
                  icon: Icons.auto_awesome_rounded,
                  loading: _working,
                  onPressed: _working ? null : _convert,
                ),
              ],
            ),
    );
  }
}
