import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../translation/services/speech_service.dart';
import 'package:provider/provider.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../models/document_item.dart';
import '../services/ocr_service.dart';
import '../../translation/screens/translation_screen.dart';

class TextExtractionScreen extends StatefulWidget {
  final String imagePath;
  final String? documentId;
  const TextExtractionScreen({super.key, required this.imagePath, this.documentId});
  @override State<TextExtractionScreen> createState() => _TextExtractionScreenState();
}

class _TextExtractionScreenState extends State<TextExtractionScreen> {
  final _ocr = OcrService();
  final _controller = TextEditingController();
  final _tts = SpeechService();
  bool _loading = true;
  int _progress = 0;
  int _total = 1;
  OcrCancelToken? _cancelToken;
  String? _error;
  String _language = 'auto';

  static const _languages = <String, String>{
    'auto': 'Auto detect (English / Urdu / Arabic)',
    'eng': 'English',
    'urd': 'Urdu',
    'ara': 'Arabic',
    'eng+urd': 'English + Urdu',
    'eng+ara': 'English + Arabic',
  };

  bool get _isRtl {
    if (_language == 'urd' ||
        _language == 'ara' ||
        _language.contains('urd') ||
        _language.contains('ara')) {
      return true;
    }

    // Auto mode: detect Arabic/Urdu characters in the extracted result.
    final text = _controller.text;
    return RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]')
        .hasMatch(text);
  }

  TextDirection get _textDirection =>
      _isRtl ? TextDirection.rtl : TextDirection.ltr;

  TextAlign get _textAlign =>
      _isRtl ? TextAlign.right : TextAlign.left;

  @override void initState() {
    super.initState();
    final saved = context.read<AppDataController>().defaultOcrLanguage;
    _language = saved;
    _extract();
  }

  Future<void> _saveSearchText() async {
    final id = widget.documentId;
    if (id != null) await context.read<AppDataController>().updateExtractedText(id, _controller.text);
  }

  Future<void> _extract() async {
    _cancelToken?.cancel();
    final token = OcrCancelToken();
    _cancelToken = token;
    setState(() { _loading = true; _error = null; _progress = 0; _total = 1; });
    try {
      final text = await _ocr.extractText(widget.imagePath, language: _language, cancelToken: token, onProgress: (current, total) { if (mounted) setState(() { _progress = current; _total = total; }); });
      _controller.text = text;
      await _saveSearchText();
    } catch (e) {
      if (e is OcrCancelledException) { if (mounted) setState(() { _loading = false; }); return; }
      _error = e is UnsupportedError
          ? 'OCR is not available in the Windows edition yet. Use Android/iOS for image and PDF text extraction.'
          : 'Text could not be extracted. For Urdu/Arabic, check your internet connection for the first language-data download.';
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _listen() async {
    final text = _controller.text.trim(); if (text.isEmpty) return;
    await _tts.speak(text, language: _language == 'urd' || _language.contains('urd') ? 'ur-PK' : _language == 'ara' || _language.contains('ara') ? 'ar-SA' : 'en-US');
  }

  Future<void> _shareText() async { final text = _controller.text.trim(); if (text.isNotEmpty) await Share.share(text, subject: 'Extracted text'); }

  Future<void> _saveAsText() async {
    final text = _controller.text.trim(); if (text.isEmpty) return;
    final storage = context.read<FileStorageService>();
    final controller = context.read<AppDataController>();
    final tmp = await storage.newTmpFile('extracted.txt');
    await tmp.writeAsString(text, flush: true);
    final path = await storage.importIntoLibrary(tmp, preferredName: 'Extracted_Text.txt');
    final now = DateTime.now();
    final doc = DocumentItem(id: storage.newId(), name: path.split(Platform.pathSeparator).last, filePath: path, sizeBytes: await storage.fileSize(path), createdAt: now, modifiedAt: now, type: 'text');
    await controller.addDocument(doc);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Text saved to Library')));
  }

  @override void dispose() { _tts.stop(); _controller.dispose(); _ocr.dispose(); super.dispose(); }

  @override
Widget build(BuildContext context) {
  final isPdf = widget.imagePath.toLowerCase().endsWith('.pdf');

  return Scaffold(
    appBar: AppBar(
      title: const Text('Extract Text'),
      actions: [
        IconButton(
          tooltip: 'Copy',
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Clipboard.setData(
                    ClipboardData(text: _controller.text),
                  ),
          icon: const Icon(Icons.copy_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    const Icon(Icons.translate_rounded),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _language,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'OCR language',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: _languages.entries.map(
                          (e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(
                              e.value,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ).toList(),
                        onChanged: _loading
                            ? null
                            : (v) {
                                if (v != null) {
                                  setState(() => _language = v);
                                  context
                                      .read<AppDataController>()
                                      .setDefaultOcrLanguage(v);
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Extract again',
                      onPressed: _loading ? null : _extract,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 10),

            // Compact source preview.
            SizedBox(
              height: 125,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: isPdf
                    ? Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 44,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'All PDF pages will be processed',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Image.file(
                          File(widget.imagePath),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 10),

            // Main extracted-text box gets all remaining space.
            Expanded(
              child: _loading
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              isPdf
                                  ? 'Processing page $_progress of $_total…'
                                  : 'Extracting text…',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => _cancelToken?.cancel(),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : TextField(
                          controller: _controller,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          textDirection: _textDirection,
                          textAlign: _textAlign,
                          textAlignVertical: TextAlignVertical.top,
                          keyboardType: TextInputType.multiline,
                          scrollPadding: const EdgeInsets.all(20),
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.55,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Extracted text will appear here…',
                            hintTextDirection: _textDirection,
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
            ),

            const SizedBox(height: 10),

            // Action buttons wrap instead of overflowing.
            LayoutBuilder(
              builder: (context, constraints) {
                final enabled =
                    !_loading && _controller.text.trim().isNotEmpty;

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: enabled ? _saveAsText : null,
                      icon: const Icon(Icons.save_alt_rounded),
                      label: const Text('Save'),
                    ),
                    OutlinedButton.icon(
                      onPressed: enabled ? _shareText : null,
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share'),
                    ),
                    OutlinedButton.icon(
                      onPressed: enabled ? _listen : null,
                      icon: const Icon(Icons.volume_up_rounded),
                      label: const Text('Listen'),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading || _controller.text.trim().isEmpty
                    ? null
                    : () async {
                        await _saveSearchText();
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TranslationScreen(
                                initialText: _controller.text,
                              ),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.translate_rounded),
                label: const Text(
                  'Translate extracted text',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
