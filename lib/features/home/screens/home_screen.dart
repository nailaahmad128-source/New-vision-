import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/banner_ad_slot.dart';
import '../../tools/screens/tool_router.dart';
import '../../library/screens/library_screen.dart';
import '../../scanner/screens/smart_scanner_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../document/screens/document_detail_screen.dart';
import '../../tools/screens/tools_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<AppDataController>(
      builder: (context, data, _) {
        final recent = data.documents.take(4).toList();
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AppBackground(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  sliver: SliverToBoxAdapter(child: _Header(data: data)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  sliver: SliverToBoxAdapter(child: _SearchBar()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: _ScanHero(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartScannerScreen()))),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 8),
                  sliver: SliverToBoxAdapter(
                    child: _SectionHeader(title: 'Quick actions', action: 'All tools', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ToolsScreen()))),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  sliver: SliverToBoxAdapter(child: _QuickActions(context)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 8),
                  sliver: SliverToBoxAdapter(child: Text('Popular tools', style: theme.textTheme.titleLarge)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  sliver: SliverToBoxAdapter(child: _PopularTools(context)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 8),
                  sliver: SliverToBoxAdapter(
                    child: _SectionHeader(title: 'Recent documents', action: recent.isEmpty ? null : 'View all', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryScreen()))),
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
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
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final AppDataController data;
  const _Header({required this.data});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 50, height: 50, decoration: BoxDecoration(color: AppColors.brandPrimary, borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: const Text('SF', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900))),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ScanFlow', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), Text('${data.documents.length} documents', style: Theme.of(context).textTheme.bodySmall)])),
    IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())), icon: const Icon(Icons.settings_outlined)),
  ]);
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextField(
    textInputAction: TextInputAction.search,
    onSubmitted: (value) => Navigator.push(context, MaterialPageRoute(builder: (_) => LibraryScreen(initialQuery: value.trim()))),
    decoration: const InputDecoration(hintText: 'Search tools or documents', prefixIcon: Icon(Icons.search_rounded), suffixIcon: Icon(Icons.mic_none_rounded)),
  );
}

class _ScanHero extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanHero({required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.brandPrimary,
    borderRadius: BorderRadius.circular(26),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
        child: Row(children: [
          Container(width: 58, height: 58, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), shape: BoxShape.circle), child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 30)),
          const SizedBox(width: 16),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Scan Anything', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('Turn paper into clear PDF documents', style: TextStyle(color: Colors.white70, fontSize: 13))])),
          const Icon(Icons.arrow_forward_rounded, color: Colors.white),
        ]),
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title; final String? action; final VoidCallback? onTap;
  const _SectionHeader({required this.title, this.action, this.onTap});
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), if (action != null) TextButton(onPressed: onTap, child: Text(action!))]);
}

Widget _QuickActions(BuildContext context) => Row(children: [
  _ActionCard(icon: Icons.camera_alt_rounded, title: 'Scan', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartScannerScreen()))),
  _ActionCard(icon: Icons.image_rounded, title: 'Image to PDF', onTap: () => openTool(context, ToolId.imageToPdf)),
  _ActionCard(icon: Icons.folder_open_rounded, title: 'Files', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryScreen()))),
  _ActionCard(icon: Icons.apps_rounded, title: 'More', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ToolsScreen()))),
]);

Widget _PopularTools(BuildContext context) => GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.12, children: [
  _ToolCard('PDF to Word', Icons.description_rounded, AppColors.toolConvertWord, () => openTool(context, ToolId.pdfToWord)),
  _ToolCard('PDF to Excel', Icons.table_chart_rounded, AppColors.toolConvertExcel, () => openTool(context, ToolId.pdfToExcel)),
  _ToolCard('Extract Text', Icons.text_fields_rounded, AppColors.toolOcr, () => openTool(context, ToolId.extractText)),
  _ToolCard('Image to PDF', Icons.image_rounded, AppColors.toolImageToPdf, () => openTool(context, ToolId.imageToPdf)),
  _ToolCard('QR Generator', Icons.qr_code_2_rounded, AppColors.toolQrGen, () => openTool(context, ToolId.qrGenerate)),
  _ToolCard('PDF to Long Image', Icons.view_agenda_rounded, AppColors.toolPdfToImage, () => openTool(context, ToolId.pdfToLongImage)),
]);

class _ActionCard extends StatelessWidget { final IconData icon; final String title; final VoidCallback onTap; const _ActionCard({required this.icon, required this.title, required this.onTap}); @override Widget build(BuildContext context) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.lightBorder)), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: AppColors.brandPrimary, size: 26), const SizedBox(height: 7), Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.15))]))))); }
class _ToolCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ToolCard(this.title, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .94), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.lightBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 6),
          // Expanded (not Spacer) so the title absorbs remaining height
          // instead of forcing the card to overflow when it wraps to 2 lines.
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, height: 1.15)),
            ),
          ),
        ],
      ),
    ),
  );
}
class _RecentIcon extends StatelessWidget { final String type; const _RecentIcon({required this.type}); @override Widget build(BuildContext context) => Container(width: 46, height: 52, decoration: BoxDecoration(color: AppColors.brandPrimary.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: Icon(type == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded, color: AppColors.brandPrimary)); }
class _EmptyRecent extends StatelessWidget { final VoidCallback onScan; const _EmptyRecent({required this.onScan}); @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [const Icon(Icons.description_outlined, size: 44, color: AppColors.brandPrimary), const SizedBox(height: 10), const Text('No documents yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 5), const Text('Scan your first document to get started', textAlign: TextAlign.center), const SizedBox(height: 14), ElevatedButton.icon(onPressed: onScan, icon: const Icon(Icons.camera_alt_rounded), label: const Text('Start scanning'))]))); }
