import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../models/tool_history_entry.dart';
import '../../tools/widgets/tool_history_list.dart';

class QrScanScreen extends StatelessWidget {
  const QrScanScreen({super.key});

  Future<void> _showDesktopNotice(BuildContext context) async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('QR Scanner'),
      content: const Text('The Windows edition currently supports the full PDF/document workflow. Live QR camera scanning remains available on Android/iOS.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ));
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('QR Scanner'), actions: [
      IconButton(icon: const Icon(Icons.history_rounded), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ToolHistoryScreen(toolId: ToolId.qrScan, title: 'Scan History'))),),
    ]),
    body: Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.qr_code_scanner_rounded, size: 80, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        const Text('QR Scanner on Windows', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        const Text('Choose a QR image from your computer. Live camera scanning is kept for mobile.', textAlign: TextAlign.center),
        const SizedBox(height: 22),
        FilledButton.icon(onPressed: () async {
          final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
          if (context.mounted && r?.files.single.path != null) {
            await _showDesktopNotice(context);
          }
        }, icon: const Icon(Icons.image_search_rounded), label: const Text('Choose QR image')),
      ],
    )),
  );
}
