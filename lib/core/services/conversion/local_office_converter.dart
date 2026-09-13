import 'dart:io';

import 'package:file/local.dart';
import 'package:open_xml/open_xml.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../file_storage_service.dart';
import 'conversion_provider.dart';
import 'conversion_types.dart';

/// Local PDF -> Office conversion.
///
/// This converter intentionally focuses on reliable, on-device
/// PDF-to-Word, PDF-to-Excel and PDF-to-PowerPoint generation.
/// No cloud service or API key is required.
class LocalOfficeConverter implements ConversionProvider {
  const LocalOfficeConverter();

  @override
  String get id => 'local';

  @override
  String get displayName => 'On-device conversion';

  @override
  bool get isConfigured => true;

  static const LocalFileSystem _fs = LocalFileSystem();

  @override
  Future<File> convert({
    required String sourcePath,
    required ConversionFormat sourceFormat,
    required ConversionFormat targetFormat,
    required String outputFileName,
    required FileStorageService storage,
    void Function(ConversionPhase phase)? onPhase,
  }) async {
    if (sourceFormat != ConversionFormat.pdf) {
      throw const ConversionException(
        'Local conversion currently supports PDF to Word, Excel and PowerPoint.',
      );
    }

    if (targetFormat == ConversionFormat.pdf) {
      throw const ConversionException(
        'PDF is already the source format.',
      );
    }

    onPhase?.call(ConversionPhase.converting);

    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      throw const ConversionException(
        'The selected PDF file was not found.',
      );
    }

    final bytes = await sourceFile.readAsBytes();

    if (bytes.isEmpty) {
      throw const ConversionException(
        'The selected PDF file is empty.',
      );
    }

    final document = PdfDocument(inputBytes: bytes);

    try {
      final extractor = PdfTextExtractor(document);
      final pageTexts = <String>[];

      for (var pageIndex = 0;
          pageIndex < document.pages.count;
          pageIndex++) {
        final text = extractor
            .extractText(
              startPageIndex: pageIndex,
              endPageIndex: pageIndex,
              layoutText: true,
            )
            .trim();

        pageTexts.add(text);
      }

      final tmpDirectory = await storage.tmpDir;
      final outputPath = '${tmpDirectory.path}/$outputFileName';

      switch (targetFormat) {
        case ConversionFormat.docx:
          await _writeDocx(pageTexts, outputPath);
          break;

        case ConversionFormat.xlsx:
          await _writeXlsx(pageTexts, outputPath);
          break;

        case ConversionFormat.pptx:
          await _writePptx(pageTexts, outputPath);
          break;

        case ConversionFormat.pdf:
          throw const ConversionException(
            'PDF is already the source format.',
          );
      }

      final result = File(outputPath);

      if (!await result.exists()) {
        throw const ConversionException(
          'The local conversion did not produce an output file.',
        );
      }

      final size = await result.length();

      if (size == 0) {
        throw const ConversionException(
          'The local conversion produced an empty file.',
        );
      }

      return result;
    } finally {
      document.dispose();
    }
  }

  Future<void> _writeDocx(
    List<String> pageTexts,
    String outputPath,
  ) async {
    final doc = await WordDocument.create(_fs);

    doc.addParagraph(
      Paragraph()
        ..addRun(
          Run(
            text: 'Converted PDF Document',
            bold: true,
            fontSize: 22,
          ),
        ),
    );

    doc.addParagraph(
      Paragraph()
        ..addRun(
          Run(
            text: 'Generated locally by PDF Master Tools',
            italic: true,
            fontSize: 10,
          ),
        ),
    );

    for (var pageIndex = 0; pageIndex < pageTexts.length; pageIndex++) {
      doc.addParagraph(
        Paragraph()
          ..addRun(
            Run(
              text: 'Page ${pageIndex + 1}',
              bold: true,
              fontSize: 16,
            ),
          ),
      );

      final pageText = pageTexts[pageIndex].trim();

      if (pageText.isEmpty) {
        doc.addParagraph(
          Paragraph()
            ..addRun(
              Run(
                text: '[No selectable text found on this page]',
                italic: true,
              ),
            ),
        );
        continue;
      }

      final lines = pageText
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      for (final line in lines) {
        if (_looksLikeHeading(line)) {
          doc.addParagraph(
            Paragraph()
              ..addRun(
                Run(
                  text: line,
                  bold: true,
                  fontSize: 13,
                ),
              ),
          );
        } else {
          doc.addParagraph(
            Paragraph()..addRun(
              Run(
                text: line,
                fontSize: 11,
              ),
            ),
          );
        }
      }
    }

    await doc.save(_fs.file(outputPath));
  }

  Future<void> _writeXlsx(
    List<String> pageTexts,
    String outputPath,
  ) async {
    final workbook = await Workbook.create(_fs);
    final sheet = workbook.addSheet('PDF Text');

    sheet.addRow()
      ..addCell('Page')
      ..addCell('Line')
      ..addCell('Text');

    for (var pageIndex = 0; pageIndex < pageTexts.length; pageIndex++) {
      final pageText = pageTexts[pageIndex].trim();

      if (pageText.isEmpty) {
        sheet.addRow()
          ..addCell(pageIndex + 1)
          ..addCell(1)
          ..addCell('[No selectable text found]');
        continue;
      }

      final lines = pageText
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        sheet.addRow()
          ..addCell(pageIndex + 1)
          ..addCell(1)
          ..addCell('[No selectable text found]');
        continue;
      }

      for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        sheet.addRow()
          ..addCell(pageIndex + 1)
          ..addCell(lineIndex + 1)
          ..addCell(lines[lineIndex]);
      }
    }

    await workbook.save(_fs.file(outputPath));
  }

  Future<void> _writePptx(
    List<String> pageTexts,
    String outputPath,
  ) async {
    final presentation = await Presentation.create(_fs);

    for (var pageIndex = 0; pageIndex < pageTexts.length; pageIndex++) {
      final slide = presentation.addSlide();

      slide.addTitle('Page ${pageIndex + 1}');

      final pageText = pageTexts[pageIndex].trim();

      if (pageText.isEmpty) {
        slide.addText(
          '[No selectable text found on this page]',
        );
        slide.addNote(
          'This slide was generated from PDF page ${pageIndex + 1}.',
        );
        continue;
      }

      final lines = pageText
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        slide.addText(
          '[No selectable text found on this page]',
        );
      } else {
        final text = lines.join('\n');
        slide.addText(text);
      }

      slide.addNote(
        'This slide was generated from PDF page ${pageIndex + 1}.',
      );
    }

    await presentation.save(_fs.file(outputPath));
  }

  bool _looksLikeHeading(String text) {
    final value = text.trim();

    if (value.isEmpty || value.length > 90) {
      return false;
    }

    if (value.endsWith('.') ||
        value.endsWith(',') ||
        value.endsWith(';') ||
        value.endsWith(':')) {
      return false;
    }

    final words = value.split(RegExp(r'\s+'));

    if (words.length > 12) {
      return false;
    }

    final hasLetters = RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(value);

    if (!hasLetters) {
      return false;
    }

    return value.length <= 60;
  }
}
