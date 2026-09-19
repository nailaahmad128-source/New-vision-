import 'package:flutter/material.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import 'tool_router.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: const Text('All Tools'), backgroundColor: Colors.transparent),
    body: AppBackground(child: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 30), children: [
      _Category(title: 'PDF Tools', children: [
        _Tool('PDF to Word', Icons.description_rounded, AppColors.toolConvertWord, () => openTool(context, ToolId.pdfToWord)),
        _Tool('PDF to Excel', Icons.table_chart_rounded, AppColors.toolConvertExcel, () => openTool(context, ToolId.pdfToExcel)),
        _Tool('PDF to PPT', Icons.slideshow_rounded, AppColors.toolConvertPpt, () => openTool(context, ToolId.pdfToPpt)),
        _Tool('PDF to Images', Icons.photo_library_rounded, AppColors.toolPdfToImage, () => openTool(context, ToolId.pdfToImage)),
        _Tool('Long Image', Icons.view_agenda_rounded, AppColors.toolPdfToImage, () => openTool(context, ToolId.pdfToLongImage)),
        _Tool('Merge PDF', Icons.merge_type_rounded, AppColors.toolMerge, () => openTool(context, ToolId.merge)),
        _Tool('Extract Text', Icons.text_fields_rounded, AppColors.toolOcr, () => openTool(context, ToolId.extractText)),
        _Tool('Reorder Pages', Icons.reorder_rounded, AppColors.toolReorder, () => openTool(context, ToolId.reorder)),
        _Tool('Compress PDF', Icons.compress_rounded, AppColors.toolCompress, () => openTool(context, ToolId.compress)),
        _Tool('Protect PDF', Icons.lock_rounded, AppColors.toolSecurity, () => openTool(context, ToolId.security)),
      ]),
      _Category(title: 'Image Tools', children: [
        _Tool('Image to PDF', Icons.image_rounded, AppColors.toolImageToPdf, () => openTool(context, ToolId.imageToPdf)),
        _Tool('OCR', Icons.document_scanner_rounded, AppColors.toolOcr, () => openTool(context, ToolId.ocrImageToText)),
      ]),
      _Category(title: 'Edit & Sign', children: [
        _Tool('Sign', Icons.draw_rounded, AppColors.toolSign, () => openTool(context, ToolId.fillSign)),
        _Tool('Watermark', Icons.branding_watermark_rounded, AppColors.toolSecurity, () => openTool(context, ToolId.watermark)),
        _Tool('Rotate PDF', Icons.rotate_90_degrees_ccw_rounded, AppColors.toolRotate, () => openTool(context, ToolId.rotate)),
      ]),
    ])),
  );
}

class _Category extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Category({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            // 3-column grid, but the height is driven by the tallest content
            // (icon + up to two lines of wrapped title) rather than a fixed
            // aspect ratio, so long tool names never overflow their card.
            const crossAxisCount = 3;
            const spacing = 10.0;
            final cellWidth = (constraints.maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
            final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3);
            final cellHeight = 96.0 + (textScale - 1.0) * 40;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: cellWidth / cellHeight,
              ),
              itemCount: children.length,
              itemBuilder: (context, index) => children[index],
            );
          },
        ),
      ],
    ),
  );
}

class _Tool extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Tool(this.title, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .94), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.lightBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 21)),
          const SizedBox(height: 6),
          // Expanded lets the title claim exactly the remaining card height
          // instead of demanding its own intrinsic height, which is what
          // was causing "BOTTOM OVERFLOWED" errors for longer tool names.
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, height: 1.18),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
