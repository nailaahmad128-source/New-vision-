import 'package:flutter/material.dart';
import '../widgets/source_picker.dart';
import '../../ocr/screens/text_extraction_screen.dart';

class OcrToolScreen extends StatefulWidget {
  const OcrToolScreen({super.key});
  @override State<OcrToolScreen> createState() => _OcrToolScreenState();
}

class _OcrToolScreenState extends State<OcrToolScreen> {
  bool _opening = false;
  Future<void> _choose() async {
    setState(() => _opening = true);
    try {
      final paths = await pickSourceFiles(context, allowMultiple: false, extensions: const ['jpg','jpeg','png','webp','pdf']);
      if (paths.isEmpty || !mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => TextExtractionScreen(imagePath: paths.first)));
    } finally { if (mounted) setState(() => _opening = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('OCR — Image to Text')),
    body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.text_snippet_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 16), Text('Extract editable text from a scan or PDF', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
      const SizedBox(height: 8), const Text('English, Urdu and Arabic workflows are supported by the existing OCR service.', textAlign: TextAlign.center),
      const SizedBox(height: 22), FilledButton.icon(onPressed: _opening ? null : _choose, icon: const Icon(Icons.upload_file_rounded), label: Text(_opening ? 'Opening…' : 'Choose file')),
    ]))),
  );
}
