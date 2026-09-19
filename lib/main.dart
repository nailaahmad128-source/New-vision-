import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import 'core/storage/hive_boxes.dart';
import 'core/storage/app_data_controller.dart';
import 'core/services/file_storage_service.dart';
import 'core/services/pdf_tools_service.dart';
import 'core/services/ads_service.dart';
import 'core/theme/app_theme.dart';
import 'app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isWindows) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  await HiveBoxes.init();

  final storage = FileStorageService();
  final adsService = AdsService();

  // Initialize ads before the first screen so banner widgets can request
  // immediately. If AdMob fails, the app still starts normally.
  await adsService.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<FileStorageService>.value(value: storage),
        Provider<PdfToolsService>.value(
          value: PdfToolsService(storage),
        ),
        Provider<AdsService>.value(value: adsService),
        ChangeNotifierProvider(
          create: (_) => AppDataController(storage),
        ),
      ],
      child: const PdfMasterApp(),
    ),
  );
}

class PdfMasterApp extends StatelessWidget {
  const PdfMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppDataController>();
    final themeMode = switch (data.themeModeName) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return MaterialApp(
      title: 'ScanFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const AppShell(),
    );
  }
}
