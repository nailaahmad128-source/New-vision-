import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/pdf_tools_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/source_picker.dart';
import '../widgets/professional_tool_page.dart';
import '../widgets/tool_history_list.dart';
import '../widgets/tool_result_screen.dart';

class CompressScreen extends StatefulWidget {
  final String? initialSourcePath;
  const CompressScreen({super.key, this.initialSourcePath});
  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  String? _path;
  int _originalSize = 0;
  CompressionLevel _level = CompressionLevel.medium;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSourcePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadFile(widget.initialSourcePath!));
    }
  }

  Future<void> _pickFile() async {
    final picked = await pickSourceFiles(context, allowMultiple: false, extensions: const ['pdf']);
    if (picked.isEmpty) return;
    await _loadFile(picked.first);
  }

  Future<void> _loadFile(String path) async {
    try {
      final tools = context.read<PdfToolsService>();
      final size = await tools.storage.fileSize(path);
      // Confirm the file actually opens as a valid PDF before accepting it.
      await tools.pageCount(path);
      if (!mounted) return;
      setState(() { _path = path; _originalSize = size; });
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
    return ProfessionalToolPage(
      title: 'Compress PDF',
      description: 'Reduce PDF size for faster sharing and easier storage.',
      icon: Icons.compress_rounded,
      history: const ToolHistorySection(toolId: ToolId.compress),
      child: _path == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ProfessionalSectionTitle(
                  title: 'Create or Import',
                  subtitle: 'Choose a PDF from your device to compress.',
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
                  subtitle: 'Current size: ${formatBytes(_originalSize)}',
                  onRemove: () => setState(() {
                    _path = null;
                    _originalSize = 0;
                  }),
                ),
                const SizedBox(height: 20),
                const ProfessionalSectionTitle(
                  title: 'Compression level',
                  subtitle: 'Choose the balance between quality and file size.',
                ),
                const SizedBox(height: 14),
                SegmentedButton<CompressionLevel>(
                  segments: const [
                    ButtonSegment(
                      value: CompressionLevel.low,
                      label: Text('Low'),
                    ),
                    ButtonSegment(
                      value: CompressionLevel.medium,
                      label: Text('Medium'),
                    ),
                    ButtonSegment(
                      value: CompressionLevel.high,
                      label: Text('High'),
                    ),
                  ],
                  selected: {_level},
                  onSelectionChanged: (s) => setState(() => _level = s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  _level == CompressionLevel.low
                      ? 'Best quality with smaller size reduction.'
                      : _level == CompressionLevel.medium
                          ? 'Balanced quality and size — recommended.'
                          : 'Smallest file with more visible quality loss.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 22),
                ProfessionalPrimaryButton(
                  label: 'Compress PDF',
                  icon: Icons.compress_rounded,
                  loading: _working,
                  onPressed: _working ? null : _compress,
                ),
              ],
            ),
    );
  }
}
