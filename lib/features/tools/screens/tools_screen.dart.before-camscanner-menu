import 'package:flutter/material.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/theme/app_colors.dart';
import 'tool_router.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});
  @override State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tools = ToolsCatalog.all.where((t) {
      final q = query.trim().toLowerCase();
      return q.isEmpty || t.title.toLowerCase().contains(q) || t.subtitle.toLowerCase().contains(q);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('All PDF Tools')),
      body: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          sliver: SliverToBoxAdapter(child: TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(hintText: 'Search a tool', prefixIcon: Icon(Icons.search_rounded)),
          )),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          sliver: SliverToBoxAdapter(child: Text('Popular', style: theme.textTheme.titleMedium)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          sliver: SliverGrid.count(
            crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.25,
            children: ToolsCatalog.popularOnHome.map((id) => _ToolCard(tool: ToolsCatalog.byId(id))).toList(),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          sliver: SliverToBoxAdapter(child: Text('Every tool', style: theme.textTheme.titleMedium)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .95),
            itemCount: tools.length,
            itemBuilder: (_, i) => _LargeToolCard(tool: tools[i]),
          ),
        ),
      ]),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final ToolDef tool;
  const _ToolCard({required this.tool});
  @override Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: () => openTool(context, tool.id),
    child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
      CircleAvatar(backgroundColor: tool.color.withValues(alpha: .12), child: Icon(tool.icon, color: tool.color)),
      const SizedBox(width: 10), Expanded(child: Text(tool.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
    ]))),
  );
}

class _LargeToolCard extends StatelessWidget {
  final ToolDef tool;
  const _LargeToolCard({required this.tool});
  @override Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(22),
    onTap: () => openTool(context, tool.id),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: Theme.of(context).dividerColor), color: Theme.of(context).colorScheme.surface),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: tool.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)), child: Icon(tool.icon, color: tool.color, size: 27)),
        const Spacer(), Text(tool.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4), Text(tool.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
      ]),
    ),
  );
}
