import 'package:flutter/material.dart';

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            width: 84,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
