import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/banner_ad_slot.dart';
import '../../tools/screens/tool_router.dart';
import '../../library/screens/library_screen.dart';
import '../../qr/screens/qr_scan_screen.dart';
import '../../qr/screens/qr_generate_screen.dart';
import '../../scanner/screens/smart_scanner_screen.dart';
import '../../translation/screens/translation_screen.dart';
import '../../tools/screens/tools_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../document/screens/document_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<AppDataController>(
      builder: (context, data, _) {
        final recent = data.documents.take(4).toList();
        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: AppColors.heroGradient),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PDF Master Tools', style: theme.textTheme.titleLarge),
                              Text('${data.documents.length} documents', style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Settings',
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                          icon: const Icon(Icons.settings_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => LibraryScreen(initialQuery: value.trim()),
                        ));
                      },
                      decoration: InputDecoration(
                        hintText: 'Search documents & text',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          tooltip: 'Documents',
                          icon: const Icon(Icons.folder_open_rounded),
                          onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const LibraryScreen())),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Create & Scan', style: theme.textTheme.titleMedium),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const SmartScannerScreen(),
                          )),
                          child: const Text('Scan now'),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  sliver: SliverGrid.count(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 10,
                    childAspectRatio: .82,
                    children: [
                      _Feature(icon: Icons.document_scanner_rounded, label: 'Smart Scan', color: AppColors.brandPrimary, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartScannerScreen()))),
                      _Feature(icon: Icons.picture_as_pdf_rounded, label: 'PDF Tools', color: AppColors.toolMerge, onTap: () => openTool(context, ToolId.merge)),
                      _Feature(icon: Icons.image_rounded, label: 'Import Images', color: AppColors.toolImageToPdf, onTap: () => openTool(context, ToolId.imageToPdf)),
                      _Feature(icon: Icons.file_open_rounded, label: 'Import Files', color: AppColors.toolSplit, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryScreen()))),
                      _Feature(icon: Icons.badge_rounded, label: 'ID Scan', color: AppColors.toolQrScan, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartScannerScreen()))),
                      _Feature(icon: Icons.text_fields_rounded, label: 'Extract Text', color: AppColors.toolFill, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartScannerScreen()))),
                      _Feature(icon: Icons.translate_rounded, label: 'Translate', color: AppColors.toolQrGen, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TranslationScreen(initialText: '')))),
                      _Feature(icon: Icons.apps_rounded, label: 'All Tools', color: AppColors.accentCoral, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ToolsScreen()))),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 26, 18, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recent documents', style: theme.textTheme.titleLarge),
                        if (recent.isNotEmpty)
                          TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryScreen())),
                            child: const Text('View all'),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  sliver: recent.isEmpty
                      ? SliverToBoxAdapter(child: _EmptyRecent(onScan: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartScannerScreen()))))
                      : SliverList.builder(
                          itemCount: recent.length,
                          itemBuilder: (context, index) {
                            final doc = recent[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: doc.thumbnailPath != null
                                      ? Image.file(File(doc.thumbnailPath!), width: 46, height: 52, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _RecentIcon(type: doc.type))
                                      : _RecentIcon(type: doc.type),
                                ),
                                title: Text(doc.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('${doc.pageCount ?? 1} page${(doc.pageCount ?? 1) == 1 ? '' : 's'} • ${doc.type.toUpperCase()}'),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentDetailScreen(doc: doc))),
                              ),
                            );
                          },
                        ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                const SliverToBoxAdapter(child: Center(child: BannerAdSlot())),
                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartScannerScreen())),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Scan'),
          ),
        );
      },
    );
  }
}

class _RecentIcon extends StatelessWidget {
  final String type;
  const _RecentIcon({required this.type});
  @override Widget build(BuildContext context) => Container(width: 46, height: 52, decoration: BoxDecoration(color: AppColors.brandPrimary.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: Icon(type == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded, color: AppColors.brandPrimary));
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Feature({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(height: 7),
          Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyRecent({required this.onScan});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 34, color: AppColors.brandPrimary),
            const SizedBox(width: 14),
            Expanded(child: Text('Your scanned documents will appear here.', style: Theme.of(context).textTheme.bodyMedium)),
            FilledButton(onPressed: onScan, child: const Text('Start')),
          ],
        ),
      ),
    );
  }
}
