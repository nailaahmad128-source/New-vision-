import 'package:flutter/material.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/theme/app_colors.dart';
import 'tool_router.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PDF Tools',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          _SectionTitle(title: 'Convert'),
          const SizedBox(height: 10),

          _ToolGrid(
            children: [
              _ToolItem(
                title: 'To Word',
                icon: Icons.description_rounded,
                color: AppColors.toolConvertWord,
                onTap: () => openTool(context, ToolId.pdfToWord),
              ),
              _ToolItem(
                title: 'To Excel',
                icon: Icons.table_chart_rounded,
                color: AppColors.toolConvertWord,
                onTap: () => openTool(context, ToolId.pdfToExcel),
              ),
              _ToolItem(
                title: 'To PPT',
                icon: Icons.slideshow_rounded,
                color: AppColors.toolConvertWord,
                onTap: () => openTool(context, ToolId.pdfToPpt),
              ),
              _ToolItem(
                title: 'PDF to Images',
                icon: Icons.photo_library_rounded,
                color: AppColors.toolPdfToImage,
                onTap: () => openTool(context, ToolId.pdfToImage),
              ),
              _ToolItem(
                title: 'PDF to Long Image',
                icon: Icons.view_agenda_rounded,
                color: AppColors.toolPdfToImage,
                onTap: () => openTool(context, ToolId.pdfToLongImage),
              ),
            ],
          ),

          const SizedBox(height: 26),

          _SectionTitle(title: 'Edit'),
          const SizedBox(height: 10),

          _ToolGrid(
            children: [
              _ToolItem(
                title: 'Sign',
                icon: Icons.draw_rounded,
                color: AppColors.toolSign,
                onTap: () => openTool(context, ToolId.fillSign),
              ),
              _ToolItem(
                title: 'Add Watermark',
                icon: Icons.branding_watermark_rounded,
                color: AppColors.toolSecurity,
                onTap: () => openTool(context, ToolId.watermark),
              ),
              _ToolItem(
                title: 'Compress PDF',
                icon: Icons.compress_rounded,
                color: AppColors.toolCompress,
                onTap: () => openTool(context, ToolId.compress),
              ),
              _ToolItem(
                title: 'Merge Files',
                icon: Icons.merge_type_rounded,
                color: AppColors.toolMerge,
                onTap: () => openTool(context, ToolId.merge),
              ),
              _ToolItem(
                title: 'PDF Extract',
                icon: Icons.content_cut_rounded,
                color: AppColors.toolSplit,
                onTap: () => openTool(context, ToolId.split),
              ),
              _ToolItem(
                title: 'Reorder Pages',
                icon: Icons.reorder_rounded,
                color: AppColors.toolReorder,
                onTap: () => openTool(context, ToolId.reorder),
              ),
              _ToolItem(
                title: 'Protect PDF',
                icon: Icons.lock_rounded,
                color: AppColors.toolSecurity,
                onTap: () => openTool(context, ToolId.security),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Seamlessly manage documents from other apps.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ToolGrid extends StatelessWidget {
  final List<Widget> children;

  const _ToolGrid({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (_, index) => children[index],
    );
  }
}

class _ToolItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ToolItem({
    required this.title,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 29,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
