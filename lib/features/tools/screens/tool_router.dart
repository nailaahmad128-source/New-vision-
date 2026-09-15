import 'package:flutter/material.dart';
import '../../../core/constants/tools_catalog.dart';
import 'merge_screen.dart';
import 'split_screen.dart';
import 'compress_screen.dart';
import 'image_to_pdf_screen.dart';
import 'pdf_to_image_screen.dart';
import 'pdf_to_long_image_screen.dart';
import 'pdf_extract_text_screen.dart';
import 'page_selection_tool_screen.dart';
import 'reorder_screen.dart';
import 'rotate_screen.dart';
import 'fill_screen.dart';
import 'security_screen.dart';
import 'watermark_screen.dart';
import 'text_to_speech_screen.dart';
import 'office_conversion_screen.dart';
import '../../fill_sign/screens/fill_sign_screen.dart';
import '../../qr/screens/qr_scan_screen.dart';
import '../../qr/screens/qr_generate_screen.dart';
import '../../translation/screens/translation_screen.dart';
import '../../ocr/screens/ocr_picker_screen.dart';
import '../../../core/services/conversion/conversion_types.dart';

void openTool(BuildContext context, ToolId id) {
  final screen = switch (id) {
    ToolId.merge => const MergeScreen(),
    ToolId.split => const SplitScreen(),
    ToolId.compress => const CompressScreen(),
    ToolId.imageToPdf => const ImageToPdfScreen(),
    ToolId.pdfToImage => const PdfToImageScreen(),
    ToolId.pdfToLongImage => const PdfToLongImageScreen(),
    ToolId.reorder => const ReorderScreen(),
    ToolId.rotate => const RotateScreen(),
    ToolId.fill => const FillScreen(),
    ToolId.fillSign => const FillSignScreen(),
    ToolId.security => const SecurityScreen(),
    ToolId.watermark => const WatermarkScreen(),
    ToolId.qrScan => const QrScanScreen(),
    ToolId.qrGenerate => const QrGenerateScreen(),
    ToolId.translate => const TranslationScreen(initialText: ''),
    ToolId.textToSpeech => const TextToSpeechScreen(),
    ToolId.ocrImageToText => const OcrPickerScreen(),
    ToolId.extractText => const PdfExtractTextScreen(),
    ToolId.extractPages => const PageSelectionToolScreen(
        mode: PageSelectionMode.extract,
    ),
    ToolId.deletePages => const PageSelectionToolScreen(
        mode: PageSelectionMode.delete,
    ),
    ToolId.pdfToWord => const OfficeConversionScreen(
        toolId: ToolId.pdfToWord, sourceFormat: ConversionFormat.pdf, targetFormat: ConversionFormat.docx, title: 'PDF to Word'),
    ToolId.wordToPdf => const OfficeConversionScreen(
        toolId: ToolId.wordToPdf, sourceFormat: ConversionFormat.docx, targetFormat: ConversionFormat.pdf, title: 'Word to PDF'),
    ToolId.pdfToExcel => const OfficeConversionScreen(
        toolId: ToolId.pdfToExcel, sourceFormat: ConversionFormat.pdf, targetFormat: ConversionFormat.xlsx, title: 'PDF to Excel'),
    ToolId.excelToPdf => const OfficeConversionScreen(
        toolId: ToolId.excelToPdf, sourceFormat: ConversionFormat.xlsx, targetFormat: ConversionFormat.pdf, title: 'Excel to PDF'),
    ToolId.pdfToPpt => const OfficeConversionScreen(
        toolId: ToolId.pdfToPpt, sourceFormat: ConversionFormat.pdf, targetFormat: ConversionFormat.pptx, title: 'PDF to PowerPoint'),
    ToolId.pptToPdf => const OfficeConversionScreen(
        toolId: ToolId.pptToPdf, sourceFormat: ConversionFormat.pptx, targetFormat: ConversionFormat.pdf, title: 'PowerPoint to PDF'),
  };
  Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}
