import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/conversion/conversion_service.dart';
import '../../../core/services/conversion/conversion_types.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../settings/screens/settings_screen.dart';
import '../widgets/source_picker.dart';
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
  bool _errorIsConfig = false;

  @override
  void initState() {
    super.initState();
    _path = widget.initialSourcePath;
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
      _errorIsConfig = false;
      _phase = ConversionPhase.uploading;
    });
    try {
      final appData = context.read<AppDataController>();
      final storage = context.read<FileStorageService>();
      final provider = resolveConversionProvider(appData);
      final baseName = p.basenameWithoutExtension(path);
      final outName = '$baseName${widget.targetFormat.fileExtension}';

      final file = await provider.convert(
        sourcePath: path,
        sourceFormat: widget.sourceFormat,
        targetFormat: widget.targetFormat,
        outputFileName: outName,
        storage: storage,
        onPhase: (phase) {
          if (mounted) setState(() => _phase = phase);
        },
      );

      final doc = await appData.registerToolResult(
        tmpFile: file,
        fileName: outName,
        toolId: widget.toolId.name,
        toolTitle: '${widget.title}: $baseName',
        type: widget.targetFormat.apiFormat,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ToolResultScreen(results: [doc], successTitle: 'Converted!')),
      );
      setState(() => _path = widget.initialSourcePath);
    } on ConversionException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _errorIsConfig = e.isConfigurationError;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Conversion failed: $e');
    } finally {
      if (mounted) setState(() {
        _working = false;
        _phase = null;
      });
    }
  }

  String _phaseLabel(ConversionPhase phase) => switch (phase) {
        ConversionPhase.uploading => 'Uploading document…',
        ConversionPhase.converting => 'Converting…',
        ConversionPhase.downloading => 'Downloading result…',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_path == null)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: EmptyState(
                      icon: Icons.cloud_sync_rounded,
                      title: 'Choose a ${widget.sourceFormat.displayName} file',
                      message:
                          'Converted using a secure cloud conversion service — the file is uploaded only for this conversion and isn\'t kept afterwards.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text('Choose ${widget.sourceFormat.displayName}'),
                    ),
                  ),
                ],
              )
            else ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file_rounded),
                  title: Text(p.basename(_path!), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Will convert to ${widget.targetFormat.displayName}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _working ? null : () => setState(() => _path = null),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                      const SizedBox(height: 10),
                      if (_errorIsConfig)
                        FilledButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                          icon: const Icon(Icons.settings_rounded),
                          label: const Text('Open Settings'),
                        )
                      else
                        OutlinedButton.icon(onPressed: _convert, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _working ? null : _convert,
                  child: _working
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            const SizedBox(width: 12),
                            Text(_phase != null ? _phaseLabel(_phase!) : 'Working…'),
                          ],
                        )
                      : Text('Convert to ${widget.targetFormat.displayName}'),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            ToolHistorySection(toolId: widget.toolId),
          ],
        ),
      ),
    );
  }
}
