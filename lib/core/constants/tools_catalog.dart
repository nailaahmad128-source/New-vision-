import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ToolId {
  merge,
  split,
  compress,
  imageToPdf,
  pdfToImage,
  pdfToLongImage,
  reorder,
  rotate,
  fill,
  fillSign,
  security,
  watermark,
  qrScan,
  qrGenerate,
  translate,
  textToSpeech,
  ocrImageToText,
  extractText,
  extractPages,
  deletePages,
  pdfToWord,
  pdfToExcel,
  pdfToPpt,
  wordToPdf,
  excelToPdf,
  pptToPdf,
}

class ToolDef {
  final ToolId id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const ToolDef({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  String get storageId => id.name;
}

class ToolsCatalog {
  ToolsCatalog._();

  static const List<ToolDef> all = [
    ToolDef(
      id: ToolId.merge,
      title: 'Merge PDF',
      subtitle: 'Combine multiple PDFs into one',
      icon: Icons.merge_type_rounded,
      color: AppColors.toolMerge,
    ),
    ToolDef(
      id: ToolId.split,
      title: 'Split PDF',
      subtitle: 'Break a PDF into separate files',
      icon: Icons.call_split_rounded,
      color: AppColors.toolSplit,
    ),
    ToolDef(
      id: ToolId.compress,
      title: 'Compress PDF',
      subtitle: 'Shrink file size',
      icon: Icons.compress_rounded,
      color: AppColors.toolCompress,
    ),
    ToolDef(
      id: ToolId.imageToPdf,
      title: 'Image to PDF',
      subtitle: 'Turn photos into a PDF',
      icon: Icons.image_rounded,
      color: AppColors.toolImageToPdf,
    ),
    ToolDef(
      id: ToolId.pdfToImage,
      title: 'PDF to Image',
      subtitle: 'Export pages as images',
      icon: Icons.photo_library_rounded,
      color: AppColors.toolPdfToImage,
    ),
    ToolDef(
      id: ToolId.reorder,
      title: 'Reorder Pages',
      subtitle: 'Drag pages into a new order',
      icon: Icons.reorder_rounded,
      color: AppColors.toolReorder,
    ),
    ToolDef(
      id: ToolId.rotate,
      title: 'Rotate PDF',
      subtitle: 'Fix sideways or upside-down pages',
      icon: Icons.rotate_right_rounded,
      color: AppColors.toolRotate,
    ),
    ToolDef(
      id: ToolId.fill,
      title: 'Fill PDF',
      subtitle: 'Fill in form fields',
      icon: Icons.edit_note_rounded,
      color: AppColors.toolFill,
    ),
    ToolDef(
      id: ToolId.fillSign,
      title: 'Fill & Sign',
      subtitle: 'Add text and your signature',
      icon: Icons.draw_rounded,
      color: AppColors.toolSign,
    ),
    ToolDef(
      id: ToolId.security,
      title: 'PDF Security',
      subtitle: 'Password protect or unlock',
      icon: Icons.lock_rounded,
      color: AppColors.toolSecurity,
    ),
    ToolDef(
      id: ToolId.watermark,
      title: 'Watermark PDF',
      subtitle: 'Add a custom watermark to every page',
      icon: Icons.branding_watermark_rounded,
      color: AppColors.toolSecurity,
    ),
    ToolDef(
      id: ToolId.qrScan,
      title: 'QR Scanner',
      subtitle: 'Scan any QR code',
      icon: Icons.qr_code_scanner_rounded,
      color: AppColors.toolQrScan,
    ),
    ToolDef(
      id: ToolId.qrGenerate,
      title: 'QR Generator',
      subtitle: 'Create and share a QR code',
      icon: Icons.qr_code_2_rounded,
      color: AppColors.toolQrGen,
    ),
    ToolDef(
      id: ToolId.translate,
      title: 'Translate Text',
      subtitle: 'Translate between English, Urdu, Arabic and more',
      icon: Icons.translate_rounded,
      color: AppColors.toolTranslate,
    ),
    ToolDef(
      id: ToolId.textToSpeech,
      title: 'Text to Speech',
      subtitle: 'Listen to any text read aloud',
      icon: Icons.record_voice_over_rounded,
      color: AppColors.toolTts,
    ),
    ToolDef(
      id: ToolId.ocrImageToText,
      title: 'Image to Text',
      subtitle: 'OCR any photo or PDF into editable text',
      icon: Icons.document_scanner_outlined,
      color: AppColors.toolOcr,
    ),
    ToolDef(
      id: ToolId.pdfToWord,
      title: 'PDF to Word',
      subtitle: 'Convert a PDF into an editable .docx',
      icon: Icons.description_rounded,
      color: AppColors.toolConvertWord,
    ),
    ToolDef(
      id: ToolId.wordToPdf,
      title: 'Word to PDF',
      subtitle: 'Convert a .docx into a PDF',
      icon: Icons.picture_as_pdf_rounded,
      color: AppColors.toolConvertWord,
    ),
    ToolDef(
      id: ToolId.pdfToExcel,
      title: 'PDF to Excel',
      subtitle: 'Convert a PDF into an editable .xlsx',
      icon: Icons.table_chart_rounded,
      color: AppColors.toolConvertExcel,
    ),
    ToolDef(
      id: ToolId.excelToPdf,
      title: 'Excel to PDF',
      subtitle: 'Convert an .xlsx into a PDF',
      icon: Icons.picture_as_pdf_rounded,
      color: AppColors.toolConvertExcel,
    ),
    ToolDef(
      id: ToolId.pdfToPpt,
      title: 'PDF to PowerPoint',
      subtitle: 'Convert a PDF into an editable .pptx',
      icon: Icons.slideshow_rounded,
      color: AppColors.toolConvertPpt,
    ),
    ToolDef(
      id: ToolId.pptToPdf,
      title: 'PowerPoint to PDF',
      subtitle: 'Convert a .pptx into a PDF',
      icon: Icons.picture_as_pdf_rounded,
      color: AppColors.toolConvertPpt,
    ),
  ];

  static ToolDef byId(ToolId id) => all.firstWhere((t) => t.id == id);

  static const List<ToolId> popularOnHome = [
    ToolId.merge,
    ToolId.split,
    ToolId.compress,
    ToolId.fillSign,
  ];
}
