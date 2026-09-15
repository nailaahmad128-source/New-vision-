import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/conversion/conversion_service.dart';
import '../../../core/services/conversion/conversion_types.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/services/image_capture.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/source_picker.dart';
import '../widgets/professional_tool_page.dart';
import '../widgets/tool_history_list.dart';
import '../widgets/tool_result_screen.dart';

/// Drives every PDF <-> Office conversion direction (PDF to Word, Word to
/// PDF, PDF to Excel, ...) through one real, provider-agnostic path: pick a
/// file, hand it to whichever [ConversionProvider] is configured
/// (see conversion_service.dart), show which stage it's in, and surface
/// exactly what went wrong if it fails — never a fake success.
class OfficeConversionScreen extends StatefulWidget {
  final ToolId toolId;
  final ConversionFormat sourceFormat;
  final ConversionFormat targetFormat;
  final String title;
  final String? initialSourcePath;

  const OfficeConversionScreen({
    super.key,
    required this.toolId,
    required this.sourceFormat,
    required this.targetFormat,
    required this.title,
    this.initialSourcePath,
  });

  @override
  State<OfficeConversionScreen> createState() => _OfficeConversionScreenState();
}

class _OfficeConversionScreenState extends State<OfficeConversionScreen> {
  String? _path;
  bool _working = false;
  ConversionPhase? _phase;
  String? _error;

  @override
  void initState() {
    super.initState();
    _path = widget.initialSourcePath;
  }

  Future<void> _pickGalleryImage() async {
    if (_working) return;

    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      imageQuality: 100,
    );

    if (images.isEmpty) return;

    setState(() {
      _path = images.first.path;
      _error = null;
      _phase = null;
    });
  }

  Future<void> _pickScanImage() async {
    if (_working) return;

    try {
      final file = await pickImageFromCamera();

      if (file == null) return;

      setState(() {
        _path = file;
        _error = null;
        _phase = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not open camera: $e';
      });
    }
  }

  Future<void> _pickFile() async {
    final picked = await pickSourceFiles(
      context,
      allowMultiple: false,
      extensions: widget.sourceFormat.pickerExtensions,
    );
    if (picked.isEmpty) return;
    setState(() {
      _path = picked.first;
      _error = null;
    });
  }

  Future<void> _convert() async {
    final path = _path;
    if (path == null) return;

    setState(() {
      _working = true;
      _error = null;
      _phase = ConversionPhase.uploading;
    });

    try {
      final storage = context.read<FileStorageService>();
      final provider = resolveConversionProvider();

      final baseName = p.basenameWithoutExtension(path);

      // Keep images as images.
      // LocalOfficeConverter detects image input and runs:
      // Image -> OCR -> editable Word / Excel / PowerPoint.
      final outName =
          '$baseName${widget.targetFormat.fileExtension}';

      final file = await provider.convert(
        sourcePath: path,
        sourceFormat: widget.sourceFormat,
        targetFormat: widget.targetFormat,
        outputFileName: outName,
        storage: storage,
        onPhase: (phase) {
          if (mounted) {
            setState(() => _phase = phase);
          }
        },
      );

      final data = context.read<AppDataController>();

      final doc = await data.registerToolResult(
        tmpFile: file,
        fileName: outName,
        toolId: widget.toolId.name,
        toolTitle: '${widget.title}: $baseName',
        type: widget.targetFormat.apiFormat,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ToolResultScreen(
            results: [doc],
            successTitle: 'Converted!',
          ),
        ),
      );

      setState(() {
        _path = widget.initialSourcePath;
      });
    } on ConversionException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Conversion failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _phase = null;
        });
      }
    }
  }

  String _phaseLabel(ConversionPhase phase) => switch (phase) {
        ConversionPhase.uploading => 'Preparing…',
        ConversionPhase.converting => 'Converting on device…',
        ConversionPhase.downloading => 'Saving result…',
      };


  @override
  Widget build(BuildContext context) {
    return ProfessionalToolPage(
      title: widget.title,
      description:
          'Convert documents directly on your device without uploading them to the cloud.',
      icon: widget.targetFormat == ConversionFormat.docx
          ? Icons.description_rounded
          : widget.targetFormat == ConversionFormat.xlsx
              ? Icons.table_chart_rounded
              : Icons.slideshow_rounded,
      history: ToolHistorySection(toolId: widget.toolId),
      child: _path == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ProfessionalSectionTitle(
                  title: 'Create or Import',
                  subtitle: 'Choose the file you want to convert.',
                ),
                const SizedBox(height: 16),
                ProfessionalActionGrid(
              children: [
                if (widget.sourceFormat == ConversionFormat.pdf)
                  ProfessionalAction(
                    title: 'Gallery',
                    subtitle: 'Choose image',
                    icon: Icons.photo_library_rounded,
                    onTap: _pickGalleryImage,
                  ),
                ProfessionalAction(
                  title: 'Device',
                  subtitle: 'Choose ${widget.sourceFormat.displayName}',
                  icon: Icons.folder_rounded,
                  onTap: _pickFile,
                ),
                if (widget.sourceFormat == ConversionFormat.pdf)
                  ProfessionalAction(
                    title: 'Scan',
                    subtitle: 'Scan document',
                    icon: Icons.document_scanner_rounded,
                    onTap: _pickScanImage,
                  ),
              ],
            ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.offline_bolt_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your file stays on the device during conversion.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfessionalFileCard(
                  name: p.basename(_path!),
                  subtitle:
                      'Convert to ${widget.targetFormat.displayName}',
                  onRemove: _working
                      ? null
                      : () => setState(() => _path = null),
                ),
                const SizedBox(height: 18),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _working ? null : _convert,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ProfessionalPrimaryButton(
                  label: 'Convert to ${widget.targetFormat.displayName}',
                  icon: Icons.auto_awesome_rounded,
                  loading: _working,
                  onPressed: _working ? null : _convert,
                ),
                if (_phase != null) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      _phaseLabel(_phase!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
