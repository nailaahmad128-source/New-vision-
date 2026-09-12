import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

/// OCR engine used by the document workflow.
///
/// Latin uses ML Kit for fast on-device recognition. Arabic/Urdu and mixed
/// scripts use Tesseract, with trained data downloaded on first use and kept
/// in the app's private OCR directory.
class OcrCancelledException implements Exception {
  const OcrCancelledException();
}

class OcrCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class OcrService {
  final TextRecognizer _latin = TextRecognizer(script: TextRecognitionScript.latin);

  static const _supported = {'eng', 'ara', 'urd'};

  Future<String> extractText(String path, {String language = 'auto', OcrCancelToken? cancelToken, void Function(int current, int total)? onProgress}) async {
    final isPdf = p.extension(path).toLowerCase() == '.pdf';
    final lang = language == 'auto' ? 'eng+urd+ara' : language;

    if (!isPdf) {
      onProgress?.call(1, 1);
      return _extractImage(path, lang);
    }

    final pdfBytes = await File(path).readAsBytes();
    final dir = await getTemporaryDirectory();
    final texts = <String>[];
    var index = 0;
    final total = await _pdfPageCount(pdfBytes);
    await for (final page in Printing.raster(pdfBytes, dpi: 190)) {
      if (cancelToken?.isCancelled == true) throw const OcrCancelledException();
      final file = File(p.join(dir.path, 'ocr_${DateTime.now().microsecondsSinceEpoch}_${index++}.png'));
      try {
        await file.writeAsBytes(await page.toPng(), flush: true);
        final text = await _extractImage(file.path, lang);
        onProgress?.call(index, total);
        if (text.trim().isNotEmpty) {
          texts.add('--- Page $index ---\n${text.trim()}');
        }
      } finally {
        if (await file.exists()) {
          try { await file.delete(); } catch (_) {}
        }
      }
    }
    if (cancelToken?.isCancelled == true) throw const OcrCancelledException();
    return texts.join('\n\n').trim();
  }

  Future<int> _pdfPageCount(List<int> bytes) async {
    var count = 0;
    await for (final _ in Printing.raster(Uint8List.fromList(bytes), dpi: 36)) { count++; }
    return count == 0 ? 1 : count;
  }

  Future<String> _extractImage(String path, String language) async {
    final normalized = language.toLowerCase().trim();
    if (normalized == 'eng') {
      final result = await _latin.processImage(InputImage.fromFile(File(path)));
      return result.text.trim();
    }

    final codes = normalized.split('+').where(_supported.contains).toList();
    if (codes.isEmpty) {
      final result = await _latin.processImage(InputImage.fromFile(File(path)));
      return result.text.trim();
    }

    for (final code in codes) {
      await _ensureTessData(code);
    }
    return (await FlutterTesseractOcr.extractText(
      path,
      language: codes.join('+'),
      args: const {
        'psm': '6',
        'preserve_interword_spaces': '1',
      },
    )).trim();
  }

  Future<void> _ensureTessData(String language) async {
    final root = await FlutterTesseractOcr.getTessdataPath();
    final file = File(p.join(root, '$language.traineddata'));
    if (await file.exists() && await file.length() > 100000) return;

    final client = HttpClient();
    try {
      final url = Uri.parse('https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/$language.traineddata');
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw Exception('Could not download OCR language data ($language).');
      }
      final bytes = <int>[];
      await for (final chunk in response) { bytes.addAll(chunk); }
      if (bytes.length < 100000) throw Exception('OCR language data is incomplete.');
      await file.writeAsBytes(bytes, flush: true);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> dispose() => _latin.close();
}
