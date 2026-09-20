import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'online_ocr_service.dart';

class OcrCancelledException implements Exception {
  const OcrCancelledException();
}

class OcrCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

class OcrService {
  static const MethodChannel _paddleChannel =
      MethodChannel('com.hameed.pdfmastertools/paddle_ocr');

  static const _paddleLanguages = <String>{
    'eng',
    'urd',
    'ara',
    'fas',
    'pus',
    'uig',
    'syr',
    'kmr',
    'snd',
    'bal',
  };

  bool _paddleDisabled = false;

  OcrService({String? onlineApiKey}) {
    final key = onlineApiKey?.trim() ?? '';
    if (key.isNotEmpty) {
      _online = OnlineOcrService(apiKey: key);
    }
  }

  final TextRecognizer _latin =
      TextRecognizer(script: TextRecognitionScript.latin);

  OnlineOcrService? _online;

  // Once the online service fails, stop retrying it for the rest of
  // this OCR operation. The existing local OCR remains the fallback.
  bool _onlineDisabled = false;

  // Official Tesseract tessdata_best language models supported by ScanFlow.
  // Models are downloaded only when the user selects a language.
  static const _supported = <String>{
    'afr', 'amh', 'ara', 'asm', 'aze', 'aze_cyrl', 'bel', 'ben',
    'bod', 'bos', 'bre', 'bul', 'cat', 'ceb', 'ces', 'chi_sim',
    'chi_tra', 'chr', 'cym', 'dan', 'deu', 'div', 'dzo', 'ell',
    'eng', 'enm', 'epo', 'est', 'eus', 'fao', 'fas', 'fil', 'fin',
    'fra', 'frm', 'fry', 'gla', 'gle', 'glg', 'grc', 'guj', 'hat',
    'heb', 'hin', 'hrv', 'hun', 'hye', 'iku', 'ind', 'isl', 'ita',
    'jav', 'jpn', 'kan', 'kat', 'kaz', 'khm', 'kir', 'kmr', 'kor',
    'lao', 'lat', 'lav', 'lit', 'ltz', 'mal', 'mar', 'mkd', 'mlt',
    'mon', 'mri', 'msa', 'mya', 'nep', 'nld', 'nor', 'oci', 'ori',
    'pan', 'pol', 'por', 'pus', 'que', 'ron', 'rus', 'san', 'sin',
    'slk', 'slv', 'spa', 'sqi', 'srp', 'srp_latn', 'swa', 'swe',
    'syr', 'tam', 'tel', 'tgk', 'tha', 'tir', 'tur', 'uig',
    'ukr', 'urd', 'uzb', 'uzb_cyrl', 'vie', 'yid',
  };

