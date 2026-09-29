import 'dart:convert';
import 'dart:io';

import 'package:file/local.dart';
import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../features/ocr/services/ocr_service_io.dart';
import '../file_storage_service.dart';
import 'conversion_provider.dart';
import 'conversion_types.dart';

/// Structure-aware local PDF -> Office conversion.
///
/// The converter reads PDF text together with its position, font size,
/// font style and word boundaries. The extracted structure is then mapped
/// independently to Word, Excel and PowerPoint.
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


    final extension = sourcePath.toLowerCase().split('.').last;

    final isImage = const {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'heic',
      'heif',
    }.contains(extension);

    // Gallery / Scan image -> OCR -> editable Office file.
    if (isImage) {
      final tmpDirectory = await storage.tmpDir;
      final outputPath = '${tmpDirectory.path}/$outputFileName';

      final ocr = OcrService();

      try {
        onPhase?.call(ConversionPhase.converting);

        final text = await ocr.extractText(sourcePath);

        if (text.trim().isEmpty) {
          throw const ConversionException(
            'No readable text was found in this image. Please use a clearer image or scan.',
          );
        }

        switch (targetFormat) {
          case ConversionFormat.docx:
            await _writeDocxFromOcrText(
              text,
              outputPath,
            );
            break;

          case ConversionFormat.xlsx:
            await _writeXlsxFromOcrText(
              text,
              outputPath,
            );
            break;

          case ConversionFormat.pptx:
            await _writePptxFromOcrText(
              text,
              outputPath,
            );
            break;

          case ConversionFormat.pdf:
            throw const ConversionException(
              'PDF is already the source format.',
            );
        }

        final result = File(outputPath);

        if (!await result.exists() ||
            await result.length() == 0) {
          throw const ConversionException(
            'OCR conversion did not produce a valid output file.',
          );
        }

        return result;
      } finally {
        await ocr.dispose();
      }
    }

    final bytes = await sourceFile.readAsBytes();

    if (bytes.isEmpty) {
      throw const ConversionException(
        'The selected PDF file is empty.',
      );
    }

    final document = PdfDocument(inputBytes: bytes);

    try {
      final pages = _extractPages(document);

      final tmpDirectory = await storage.tmpDir;
      final outputPath = '${tmpDirectory.path}/$outputFileName';

      // Scanned/image-only PDF fallback:
      // PdfTextExtractor returns no lines for scanned pages, so run
      // the real OCR pipeline before generating Office output.
      final hasSelectableText =
          pages.any((page) => page.lines.isNotEmpty);

      if (!hasSelectableText) {
        onPhase?.call(ConversionPhase.converting);

        final ocr = OcrService();

        try {
          final text = await ocr.extractText(
            sourcePath,
            language: 'auto',
          );

          if (text.trim().isEmpty) {
            throw const ConversionException(
              'No readable text was found in this PDF. '
              'Please use a clearer scan.',
            );
          }

          switch (targetFormat) {
            case ConversionFormat.docx:
              await _writeDocxFromOcrText(
                text,
                outputPath,
              );
              break;

            case ConversionFormat.xlsx:
              await _writeXlsxFromOcrText(
                text,
                outputPath,
              );
              break;

            case ConversionFormat.pptx:
              await _writePptxFromOcrText(
                text,
                outputPath,
              );
              break;

            case ConversionFormat.pdf:
              throw const ConversionException(
                'PDF is already the source format.',
              );
          }

          final ocrResult = File(outputPath);

          if (!await ocrResult.exists() ||
              await ocrResult.length() == 0) {
            throw const ConversionException(
              'OCR conversion did not produce a valid output file.',
            );
          }

          return ocrResult;
        } finally {
          await ocr.dispose();
        }
      }

      switch (targetFormat) {
        case ConversionFormat.docx:
          await _writeDocx(pages, outputPath);
          break;

        case ConversionFormat.xlsx:
          await _writeXlsx(pages, outputPath);
          break;

        case ConversionFormat.pptx:
          await _writePptx(pages, outputPath);
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

  List<_ConvertedPage> _extractPages(PdfDocument document) {
    final extractor = PdfTextExtractor(document);
    final pages = <_ConvertedPage>[];

    for (var pageIndex = 0;
        pageIndex < document.pages.count;
        pageIndex++) {
      final lines = extractor.extractTextLines(
        startPageIndex: pageIndex,
        endPageIndex: pageIndex,
      );

      final sortedLines = [...lines]
        ..sort((a, b) {
          final y = a.bounds.top.compareTo(b.bounds.top);
          if (y != 0) return y;
          return a.bounds.left.compareTo(b.bounds.left);
        });

      final pageSize = document.pages[pageIndex].getClientSize();

      pages.add(
        _ConvertedPage(
          pageNumber: pageIndex + 1,
          width: pageSize.width,
          height: pageSize.height,
          lines: sortedLines,
        ),
      );
    }

    return pages;
  }

  String _sanitizeDocxText(String text) {
    return text.replaceAllMapped(
      RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'),
      (_) => ' ',
    );
  }

  String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  bool _containsRtl(String text) {
    return RegExp(r'[\u0590-\u08FF]').hasMatch(text);
  }

  String _docxRun(
    String text, {
    bool bold = false,
    bool italic = false,
    int fontSize = 11,
  }) {
    final escaped = _xmlEscape(_sanitizeDocxText(text));
    final rtl = _containsRtl(text);

    return '<w:r>'
        '<w:rPr>'
        '${bold ? '<w:b/>' : ''}'
        '${italic ? '<w:i/>' : ''}'
        '${rtl ? '<w:rtl/>' : ''}'
        '<w:sz w:val="${fontSize * 2}"/>'
        '</w:rPr>'
        '<w:t xml:space="preserve">$escaped</w:t>'
        '</w:r>';
  }

  String _docxParagraph(String content, {bool rtl = false}) {
    return '<w:p><w:pPr>${rtl ? '<w:bidi/>' : ''}</w:pPr>$content</w:p>';
  }

  Future<void> _saveStandardDocx(String outputPath, String body) async {
    final contentTypes = [
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
      '<Default Extension="rels" ContentType="application/vnd.openxmformats-package.relationships+xml"/>',
      '<Default Extension="xml" ContentType="application/xml"/>',
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '</Types>',
    ].join('');

    final rels = [
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relations/officeDocument" Target="word/document.xml"/>'
      '</Relationships>',
    ].join('');

    final document = [
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
      '<w:body>',
      body,
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/></w:sectPr>',
      '</w:body>',
      '</w:document>',
    ].join('');

    final archive = Archive();
    archive.addFile(ArchiveFile.bytes('[Content_Types].xml', utf8.ncode(contentTypes)));
    archive.addFile(ArchiveFile.bytes('_rels/.rels', utf8.ncode(rels)));
    archive.addFile(ArchiveFile.bytes('word/document.xml', utf8.encode(document)));

    final zipBytes = ZipEncoder().encode(archive);
    if (ripBytes.isEmpty) {
      throw const ConversionException('Failed to create DOCX package.');
    }

    await _fs.file(outputPath).writeAsBytes(ripBytes, flush: true);
    debugPrint('DOCX created: $outputPath (${ripBytes.length} bytes)');
  }
  Future<void> _writeDocx(
    List<_ConvertedPage> pages,
    String outputPath,
  ) async {
    final body = StringBuffer();

    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      if (pageIndex > 0) {
        body.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
      }

      final lines = pages[pageIndex].lines
          .map((line) => _sanitizeDocxText(line.trim()))
          .where((line) => line.isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        body.write(_docxParagraph(
          _docxRun('No readable text was found.', italic: true),
        ));
        continue;
      }

      for (final line in lines) {
        body.write(_docxParagraph(
          _docxRun(line),
          rtl: _containsRtl(line),
        ));
      }
    }

    if (body.isEmpty) {
      body.write(_docxParagraph(
        _docxRun('No readable text was found.', italic: true),
      ));
    }

    await _saveStandardDocx(outputPath, body.toString());
  }

  Future<void> _writeXlsx(
    List<_ConvertedPage> pages,
    String outputPath,
  ) async {
    final workbook = await Workbook.create(_fs);

    var createdSheet = false;

    for (final page in pages) {
      if (page.lines.isEmpty) {
        continue;
      }

      final sheet = workbook.addSheet(
        _sheetName('Page ${page.pageNumber}'),
      );

      createdSheet = true;

      if (_looksLikeTable(page.lines)) {
        final rows = _buildTableRows(page.lines);

        for (final values in rows) {
          final row = sheet.addRow();

          for (final value in values) {
            row.addCell(
              _excelCellValue(value),
            );
          }
        }
      } else {
        // For normal paragraphs, do not pretend that every PDF line
        // is a table. Keep one clean text column.
        sheet.addRow()
          ..addCell('Text');

        for (final line in page.lines) {
          final text = _sanitizeDocxText(line.text.trim());

          if (text.isEmpty) continue;

          sheet.addRow()
            ..addCell(text);
        }
      }
    }

    if (!createdSheet) {
      final sheet = workbook.addSheet('PDF Text');

      sheet.addRow()
        ..addCell('No selectable text found in this PDF.');
    }

    await workbook.save(_fs.file(outputPath));
  }

  dynamic _excelCellValue(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      return '';
    }

    final normalized =
        text.replaceAll(',', '').replaceAll(' ', '');

    final integerValue = int.tryParse(normalized);

    if (integerValue != null) {
      return integerValue;
    }

    final doubleValue = double.tryParse(normalized);

    if (doubleValue != null) {
      return doubleValue;
    }

    if (text.toLowerCase() == 'true') {
      return true;
    }

    if (text.toLowerCase() == 'false') {
      return false;
    }

    return text;
  }

  bool _looksLikeTable(List<TextLine> lines) {
    final usable = lines
        .where(
          (line) => line.wordCollection.length >= 2,
        )
        .toList();

    if (usable.length < 3) {
      return false;
    }

    // A real table normally has repeated vertical starting positions.
    final xPositions = <double>[];

    for (final line in usable) {
      for (final word in line.wordCollection) {
        xPositions.add(word.bounds.left);
      }
    }

    if (xPositions.length < 6) {
      return false;
    }

    xPositions.sort();

    final clusters = <double>[];

    for (final x in xPositions) {
      if (clusters.isEmpty ||
          (x - clusters.last).abs() > 16) {
        clusters.add(x);
      }
    }

    if (clusters.length < 2) {
      return false;
    }

    var repeatedColumns = 0;

    for (final columnX in clusters) {
      var lineCount = 0;

      for (final line in usable) {
        if (line.wordCollection.any(
          (word) =>
              (word.bounds.left - columnX).abs() <= 16,
        )) {
          lineCount++;
        }
      }

      if (lineCount >= 3) {
        repeatedColumns++;
      }
    }

    // Require at least two repeated columns and enough rows
    // before classifying the page as a table.
    return repeatedColumns >= 2 &&
        usable.length >= 3;
  }

  List<List<String>> _buildTableRows(
    List<TextLine> lines,
  ) {
    final usable = lines
        .where(
          (line) => line.wordCollection.isNotEmpty,
        )
        .toList();

    if (usable.isEmpty) {
      return const [];
    }

    // First group nearby PDF lines into visual rows using Y position.
    final visualRows = <List<TextWord>>[];

    for (final line in usable) {
      final words = [...line.wordCollection]
        ..sort(
          (a, b) => a.bounds.left.compareTo(
            b.bounds.left,
          ),
        );

      if (words.isEmpty) continue;

      List<TextWord>? target;

      for (final row in visualRows) {
        final referenceY = row.first.bounds.top;

        if ((line.bounds.top - referenceY).abs() <=
            (line.bounds.height.clamp(8, 24)) * 0.75) {
          target = row;
          break;
        }
      }

      if (target == null) {
        visualRows.add([...words]);
      } else {
        target.addAll(words);
      }
    }

    for (final row in visualRows) {
      row.sort(
        (a, b) => a.bounds.left.compareTo(
          b.bounds.left,
        ),
      );
    }

    // Detect stable column starts from all visual rows.
    final positions = <double>[];

    for (final row in visualRows) {
      for (final word in row) {
        positions.add(word.bounds.left);
      }
    }

    positions.sort();

    final columns = <double>[];

    for (final x in positions) {
      if (columns.isEmpty ||
          (x - columns.last).abs() > 16) {
        columns.add(x);
      }
    }

    final rows = <List<String>>[];

    for (final rowWords in visualRows) {
      final cells = List<String>.filled(
        columns.length,
        '',
      );

      for (final word in rowWords) {
        var nearest = 0;
        var distance =
            (word.bounds.left - columns[0]).abs();

        for (var i = 1; i < columns.length; i++) {
          final current =
              (word.bounds.left - columns[i]).abs();

          if (current < distance) {
            distance = current;
            nearest = i;
          }
        }

        final text = _sanitizeDocxText(word.text.trim());

        if (text.isEmpty) continue;

        if (cells[nearest].isEmpty) {
          cells[nearest] = text;
        } else {
          cells[nearest] =
              '${cells[nearest]} $text';
        }
      }

      while (cells.isNotEmpty &&
          cells.last.trim().isEmpty) {
        cells.removeLast();
      }

      if (cells.isNotEmpty &&
          cells.any((value) => value.isNotEmpty)) {
        rows.add(cells);
      }
    }

    return rows;
  }

  Future<void> _writePptx(
    List<_ConvertedPage> pages,
    String outputPath,
  ) async {
    final presentation = await Presentation.create(_fs);

    for (final page in pages) {
      final slide = presentation.addSlide();

      if (page.lines.isEmpty) {
        slide.addTitle('Page ${page.pageNumber}');
        slide.addText(
          'No selectable text was found on this PDF page.',
        );
        slide.addNote(
          'Generated from PDF page ${page.pageNumber}.',
        );
        continue;
      }

      // Recreate the PDF page as editable, independently positioned
      // PowerPoint text boxes. PDF points are converted to EMUs.
      for (final line in page.lines) {
        final text = _sanitizeDocxText(line.text.trim());

        if (text.isEmpty) continue;

        final x = _pointsToEmu(line.bounds.left);
        final y = _pointsToEmu(line.bounds.top);

        final width = _pointsToEmu(
          line.bounds.width < 20
              ? 120
              : line.bounds.width,
        );

        final height = _pointsToEmu(
          line.bounds.height < 10
              ? _safeFontSize(line.fontSize) * 1.8
              : line.bounds.height * 1.8,
        );

        slide.addTextBox(
          text: text,
          x: x,
          y: y,
          width: width,
          height: height,
          fontSize: _safeFontSize(line.fontSize).round(),
        );
      }

      slide.addNote(
        'Generated from PDF page ${page.pageNumber}. '
        'Text boxes remain editable in PowerPoint.',
      );
    }

    if (pages.isEmpty) {
      final slide = presentation.addSlide();
      slide.addTitle('PDF Conversion');
      slide.addText('The PDF contains no pages.');
    }

    await presentation.save(_fs.file(outputPath));
  }


  // =========================================================
  // IMAGE OCR -> WORD
  // =========================================================
  Future<void> _writeDocxFromOcrText(
    String text,
    String outputPath,
  ) async {
    final body = StringBuffer();

    final lines = _sanitizeDocxText(text)
        .split(RegExp(r'?
'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (final line in lines) {
      body.write(_docxParagraph(
        _docxRun(line),
        rtl: _containsRtl(line),
      ));
    }

    if (body.isEmpty) {
      body.write(_docxParagraph(
        _docxRun('No readable text was found.', italic: true),
      ));
    }

    await _saveStandardDocx(outputPath, body.toString());
  }

  Future<void> _writeXlsxFromOcrText(
    String text,
    String outputPath,
  ) async {
    final workbook = await Workbook.create(_fs);
    final sheet = workbook.addSheet('Extracted Text');

    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (normalized.isEmpty) {
      sheet.addRow()
        ..addCell('No readable text was found.');

      await workbook.save(_fs.file(outputPath));
      return;
    }

    final lines = normalized
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final hasTabs = lines.any((e) => e.contains('\t'));
    final hasPipes = lines.any((e) => e.contains('|'));

    if (hasTabs || hasPipes) {
      for (final line in lines) {
        final parts = hasTabs
            ? line.split('\t')
            : line.split('|');

        final row = sheet.addRow();

        for (final part in parts) {
          row.addCell(
            _excelCellValue(part.trim()),
          );
        }
      }
    } else {
      sheet.addRow()
        ..addCell('Extracted Text');

      for (final line in lines) {
        sheet.addRow()
          ..addCell(
            _excelCellValue(line),
          );
      }
    }

    await workbook.save(_fs.file(outputPath));
  }


  // =========================================================
  // IMAGE OCR -> POWERPOINT
  // =========================================================
  Future<void> _writePptxFromOcrText(
    String text,
    String outputPath,
  ) async {
    final presentation = await Presentation.create(_fs);

    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    final lines = normalized
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      final slide = presentation.addSlide();

      slide.addTitle('Extracted Text');
      slide.addText('No readable text was found.');

      await presentation.save(
        _fs.file(outputPath),
      );

      return;
    }

    var slide = presentation.addSlide();

    slide.addTitle('Extracted Text');

    var y = 850000;

    for (final line in lines) {
      const height = 520000;

      if (y + height > 6500000) {
        slide = presentation.addSlide();
        slide.addTitle('Extracted Text');
        y = 850000;
      }

      slide.addTextBox(
        text: line,
        x: 700000,
        y: y,
        width: 9000000,
        height: height,
        fontSize: 18,
      );

      y += height + 70000;
    }

    await presentation.save(
      _fs.file(outputPath),
    );
  }

  bool _looksLikeHeading(
    String text,
    double fontSize,
    List<TextLine> pageLines,
  ) {
    final value = text.trim();

    if (value.isEmpty || value.length > 100) {
      return false;
    }

    final averageFont = pageLines.isEmpty
        ? 11.0
        : pageLines
                .map((line) => _safeFontSize(line.fontSize))
                .reduce((a, b) => a + b) /
            pageLines.length;

    final shortEnough =
        value.split(RegExp(r'\s+')).length <= 14;

    return shortEnough &&
        (fontSize >= averageFont * 1.18 ||
            value.length <= 55);
  }

  bool _isBold(List<PdfFontStyle> styles) {
    return styles.contains(PdfFontStyle.bold);
  }

  bool _isItalic(List<PdfFontStyle> styles) {
    return styles.contains(PdfFontStyle.italic);
  }

  double _safeFontSize(double value) {
    if (value.isNaN || value.isInfinite) {
      return 11;
    }

    return value.clamp(7.0, 48.0).toDouble();
  }

  int _pointsToEmu(double points) {
    final value = (points * 12700).round();

    if (value < 10000) {
      return 10000;
    }

    return value;
  }

  String _sheetName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\\/:?*\[\]]'), '_');

    if (cleaned.length <= 31) {
      return cleaned;
    }

    return cleaned.substring(0, 31);
  }
}

class _ConvertedPage {
  final int pageNumber;
  final double width;
  final double height;
  final List<TextLine> lines;

  const _ConvertedPage({
    required this.pageNumber,
    required this.width,
    required this.height,
    required this.lines,
  });
}
