import 'package:flutter/material.dart';
import '../../../core/constants/tools_catalog.dart';

class PopularToolCard extends StatelessWidget {
  final ToolDef tool;
  final VoidCallback onTap;
  const PopularToolCard({super.key, required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(tool.icon, color: tool.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tool.title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
