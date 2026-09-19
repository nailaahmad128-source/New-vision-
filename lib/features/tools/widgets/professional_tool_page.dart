
import 'package:flutter/material.dart';
import '../../../core/widgets/app_background.dart';

class ProfessionalToolPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Widget child;
  final Widget? history;

  const ProfessionalToolPage({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.child,
    this.history,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.fromLTRB(20, 22, 16, 20),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withOpacity(.42),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.35,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: scheme.surface.withOpacity(.82),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 38,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                    color: Colors.black.withOpacity(.055),
                  ),
                ],
              ),
              child: child,
            ),

            if (history != null) ...[
              const SizedBox(height: 22),
              history!,
            ],
          ],
          ),
        ),
      ),
    );
  }
}

class ProfessionalSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const ProfessionalSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

class ProfessionalFileCard extends StatelessWidget {
  final String name;
  final String? subtitle;
  final VoidCallback? onRemove;
  final VoidCallback? onChange;

  const ProfessionalFileCard({
    super.key,
    required this.name,
    this.subtitle,
    this.onRemove,
    this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: primary.withOpacity(.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.picture_as_pdf_rounded,
              color: primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onChange != null)
            IconButton(
              tooltip: 'Change',
              onPressed: onChange,
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }
}

class ProfessionalActionGrid extends StatelessWidget {
  final List<Widget> children;

  const ProfessionalActionGrid({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 3 : 2;

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: children,
        );
      },
    );
  }
}

class ProfessionalAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const ProfessionalAction({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(.55),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primary.withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfessionalPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  const ProfessionalPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(
          loading ? 'Working…' : label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
