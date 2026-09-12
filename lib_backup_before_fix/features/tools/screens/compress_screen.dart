import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/pdf_tools_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/source_picker.dart';
import '../widgets/tool_history_list.dart';
import '../widgets/tool_result_screen.dart';

class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});
  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  String? _path;
  int _originalSize = 0;
  CompressionLevel _level = CompressionLevel.medium;
  bool _working = false;

  Future<void> _pickFile() async {
    final picked = await pickSourceFiles(context, allowMultiple: false, extensions: const ['pdf']);
    if (picked.isEmpty) return;
    try {
      final tools = context.read<PdfToolsService>();
      final size = await tools.storage.fileSize(picked.first);
      // Confirm the file actually opens as a valid PDF before accepting it.
      await tools.pageCount(picked.first);
      if (!mounted) return;
      setState(() { _path = picked.first; _originalSize = size; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't open this PDF. It may be corrupted or password protected."),
      ));
    }
  }

  Future<void> _compress() async {
    if (_path == null) return;
    setState(() => _working = true);
    try {
      final tools = context.read<PdfToolsService>();
      final data = context.read<AppDataController>();
      final baseName = p.basenameWithoutExtension(_path!);
      final outName = '${baseName}_compressed.pdf';
      final file = await tools.compress(_path!, level: _level, outputName: outName);
      final pages = await tools.pageCount(file.path);
      final thumb = await tools.generateThumbnail(file.path, type: 'pdf');
      final doc = await data.registerToolResult(
        tmpFile: file,
        fileName: outName,
        toolId: ToolId.compress.name,
        toolTitle: 'Compressed $baseName',
        type: 'pdf',
        pageCount: pages,
      );
      if (!mounted) return;
      final saved = _originalSize > 0
          ? (100 - (doc.sizeBytes / _originalSize * 100)).clamp(0, 99).toStringAsFixed(0)
          : null;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ToolResultScreen(
          results: [doc],
          successTitle: saved != null ? 'Reduced by $saved%!' : 'Compressed!',
        ),
      ));
      setState(() { _path = null; _originalSize = 0; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Compression failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compress PDF')),
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
                      icon: Icons.compress_rounded,
                      title: 'Choose a PDF to compress',
                      message: 'Reduce file size for easier sharing and storage.',
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
                  subtitle: Text('Current size: ${formatBytes(_originalSize)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() { _path = null; _originalSize = 0; }),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Compression level', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<CompressionLevel>(
                segments: const [
                  ButtonSegment(value: CompressionLevel.low, label: Text('Low')),
                  ButtonSegment(value: CompressionLevel.medium, label: Text('Medium')),
                  ButtonSegment(value: CompressionLevel.high, label: Text('High')),
                ],
                selected: {_level},
                onSelectionChanged: (s) => setState(() => _level = s.first),
              ),
              const SizedBox(height: 6),
              Text(
                _level == CompressionLevel.low
                    ? 'Best quality, smallest size reduction.'
                    : _level == CompressionLevel.medium
                        ? 'Balanced quality and size — recommended.'
                        : 'Smallest file, more visible quality loss.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _working ? null : _compress,
                  child: _working
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Compress PDF'),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const ToolHistorySection(toolId: ToolId.compress),
          ],
        ),
      ),
    );
  }
}
