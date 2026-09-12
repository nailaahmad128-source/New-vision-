import 'package:flutter/material.dart';
import 'features/home/screens/home_screen.dart';
import 'features/library/screens/library_screen.dart';
import 'features/scanner/screens/smart_scanner_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/tools/screens/tools_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    LibraryScreen(),
    SmartScannerScreen(),
    ToolsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 5),
          child: Row(
            children: [
              _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home', selected: _index == 0, onTap: () => _select(0)),
              _NavItem(icon: Icons.folder_outlined, selectedIcon: Icons.folder_rounded, label: 'Library', selected: _index == 1, onTap: () => _select(1)),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _select(2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 58,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF5B4FE9), Color(0xFF8B5CF6)]),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: _index == 2
                              ? [BoxShadow(color: const Color(0xFF5B4FE9).withValues(alpha: .25), blurRadius: 14, offset: const Offset(0, 5))]
                              : null,
                        ),
                        child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(height: 2),
                      Text('Scan', style: TextStyle(fontSize: 11, fontWeight: _index == 2 ? FontWeight.w800 : FontWeight.w500, color: _index == 2 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              _NavItem(icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, label: 'Tools', selected: _index == 3, onTap: () => _select(3)),
              _NavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Me', selected: _index == 4, onTap: () => _select(4)),
            ],
          ),
        ),
      ),
    );
  }

  void _select(int index) => setState(() => _index = index);
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.selectedIcon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? selectedIcon : icon, color: color, size: 23),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
