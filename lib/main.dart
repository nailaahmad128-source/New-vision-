
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_shell.dart';
import 'features/splash/screens/splash_screen.dart';
import 'core/storage/hive_boxes.dart';
import 'core/storage/app_data_controller.dart';
import 'core/services/file_storage_service.dart';
import 'core/services/pdf_tools_service.dart';
import 'core/services/ads_service.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScanFlowBootstrap());
}

class ScanFlowBootstrap extends StatefulWidget {
  const ScanFlowBootstrap({super.key});

  @override
  State<ScanFlowBootstrap> createState() => _ScanFlowBootstrapState();
}

class _ScanFlowBootstrapState extends State<ScanFlowBootstrap> {
  double _progress = 0.02;
  String _status = 'Starting ScanFlow...';

  FileStorageService? _storage;
  AdsService? _adsService;
  AppDataController? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _update(double progress, String status) {
    if (!mounted) return;

    setState(() {
      _progress = progress;
      _status = status;
    });
  }

  Future<void> _initialize() async {
    try {
      _update(.08, 'Preparing workspace...');

      if (!Platform.isWindows) {
        try {
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
        } catch (_) {}
      }

      _update(.22, 'Loading secure storage...');
      await HiveBoxes.init();

      _update(.42, 'Preparing document tools...');
      final storage = FileStorageService();

      _update(.58, 'Connecting services...');
      final adsService = AdsService();

      // Ads are optional. A failure here must never block app startup.
      try {
        await adsService.init();
      } catch (_) {}

      _update(.78, 'Loading your preferences...');
      final data = AppDataController(storage);

      _storage = storage;
      _adsService = adsService;
      _data = data;

      _update(.94, 'Almost ready...');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      _update(1.0, 'Ready');

      // Keep the completed state visible briefly so the user actually
      // sees the loading reach 100% before the main app opens.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e;
        _status = 'Could not start ScanFlow';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _storage != null &&
        _adsService != null &&
        _data != null &&
        _error == null &&
        _progress >= 1.0;

    if (ready) {
      return PdfMasterApp(
        storage: _storage!,
        adsService: _adsService!,
        data: _data!,
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        body: Stack(
          children: [
            ScanFlowSplashScreen(
              progress: _progress,
              status: _error == null
                  ? _status
                  : 'Startup error — tap Retry',
            ),

            if (_error != null)
              Positioned(
                left: 28,
                right: 28,
                bottom: 78,
                child: Center(
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _progress = .02;
                        _status = 'Retrying...';
                        _storage = null;
                        _adsService = null;
                        _data = null;
                      });
                      _initialize();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PdfMasterApp extends StatelessWidget {
  final FileStorageService storage;
  final AdsService adsService;
  final AppDataController data;

  const PdfMasterApp({
    super.key,
    required this.storage,
    required this.adsService,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final themeMode = switch (data.themeModeName) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MultiProvider(
      providers: [
        Provider<FileStorageService>.value(value: storage),
        Provider<PdfToolsService>(
          create: (_) => PdfToolsService(storage),
        ),
        Provider<AdsService>.value(value: adsService),
        ChangeNotifierProvider<AppDataController>.value(value: data),
      ],
      child: MaterialApp(
        title: 'ScanFlow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: const AppShell(),
      ),
    );
  }
}
