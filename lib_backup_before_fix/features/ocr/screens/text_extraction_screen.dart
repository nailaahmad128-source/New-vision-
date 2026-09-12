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

  @override void initState() {
    super.initState();
    final saved = context.read<AppDataController>().defaultOcrLanguage;
    _language = _languages.containsKey(saved) ? saved : 'auto';
    _controller.addListener(_onTextChanged);
    _extract();
  }

  void _onTextChanged() => setState(() {});

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

  @override void dispose() { _cancelToken?.cancel(); _controller.removeListener(_onTextChanged); _tts.stop(); _controller.dispose(); _ocr.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasText = _controller.text.trim().isNotEmpty;
    final isPdf = widget.imagePath.toLowerCase().endsWith('.pdf');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Text'),
        actions: [
          IconButton(
            tooltip: 'Copy text',
            onPressed: hasText ? () => Clipboard.setData(ClipboardData(text: _controller.text)) : null,
            icon: const Icon(Icons.copy_rounded),
          ),
          IconButton(
            tooltip: 'Run OCR again',
            onPressed: _loading ? null : _extract,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
                  child: Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.document_scanner_rounded, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isPdf ? 'PDF text extraction' : 'Image text extraction', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(isPdf ? 'OCR will process the document pages.' : 'Extract editable text from this scan.', style: theme.textTheme.bodySmall),
                ])),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: _language,
                decoration: const InputDecoration(labelText: 'OCR language', prefixIcon: Icon(Icons.language_rounded)),
                items: _languages.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: _loading ? null : (v) { if (v != null) { setState(() => _language = v); context.read<AppDataController>().setDefaultOcrLanguage(v); } },
              )),
            ]),
          ),
          const SizedBox(height: 12),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(value: _total > 1 ? (_progress / _total).clamp(0.0, 1.0) : null, borderRadius: BorderRadius.circular(8)),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _loading
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.document_scanner_rounded, size: 58, color: scheme.primary),
                      const SizedBox(height: 14),
                      Text(isPdf && _total > 1 ? 'Processing page $_progress of $_total…' : 'Extracting text…', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Keep this screen open while OCR is running.', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 16),
                      TextButton.icon(onPressed: () => _cancelToken?.cancel(), icon: const Icon(Icons.close_rounded), label: const Text('Cancel')),
                    ]))
                  : _error != null
                      ? _ErrorCard(message: _error!, onRetry: _extract)
                      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Expanded(child: Container(
                            decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(20), border: Border.all(color: scheme.outlineVariant)),
                            child: TextField(
                              controller: _controller,
                              expands: true, maxLines: null, minLines: null,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: const InputDecoration(hintText: 'Extracted text will appear here…', border: InputBorder.none, contentPadding: EdgeInsets.all(18)),
                            ),
                          )),
                          const SizedBox(height: 10),
                          if (hasText) Text('${_controller.text.trim().length} characters', style: theme.textTheme.bodySmall, textAlign: TextAlign.right),
                        ]),
            ),
          ),
          if (!_loading && _error == null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: hasText ? _saveAsText : null, icon: const Icon(Icons.save_alt_rounded), label: const Text('Save'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: hasText ? _shareText : null, icon: const Icon(Icons.share_rounded), label: const Text('Share'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: hasText ? _listen : null, icon: const Icon(Icons.volume_up_rounded), label: const Text('Listen'))),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: FilledButton.icon(
                    onPressed: hasText ? () async { await _saveSearchText(); if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => TranslationScreen(initialText: _controller.text))); } : null,
                    icon: const Icon(Icons.translate_rounded), label: const Text('Translate extracted text'),
                  )),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});
  @override Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(child: Card(
      child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, size: 52, color: scheme.error),
        const SizedBox(height: 12),
        Text('OCR could not finish', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
      ])),
    ));
  }
}
