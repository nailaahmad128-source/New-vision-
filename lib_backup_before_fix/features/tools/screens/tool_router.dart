import 'package:flutter/material.dart';
import '../../../core/constants/tools_catalog.dart';
import 'merge_screen.dart';
import 'split_screen.dart';
import 'page_selection_tool_screen.dart';
import 'compress_screen.dart';
import 'image_to_pdf_screen.dart';
import 'pdf_to_image_screen.dart';
import 'reorder_screen.dart';
import 'rotate_screen.dart';
import 'fill_screen.dart';
import 'security_screen.dart';
import 'watermark_screen.dart';
import '../../fill_sign/screens/fill_sign_screen.dart';
import '../../qr/screens/qr_scan_screen.dart';
import '../../qr/screens/qr_generate_screen.dart';
import 'id_scan_screen.dart';
import 'ocr_tool_screen.dart';
import 'text_to_speech_screen.dart';
import '../../translation/screens/translation_screen.dart';

void openTool(BuildContext context, ToolId id) {
  final screen = switch (id) {
    ToolId.merge => const MergeScreen(),
    ToolId.split => const SplitScreen(),
    ToolId.extractPages => const PageSelectionToolScreen(mode: PageSelectionMode.extract),
    ToolId.deletePages => const PageSelectionToolScreen(mode: PageSelectionMode.delete),
    ToolId.compress => const CompressScreen(),
    ToolId.imageToPdf => const ImageToPdfScreen(),
    ToolId.pdfToImage => const PdfToImageScreen(),
    ToolId.reorder => const ReorderScreen(),
    ToolId.rotate => const RotateScreen(),
    ToolId.fill => const FillScreen(),
    ToolId.fillSign => const FillSignScreen(),
    ToolId.security => const SecurityScreen(),
    ToolId.watermark => const WatermarkScreen(),
    ToolId.qrScan => const QrScanScreen(),
    ToolId.qrGenerate => const QrGenerateScreen(),
    ToolId.idScan => const IdScanScreen(),
    ToolId.ocr => const OcrToolScreen(),
    ToolId.translation => const TranslationScreen(initialText: ''),
    ToolId.textToSpeech => const TextToSpeechScreen(),
  };
  Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}