  Future<String> extractText(
    String path, {
    String language = 'auto',
    OcrCancelToken? cancelToken,
    void Function(int current, int total)? onProgress,
  }) async {
    final isPdf = p.extension(path).toLowerCase() == '.pdf';

    // Auto keeps a practical fast path for the most common ScanFlow
    // multilingual documents. Users can select any supported language
    // explicitly from the global language selector.
    final lang = language == 'auto'
        ? 'eng+urd+ara'
        : language.toLowerCase().trim();

    if (!isPdf) {
      onProgress?.call(0, 1);

      if (cancelToken?.isCancelled == true) {
        throw const OcrCancelledException();
      }

      final paddleText = await _tryPaddle(
        path,
        lang,
      );

      if (paddleText != null) {
        onProgress?.call(1, 1);
        return paddleText;
      }

      final onlineText = await _tryOnline(
        path,
        lang,
      );

      if (onlineText != null) {
        onProgress?.call(1, 1);
        return onlineText;
      }

      final localText = await _extractImage(path, lang);
      onProgress?.call(1, 1);
      return localText;
    }

    final pdfBytes = await File(path).readAsBytes();
    final dir = await getTemporaryDirectory();
    final texts = <String>[];

    final total = await _pdfPageCount(pdfBytes);
    var index = 0;

    await for (final page in Printing.raster(
      pdfBytes,
      dpi: 300,
    )) {
      if (cancelToken?.isCancelled == true) {
        throw const OcrCancelledException();
      }

      final file = File(
        p.join(
          dir.path,
          'scanflow_ocr_${DateTime.now().microsecondsSinceEpoch}_$index.png',
        ),
      );

      try {
        await file.writeAsBytes(
          await page.toPng(),
          flush: true,
        );

        index++;

        String text = await _tryPaddle(
              file.path,
              lang,
            ) ??
            await _tryOnline(
              file.path,
              lang,
            ) ??
            await _extractImage(
              file.path,
              lang,
            );

        onProgress?.call(index, total);

        if (text.trim().isNotEmpty) {
          texts.add(
            '--- Page $index ---\n${text.trim()}',
          );
        }
      } finally {
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
    }

    if (cancelToken?.isCancelled == true) {
      throw const OcrCancelledException();
    }

    return texts.join('\n\n').trim();
  }

  Future<String?> _tryPaddle(
    String path,
    String language,
  ) async {
    if (_paddleDisabled) {
      return null;
    }

    final normalized = language.toLowerCase().trim();

    if (normalized != 'auto') {
      final requested = normalized
          .split('+')
          .where((code) => code.trim().isNotEmpty)
          .map((code) => code.trim())
          .toSet();

      if (requested.isEmpty ||
          !requested.every(_paddleLanguages.contains)) {
        return null;
      }
    }

    try {
      final raw = await _paddleChannel.invokeMethod<dynamic>(
        'recognizeFile',
        <String, dynamic>{
          'path': path,
        },
      );

      if (raw is! Map) {
        return null;
      }

      final text = raw['text']?.toString().trim() ?? '';

      if (text.length < 2) {
        return null;
      }

      return text;
    } on PlatformException {
      // Disable Paddle for the rest of this service instance after
      // a native/model initialization failure. Existing OCR remains
      // available as the fallback.
      _paddleDisabled = true;
      return null;
    } catch (_) {
      _paddleDisabled = true;
      return null;
    }
  }

  Future<String?> _tryOnline(
    String path,
    String language,
  ) async {
    final online = _online;

    if (online == null || _onlineDisabled) {
      return null;
    }

    try {
      // OCR.space Engine 3 supports automatic language detection.
      // Mixed selections such as eng+urd are therefore sent as auto.
      final onlineLanguage = language.contains('+') ? 'auto' : language;

      final text = await online.extractText(
        filePath: path,
        language: onlineLanguage,
      );

      final cleaned = text.trim();

      if (cleaned.length < 2) {
        return null;
      }

      return cleaned;
    } catch (_) {
      // Never let an online/API/network problem break OCR.
      // Fall back to the existing local ML Kit/Tesseract engine.
      _onlineDisabled = true;
      return null;
    }
  }

  Future<int> _pdfPageCount(List<int> bytes) async {
    var count = 0;

    await for (final _ in Printing.raster(
      Uint8List.fromList(bytes),
      dpi: 36,
    )) {
      count++;
    }

    return count == 0 ? 1 : count;
  }

  Future<String> _extractImage(
    String path,
    String language,
  ) async {
    final normalized = language.toLowerCase().trim();

    // English gets the fast ML Kit path first.
    if (normalized == 'eng') {
      try {
        final result = await _latin.processImage(
          InputImage.fromFile(File(path)),
        );

        final text = result.text.trim();

        if (text.isNotEmpty) {
          return text;
        }
      } catch (_) {}
    }

    final requested = normalized
        .split('+')
        .where(_supported.contains)
        .toSet()
        .toList();

    if (requested.isEmpty) {
      return '';
    }

    for (final code in requested) {
      await _ensureTessData(code);
    }

    String ocrPath = path;
    String? processedPath;

    try {
      // Clean the input before Tesseract.
      // This is especially useful for phone photos and scanned PDFs.
      processedPath = await _preprocessForOcr(path);

      if (processedPath != null) {
        ocrPath = processedPath;
      }
    } catch (_) {
      // Never make OCR fail just because preprocessing failed.
      ocrPath = path;
    }

    try {
      final candidates = <String>[];

      // For a single language, use two useful page layouts.
      // This avoids the old 5-pass-per-language approach.
      for (final code in requested) {
        try {
          final text = await _tesseractBest(
            ocrPath,
            [code],
          );

          if (text.trim().isNotEmpty) {
            candidates.add(text.trim());
          }
        } catch (_) {}
      }

      // Mixed-language OCR gets one combined pass as a fallback.
      if (requested.length > 1) {
        try {
          final mixed = await _tesseractBest(
            ocrPath,
            requested,
          );

          if (mixed.trim().isNotEmpty) {
            candidates.add(mixed.trim());
          }
        } catch (_) {}
      }

      if (candidates.isEmpty) {
        return '';
      }

      candidates.sort(
        (a, b) => _qualityScore(b).compareTo(
          _qualityScore(a),
        ),
      );

      return candidates.first.trim();
    } finally {
      if (processedPath != null) {
        final file = File(processedPath);

        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
    }
  }

  /// Prepare a document image for OCR.
  ///
  /// The goal is not to destroy the original image. A temporary
  /// grayscale/contrast-enhanced PNG is created only for OCR.
  Future<String?> _preprocessForOcr(String path) async {
    final source = File(path);

    if (!await source.exists()) {
      return null;
    }

    final bytes = await source.readAsBytes();

    if (bytes.isEmpty) {
      return null;
    }

    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      return null;
    }

    // Respect camera/gallery EXIF orientation.
    var image = img.bakeOrientation(decoded);

    // Very large camera images waste RAM and slow Tesseract.
    // Keep enough resolution for document OCR.
    const maxWidth = 2600;

    if (image.width > maxWidth) {
      image = img.copyResize(
        image,
        width: maxWidth,
        interpolation: img.Interpolation.cubic,
      );
    }

    // Grayscale removes distracting colour information.
    image = img.grayscale(image);

    // Moderate contrast enhancement helps faded/grey scans
    // without aggressively destroying Urdu/Arabic diacritics.
    image = img.adjustColor(
      image,
      contrast: 1.20,
      brightness: 1.04,
    );

    final directory = await getTemporaryDirectory();

    final output = File(
      p.join(
        directory.path,
        'scanflow_ocr_preprocessed_'
            '${DateTime.now().microsecondsSinceEpoch}.png',
      ),
    );

    await output.writeAsBytes(
      img.encodePng(image, level: 6),
      flush: true,
    );

    return output.path;
  }

  Future<String> _tesseractBest(
    String path,
    List<String> languages,
  ) async {
    final language = languages.join('+');
    final results = <String>[];

    // PSM 6 is strong for ordinary scanned document pages.
    // PSM 11 is useful for sparse/irregular text.
    // For mixed languages, PSM 3 is also useful as a final fallback.
    final List<String> psmModes;

    if (languages.length > 1) {
      psmModes = const ['6', '11', '3'];
    } else {
      psmModes = const ['6', '11'];
    }

    for (final psm in psmModes) {
      try {
        final text = await FlutterTesseractOcr.extractText(
          path,
          language: language,
          args: {
            'psm': psm,
            'oem': '1',
            'preserve_interword_spaces': '1',
          },
        );

        final cleaned = _cleanText(text);

        if (cleaned.isNotEmpty) {
          results.add(cleaned);
        }
      } catch (_) {}
    }

    if (results.isEmpty) {
      return '';
    }

    results.sort(
      (a, b) => _qualityScore(b).compareTo(
        _qualityScore(a),
      ),
    );

    return results.first.trim();
  }

  String _cleanText(String text) {
    return text
        .replaceAll('\u0000', '')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  int _qualityScore(String text) {
    final value = text.trim();

    if (value.isEmpty) {
      return 0;
    }

    var score = value.length;

    final words = value
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .length;

    score += words * 6;

    final arabic = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]',
    ).allMatches(value).length;

    final latin = RegExp(
      r'[A-Za-z]',
    ).allMatches(value).length;

    score += arabic * 10;
    score += latin * 2;

    // Penalize obviously broken OCR consisting mostly of punctuation.
    final useful = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FFA-Za-z0-9]',
    ).allMatches(value).length;

    if (useful < 3) {
      score -= 1000;
    }

    return score;
  }

  Future<void> _ensureTessData(String language) async {
    final root = await FlutterTesseractOcr.getTessdataPath();

    final directory = Directory(root);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final file = File(
      p.join(root, '$language.traineddata'),
    );

    // Keep a valid existing model.
    const minimumSize = 100000;

    if (await file.exists()) {
      final size = await file.length();
      if (size >= minimumSize) {
        return;
      }

      // Remove incomplete/corrupt model.
      try {
        await file.delete();
      } catch (_) {}
    }

    final client = HttpClient();

    try {
      final url = Uri.parse(
        'https://raw.githubusercontent.com/'
        'tesseract-ocr/tessdata_best/main/$language.traineddata',
      );

      final request = await client.getUrl(url);
      request.headers.set(
        HttpHeaders.acceptEncodingHeader,
        'identity',
      );

      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw Exception(
          'Could not download OCR language data ($language): '
          'HTTP ${response.statusCode}',
        );
      }

      final bytes = <int>[];

      await for (final chunk in response) {
        bytes.addAll(chunk);
      }

      if (bytes.length < minimumSize) {
        throw Exception(
          'OCR language data for $language is incomplete '
          '(${bytes.length} bytes).',
        );
      }

      // IMPORTANT:
      // Write directly to the final traineddata path.
      // Do NOT create .download and do NOT rename it.
      await file.writeAsBytes(
        bytes,
        flush: true,
      );

      final savedSize = await file.length();

      if (savedSize < minimumSize) {
        try {
          await file.delete();
        } catch (_) {}

        throw Exception(
          'OCR language data for $language could not be saved correctly.',
        );
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> dispose() async {
    await _latin.close();
    _online?.dispose();
  }
}
