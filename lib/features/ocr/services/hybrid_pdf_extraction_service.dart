import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'ocr_service.dart';

class HybridPdfPageResult {
  final int pageNumber;
  final String text;
  final bool usedOcr;

  const HybridPdfPageResult({
    required this.pageNumber,
    required this.text,
    required this.usedOcr,
  });
}

class HybridPdfExtractionService {
  final OcrService _ocr = OcrService();

  Future<List<HybridPdfPageResult>> extract(
    String pdfPath, {
    String language = 'auto',
    OcrCancelToken? cancelToken,
    void Function(int current, int total)? onProgress,
  }) async {
    final bytes = await File(pdfPath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final total = document.pages.count;
    final results = <HybridPdfPageResult>[];

    try {
      final tempDir = await getTemporaryDirectory();

      for (var pageIndex = 0; pageIndex < total; pageIndex++) {
        if (cancelToken?.isCancelled == true) {
          throw const OcrCancelledException();
        }

        String nativeText = '';
        try {
          nativeText = extractor
              .extractText(
                startPageIndex: pageIndex,
                endPageIndex: pageIndex,
                layoutText: true,
              )
              .trim();
        } catch (_) {
          nativeText = '';
        }

        // A very small amount of native text is often a scanned/image page
        // with only a stray PDF text object. OCR gives a much better result.
        final needsOcr = nativeText.length < 20;

        String finalText = nativeText;
        var usedOcr = false;

        if (needsOcr) {
          final imagePath = p.join(
            tempDir.path,
            'hybrid_pdf_${DateTime.now().microsecondsSinceEpoch}_$pageIndex.png',
          );

          try {
            await _renderPage(
              bytes,
              pageIndex,
              imagePath,
            );

            if (await File(imagePath).exists()) {
              final ocrText = await _ocr.extractText(
                imagePath,
                language: language,
                cancelToken: cancelToken,
              );

              if (ocrText.trim().isNotEmpty) {
                finalText = ocrText.trim();
                usedOcr = true;
              }
            }
          } finally {
            final file = File(imagePath);
            if (await file.exists()) {
              try {
                await file.delete();
              } catch (_) {}
            }
          }
        }

        results.add(
          HybridPdfPageResult(
            pageNumber: pageIndex + 1,
            text: finalText.trim(),
            usedOcr: usedOcr,
          ),
        );

        onProgress?.call(pageIndex + 1, total);
      }
    } finally {
      document.dispose();
    }

    return results;
  }

  Future<void> _renderPage(
    Uint8List pdfBytes,
    int pageIndex,
    String outputPath,
  ) async {
    await for (final page in Printing.raster(
      pdfBytes,
      dpi: 200,
      pages: [pageIndex],
    )) {
      final png = await page.toPng();
      await File(outputPath).writeAsBytes(png, flush: true);
      break;
    }
  }

  Future<void> dispose() async {
    await _ocr.dispose();
  }
}
