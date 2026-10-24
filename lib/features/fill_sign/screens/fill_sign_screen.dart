import 'dart:io';
import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/services/pdf_tools_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../tools/widgets/source_picker.dart';
import '../../tools/widgets/tool_history_list.dart';
import '../../tools/widgets/tool_result_screen.dart';

class FillSignScreen extends StatefulWidget {
  final String? initialPath;

  const FillSignScreen({super.key, this.initialPath});

  @override
  State<FillSignScreen> createState() => _FillSignScreenState();
}

class _FillSignScreenState extends State<FillSignScreen> {
  String? _path;
  Uint8List? _pdfBytes;
  bool _loading = false;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    final path = widget.initialPath;
    if (path != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(path));
    }
  }

  Future<void> _pickFile() async {
    final picked = await pickSourceFiles(
      context,
      allowMultiple: false,
      extensions: const ['pdf'],
    );
    if (picked.isEmpty || !mounted) return;
    await _load(picked.first);
  }

  Future<void> _load(String path) async {
    setState(() {
      _path = null;
      _pdfBytes = null;
      _loading = true;
    });

    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) {
        throw const FormatException('The selected PDF is empty.');
      }

      if (!mounted) return;
      setState(() {
        _path = path;
        _pdfBytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't open this PDF. It may be corrupted or password protected.",
          ),
        ),
      );
    }
  }

  Future<void> _saveEditedPdf(Uint8List bytes) async {
    if (_path == null || _working) return;

    setState(() => _working = true);

    try {
      final storage = context.read<FileStorageService>();
      final tools = context.read<PdfToolsService>();
      final data = context.read<AppDataController>();

      final baseName = p.basenameWithoutExtension(_path!);
      final outName = '${baseName}_signed.pdf';

      final file = await storage.newTmpFile(outName);
      await file.writeAsBytes(bytes, flush: true);

      final pages = await tools.pageCount(file.path);

      final doc = await data.registerToolResult(
        tmpFile: file,
        fileName: outName,
        toolId: ToolId.fillSign.name,
        toolTitle: 'Signed $baseName',
        type: 'pdf',
        pageCount: pages,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ToolResultScreen(
            results: [doc],
            successTitle: 'Document saved!',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fill & Sign'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ToolHistoryScreen(
                    toolId: ToolId.fillSign,
                    title: 'Fill & Sign History',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _pdfBytes == null
                ? Column(
                    children: [
                      const Expanded(
                        child: EmptyState(
                          icon: Icons.draw_rounded,
                          title: 'Choose a PDF',
                          message:
                              'Open a PDF to sign, add text, fill forms, and edit pages.',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.upload_file_rounded),
                            label: const Text('Choose PDF'),
                          ),
                        ),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      Positioned.fill(
                        child: PdfEditorView(
                          key: ValueKey(_path),
                          bytes: _pdfBytes!,
                          documentId: _path,
                          onSave: _saveEditedPdf,
                        ),
                      ),
                      if (_working)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black26,
                            child: Center(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 12),
                                      Text('Saving PDF...'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}
