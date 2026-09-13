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
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF to Long Image'),
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
                      icon: Icons.view_agenda_rounded,
                      title: 'Create a long image from a PDF',
                      message:
                          'All PDF pages will be joined vertically into one continuous JPEG image.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _working ? null : _pickFile,
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
                  title: Text(
                    p.basename(_path!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('$_pageCount pages will be joined'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _working
                        ? null
                        : () => setState(() {
                              _path = null;
                              _pageCount = 0;
                            }),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Image quality',
                style: Theme.of(context).textTheme.titleMedium,
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
              Text(
                'Lower DPI creates a smaller long image and uses less memory.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _working ? null : _convert,
                  icon: _working
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    _working ? 'Creating Long Image…' : 'Create Long Image',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const ToolHistorySection(
              toolId: ToolId.pdfToLongImage,
            ),
          ],
        ),
      ),
    );
  }
}
