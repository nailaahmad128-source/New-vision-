import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ToolId {
  merge,
  split,
  extractPages,
  deletePages,
  compress,
  imageToPdf,
  pdfToImage,
  reorder,
  rotate,
  fill,
  fillSign,
  security,
  watermark,
  qrScan,
  qrGenerate,
  idScan,
  ocr,
  translation,
  textToSpeech,
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
      id: ToolId.extractPages,
      title: 'Extract Pages',
      subtitle: 'Save selected pages as a new PDF',
      icon: Icons.content_cut_rounded,
      color: AppColors.toolSplit,
    ),
    ToolDef(
      id: ToolId.deletePages,
      title: 'Delete Pages',
      subtitle: 'Remove selected pages from a PDF',
      icon: Icons.delete_sweep_rounded,
      color: AppColors.toolSecurity,
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
      id: ToolId.idScan,
      title: 'ID Scanner',
      subtitle: 'Capture front and back into one PDF',
      icon: Icons.badge_rounded,
      color: AppColors.toolSign,
    ),
    ToolDef(
      id: ToolId.ocr,
      title: 'Image to Text',
      subtitle: 'Extract editable text with OCR',
      icon: Icons.text_snippet_rounded,
      color: AppColors.toolMerge,
    ),
    ToolDef(
      id: ToolId.translation,
      title: 'Smart Translation',
      subtitle: 'Translate extracted or typed text',
      icon: Icons.translate_rounded,
      color: AppColors.toolQrGen,
    ),
    ToolDef(
      id: ToolId.textToSpeech,
      title: 'Text to Speech',
      subtitle: 'Listen to text in multiple languages',
      icon: Icons.record_voice_over_rounded,
      color: AppColors.toolCompress,
    ),
    ToolDef(
      id: ToolId.qrGenerate,
      title: 'QR Generator',
      subtitle: 'Create and share a QR code',
      icon: Icons.qr_code_2_rounded,
      color: AppColors.toolQrGen,
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
