import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../widgets/professional_tool_page.dart';
import '../widgets/source_picker.dart';
import '../widgets/tool_history_list.dart';
import '../widgets/tool_result_screen.dart';
import '../../ocr/services/hybrid_pdf_extraction_service.dart';
import '../../ocr/services/ocr_service.dart';

class PdfExtractTextScreen extends StatefulWidget {
  const PdfExtractTextScreen({super.key});

  @override
  State<PdfExtractTextScreen> createState() => _PdfExtractTextScreenState();
}

class _PdfExtractTextScreenState extends State<PdfExtractTextScreen> {
  late final TextEditingController _textController;
  final _extractor = HybridPdfExtractionService();

  String? _path;
  String _language = 'auto';
  String _text = '';
  bool _working = false;
  int _current = 0;
  int _total = 1;
  String? _error;

  static const _languages = <String, String>{
    'auto': 'Auto — English / Urdu / Arabic',
    'eng': 'English',
    'urd': 'Urdu',
    'ara': 'Arabic',
    'eng+urd': 'English + Urdu',
    'eng+ara': 'English + Arabic',
  };

  Future<void> _pick() async {
    final picked = await pickSourceFiles(
      context,
      allowMultiple: false,
      extensions: const ['pdf'],
    );

    if (picked.isEmpty) return;

    setState(() {
      _path = picked.first;
      _text = '';
      _error = null;
      _current = 0;
      _total = 1;
    });
  }

  Future<void> _extract() async {
    final path = _path;
    if (path == null || _working) return;

    setState(() {
      _working = true;
      _error = null;
      _text = '';
      _current = 0;
      _total = 1;
    });

    try {
      final pages = await _extractor.extract(
        path,
        language: _language,
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _current = current;
            _total = total;
          });
        },
      );

      final buffer = StringBuffer();

      for (final page in pages) {
        if (page.text.trim().isEmpty) continue;

        if (buffer.isNotEmpty) {
          buffer.writeln();
          buffer.writeln();
        }

        buffer.writeln('--- Page ${page.pageNumber} ---');
        buffer.writeln(page.text.trim());

        if (page.usedOcr) {

        }
      }

      final result = buffer.toString().trim();

      if (result.isEmpty) {
        throw Exception(
          'No readable text was found in this PDF. '
          'Try selecting the correct OCR language.',
        );
      }

      if (!mounted) return;

      setState(() {
        _text = result;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e is OcrCancelledException
            ? 'Extraction cancelled.'
            : 'Extraction failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _save() async {
    final text = _text.trim();
    if (text.isEmpty) return;

    final storage = context.read<FileStorageService>();
    final data = context.read<AppDataController>();

    final base = _path == null
        ? 'Extracted_Text'
        : p.basenameWithoutExtension(_path!);

    final tmp = await storage.newTmpFile('${base}_extracted.txt');
    await tmp.writeAsString(text, flush: true);

    final imported = await storage.importIntoLibrary(
      tmp,
      preferredName: '${base}_extracted.txt',
    );

    final now = DateTime.now();

    final doc = await data.registerToolResult(
      tmpFile: File(imported),
      fileName: p.basename(imported),
      toolId: ToolId.extractText.name,
      toolTitle: 'PDF Extract: $base',
      type: 'text',
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ToolResultScreen(
          results: [doc],
          successTitle: 'Text extracted successfully!',
        ),
      ),
    );
  }

  Future<void> _share() async {
    final text = _text.trim();
    if (text.isEmpty) return;

    await Share.share(
      text,
      subject: 'Extracted PDF text',
    );
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _extractor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProfessionalToolPage(
      title: 'PDF Extract',
      description:
          'Extract text from normal, scanned, and mixed PDFs using native extraction with OCR fallback.',
      icon: Icons.text_snippet_rounded,
      history: const ToolHistorySection(
        toolId: ToolId.extractText,
      ),
      child: _path == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ProfessionalSectionTitle(
                  title: 'Create or Import',
                  subtitle: 'Choose a PDF to extract its readable content.',
                ),
                const SizedBox(height: 16),
                ProfessionalActionGrid(
                  children: [
                    ProfessionalAction(
                      title: 'Device',
                      subtitle: 'Choose a PDF',
                      icon: Icons.folder_rounded,
                      onTap: _pick,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Normal PDF text is extracted directly. Scanned pages automatically use OCR.',
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
                  subtitle: 'Hybrid text extraction',
                  onRemove: _working
                      ? null
                      : () {
                          setState(() {
                            _path = null;
                            _text = '';
                            _error = null;
                          });
                        },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _language,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'OCR language',
                    border: OutlineInputBorder(),
                  ),
                  items: _languages.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: _working
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _language = value);
                          }
                        },
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(_error!),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_working) ...[
                  LinearProgressIndicator(
                    value: _total > 0 ? _current / _total : null,
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Processing page $_current of $_total…',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_text.isNotEmpty)
                  Container(
                    height: 360,
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant,
                      ),
                    ),
                    child: TextField(
                      controller: _textController,
                      readOnly: false,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Extracted text',
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                ProfessionalPrimaryButton(
                  label: _working
                      ? 'Extracting…'
                      : 'Extract Text',
                  icon: Icons.text_snippet_rounded,
                  loading: _working,
                  onPressed: _working ? null : _extract,
                ),
                if (_text.isNotEmpty && !_working) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _share,
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}
