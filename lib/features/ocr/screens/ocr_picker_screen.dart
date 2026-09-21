import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../tools/widgets/source_picker.dart';
import 'text_extraction_screen.dart';
import '../../tools/screens/pdf_extract_text_screen.dart';

/// Unified Extract Text entry point for images and PDFs. TextExtractionScreen
/// itself expects to already know which file to process (it's normally
/// opened from a scan or a Library document), so this screen just adds the
/// missing first step for the Tools catalog: let the user pick an image or
/// a PDF, then hand off to the same real OCR engine everything else uses.
class OcrPickerScreen extends StatefulWidget {
  const OcrPickerScreen({super.key});

  @override
  State<OcrPickerScreen> createState() => _OcrPickerScreenState();
}

class _OcrPickerScreenState extends State<OcrPickerScreen> {
  bool _busy = false;

  Future<void> _pickImage() async {
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (file == null || !mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TextExtractionScreen(imagePath: file.path)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPdf() async {
    setState(() => _busy = true);
    try {
      final picked = await pickSourceFiles(context, allowMultiple: false, extensions: const ['pdf']);
      if (picked.isEmpty || !mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PdfExtractTextScreen(initialPath: picked.first)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Extract Text')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _busy
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.text_fields_rounded, size: 72, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 18),
                    const Text('Choose an image or PDF to extract its text.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text('Gallery or PDF and extract its text.', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton.icon(onPressed: _pickImage, icon: const Icon(Icons.image_outlined), label: const Text('Gallery / Image')),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(onPressed: _pickPdf, icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('PDF')),
                  ],
                ),
        ),
      ),
    );
  }
}
