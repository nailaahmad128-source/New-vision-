import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:image/image.dart' as img;
import 'file_storage_service.dart';
import 'image_codec_isolate.dart';

/// All heavy PDF manipulation lives here so tool screens stay thin. Every
/// method returns a File already written to the tmp/ scratch directory —
/// callers hand that off to [AppDataController.registerToolResult] which
/// commits it into the Library and writes the history entry.
class PdfToolsService {
  final FileStorageService storage;
  PdfToolsService(this.storage);

  /// Renders a small JPEG thumbnail of a PDF's first page (or, for image
  /// files, a downscaled copy) for use in Library/Tools history lists.
  Future<String?> generateThumbnail(String sourcePath, {required String type}) async {
    try {
      final thumbsDir = await storage.thumbnailsDir;
      final id = storage.newId().substring(0, 8);
      final outPath = '${thumbsDir.path}/$id.jpg';
      if (type == 'image') {
        final bytes = await File(sourcePath).readAsBytes();
        final jpg = await encodeJpgInBackground(bytes, quality: 80, resizeWidth: 160);
        if (jpg == null) return null;
        await File(outPath).writeAsBytes(jpg, flush: true);
        return outPath;
      }
      final bytes = await File(sourcePath).readAsBytes();
      await for (final page in Printing.raster(bytes, dpi: 72, pages: const [0])) {
        final png = await page.toPng();
        final jpg = await encodeJpgInBackground(png, quality: 80, resizeWidth: 160);
        if (jpg == null) break;
        await File(outPath).writeAsBytes(jpg, flush: true);
        return outPath;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Renders every page as an in-memory JPEG thumbnail for pick-and-reorder
  /// / pick-and-rotate UIs. Nothing here is written to the Library — it's
  /// pure preview data for a tool screen's working state.
  Future<List<Uint8List>> renderPageThumbnails(String path, {double dpi = 90}) async {
    final bytes = await File(path).readAsBytes();
    final thumbs = <Uint8List>[];
    await for (final page in Printing.raster(bytes, dpi: dpi)) {
      final png = await page.toPng();
      final jpg = await encodeJpgInBackground(png, quality: 78);
      if (jpg != null) thumbs.add(jpg);
    }
    return thumbs;
  }

  Future<int> pageCount(String path) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    final count = doc.pages.count;
    doc.dispose();
    return count;
  }

  /// Merge several PDFs (in the given order) into a single document.
  Future<File> merge(List<String> paths, {required String outputName}) async {
    final merged = PdfDocument();
    merged.pageSettings.margins.all = 0;
    for (final path in paths) {
      final src = PdfDocument(inputBytes: await File(path).readAsBytes());
      for (int i = 0; i < src.pages.count; i++) {
        final template = src.pages[i].createTemplate();
        final page = merged.pages.add();
        page.graphics.drawPdfTemplate(template, const Offset(0, 0), src.pages[i].size);
      }
      src.dispose();
    }
    final bytes = await merged.save();
    merged.dispose();
    final out = await storage.newTmpFile(outputName);
    await out.writeAsBytes(bytes, flush: true);
    return out;
  }

  /// Split a PDF into one file per contiguous page range, e.g. ranges =
  /// [[1,3],[4,4],[5,10]] (1-indexed, inclusive).
  Future<List<File>> split(
    String path, {
    required List<List<int>> ranges,
    required String baseOutputName,
  }) async {
    final src = PdfDocument(inputBytes: await File(path).readAsBytes());
    final outputs = <File>[];
    for (int r = 0; r < ranges.length; r++) {
      final start = ranges[r][0] - 1;
      final end = ranges[r][1] - 1;
      final out = PdfDocument();
      out.pageSettings.margins.all = 0;
      for (int i = start; i <= end && i < src.pages.count; i++) {
        final template = src.pages[i].createTemplate();
        final page = out.pages.add();
        page.graphics.drawPdfTemplate(template, const Offset(0, 0), src.pages[i].size);
      }
      final bytes = await out.save();
      out.dispose();
      final file = await storage.newTmpFile('${baseOutputName}_part${r + 1}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      outputs.add(file);
    }
    src.dispose();
    return outputs;
  }

  /// Creates a new PDF containing only the selected page indexes.
  /// [pageIndexes] are 0-based and are kept in the supplied order.
  Future<File> extractPages(
    String path, {
    required List<int> pageIndexes,
    required String outputName,
  }) async {
    return _rebuildWithPageIndexes(
      path,
      pageIndexes: pageIndexes,
      outputName: outputName,
    );
  }

  /// Creates a new PDF with the selected page indexes removed.
  /// [pageIndexes] are 0-based.
  Future<File> deletePages(
    String path, {
    required List<int> pageIndexes,
    required String outputName,
  }) async {
    final src = PdfDocument(inputBytes: await File(path).readAsBytes());
    final selected = pageIndexes.toSet();

    final remaining = <int>[
      for (var i = 0; i < src.pages.count; i++)
        if (!selected.contains(i)) i,
    ];

    src.dispose();

    if (remaining.isEmpty) {
      throw StateError('At least one page must remain in the PDF.');
    }

    return _rebuildWithPageIndexes(
      path,
      pageIndexes: remaining,
      outputName: outputName,
    );
  }

  Future<File> _rebuildWithPageIndexes(
    String path, {
    required List<int> pageIndexes,
    required String outputName,
  }) async {
    if (pageIndexes.isEmpty) {
      throw StateError('No pages were selected.');
    }

    final src = PdfDocument(inputBytes: await File(path).readAsBytes());
    final out = PdfDocument();
    out.pageSettings.margins.all = 0;

    for (final index in pageIndexes) {
      if (index < 0 || index >= src.pages.count) continue;

      final sourcePage = src.pages[index];
      final template = sourcePage.createTemplate();
      final page = out.pages.add();

      page.graphics.drawPdfTemplate(
        template,
        const Offset(0, 0),
        sourcePage.size,
      );
    }

    if (out.pages.count == 0) {
      out.dispose();
      src.dispose();
      throw StateError('No valid pages were selected.');
    }

    final bytes = await out.save();

    out.dispose();
    src.dispose();

    final file = await storage.newTmpFile(outputName);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Rebuild a document with pages in [newOrder] (0-indexed positions into
  /// the original document).
  Future<File> reorder(String path, List<int> newOrder, {required String outputName}) async {
    final src = PdfDocument(inputBytes: await File(path).readAsBytes());
    final out = PdfDocument();
    out.pageSettings.margins.all = 0;
    for (final idx in newOrder) {
      final template = src.pages[idx].createTemplate();
      final page = out.pages.add();
      page.graphics.drawPdfTemplate(template, const Offset(0, 0), src.pages[idx].size);
    }
    final bytes = await out.save();
    out.dispose();
    src.dispose();
    final file = await storage.newTmpFile(outputName);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }


  /// Rebuilds a PDF using the supplied page order and per-page rotations.
  /// [order] contains original 0-based page indexes. [rotations] contains
  /// additional clockwise rotation in degrees for each output page.
  Future<File> editPages(
    String path, {
    required List<int> order,
    required Map<int, int> rotations,
    required String outputName,
  }) async {
    final src = PdfDocument(inputBytes: await File(path).readAsBytes());
    final out = PdfDocument();
    out.pageSettings.margins.all = 0;

    for (var outputIndex = 0; outputIndex < order.length; outputIndex++) {
      final sourceIndex = order[outputIndex];
      if (sourceIndex < 0 || sourceIndex >= src.pages.count) continue;
      final sourcePage = src.pages[sourceIndex];
      final template = sourcePage.createTemplate();
      final page = out.pages.add();
      page.graphics.drawPdfTemplate(template, const Offset(0, 0), sourcePage.size);
      final degrees = ((rotations[outputIndex] ?? 0) % 360 + 360) % 360;
      if (degrees != 0) {
        page.rotation = _angleFor(degrees);
      }
    }

    final bytes = await out.save();
    out.dispose();
    src.dispose();
    final file = await storage.newTmpFile(outputName);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Rebuilds a PDF and optionally inserts image pages at output positions.
  /// A negative value in [order] means the matching entry in [insertedImages]
  /// is used instead of an original PDF page.
  Future<File> editPagesWithImages(
    String path, {
    required List<int> order,
    required Map<int, int> rotations,
    required List<Uint8List> insertedImages,
    required String outputName,
  }) async {
    final src = PdfDocument(inputBytes: await File(path).readAsBytes());
    final out = PdfDocument();
    out.pageSettings.margins.all = 0;
    for (var outputIndex = 0; outputIndex < order.length; outputIndex++) {
      final sourceIndex = order[outputIndex];
      final degrees = ((rotations[outputIndex] ?? 0) % 360 + 360) % 360;
      if (sourceIndex < 0) {
        final imageIndex = -sourceIndex - 1;
        if (imageIndex < 0 || imageIndex >= insertedImages.length) continue;
        final imageBytes = insertedImages[imageIndex];
        final decoded = img.decodeImage(imageBytes);
        if (decoded == null) continue;
        final image = PdfBitmap(imageBytes);
        final page = out.pages.add();
        final imageWidth = decoded.width.toDouble();
        final imageHeight = decoded.height.toDouble();
        final scale = (page.size.width / imageWidth).clamp(0.01, 1.0);
        final h = imageHeight * scale;
        final top = (page.size.height - h).clamp(0.0, page.size.height);
        page.graphics.drawImage(image, Rect.fromLTWH(0, top, page.size.width, h));
        if (degrees != 0) page.rotation = _angleFor(degrees);
        continue;
      }
      if (sourceIndex >= src.pages.count) continue;
      final sourcePage = src.pages[sourceIndex];
      final template = sourcePage.createTemplate();
      final page = out.pages.add();
      page.graphics.drawPdfTemplate(template, const Offset(0, 0), sourcePage.size);
      if (degrees != 0) page.rotation = _angleFor(degrees);
    }
    final bytes = await out.save();
    out.dispose();
    src.dispose();
    final file = await storage.newTmpFile(outputName);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Adds a light text watermark to every page and returns a new PDF.
  Future<File> watermark(
    String path, {
    required String text,
    required double fontSize,
    required String outputName,
  }) async {
    final src = PdfDocument(inputBytes: await File(path).readAsBytes());
    final font = PdfStandardFont(PdfFontFamily.helvetica, fontSize);
    final brush = PdfSolidBrush(PdfColor(145, 145, 145));
    for (var i = 0; i < src.pages.count; i++) {
      final page = src.pages[i];
      final size = page.size;
      page.graphics.drawString(
        text,
        font,
        brush: brush,
        bounds: Rect.fromLTWH(0, size.height * .48, size.width, fontSize + 12),
        format: PdfStringFormat(alignment: PdfTextAlignment.center, lineAlignment: PdfVerticalAlignment.middle),
      );
    }
    final bytes = await src.save();
    src.dispose();
    final file = await storage.newTmpFile(outputName);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Rotate specific pages (0-indexed) by 90/180/270 degrees clockwise.
  /// If [pageIndexes] is null, rotates every page.
  Future<File> rotate(
    String path, {
    required int degrees,
    List<int>? pageIndexes,
    required String outputName,
  }) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    final targets = pageIndexes ?? List.generate(doc.pages.count, (i) => i);
    final angle = _angleFor(degrees);
    for (final i in targets) {
      if (i < 0 || i >= doc.pages.count) continue;
      final current = doc.pages[i].rotation;
      doc.pages[i].rotation = _combine(current, angle);
    }
    final bytes = await doc.save();
    doc.dispose();
    final file = await storage.newTmpFile(outputName);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  PdfPageRotateAngle _angleFor(int degrees) {
    switch (degrees % 360) {
      case 90:
        return PdfPageRotateAngle.rotateAngle90;
      case 180:
        return PdfPageRotateAngle.rotateAngle180;
      case 270:
        return PdfPageRotateAngle.rotateAngle270;
      default:
        return PdfPageRotateAngle.rotateAngle0;
    }
  }

  PdfPageRotateAngle _combine(PdfPageRotateAngle current, PdfPageRotateAngle add) {
    const order = [
      PdfPageRotateAngle.rotateAngle0,
      PdfPageRotateAngle.rotateAngle90,
      PdfPageRotateAngle.rotateAngle180,
      PdfPageRotateAngle.rotateAngle270,
    ];
    final total = (order.indexOf(current) + order.indexOf(add)) % 4;
    return order[total];
  }

  /// Apply password protection / permission restrictions.
  Future<File> protect(
    String path, {
    String? userPassword,
    String? ownerPassword,
    bool allowPrinting = true,
    bool allowCopying = true,
    required String outputName,
  }) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    if (userPassword != null && userPassword.isNotEmpty) {
      doc.security.userPassword = userPassword;
    }
    if (ownerPassword != null && ownerPassword.isNotEmpty) {
      doc.security.ownerPassword = ownerPassword;
    }
    doc.security.permissions
      ..clear()
      ..addAll([
        if (allowPrinting) PdfPermissionsFlags.print,
        if (allowCopying) PdfPermissionsFlags.copyContent,
      ]);
    final bytes = await doc.save();
    doc.dispose();
    final file = await storage.newTmpFile(outputName);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Remove password protection given the correct current password.
  Future<File> removePassword(String path, String currentPassword, {required String outputName}) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes(), password: currentPassword);
    doc.security.userPassword = '';
    doc.security.ownerPassword = '';
    final bytes = await doc.save();
    doc.dispose();
    final file = await storage.newTmpFile(outputName);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Best-effort compression. Rasterizes each page at a quality-dependent
  /// DPI and re-encodes as JPEG, then rebuilds a new PDF from those images.
  /// This trades text-selectability for a real, predictable size
  /// reduction — the same strategy most consumer "Compress PDF" tools use
  /// for image-heavy or scanned documents.
  Future<File> compress(
    String path, {
    required CompressionLevel level,
    required String outputName,
  }) async {
    final bytes = await File(path).readAsBytes();
    final dpi = switch (level) {
      CompressionLevel.low => 130.0,
      CompressionLevel.medium => 100.0,
      CompressionLevel.high => 72.0,
    };
    final jpegQuality = switch (level) {
      CompressionLevel.low => 85,
      CompressionLevel.medium => 65,
      CompressionLevel.high => 45,
    };

    final pdfDoc = pw.Document();
    await for (final page in Printing.raster(bytes, dpi: dpi)) {
      final png = await page.toPng();
      final jpg = await encodeJpgInBackground(png, quality: jpegQuality);
      if (jpg == null) continue;
      final image = pw.MemoryImage(jpg);
      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(page.width.toDouble(), page.height.toDouble()),
          build: (context) => pw.Image(image, fit: pw.BoxFit.fill),
        ),
      );
    }
    final outBytes = await pdfDoc.save();
    final file = await storage.newTmpFile(outputName);
    await file.writeAsBytes(outBytes, flush: true);
    return file;
  }


Future<List<dynamic>?> _prepareImageForPdf(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    const maxWidth = 1800;

    final resized = decoded.width > maxWidth
        ? img.copyResize(
            decoded,
            width: maxWidth,
            interpolation: img.Interpolation.average,
          )
        : decoded;

    final jpg = img.encodeJpg(
      resized,
      quality: 88,
    );

    return <dynamic>[
      Uint8List.fromList(jpg),
      resized.width,
      resized.height,
    ];
  } catch (_) {
    return null;
  }
}


/// Build a single PDF from a sequence of image files, one image per page,
  /// each page sized to match its image's aspect ratio.
  Future<File> imagesToPdf(
    List<String> imagePaths, {
    required String outputName,
  }) async {
    final pdfDoc = pw.Document();

    for (final path in imagePaths) {
      final result = await compute(_prepareImageForPdf, path);
      if (result == null) continue;

      final jpg = result[0] as Uint8List;
      final width = result[1] as int;
      final height = result[2] as int;

      final image = pw.MemoryImage(jpg);

      const pageFormat = PdfPageFormat.a4;
      final pageWidth = pageFormat.availableWidth;
      final pageHeight = pageFormat.availableHeight;

      final ratio = width / height;

      var imageWidth = pageWidth;
      var imageHeight = imageWidth / ratio;

      if (imageHeight > pageHeight) {
        imageHeight = pageHeight;
        imageWidth = imageHeight * ratio;
      }

      pdfDoc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) => pw.Center(
            child: pw.SizedBox(
              width: imageWidth,
              height: imageHeight,
              child: pw.Image(
                image,
                fit: pw.BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    }

    final outBytes = await pdfDoc.save();
    final file = await storage.newTmpFile(outputName);
    await file.writeAsBytes(outBytes, flush: true);
    return file;
  }

  /// Rasterize every page of a PDF into a standalone JPEG image, returning
  /// one [File] per page.
  /// Rasterize all PDF pages and join them vertically into one JPEG.
  /// Pages are normalized to a common width while preserving their aspect
  /// ratios. A practical height limit prevents extremely large documents from
  /// exhausting mobile memory.
  Future<File> pdfToLongImage(
    String path, {
    required String baseOutputName,
    double dpi = 100,
  }) async {
    final bytes = await File(path).readAsBytes();
    final pages = <img.Image>[];

    const targetWidth = 1400;
    const maxOutputHeight = 30000;

    await for (final page in Printing.raster(bytes, dpi: dpi)) {
      final png = await page.toPng();
      final decoded = img.decodeImage(png);
      if (decoded == null) continue;

      final resized = decoded.width == targetWidth
          ? decoded
          : img.copyResize(
              decoded,
              width: targetWidth,
              interpolation: img.Interpolation.average,
            );

      pages.add(resized);
    }

    if (pages.isEmpty) {
      throw StateError('No pages could be rendered from this PDF.');
    }

    var totalHeight = 0;
    for (final page in pages) {
      totalHeight += page.height;
    }

    var scale = 1.0;
    if (totalHeight > maxOutputHeight) {
      scale = maxOutputHeight / totalHeight;
    }

    final outputWidth = (targetWidth * scale).round().clamp(1, targetWidth);
    final outputHeight = (totalHeight * scale).round().clamp(1, maxOutputHeight);

    final canvas = img.Image(
      width: outputWidth,
      height: outputHeight,
      numChannels: 3,
    );

    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    var y = 0;

    for (final page in pages) {
      final resized = scale == 1.0
          ? page
          : img.copyResize(
              page,
              width: outputWidth,
              height: (page.height * scale).round().clamp(1, outputHeight),
              interpolation: img.Interpolation.average,
            );

      img.compositeImage(
        canvas,
        resized,
        dstX: 0,
        dstY: y,
      );

      y += resized.height;
    }

    final jpg = img.encodeJpg(canvas, quality: 90);
    final file = await storage.newTmpFile(
      '${baseOutputName}_long_image.jpg',
    );

    await file.writeAsBytes(jpg, flush: true);

    return file;
  }

  Future<List<File>> pdfToImages(
    String path, {
    required String baseOutputName,
    double dpi = 150,
  }) async {
    final bytes = await File(path).readAsBytes();
    final outputs = <File>[];
    int pageNum = 1;
    await for (final page in Printing.raster(bytes, dpi: dpi)) {
      final png = await page.toPng();
      final file = await storage.newTmpFile('${baseOutputName}_page$pageNum.jpg');
      final jpg = await encodeJpgInBackground(png, quality: 92);
      if (jpg != null) {
        await file.writeAsBytes(jpg, flush: true);
        outputs.add(file);
      }
      pageNum++;
    }
    return outputs;
  }

  /// Flattens a set of user-placed overlay elements (signature/text/stamp
  /// images and free text) onto the source PDF, producing a signed / filled
  /// output. Coordinates are normalized (0..1) relative to each page's
  /// rendered size, which is how the Fill & Sign canvas reports drag/resize
  /// positions regardless of on-screen zoom level.
  Future<File> applyOverlays(
    String path, {
    required List<PdfOverlayElement> elements,
    required String outputName,
  }) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    for (final el in elements) {
      if (el.pageIndex < 0 || el.pageIndex >= doc.pages.count) continue;
      final page = doc.pages[el.pageIndex];
      final size = page.size;
      final x = el.normX * size.width;
      final y = el.normY * size.height;
      final w = el.normW * size.width;
      final h = el.normH * size.height;
      if (el is PdfOverlayImage) {
        final bytes = await File(el.imagePath).readAsBytes();
        final pdfImage = PdfBitmap(bytes);
        page.graphics.drawImage(pdfImage, Rect.fromLTWH(x, y, w, h));
      } else if (el is PdfOverlayText) {
        final font = PdfStandardFont(PdfFontFamily.helvetica, el.fontSize);
        page.graphics.drawString(
          el.text,
          font,
          brush: PdfSolidBrush(PdfColor(el.color.red, el.color.green, el.color.blue)),
          bounds: Rect.fromLTWH(x, y, w, h),
        );
      }
    }
    final bytes = await doc.save();
    doc.dispose();
    final file = await storage.newTmpFile(outputName);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Extracts AcroForm field names/types so Fill PDF can render a native
  /// form-filling UI when the source PDF actually has form fields; falls
  /// back to free-placement Fill & Sign otherwise.
  Future<List<PdfFormFieldInfo>> readFormFields(String path) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    final result = <PdfFormFieldInfo>[];
    final form = doc.form;
    for (int i = 0; i < form.fields.count; i++) {
      final field = form.fields[i];
      result.add(PdfFormFieldInfo(
        name: field.name ?? 'field_$i',
        pageIndex: field.page != null ? doc.pages.indexOf(field.page!) : 0,
        bounds: field.bounds,
        isText: field is PdfTextBoxField,
        isCheckbox: field is PdfCheckBoxField,
      ));
    }
    doc.dispose();
    return result;
  }

  /// Fills native AcroForm text/checkbox fields by name and flattens them
  /// into the page content so the result renders identically everywhere.
  Future<File> fillFormFields(
    String path, {
    required Map<String, String> textValues,
    required Map<String, bool> checkValues,
    required String outputName,
  }) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    final form = doc.form;
    for (int i = 0; i < form.fields.count; i++) {
      final field = form.fields[i];
      if (field is PdfTextBoxField && textValues.containsKey(field.name)) {
        field.text = textValues[field.name]!;
      } else if (field is PdfCheckBoxField && checkValues.containsKey(field.name)) {
        field.isChecked = checkValues[field.name]!;
      }
    }
    form.flattenAllFields();
    final bytes = await doc.save();
    doc.dispose();
    final file = await storage.newTmpFile(outputName);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

class PdfFormFieldInfo {
  final String name;
  final int pageIndex;
  final Rect bounds;
  final bool isText;
  final bool isCheckbox;
  PdfFormFieldInfo({
    required this.name,
    required this.pageIndex,
    required this.bounds,
    required this.isText,
    required this.isCheckbox,
  });
}

/// Base type for a user-placed element on the Fill & Sign canvas.
sealed class PdfOverlayElement {
  final int pageIndex;
  final double normX, normY, normW, normH;
  const PdfOverlayElement({
    required this.pageIndex,
    required this.normX,
    required this.normY,
    required this.normW,
    required this.normH,
  });
}

class PdfOverlayImage extends PdfOverlayElement {
  final String imagePath; // signature stroke render or stamp PNG
  const PdfOverlayImage({
    required super.pageIndex,
    required super.normX,
    required super.normY,
    required super.normW,
    required super.normH,
    required this.imagePath,
  });
}

class PdfOverlayText extends PdfOverlayElement {
  final String text;
  final double fontSize;
  final ({int red, int green, int blue}) color;
  const PdfOverlayText({
    required super.pageIndex,
    required super.normX,
    required super.normY,
    required super.normW,
    required super.normH,
    required this.text,
    this.fontSize = 14,
    this.color = (red: 0, green: 0, blue: 0),
  });
}

enum CompressionLevel { low, medium, high }
