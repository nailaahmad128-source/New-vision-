import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart' show canLaunchUrl, launchUrl, LaunchMode;
import 'package:collection/collection.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/app_settings_opener.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../models/tool_history_entry.dart';
import '../../tools/widgets/tool_history_list.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});
  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

enum _PermState { checking, granted, denied, permanentlyDenied }

class _QrScanScreenState extends State<QrScanScreen> {
  // autoStart: false — we drive `start()` ourselves so we can distinguish
  // "not granted yet" from "granted" without needing permission_handler.
  // mobile_scanner requests android.permission.CAMERA natively (the only
  // permission this screen needs) and reports the result through
  // MobileScannerException(errorCode: MobileScannerErrorCode.permissionDenied).
  final MobileScannerController _controller =
      MobileScannerController(autoStart: false);
  _PermState _perm = _PermState.checking;
  bool _requestedOnce = false;
  String? _lastValue;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    try {
      await _controller.start();
      if (!mounted) return;
      setState(() => _perm = _PermState.granted);
    } on MobileScannerException catch (e) {
      if (!mounted) return;
      if (e.errorCode == MobileScannerErrorCode.permissionDenied) {
        // First denial: the system dialog can still be shown again, so we
        // offer "Grant access". If the user is denied a second time,
        // Android will no longer show the dialog (or has been permanently
        // denied), so we send them to system settings instead.
        setState(() {
          _perm = _requestedOnce ? _PermState.permanentlyDenied : _PermState.denied;
          _requestedOnce = true;
        });
      } else {
        setState(() => _perm = _PermState.denied);
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code == _lastValue) return;
    setState(() => _lastValue = code);
    HapticFeedback.mediumImpact();
    _logScan(code);
    _showResultSheet(code);
  }

  void _logScan(String value) {
    final storage = context.read<FileStorageService>();
    final data = context.read<AppDataController>();
    final title = value.length > 60 ? '${value.substring(0, 60)}…' : value;
    data.addHistoryEntry(ToolHistoryEntry(
      id: storage.newId(),
      toolId: ToolId.qrScan.name,
      title: title,
      createdAt: DateTime.now(),
      success: true,
      note: value,
    ));
  }

  void _showResultSheet(String value) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_rounded, size: 22),
                  const SizedBox(width: 8),
                  Text('Scanned', style: Theme.of(ctx).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(value, style: Theme.of(ctx).textTheme.bodyLarge),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_looksLikeUrl(value))
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(value);
                          if (uri != null && await canLaunchUrl(uri)) {
                            launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open'),
                      ),
                    ),
                  if (_looksLikeUrl(value)) const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Share.share(value),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _lastValue = null);
                  },
                  child: const Text('Scan again'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _lastValue = null);
    });
  }

  bool _looksLikeUrl(String v) => v.startsWith('http://') || v.startsWith('https://');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('QR Scanner'),
        actions: [
          if (_perm == _PermState.granted)
            IconButton(
              icon: Icon(_torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
              onPressed: () {
                _controller.toggleTorch();
                setState(() => _torchOn = !_torchOn);
              },
            ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Scan history',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ToolHistoryScreen(toolId: ToolId.qrScan, title: 'Scan History'),
            )),
          ),
        ],
      ),
      body: switch (_perm) {
        _PermState.checking => const Center(child: CircularProgressIndicator(color: Colors.white)),
        _PermState.granted => MobileScanner(controller: _controller, onDetect: _onDetect),
        _PermState.denied => _PermissionMessage(
            title: 'Camera access needed',
            message: 'Allow camera access to scan QR codes.',
            buttonLabel: 'Grant access',
            onPressed: _requestPermission,
          ),
        _PermState.permanentlyDenied => _PermissionMessage(
            title: 'Camera access needed',
            message: 'Camera permission was denied. Enable it from system settings to scan QR codes.',
            buttonLabel: 'Open settings',
            onPressed: AppSettingsOpener.open,
          ),
      },
    );
  }
}

class _PermissionMessage extends StatelessWidget {
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;
  const _PermissionMessage({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_rounded, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
