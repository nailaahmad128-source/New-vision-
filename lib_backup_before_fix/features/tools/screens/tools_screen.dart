import 'package:flutter/material.dart';
import '../../../core/constants/tools_catalog.dart';
import 'tool_router.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});
  @override State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  String _query = '';

  String _category(ToolId id) => switch (id) {
    ToolId.idScan || ToolId.qrScan => 'Scan',
    ToolId.imageToPdf || ToolId.qrGenerate => 'Create',
    ToolId.merge || ToolId.split || ToolId.extractPages || ToolId.deletePages || ToolId.reorder || ToolId.rotate || ToolId.compress => 'PDF Manage',
    ToolId.pdfToImage => 'Convert',
    ToolId.fill || ToolId.fillSign || ToolId.security || ToolId.watermark => 'Edit & Secure',
    ToolId.ocr || ToolId.translation || ToolId.textToSpeech => 'OCR & Language',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final filtered = ToolsCatalog.all.where((tool) => query.isEmpty || tool.title.toLowerCase().contains(query) || tool.subtitle.toLowerCase().contains(query)).toList();
    const categories = ['Scan', 'Create', 'PDF Manage', 'Convert', 'Edit & Secure', 'OCR & Language'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tools'),
        actions: [
          IconButton(
            tooltip: 'Search tools',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
            sliver: SliverToBoxAdapter(
              child: Text('Everything you need for scanning, PDFs and documents.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            sliver: SliverToBoxAdapter(
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search tools',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty ? null : IconButton(onPressed: () => setState(() => _query = ''), icon: const Icon(Icons.close_rounded)),
                ),
              ),
            ),
          ),
          if (query.isEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              sliver: SliverToBoxAdapter(child: Text('Popular', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.25,
                children: ToolsCatalog.popularOnHome.map((id) => _ToolCard(tool: ToolsCatalog.byId(id))).toList(),
              ),
            ),
          ],
          for (final category in categories)
            if (filtered.any((tool) => _category(tool.id) == category)) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: Row(children: [
                    Text(category, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('${filtered.where((t) => _category(t.id) == category).length}', style: theme.textTheme.bodySmall),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .98),
                  itemCount: filtered.where((t) => _category(t.id) == category).length,
                  itemBuilder: (_, i) => _LargeToolCard(tool: filtered.where((t) => _category(t.id) == category).elementAt(i)),
                ),
              ),
            ],
          if (filtered.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('No tools match your search.'))),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final ToolDef tool;
  const _ToolCard({required this.tool});
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => openTool(context, tool.id),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: tool.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)), child: Icon(tool.icon, color: tool.color, size: 21)),
          const SizedBox(width: 10),
          Expanded(child: Text(tool.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      ),
    ),
  );
}

class _LargeToolCard extends StatelessWidget {
  final ToolDef tool;
  const _LargeToolCard({required this.tool});
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => openTool(context, tool.id),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(color: tool.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)), child: Icon(tool.icon, color: tool.color, size: 26)),
          const Spacer(),
          Text(tool.title, style: const TextStyle(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(tool.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    ),
  );
}
