import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../tools/widgets/tool_history_list.dart';

class QrGenerateScreen extends StatefulWidget {
  const QrGenerateScreen({super.key});
  @override
  State<QrGenerateScreen> createState() => _QrGenerateScreenState();
}

class _QrGenerateScreenState extends State<QrGenerateScreen> {
  final _controller = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();
  String _content = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Generator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Generated QR history',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ToolHistoryScreen(toolId: ToolId.qrGenerate, title: 'QR History'),
            )),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Text, URL, or any content',
                  hintText: 'https://example.com',
                ),
                onChanged: (v) => setState(() => _content = v),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: Center(
                  child: _content.trim().isEmpty
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_2_rounded, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text('Type something above to generate a QR code', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                          ],
                        )
                      : RepaintBoundary(
                          key: _qrKey,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: _content,
                              version: QrVersions.auto,
                              size: 240,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: AppColors.brandPrimary,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              if (_content.trim().isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saveToLibrary,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Save'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _share,
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> _captureImage() async {
    final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveToLibrary() async {
    final bytes = await _captureImage();
    if (bytes == null || !mounted) return;
    final storage = context.read<FileStorageService>();
    final data = context.read<AppDataController>();
    final fileName = 'QR_${DateTime.now().millisecondsSinceEpoch}.png';
    final tmp = await storage.newTmpFile(fileName);
    await tmp.writeAsBytes(bytes, flush: true);
    final doc = await data.registerToolResult(
      tmpFile: tmp,
      fileName: fileName,
      toolId: ToolId.qrGenerate.name,
      toolTitle: 'Generated QR code',
      type: 'image',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR code saved to QR History')),
    );
  }

  Future<void> _share() async {
    final bytes = await _captureImage();
    if (bytes == null || !mounted) return;
    final storage = context.read<FileStorageService>();
    final tmp = await storage.newTmpFile('qr_share.png');
    await tmp.writeAsBytes(bytes, flush: true);
    if (!mounted) return;
    await Share.shareXFiles([XFile(tmp.path)]);
  }
}
