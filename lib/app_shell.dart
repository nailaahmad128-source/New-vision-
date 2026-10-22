import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'core/services/ads_service.dart';
import 'core/widgets/banner_ad_slot.dart';
import 'features/home/screens/home_screen.dart';
import 'features/library/screens/library_screen.dart';
import 'features/trash/screens/trash_screen.dart';
import 'features/scanner/screens/smart_scanner_screen.dart';

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
    TrashScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdsService>().requestAppOpenShow();
      _checkScanFlowUpdate();
    });
  }


  Future<void> _checkScanFlowUpdate() async {
    if (!Platform.isAndroid || !mounted) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (!mounted) return;

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('scanflow_update_prompt_count');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt('scanflow_update_prompt_count') ?? 0) + 1;
      await prefs.setInt('scanflow_update_prompt_count', count);

      if (!mounted) return;

      if (count >= 5) {
        await _requireScanFlowUpdate();
      } else {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('ScanFlow Update Available'),
            content: Text(
              'A newer version of ScanFlow is available. '
              'Please update to get the latest improvements. '
              'Reminder $count of 5.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  try {
                    await InAppUpdate.performImmediateUpdate();
                  } catch (_) {}
                },
                child: const Text('Update Now'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      // Update checks must never prevent the app from opening.
    }
  }

  Future<void> _requireScanFlowUpdate() async {
    while (mounted) {
      final shouldRetry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update Required'),
          content: const Text(
            'Please update ScanFlow to continue using the app.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Update Now'),
            ),
          ],
        ),
      );

      if (!mounted || shouldRetry != true) return;

      try {
        await InAppUpdate.performImmediateUpdate();
        return;
      } catch (_) {
        // If update fails or is cancelled, show the required-update prompt again.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        reverseDuration: const Duration(milliseconds: 160),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0.018, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: _screens[_index],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_index == 0)
            const BannerAdSlot(placement: 'home'),
          if (_index == 1)
            const BannerAdSlot(placement: 'library'),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              if (i == _index) return;
              setState(() => _index = i);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder_rounded),
                label: 'Library',
              ),
              NavigationDestination(
                icon: Icon(Icons.document_scanner_outlined),
                selectedIcon: Icon(Icons.document_scanner_rounded),
                label: 'Scan',
              ),
              NavigationDestination(
                icon: Icon(Icons.delete_outline_rounded),
                selectedIcon: Icon(Icons.delete_rounded),
                label: 'Deleted',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
